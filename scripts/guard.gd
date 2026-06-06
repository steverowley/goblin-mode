extends CharacterBody2D
## A "tall folk" guard (greybox: a big, slow red lug with a vision cone).
##
## Built as three clear layers so new guard types are cheap to add later:
##   SENSES  — _can_see_player() (a facing cone with real line-of-sight) and
##             hear_noise() (discrete noise events, muffled by walls).
##   BRAIN   — _decide(): an explicit state machine over what the senses report.
##               PATROL      walk the loop.
##               INVESTIGATE heard something — go look where it came from.
##               CHASE       actually saw you — run you down (touch = nabbed).
##               SEARCH      lost sight — sweep the last-seen spot, then give up.
##   BODY    — _act(): move toward the brain's target; move_and_slide().
## A guard "type" is just a different STAT BLOCK (the vars below) — no new code.
## Sound alone never reaches CHASE; only SEEING you does. Dawn-tension sharpens
## the ears and quickens the step.

enum State { PATROL, INVESTIGATE, CHASE, SEARCH }

# --- Stat block: this is what makes a guard "type". Override after .new(). ---
var patrol_speed := 46.0
var chase_speed := 100.0
var view_dist := 205.0
var view_dist_lit := 320.0
var half_fov := deg_to_rad(34.0)
var hear_range := 330.0          # how far a loudness-1.0 noise carries with no walls
var hear_threshold := 0.12       # quieter than this (after falloff + walls) = unheard

# --- Shared behaviour tuning (the same for every guard). ---
const WALL_MUFFLE := 0.32        # a wall between guard and the sound dampens it to this
const HEAR_GAIN := 0.9           # how fast a heard noise raises suspicion
const INVESTIGATE_AT := 0.22     # suspicion above this (but below alert) = go and look
const SEE_FILL := 1.7            # how fast seeing you (unlit) fills suspicion
const SUSPICION_DECAY := 0.45    # how fast suspicion drains when it senses nothing
const SEARCH_TIME := 3.5         # seconds spent poking around last-seen before giving up
const INVESTIGATE_TIME := 4.0    # seconds chasing a heard-noise point before giving up
const SCAN_RATE := 1.5           # how fast the gaze sweeps while standing and searching
const CATCH_DIST := 24.0

const GoblinScript := preload("res://scripts/player.gd")

var waypoints: PackedVector2Array = PackedVector2Array()
var facing := Vector2.RIGHT
var state := State.PATROL
var suspicion := 0.0
var heard_pos := Vector2.ZERO      # where the last heard noise came from (look here)
var last_seen := Vector2.ZERO      # where the goblin was last actually seen

# Cheap flags the level reads for the HUD / markers.
var alerted := false
var investigating := false
var searching := false

var _wp := 0
var _player: GoblinScript = null
var _tension := 0.0
var _seen := false
var _search_t := 0.0
var _investigate_t := 0.0
var _caught := false
var _cone_pts := PackedVector2Array()   # the drawn vision cone, clipped to walls
var nav                                  # the level — provides nav_path() for doorway pathfinding
var _path := PackedVector2Array()        # current A* path to the move target
var _pi := 0                             # index of the next path node
var _path_goal := Vector2.ZERO           # the goal the current path was built for
var _repath_t := 0.0                     # countdown to the next path recompute

signal caught_player
signal spotted          # emitted the instant it freshly spots you (for an "OI!")

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

func _physics_process(delta: float) -> void:
	_seen = _can_see_player()
	if _seen and _player != null:
		last_seen = _player.global_position
		heard_pos = _player.global_position
	_decide(delta)
	_act(delta)

	if not _caught and state == State.CHASE and _player != null and global_position.distance_to(_player.global_position) < CATCH_DIST:
		_caught = true
		caught_player.emit()

	if state != State.CHASE:
		_compute_cone()
	queue_redraw()

# --- SENSES ---------------------------------------------------------------

## Called (via the level) whenever the goblin makes a noise. Sound that survives
## distance-falloff and wall-muffling raises suspicion and marks where to look —
## but it caps below full alert, so noise alone never nabs you.
func hear_noise(source: Vector2, loudness: float) -> void:
	if _player == null or state == State.CHASE:
		return
	var dist := global_position.distance_to(source)
	if dist >= hear_range:
		return
	var perceived := loudness * (1.0 - dist / hear_range)
	if not _has_line_of_sight(source):
		perceived *= WALL_MUFFLE
	var thresh := hear_threshold * (1.0 - 0.45 * _tension)   # sharper ears near dawn
	if perceived < thresh:
		return
	heard_pos = source
	# Only ever RAISE suspicion — never claw back progress the sight system made.
	suspicion = maxf(suspicion, minf(0.95, suspicion + perceived * HEAR_GAIN))

func _can_see_player() -> bool:
	if _player == null:
		return false
	var to := _player.global_position - global_position
	var dist := to.length()
	var max_dist := view_dist_lit if _player.is_lit else view_dist
	if dist > max_dist:
		return false
	if absf(facing.angle_to(to)) > half_fov:
		return false
	return _has_line_of_sight(_player.global_position)

func _has_line_of_sight(point: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, point, 0b01)
	return space.intersect_ray(query).is_empty()

## Build the drawn cone as a fan of rays that STOP at the first wall, so the
## visible cone matches the line-of-sight the guard actually has.
func _compute_cone() -> void:
	_cone_pts = PackedVector2Array()
	_cone_pts.append(Vector2.ZERO)
	var lit := _player != null and _player.is_lit
	var view := view_dist_lit if lit else view_dist
	var space := get_world_2d().direct_space_state
	var steps := 18
	var a0 := facing.angle() - half_fov
	for i in range(steps + 1):
		var a := a0 + (2.0 * half_fov) * (float(i) / float(steps))
		var d := Vector2(cos(a), sin(a))
		var q := PhysicsRayQueryParameters2D.create(global_position, global_position + d * view, 0b01)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			_cone_pts.append(d * view)
		else:
			_cone_pts.append(hit.position - global_position)

# --- BRAIN ----------------------------------------------------------------

func _decide(delta: float) -> void:
	if _seen and _player != null:
		suspicion = 1.0 if _player.is_lit else minf(1.0, suspicion + SEE_FILL * delta)
	else:
		suspicion = maxf(0.0, suspicion - SUSPICION_DECAY * delta)

	match state:
		State.PATROL:
			if _seen and suspicion >= 1.0:
				_to_chase()
			elif suspicion >= INVESTIGATE_AT:
				state = State.INVESTIGATE
				_investigate_t = INVESTIGATE_TIME
		State.INVESTIGATE:
			_investigate_t -= delta
			if _seen and suspicion >= 1.0:
				_to_chase()
			elif suspicion < INVESTIGATE_AT * 0.4 or _investigate_t <= 0.0:
				_to_patrol()
		State.CHASE:
			if not _seen and suspicion < 1.0:
				state = State.SEARCH
				_search_t = SEARCH_TIME
		State.SEARCH:
			if _seen and suspicion >= 1.0:
				_to_chase()
			else:
				_search_t -= delta
				if _search_t <= 0.0 or suspicion <= 0.0:
					_to_patrol()

	alerted = state == State.CHASE
	investigating = state == State.INVESTIGATE
	searching = state == State.SEARCH

func _to_chase() -> void:
	# Only shout "OI!" on a FRESH spot, not when re-acquiring mid-search.
	if state == State.PATROL or state == State.INVESTIGATE:
		spotted.emit()
	state = State.CHASE

func _to_patrol() -> void:
	state = State.PATROL
	_wp = _nearest_waypoint()

# --- BODY -----------------------------------------------------------------

func _act(delta: float) -> void:
	var p_speed := patrol_speed * (1.0 + 0.5 * _tension)
	var target := global_position
	var speed := 0.0
	match state:
		State.CHASE:
			target = _player.global_position if (_seen and _player != null) else last_seen
			speed = chase_speed * (1.0 + 0.15 * _tension)
		State.SEARCH:
			target = last_seen
			speed = chase_speed * 0.55
			if global_position.distance_to(target) < 10.0:
				speed = 0.0          # arrived — sweep the gaze around (below)
		State.INVESTIGATE:
			target = heard_pos
			speed = p_speed * 1.5
			if global_position.distance_to(target) < 8.0:
				speed = 0.0
		State.PATROL:
			if waypoints.size() > 0:
				target = waypoints[_wp]
				speed = p_speed
				if global_position.distance_to(target) < 6.0:
					_wp = (_wp + 1) % waypoints.size()

	# Steer along an A* path through doorways toward the target (the guard can't
	# walk through walls). Falls back to a straight line if there's no nav/route.
	var sub := target
	if speed > 0.0 and nav != null:
		sub = _path_step(target, delta)

	var to_sub := sub - global_position
	if to_sub.length() > 1.0 and speed > 0.0:
		var d := to_sub.normalized()
		velocity = d * speed
		facing = facing.lerp(d, 0.16).normalized()
	else:
		velocity = Vector2.ZERO
		# Standing at a noise/last-seen spot: sweep the cone to look around.
		if state == State.SEARCH or state == State.INVESTIGATE:
			facing = facing.rotated(SCAN_RATE * delta)
	move_and_slide()

## The next path node to steer toward on the way to `goal`, recomputing the A*
## path when the goal shifts or the recompute timer lapses.
func _path_step(goal: Vector2, delta: float) -> Vector2:
	_repath_t -= delta
	if _path.is_empty() or _path_goal.distance_to(goal) > 24.0 or _repath_t <= 0.0:
		_path = nav.nav_path(global_position, goal)
		_path_goal = goal
		_repath_t = 0.3
		_pi = 0
	while _pi < _path.size() and global_position.distance_to(_path[_pi]) < 12.0:
		_pi += 1
	if _pi < _path.size():
		return _path[_pi]
	return goal

func _nearest_waypoint() -> int:
	var best := 0
	var best_d := INF
	for i in range(waypoints.size()):
		var dd := global_position.distance_to(waypoints[i])
		if dd < best_d:
			best_d = dd
			best = i
	return best

# --- DRAW -----------------------------------------------------------------

func _draw() -> void:
	# Vision cone — hidden during a chase; clipped to walls (built in _compute_cone)
	# so it never pokes through them and matches the guard's real line-of-sight.
	if state != State.CHASE and _cone_pts.size() >= 3:
		var lit := _player != null and _player.is_lit
		var cone_col := Color(1, 0.85, 0.4, 0.16) if lit else Color(1, 1, 0.25, 0.06)
		if suspicion > 0.02:
			cone_col = Color(1, 0.55, 0.1, 0.13)
		draw_colored_polygon(_cone_pts, cone_col)

	# Big tall-folk body (deliberately larger than the goblin).
	draw_rect(Rect2(-16, -16, 32, 32), Color(0.8, 0.3, 0.3))
	draw_rect(Rect2(-16, -16, 32, 32), Color(0.5, 0.15, 0.15), false, 2.0)
	draw_line(Vector2.ZERO, facing * 22.0, Color.WHITE, 2.0)

	# State pip: red chase, sky-blue search, orange investigate, amber niggle.
	if state == State.CHASE:
		draw_circle(Vector2(0, -26), 5.0, Color(1, 0.15, 0.15))
	elif state == State.SEARCH:
		draw_circle(Vector2(0, -26), 4.0, Color(0.4, 0.8, 1.0))
	elif state == State.INVESTIGATE:
		draw_circle(Vector2(0, -26), 4.0, Color(1, 0.55, 0.1))
	elif suspicion > 0.05:
		draw_circle(Vector2(0, -26), 4.0, Color(1, 0.7, 0.1))
