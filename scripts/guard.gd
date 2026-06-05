extends CharacterBody2D
## A "tall folk" guard (greybox: a big, slow red lug with a vision cone).
##
## Deliberately big and dim next to the little goblin. Patrols a loop, sees you
## in its cone with clear line of sight (instant if you're lit), hears you if
## you're noisy (so smashing things nearby will bring it running), and once
## ALERTED it bellows "OI!" and gives chase. Touch you while alerted = nabbed.

const PATROL_SPEED := 46.0
const CHASE_SPEED := 100.0
const VIEW_DIST := 205.0
const VIEW_DIST_LIT := 320.0
const HALF_FOV := deg_to_rad(34.0)
const CATCH_DIST := 24.0

const GoblinScript := preload("res://scripts/player.gd")

var waypoints: PackedVector2Array = PackedVector2Array()
var facing := Vector2.RIGHT
var alerted := false
var suspicion := 0.0
var _wp := 0
var _player: GoblinScript = null
var _hearing := false
var _was_alerted := false

signal caught_player
signal spotted          # emitted the instant it becomes alerted (for an "OI!")

func setup(points: PackedVector2Array, player: GoblinScript) -> void:
	waypoints = points
	_player = player
	if waypoints.size() > 0:
		global_position = waypoints[0]
		if waypoints.size() > 1:
			facing = (waypoints[1] - waypoints[0]).normalized()

func _ready() -> void:
	collision_layer = 0b100
	collision_mask = 0b01
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(32, 32)
	cs.shape = rect
	add_child(cs)

func _physics_process(delta: float) -> void:
	var seen := _can_see_player()
	var heard := _can_hear_player()
	_hearing = heard

	if seen or heard:
		if seen and _player != null and _player.is_lit:
			suspicion = 1.0
		else:
			suspicion = minf(1.0, suspicion + 1.7 * delta)
	else:
		suspicion = maxf(0.0, suspicion - 0.5 * delta)

	if suspicion >= 1.0:
		alerted = true
	elif suspicion <= 0.0:
		alerted = false

	if alerted and not _was_alerted:
		spotted.emit()
	if _was_alerted and not alerted:
		_wp = _nearest_waypoint()
	_was_alerted = alerted

	var target := global_position
	var speed := 0.0
	if alerted and _player != null:
		target = _player.global_position
		speed = CHASE_SPEED
	elif waypoints.size() > 0:
		target = waypoints[_wp]
		speed = PATROL_SPEED
		if global_position.distance_to(target) < 6.0:
			_wp = (_wp + 1) % waypoints.size()

	var to_target := target - global_position
	if to_target.length() > 1.0 and speed > 0.0:
		var d := to_target.normalized()
		velocity = d * speed
		facing = facing.lerp(d, 0.16).normalized()
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	if alerted and _player != null and global_position.distance_to(_player.global_position) < CATCH_DIST:
		caught_player.emit()

	queue_redraw()

func _can_see_player() -> bool:
	if _player == null:
		return false
	var to := _player.global_position - global_position
	var dist := to.length()
	var max_dist := VIEW_DIST_LIT if _player.is_lit else VIEW_DIST
	if dist > max_dist:
		return false
	if absf(facing.angle_to(to)) > HALF_FOV:
		return false
	return _has_line_of_sight(_player.global_position)

func _can_hear_player() -> bool:
	if _player == null:
		return false
	var r := _player.noise_radius()
	if r < 8.0:
		return false
	return global_position.distance_to(_player.global_position) < r

func _has_line_of_sight(point: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, point, 0b01)
	return space.intersect_ray(query).is_empty()

func _nearest_waypoint() -> int:
	var best := 0
	var best_d := INF
	for i in range(waypoints.size()):
		var dd := global_position.distance_to(waypoints[i])
		if dd < best_d:
			best_d = dd
			best = i
	return best

func _draw() -> void:
	# Vision cone — hidden during a chase; longer when the player is lit.
	if not alerted:
		var lit := _player != null and _player.is_lit
		var cone_col := Color(1, 0.85, 0.4, 0.16) if lit else Color(1, 1, 0.25, 0.06)
		if suspicion > 0.02:
			cone_col = Color(1, 0.55, 0.1, 0.13)
		var view := VIEW_DIST_LIT if lit else VIEW_DIST
		var pts := PackedVector2Array()
		pts.append(Vector2.ZERO)
		var steps := 18
		var a0 := facing.angle() - HALF_FOV
		for i in range(steps + 1):
			var a := a0 + (2.0 * HALF_FOV) * (float(i) / float(steps))
			pts.append(Vector2(cos(a), sin(a)) * view)
		draw_colored_polygon(pts, cone_col)

	# Big tall-folk body (deliberately larger than the goblin).
	draw_rect(Rect2(-16, -16, 32, 32), Color(0.8, 0.3, 0.3))
	draw_rect(Rect2(-16, -16, 32, 32), Color(0.5, 0.15, 0.15), false, 2.0)
	draw_line(Vector2.ZERO, facing * 22.0, Color.WHITE, 2.0)

	# State pips.
	if alerted:
		draw_circle(Vector2(0, -26), 5.0, Color(1, 0.15, 0.15))     # chasing
	elif suspicion > 0.05:
		draw_circle(Vector2(0, -26), 4.0, Color(1, 0.7, 0.1))       # suspicious
	if _hearing and not alerted:
		draw_circle(Vector2(14, -26), 3.5, Color(0.4, 0.8, 1.0))    # heard you
