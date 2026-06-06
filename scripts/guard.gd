extends CharacterBody2D
## A "tall folk" guard (greybox: a big, slow red lug with a vision cone).
##
## Senses the goblin two ways: SIGHT (a facing cone with real line-of-sight —
## walls block it, and being lit makes you easy to spot) and HEARING (discrete
## noise events that fade with distance and are muffled by walls). What it does
## about it runs on a single suspicion meter:
##   PATROL      — walk the loop.
##   INVESTIGATE — heard something; go look where the sound came from.
##   CHASE       — actually saw you; run you down. Touch while alerted = nabbed.
## Sound alone never fully alerts it — noise brings the guard to LOOK; only
## SEEING you confirms the catch. As dawn nears, tension sharpens its ears and
## quickens its step.

const PATROL_SPEED := 46.0
const CHASE_SPEED := 100.0
const VIEW_DIST := 205.0
const VIEW_DIST_LIT := 320.0
const HALF_FOV := deg_to_rad(34.0)
const CATCH_DIST := 24.0

# Hearing.
const HEAR_RANGE := 330.0        # how far a loudness-1.0 noise carries with no walls
const HEAR_THRESHOLD := 0.12     # quieter than this (after falloff + walls) = unheard
const WALL_MUFFLE := 0.32        # a wall between guard and the sound dampens it to this
const HEAR_GAIN := 0.9           # how fast a heard noise raises suspicion
const INVESTIGATE_AT := 0.22     # suspicion above this (but below alert) = go and look
const SEE_FILL := 1.7            # how fast seeing you (unlit) fills suspicion
const SUSPICION_DECAY := 0.45    # how fast suspicion drains when it senses nothing

const GoblinScript := preload("res://scripts/player.gd")

var waypoints: PackedVector2Array = PackedVector2Array()
var facing := Vector2.RIGHT
var alerted := false
var investigating := false
var suspicion := 0.0
var heard_pos := Vector2.ZERO      # where the last heard noise came from (look here)
var _wp := 0
var _player: GoblinScript = null
var _last_seen := Vector2.ZERO
var _tension := 0.0
var _was_alerted := false
var _was_active := false           # was chasing or investigating last frame

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

func set_tension(t: float) -> void:
	_tension = clampf(t, 0.0, 1.0)

## Called (via the level) whenever the goblin makes a noise. Sound that survives
## distance-falloff and wall-muffling raises suspicion and marks where to look —
## but it caps below full alert, so noise never nabs you on its own.
func hear_noise(source: Vector2, loudness: float) -> void:
	if _player == null or alerted:
		return
	var dist := global_position.distance_to(source)
	if dist >= HEAR_RANGE:
		return
	var perceived := loudness * (1.0 - dist / HEAR_RANGE)
	if not _has_line_of_sight(source):
		perceived *= WALL_MUFFLE
	var thresh := HEAR_THRESHOLD * (1.0 - 0.45 * _tension)   # sharper ears near dawn
	if perceived < thresh:
		return
	heard_pos = source
	suspicion = minf(0.95, suspicion + perceived * HEAR_GAIN)

func _physics_process(delta: float) -> void:
	var seen := _can_see_player()
	if seen and _player != null:
		_last_seen = _player.global_position
		heard_pos = _player.global_position
		if _player.is_lit:
			suspicion = 1.0
		else:
			suspicion = minf(1.0, suspicion + SEE_FILL * delta)
	else:
		suspicion = maxf(0.0, suspicion - SUSPICION_DECAY * delta)

	if suspicion >= 1.0:
		alerted = true
	elif suspicion <= 0.0:
		alerted = false
	investigating = not alerted and suspicion >= INVESTIGATE_AT

	if alerted and not _was_alerted:
		spotted.emit()
	_was_alerted = alerted

	var patrol_speed := PATROL_SPEED * (1.0 + 0.5 * _tension)
	var target := global_position
	var speed := 0.0
	if alerted and _player != null:
		target = _player.global_position if seen else _last_seen
		speed = CHASE_SPEED * (1.0 + 0.15 * _tension)
	elif investigating:
		target = heard_pos
		speed = patrol_speed * 1.5
		if global_position.distance_to(target) < 8.0:
			speed = 0.0          # arrived — stand and scan while suspicion drains
	elif waypoints.size() > 0:
		target = waypoints[_wp]
		speed = patrol_speed
		if global_position.distance_to(target) < 6.0:
			_wp = (_wp + 1) % waypoints.size()

	# Just gave up a chase/search? Rejoin the patrol loop at its nearest point.
	if _was_active and not alerted and not investigating:
		_wp = _nearest_waypoint()
	_was_active = alerted or investigating

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

	# State pip: red = chasing, orange = investigating a noise, amber = a niggle.
	if alerted:
		draw_circle(Vector2(0, -26), 5.0, Color(1, 0.15, 0.15))
	elif investigating:
		draw_circle(Vector2(0, -26), 4.0, Color(1, 0.55, 0.1))
	elif suspicion > 0.05:
		draw_circle(Vector2(0, -26), 4.0, Color(1, 0.7, 0.1))
