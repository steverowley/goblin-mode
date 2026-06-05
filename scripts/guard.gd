class_name Guard
extends CharacterBody2D
## A "tall folk" guard (greybox: a red square with a vision cone).
##
## Patrols between waypoints. Spots you if you're inside its cone WITH a clear
## line of sight (instantly if you're standing in light); otherwise it has to
## get close. It can also HEAR you if you're inside your own noise radius.
## Detection fills a "suspicion" meter; when full the guard is ALERTED and
## chases. Touch you while alerted = caught.
##
## Production guards (AStarGrid2D pathfinding, shared Senses component, per-trait
## hearing) come later — see docs/03-technical-design-document.md decisions S, V, Q.

const PATROL_SPEED := 58.0
const CHASE_SPEED := 112.0
const VIEW_DIST := 210.0
const VIEW_DIST_LIT := 320.0
const HALF_FOV := deg_to_rad(34.0)   # cone half-angle
const CATCH_DIST := 18.0

var waypoints: PackedVector2Array = PackedVector2Array()
var facing := Vector2.RIGHT
var alerted := false
var suspicion := 0.0                  # 0..1; >=1 => alerted, <=0 => calm

var _wp := 0
var _player: Goblin = null
var _hearing := false                 # heard the player this frame (for the HUD/pip)
var _was_alerted := false             # for detecting the alert->calm transition

signal caught_player

func setup(points: PackedVector2Array, player: Goblin) -> void:
	waypoints = points
	_player = player
	if waypoints.size() > 0:
		global_position = waypoints[0]
		if waypoints.size() > 1:
			facing = (waypoints[1] - waypoints[0]).normalized()

func _ready() -> void:
	# Guard on collision layer 3, collides with walls (layer 1).
	collision_layer = 0b100
	collision_mask = 0b01
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(22, 22)
	cs.shape = rect
	add_child(cs)

func _physics_process(delta: float) -> void:
	var seen := _can_see_player()
	var heard := _can_hear_player()
	_hearing = heard

	if seen or heard:
		# Being lit + in view is an instant giveaway.
		if seen and _player != null and _player.is_lit:
			suspicion = 1.0
		else:
			suspicion = minf(1.0, suspicion + 1.8 * delta)
	else:
		suspicion = maxf(0.0, suspicion - 0.55 * delta)

	if suspicion >= 1.0:
		alerted = true
	elif suspicion <= 0.0:
		alerted = false

	# When calming down after a chase, resume patrol from the nearest waypoint.
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
		var dir := to_target.normalized()
		velocity = dir * speed
		facing = facing.lerp(dir, 0.18).normalized()
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
	# Ray only checks walls (layer 1); player/guard layers are ignored.
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, point, 0b01)
	var hit := space.intersect_ray(query)
	return hit.is_empty()   # nothing in the way => clear sight

func _nearest_waypoint() -> int:
	var best := 0
	var best_d := INF
	for i in range(waypoints.size()):
		var d := global_position.distance_to(waypoints[i])
		if d < best_d:
			best_d = d
			best = i
	return best

func _draw() -> void:
	# Vision cone — hidden during a chase (then the red guard itself is the threat).
	# Its length grows when the player is lit, matching the longer lit detection range.
	if not alerted:
		var lit := _player != null and _player.is_lit
		var cone_col := Color(1, 0.85, 0.4, 0.18) if lit else Color(1, 1, 0.25, 0.07)
		if suspicion > 0.02:
			cone_col = Color(1, 0.6, 0.12, 0.14)
		var view := VIEW_DIST_LIT if lit else VIEW_DIST
		var pts := PackedVector2Array()
		pts.append(Vector2.ZERO)
		var steps := 18
		var a0 := facing.angle() - HALF_FOV
		for i in range(steps + 1):
			var a := a0 + (2.0 * HALF_FOV) * (float(i) / float(steps))
			pts.append(Vector2(cos(a), sin(a)) * view)
		draw_colored_polygon(pts, cone_col)

	# Body + facing tick.
	draw_rect(Rect2(-11, -11, 22, 22), Color(0.85, 0.32, 0.32))
	draw_line(Vector2.ZERO, facing * 17.0, Color.WHITE, 2.0)

	# State pips above the guard.
	if alerted:
		draw_circle(Vector2(0, -22), 5.0, Color(1, 0.15, 0.15))      # spotted / chasing
	elif suspicion > 0.05:
		draw_circle(Vector2(0, -22), 4.0, Color(1, 0.7, 0.1))        # rising suspicion
	if _hearing and not alerted:
		draw_circle(Vector2(12, -22), 3.5, Color(0.4, 0.8, 1.0))     # heard a noise (blue)
