extends Node2D
## Milestone 0.5 "Fun Probe" — the GOBLIN cut.
##
## The first pass played like a tidy ninja. This one plays like a greedy gremlin:
##  - GREED: shinies scattered everywhere; grab all you dare, but a heavy sack
##    slows you and makes you louder.
##  - MISCHIEF: smash pots (loot pops out) and smash lanterns to KILL the light
##    and make shadows. Smashing is loud — guards come looking.
##  - GOBLIN MODE: wrecking + nicking fills a CHAOS meter; trigger the frenzy to
##    go feral (fast, weight-proof, deafening) and smash out the barred wall.
##  - FEEL: a small big-eared waddling menace with a growing sack vs a big slow
##    "tall folk" lug. Greybox shapes only.
##
## Still no warren/procgen/save (decisions log, decision D). Goal: nick as much
## as you can and escape (the OUT door, or smash the barred gate in frenzy)
## before the dawn timer — without getting nabbed.

const GoblinScript := preload("res://scripts/player.gd")
const GuardScript := preload("res://scripts/guard.gd")

const DAWN_SECONDS := 80.0
const DAWN_RAMP := 26.0          # final seconds where dawn-tension ramps the guards up
const GRAB_R := 20.0
const SMASH_R := 36.0
const PLAYER_START := Vector2(80, 470)
const EXIT_POS := Vector2(80, 80)
const EXIT_R := 34.0
const GATE_POS := Vector2(926, 270)     # barred wall section — smash out in frenzy
const GATE_R := 34.0

var _player: GoblinScript
var _guard: GuardScript

var _wall_rects: Array[Rect2] = []
var _loot: Array = []        # {pos, value, weight, taken}
var _lanterns: Array = []    # {pos, radius, lit}
var _pots: Array = []        # {pos, broken}
var _floaters: Array = []    # {pos, text, life, max, color}

var _time_left := DAWN_SECONDS
var _state := "play"         # play | won | lost
var _banked := 0

var _info: Label
var _banner: Label
var _tint: ColorRect
var _font: Font

func _ready() -> void:
	_font = ThemeDB.fallback_font
	_build_walls()
	_build_stuff()
	_build_actors()
	_build_hud()

func _build_walls() -> void:
	_add_wall(Rect2(0, 0, 960, 20))
	_add_wall(Rect2(0, 520, 960, 20))
	_add_wall(Rect2(0, 0, 20, 540))
	_add_wall(Rect2(940, 0, 20, 540))
	_add_wall(Rect2(300, 120, 40, 200))
	_add_wall(Rect2(480, 300, 240, 40))
	_add_wall(Rect2(300, 420, 240, 40))
	_add_wall(Rect2(640, 60, 40, 150))

func _add_wall(rect: Rect2) -> void:
	_wall_rects.append(rect)
	var body := StaticBody2D.new()
	body.collision_layer = 0b01
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	cs.position = rect.position + rect.size / 2.0
	body.add_child(cs)
	add_child(body)

func _build_stuff() -> void:
	# Shinies scattered around — grab as many as you dare (big ones weigh more).
	var spots := [
		Vector2(820, 140), Vector2(870, 200), Vector2(760, 110), Vector2(880, 430),
		Vector2(520, 120), Vector2(160, 160), Vector2(420, 470), Vector2(700, 470),
		Vector2(560, 220), Vector2(380, 250),
	]
	for i in range(spots.size()):
		var big: bool = (i % 3 == 0)
		_loot.append({"pos": spots[i], "value": (3 if big else 1), "weight": (3.0 if big else 1.0), "taken": false})
	# Lit lanterns — light = danger. Smash one to make a shadow.
	_lanterns.append({"pos": Vector2(820, 150), "radius": 110.0, "lit": true})
	_lanterns.append({"pos": Vector2(220, 380), "radius": 90.0, "lit": true})
	_lanterns.append({"pos": Vector2(560, 300), "radius": 95.0, "lit": true})
	# Pots — smash for chaos (some hide a shiny).
	_pots.append({"pos": Vector2(120, 120), "broken": false})
	_pots.append({"pos": Vector2(700, 360), "broken": false})
	_pots.append({"pos": Vector2(900, 110), "broken": false})
	_pots.append({"pos": Vector2(360, 470), "broken": false})

func _build_actors() -> void:
	_player = GoblinScript.new()
	_player.position = PLAYER_START
	add_child(_player)

	_guard = GuardScript.new()
	add_child(_guard)
	_guard.setup(PackedVector2Array([
		Vector2(700, 120), Vector2(880, 120), Vector2(880, 320), Vector2(640, 320),
	]), _player)
	_guard.caught_player.connect(_on_caught)
	_guard.spotted.connect(_on_spotted)
	# Footsteps reach the guard's ears through the noise router.
	_player.noise_made.connect(_emit_noise)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_tint = ColorRect.new()
	_tint.size = Vector2(960, 540)
	_tint.color = Color(0.4, 1.0, 0.3, 0.10)        # sickly-green frenzy wash
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.visible = false
	layer.add_child(_tint)

	_info = Label.new()
	_info.position = Vector2(16, 8)
	layer.add_child(_info)

	_banner = Label.new()
	_banner.position = Vector2(0, 230)
	_banner.size = Vector2(960, 80)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.visible = false
	layer.add_child(_banner)

func _physics_process(delta: float) -> void:
	if _state != "play":
		return

	# Lit by any still-burning lantern with a CLEAR line to the goblin — duck
	# behind a wall and that light no longer reaches you (you're in shadow, hidden).
	_player.is_lit = _lit_by_any()

	# Auto-grab loot on touch (goblins hoover up everything).
	for item in _loot:
		if not item.taken and _player.global_position.distance_to(item.pos) < GRAB_R:
			item.taken = true
			_player.add_loot(item.value, item.weight)
			_player.add_chaos(0.06)
			_emit_noise(item.pos, 0.30)      # a faint scuffle — risky right by a guard
			_spawn_text(item.pos, "heh heh", Color(1, 0.9, 0.3))

	# In frenzy you smash everything you barge into.
	if _player.frenzy:
		_smash_near(_player.global_position, SMASH_R, true)

	# Dawn — not a cliff: the last stretch ramps tension (guards quicken, ears sharpen).
	_time_left -= delta
	_guard.set_tension(clampf(1.0 - _time_left / DAWN_RAMP, 0.0, 1.0))
	if _time_left <= 0.0:
		_time_left = 0.0
		_lose("DAWN BROKE — sun's up, goblin's caught in the open.")

	# Win: reach the OUT door with loot, or smash the barred gate in frenzy.
	if _player.sack > 0 and _player.global_position.distance_to(EXIT_POS) < EXIT_R:
		_win()
	elif _player.frenzy and _player.global_position.distance_to(GATE_POS) < GATE_R:
		_win()

func _process(delta: float) -> void:
	for f in _floaters:
		f.life = f.life - delta
		f.pos = f.pos + Vector2(0, -14.0 * delta)
	_floaters = _floaters.filter(func(f): return f.life > 0.0)
	if _tint != null:
		_tint.visible = (_state == "play" and _player.frenzy)
	_update_info()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	if event.keycode == KEY_R:
		get_tree().reload_current_scene()
		return
	if _state != "play":
		return
	if event.keycode == KEY_SPACE:
		if _player.can_frenzy():
			_player.start_frenzy()
			_spawn_text(_player.global_position, "GOBLIN MODE!", Color(0.6, 1.0, 0.2))
	elif event.keycode == KEY_E:
		_smash_near(_player.global_position, SMASH_R, false)

## Route a noise event from somewhere in the world to everything that can hear.
## (One guard today; a loop over a guard list tomorrow.)
func _emit_noise(pos: Vector2, loudness: float) -> void:
	if _guard != null:
		_guard.hear_noise(pos, loudness)

## Is the goblin lit? Only by a burning lantern within reach AND with no wall
## between — so a wall (or a smashed-out lantern) carves a safe pocket of dark.
func _lit_by_any() -> bool:
	for L in _lanterns:
		if not L.lit:
			continue
		if _player.global_position.distance_to(L.pos) >= L.radius:
			continue
		if _clear(L.pos, _player.global_position):
			return true
	return false

func _clear(from: Vector2, to: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, to, 0b01)
	return space.intersect_ray(query).is_empty()

func _smash_near(pos: Vector2, radius: float, all_in_range: bool) -> void:
	for L in _lanterns:
		if L.lit and pos.distance_to(L.pos) < radius:
			L.lit = false
			_player.add_chaos(0.12)
			_player.bump_noise(0.85)
			_emit_noise(L.pos, 0.95)         # a smash carries far — guards come looking
			_spawn_text(L.pos, "*SMASH* lights out!", Color(1, 0.6, 0.2))
			if not all_in_range:
				return
	for p in _pots:
		if not p.broken and pos.distance_to(p.pos) < radius:
			p.broken = true
			_player.add_chaos(0.10)
			_player.bump_noise(0.80)
			_emit_noise(p.pos, 0.90)
			if int(p.pos.x) % 2 == 0:          # roughly half the pots hide loot
				_player.add_loot(1, 1.0)
				_spawn_text(p.pos, "*SMASH* shiny!", Color(1, 0.9, 0.3))
			else:
				_spawn_text(p.pos, "*SMASH*", Color(1, 0.6, 0.2))
			if not all_in_range:
				return

func _spawn_text(pos: Vector2, text: String, color: Color) -> void:
	_floaters.append({"pos": pos + Vector2(-12, -18), "text": text, "life": 1.2, "max": 1.2, "color": color})

func _on_caught() -> void:
	if _state == "play":
		_lose("NABBED! A great tall-folk fist scoops you up by the scruff.")

func _on_spotted() -> void:
	if _state == "play":
		_spawn_text(_guard.global_position, "OI!!", Color(1, 0.3, 0.3))

func _win() -> void:
	if _state != "play":
		return
	_state = "won"
	_banked = _player.sack
	_show_banner("LEGGED IT with %d shinies! What a menace.\nPress R to raid again." % _banked)

func _lose(reason: String) -> void:
	if _state != "play":
		return
	_state = "lost"
	_show_banner(reason + "\n(You were lugging %d shinies.) Press R to try again." % _player.sack)

func _show_banner(text: String) -> void:
	_banner.text = text
	_banner.visible = true
	# Freeze the world behind the banner.
	_player.velocity = Vector2.ZERO
	_guard.velocity = Vector2.ZERO
	_player.set_physics_process(false)
	_guard.set_physics_process(false)

func _update_info() -> void:
	var lines := PackedStringArray()
	lines.append("WASD move   Shift sneak   E smash   SPACE Goblin Mode   R restart")
	var tag := ""
	if _player.frenzy:
		tag = "  *** GOBLIN MODE! ***"
	elif _player.can_frenzy():
		tag = "  [FRENZY READY - press SPACE]"
	lines.append("Dawn %0.0fs   Sack %d (wt %0.0f)   Noise %s   Chaos %s%s" % [
		_time_left, _player.sack, _player.weight,
		_meter(_player.noise, 8), _meter(_player.chaos, 8), tag,
	])
	var flags := ""
	if _time_left < DAWN_RAMP:
		flags += "[DAWN COMING!]  "
	if _player.is_lit:
		flags += "[IN THE LIGHT!]  "
	if _guard.investigating:
		flags += "[GUARD HEARD SOMETHING]  "
	if _guard.alerted:
		flags += "[GUARD ON YOU!]"
	if flags != "":
		lines.append(flags.strip_edges())
	_info.text = "\n".join(lines)

func _meter(v: float, cells: int) -> String:
	var filled := int(round(clampf(v, 0.0, 1.0) * cells))
	return "[" + "#".repeat(filled) + "-".repeat(cells - filled) + "]"

func _draw() -> void:
	draw_rect(Rect2(0, 0, 960, 540), Color(0.08, 0.08, 0.12))
	# Lantern light pools (only those still lit).
	for L in _lanterns:
		if L.lit:
			draw_circle(L.pos, L.radius, Color(1.0, 0.85, 0.35, 0.16))
			draw_circle(L.pos, 7.0, Color(1.0, 0.9, 0.5))
		else:
			draw_circle(L.pos, 7.0, Color(0.25, 0.25, 0.3))     # doused lantern
	# Wall shadows cut the light pools — that's where it's safe to lurk.
	_draw_shadows()
	# Walls.
	for r in _wall_rects:
		draw_rect(r, Color(0.18, 0.18, 0.24))
	# Barred gate — smash out here in Goblin Mode.
	var frenzy := _player != null and _player.frenzy
	var gate_col := Color(0.75, 0.5, 0.2, 0.95) if frenzy else Color(0.45, 0.35, 0.2, 0.8)
	draw_rect(Rect2(GATE_POS.x - 6, GATE_POS.y - 28, 12, 56), gate_col)
	_label(GATE_POS + Vector2(-118, 2), "smash-out (frenzy) ->", Color(0.8, 0.7, 0.4, 0.85))
	# Exit (brightens once you're carrying loot).
	var carrying := _player != null and _player.sack > 0
	var ef := 0.42 if carrying else 0.16
	draw_circle(EXIT_POS, EXIT_R, Color(0.3, 0.7, 1.0, ef))
	draw_arc(EXIT_POS, EXIT_R, 0.0, TAU, 40, Color(0.4, 0.85, 1.0, 0.9), 4.0 if carrying else 2.0)
	_label(EXIT_POS + Vector2(-13, 2), "OUT", Color(0.7, 0.9, 1.0, 0.9))
	# Pots.
	for p in _pots:
		if not p.broken:
			draw_rect(Rect2(p.pos.x - 7, p.pos.y - 7, 14, 14), Color(0.5, 0.4, 0.3))
			draw_rect(Rect2(p.pos.x - 7, p.pos.y - 7, 14, 14), Color(0.3, 0.24, 0.18), false, 1.5)
	# Loot (shinies still on the floor).
	for item in _loot:
		if not item.taken:
			var s: float = 9.0 if item.value >= 3 else 6.0
			var p: Vector2 = item.pos
			draw_colored_polygon(PackedVector2Array([
				p + Vector2(0, -s), p + Vector2(s * 0.8, 0), p + Vector2(0, s), p + Vector2(-s * 0.8, 0),
			]), Color(1.0, 0.85, 0.2))
	# Where the guard is heading to investigate a noise it heard.
	if _guard != null and _guard.investigating:
		var hp: Vector2 = _guard.heard_pos
		draw_arc(hp, 15.0, 0.0, TAU, 24, Color(1, 0.55, 0.1, 0.6), 2.0)
		_label(hp + Vector2(-3, 5), "?", Color(1, 0.6, 0.15, 0.95))

	# Dawn closing in — warm red creeps from the edges.
	if _state == "play" and _time_left < DAWN_RAMP:
		var t: float = clampf(1.0 - _time_left / DAWN_RAMP, 0.0, 1.0)
		draw_rect(Rect2(0, 0, 960, 540), Color(0.95, 0.2, 0.1, 0.7 * t), false, 6.0 + 22.0 * t)

	# Floating "heh heh / SMASH / OI!" text.
	for f in _floaters:
		var a: float = clampf(f.life / f.max, 0.0, 1.0)
		var c: Color = f.color
		_label(f.pos, f.text, Color(c.r, c.g, c.b, a))

## Cast each wall's shadow away from each lit lantern, darkening the light pool
## behind it. Greybox approximation: project the wall's two silhouette corners.
func _draw_shadows() -> void:
	for L in _lanterns:
		if not L.lit:
			continue
		for r in _wall_rects:
			_draw_wall_shadow(L.pos, L.radius, r)

func _draw_wall_shadow(light: Vector2, radius: float, r: Rect2) -> void:
	if r.has_point(light):
		return
	# Skip walls whose nearest point falls outside this lantern's reach.
	var nearest := Vector2(clampf(light.x, r.position.x, r.end.x), clampf(light.y, r.position.y, r.end.y))
	if light.distance_to(nearest) > radius:
		return
	var corners := [
		r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y),
	]
	# Silhouette = the corners at the extreme angles as seen from the light.
	var base: float = (corners[0] - light).angle()
	var min_a := 0.0
	var max_a := 0.0
	var c_min: Vector2 = corners[0]
	var c_max: Vector2 = corners[0]
	for c in corners:
		var a: float = wrapf((c - light).angle() - base, -PI, PI)
		if a < min_a:
			min_a = a
			c_min = c
		elif a > max_a:
			max_a = a
			c_max = c
	var proj := radius * 2.2
	var p_min: Vector2 = c_min + (c_min - light).normalized() * proj
	var p_max: Vector2 = c_max + (c_max - light).normalized() * proj
	draw_colored_polygon(
		PackedVector2Array([c_min, c_max, p_max, p_min]),
		Color(0.08, 0.08, 0.12, 0.85),
	)

func _label(pos: Vector2, text: String, color: Color) -> void:
	if _font != null:
		draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)
