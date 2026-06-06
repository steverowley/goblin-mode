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

# Memory fog-of-war grid (the goblin only "sees" its cone + lit rooms; seen
# areas linger then fade back to black as it forgets).
const CELL := 16
const COLS := 60
const ROWS := 34
const CONE_LEN := 340.0
const CONE_HALF := deg_to_rad(60.0)   # 120° total — wide enough to read doorways
const NEAR_R := 54.0                  # always-clear bubble around the goblin
const FADE := 0.42                    # per-sec memory decay (~2.4s linger to black)
const ITEM_FADE := 0.32               # a forgotten shiny's "?" lingers a touch longer
const SEEN_T := 0.85                  # fog alpha cutoff: cell counts as clear
const REAL_THRESH := 0.6              # item.mem above this -> draw the real shiny
const Q_MIN := 0.05                   # below this -> "?" gone (forgotten)

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
var _overlay: Node2D          # light-immune layer that keeps crit cues bright in the dark
var _fog: Node2D              # the memory-fog draw node (on its own CanvasLayer)
var _mem := PackedFloat32Array()   # per-cell visibility memory (0 black .. 1 clear)
var _astar := AStarGrid2D.new()    # guard navigation grid (paths through doorways)
var _font: Font

func _ready() -> void:
	_font = ThemeDB.fallback_font
	_init_fog()
	_build_walls()
	_build_nav()
	_build_stuff()
	_build_actors()
	_build_hud()

func _init_fog() -> void:
	# The memory fog lives on its own CanvasLayer above the world (so it covers
	# the self-drawing walls/player/guard) but below the crit-cue overlay + HUD.
	_mem.resize(COLS * ROWS)
	_mem.fill(0.0)
	var fog_layer := CanvasLayer.new()
	fog_layer.layer = 1
	fog_layer.follow_viewport_enabled = true
	add_child(fog_layer)
	var fog := _FogDraw.new()
	fog.probe = self
	fog_layer.add_child(fog)
	_fog = fog

func _build_walls() -> void:
	# Outer shell.
	_add_wall(Rect2(0, 0, 960, 20))
	_add_wall(Rect2(0, 520, 960, 20))
	_add_wall(Rect2(0, 0, 20, 540))
	_add_wall(Rect2(940, 0, 20, 540))
	# Left vertical spine — doorway gap y230-330 into the central room.
	_add_wall(Rect2(300, 20, 20, 210))
	_add_wall(Rect2(300, 330, 20, 190))
	# Right vertical spine — doorway gap y130-210 into the central room.
	_add_wall(Rect2(640, 20, 20, 110))
	_add_wall(Rect2(640, 210, 20, 310))
	# Left horizontal divider — doorway gap x130-210 between the two left rooms.
	_add_wall(Rect2(20, 280, 110, 20))
	_add_wall(Rect2(210, 280, 110, 20))
	# Right horizontal divider — doorway gap x760-840 between the two right rooms.
	_add_wall(Rect2(640, 300, 120, 20))
	_add_wall(Rect2(840, 300, 100, 20))

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
	# Shinies, distributed through the rooms (big ones weigh more: indices 0,3,6,9).
	var spots := [
		Vector2(120, 90), Vector2(220, 160),                        # R1 (top-left)
		Vector2(420, 120), Vector2(540, 220), Vector2(470, 400),    # R3 (central)
		Vector2(740, 90), Vector2(880, 150), Vector2(820, 250),     # R4 (top-right)
		Vector2(760, 440), Vector2(900, 380),                       # R5 (bottom-right)
	]
	for i in range(spots.size()):
		var big: bool = (i % 3 == 0)
		_loot.append({"pos": spots[i], "value": (3 if big else 1), "weight": (3.0 if big else 1.0), "taken": false, "mem": 0.0})
	# One lantern per room (3 lit / 2 dark) — lit rooms glow, dark rooms need the cone.
	_lanterns.append({"pos": Vector2(150, 140), "radius": 100.0, "lit": false})  # R1 dark (exit room)
	_lanterns.append({"pos": Vector2(150, 430), "radius": 95.0, "lit": true})    # R2 start room glows
	_lanterns.append({"pos": Vector2(470, 270), "radius": 110.0, "lit": true})   # R3 bright crossing
	_lanterns.append({"pos": Vector2(800, 110), "radius": 95.0, "lit": false})   # R4 dark trophy room
	_lanterns.append({"pos": Vector2(800, 430), "radius": 100.0, "lit": true})   # R5 gate room glows
	# Pots — smash for chaos (some hide a shiny).
	_pots.append({"pos": Vector2(120, 470), "broken": false})   # R2
	_pots.append({"pos": Vector2(560, 470), "broken": false})   # R3
	_pots.append({"pos": Vector2(900, 90), "broken": false})    # R4
	_pots.append({"pos": Vector2(720, 470), "broken": false})   # R5

func _build_actors() -> void:
	_player = GoblinScript.new()
	_player.position = PLAYER_START
	add_child(_player)

	_guard = GuardScript.new()
	_guard.nav = self          # the guard pathfinds through doorways via the level's A* grid
	add_child(_guard)
	# Guard loops the central room (R3) — the chokepoint the goblin must cross.
	# It can now path through doorways to chase and investigate across rooms.
	_guard.setup(PackedVector2Array([
		Vector2(400, 100), Vector2(560, 100), Vector2(560, 460), Vector2(400, 460),
	]), _player)
	_guard.caught_player.connect(_on_caught)
	_guard.spotted.connect(_on_spotted)
	# Footsteps reach the guard's ears through the noise router.
	_player.noise_made.connect(_emit_noise)

func _build_hud() -> void:
	# Crit-cue overlay on its own CanvasLayer (immune to the night CanvasModulate),
	# so guard markers, floaters, and the dawn vignette stay readable in the dark.
	var overlay_layer := CanvasLayer.new()
	overlay_layer.layer = 2
	overlay_layer.follow_viewport_enabled = true   # stay aligned if a camera is added later
	add_child(overlay_layer)
	var ov := _OverlayDraw.new()
	ov.probe = self
	overlay_layer.add_child(ov)
	_overlay = ov

	var layer := CanvasLayer.new()
	layer.layer = 3
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

	# Update the memory fog (what the goblin currently sees / is forgetting).
	_update_fog(delta)

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

	# Win first, so reaching the OUT door (with loot) or smashing the gate in
	# frenzy on the very last frame counts as a win, not a dawn loss.
	if _player.sack > 0 and _player.global_position.distance_to(EXIT_POS) < EXIT_R:
		_win()
	elif _player.frenzy and _player.global_position.distance_to(GATE_POS) < GATE_R:
		_win()

	# Dawn breaks — caught in the open.
	if _state == "play" and _time_left <= 0.0:
		_time_left = 0.0
		_lose("DAWN BROKE — sun's up, goblin's caught in the open.")

func _process(delta: float) -> void:
	for f in _floaters:
		f.life = f.life - delta
		f.pos = f.pos + Vector2(0, -14.0 * delta)
	_floaters = _floaters.filter(func(f): return f.life > 0.0)
	if _tint != null:
		_tint.visible = (_state == "play" and _player.frenzy)
	_update_info()
	queue_redraw()
	if _overlay != null:
		_overlay.queue_redraw()
	if _fog != null:
		_fog.queue_redraw()

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

# --- Memory fog -----------------------------------------------------------

func _cell_idx(col: int, row: int) -> int:
	return row * COLS + col

func _cell_center(col: int, row: int) -> Vector2:
	return Vector2(col * CELL + CELL / 2, row * CELL + CELL / 2)

func _reveal_box(center: Vector2, reach: float) -> Rect2i:
	var c0 := maxi(0, int((center.x - reach) / CELL))
	var c1 := mini(COLS - 1, int((center.x + reach) / CELL))
	var r0 := maxi(0, int((center.y - reach) / CELL))
	var r1 := mini(ROWS - 1, int((center.y + reach) / CELL))
	return Rect2i(c0, r0, c1 - c0, r1 - r0)

## Each frame: fade all memory toward black, then re-reveal cells the goblin can
## currently see (its cone, with line-of-sight) and cells a burning lantern lights
## (so lit rooms glow). Finally update each shiny's remembered-ness.
func _update_fog(delta: float) -> void:
	for i in range(_mem.size()):
		_mem[i] = maxf(_mem[i] - FADE * delta, 0.0)

	# (a) The goblin's vision cone.
	var gp := _player.global_position
	var f := _player.facing
	var cb := _reveal_box(gp, CONE_LEN)
	for row in range(cb.position.y, cb.position.y + cb.size.y + 1):
		for col in range(cb.position.x, cb.position.x + cb.size.x + 1):
			var c := _cell_center(col, row)
			var v := c - gp
			var d := v.length()
			if d <= NEAR_R:
				_mem[_cell_idx(col, row)] = 1.0
			elif d <= CONE_LEN and absf(f.angle_to(v)) <= CONE_HALF and _clear(gp, c):
				_mem[_cell_idx(col, row)] = 1.0

	# (b) Lit lanterns light up their room (re-revealed every frame while lit).
	for L in _lanterns:
		if not L.lit:
			continue
		var lb := _reveal_box(L.pos, L.radius)
		for row in range(lb.position.y, lb.position.y + lb.size.y + 1):
			for col in range(lb.position.x, lb.position.x + lb.size.x + 1):
				var idx := _cell_idx(col, row)
				if _mem[idx] >= 1.0:
					continue
				var c := _cell_center(col, row)
				# Lit only where the lantern reaches it AND the goblin can see it —
				# so a lit room behind a wall stays dark until you can see into it.
				if c.distance_to(L.pos) <= L.radius and _clear(L.pos, c) and _clear(gp, c):
					_mem[idx] = 1.0

	# (c) Per-shiny memory from the cell it sits in (no extra raycasts).
	for item in _loot:
		if item.taken:
			continue
		var ci := _cell_idx(clampi(int(item.pos.x) / CELL, 0, COLS - 1), clampi(int(item.pos.y) / CELL, 0, ROWS - 1))
		if _mem[ci] >= 1.0:
			item.mem = 1.0
		else:
			item.mem = maxf(0.0, item.mem - ITEM_FADE * delta)

# --- Guard navigation -----------------------------------------------------

func _build_nav() -> void:
	# An A* grid over the same cells as the fog; cells overlapping a (slightly
	# grown) wall are solid, so guard paths keep off walls and thread doorways.
	_astar.region = Rect2i(0, 0, COLS, ROWS)
	_astar.cell_size = Vector2(CELL, CELL)
	_astar.offset = Vector2(CELL / 2.0, CELL / 2.0)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for row in range(ROWS):
		for col in range(COLS):
			var c := _cell_center(col, row)
			var solid := false
			for r in _wall_rects:
				if r.grow(14.0).has_point(c):
					solid = true
					break
			_astar.set_point_solid(Vector2i(col, row), solid)

## A walkable path (cell centres) from one world point to another, threading
## doorways. Empty if no route — the guard then falls back to a straight line.
func nav_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := _world_to_id(from)
	var b := _world_to_id(to)
	if _astar.is_point_solid(a):
		a = _nearest_free(a)
	if _astar.is_point_solid(b):
		b = _nearest_free(b)
	return _astar.get_point_path(a, b)

func _world_to_id(pos: Vector2) -> Vector2i:
	return Vector2i(clampi(int(pos.x) / CELL, 0, COLS - 1), clampi(int(pos.y) / CELL, 0, ROWS - 1))

func _nearest_free(id: Vector2i) -> Vector2i:
	for radius in range(1, 7):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var n := id + Vector2i(dx, dy)
				if n.x >= 0 and n.x < COLS and n.y >= 0 and n.y < ROWS and not _astar.is_point_solid(n):
					return n
	return id

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
	if _guard.searching:
		flags += "[GUARD SEARCHING]  "
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
	# Lanterns: a warm danger-pool for lit ones, drawn on the world canvas so the
	# night hides it — you only see a pool when your vision cone falls across it.
	for L in _lanterns:
		if L.lit:
			draw_circle(L.pos, L.radius, Color(1.0, 0.82, 0.4, 0.34))
			draw_circle(L.pos, L.radius * 0.6, Color(1.0, 0.86, 0.48, 0.34))
			draw_circle(L.pos, L.radius * 0.3, Color(1.0, 0.92, 0.62, 0.4))
		draw_circle(L.pos, 5.0, Color(1.0, 0.95, 0.65) if L.lit else Color(0.25, 0.25, 0.3))
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
	# Loot — only the real diamond when it's currently seen / freshly remembered;
	# once forgotten it becomes a "?" on the overlay instead (see _draw_overlay).
	for item in _loot:
		if not item.taken and item.get("mem", 0.0) >= REAL_THRESH:
			var s: float = 9.0 if item.value >= 3 else 6.0
			var p: Vector2 = item.pos
			draw_colored_polygon(PackedVector2Array([
				p + Vector2(0, -s), p + Vector2(s * 0.8, 0), p + Vector2(0, s), p + Vector2(-s * 0.8, 0),
			]), Color(1.0, 0.85, 0.2))

func _label(pos: Vector2, text: String, color: Color) -> void:
	if _font != null:
		draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)

## A light-immune sibling canvas: redraws the gameplay-critical cues that must
## stay readable even when the world is dimmed by the night CanvasModulate.
class _OverlayDraw extends Node2D:
	var probe
	func _draw() -> void:
		if probe != null:
			probe._draw_overlay(self)

func _draw_overlay(cv: CanvasItem) -> void:
	# Where the guard is heading to investigate a noise it heard.
	if _guard != null and _guard.investigating:
		var hp: Vector2 = _guard.heard_pos
		cv.draw_arc(hp, 15.0, 0.0, TAU, 24, Color(1, 0.55, 0.1, 0.6), 2.0)
		_label_on(cv, hp + Vector2(-3, 5), "?", Color(1, 0.6, 0.15, 0.95))
	# Where the guard is searching after losing sight of you.
	elif _guard != null and _guard.searching:
		var ls: Vector2 = _guard.last_seen
		cv.draw_arc(ls, 15.0, 0.0, TAU, 24, Color(0.4, 0.8, 1.0, 0.6), 2.0)
		_label_on(cv, ls + Vector2(-30, 5), "where'd it go?", Color(0.5, 0.85, 1.0, 0.9))
	# Dawn closing in — warm red creeps from the edges (kept bright over the fog).
	if _state == "play" and _time_left < DAWN_RAMP:
		var t: float = clampf(1.0 - _time_left / DAWN_RAMP, 0.0, 1.0)
		cv.draw_rect(Rect2(0, 0, 960, 540), Color(0.95, 0.2, 0.1, 0.7 * t), false, 6.0 + 22.0 * t)
	# Forgotten shinies — a fading "?" where the goblin remembers seeing loot.
	for item in _loot:
		if item.taken:
			continue
		var im: float = item.get("mem", 0.0)
		if im > Q_MIN and im < REAL_THRESH:
			var qa: float = clampf(im / REAL_THRESH, 0.0, 1.0) * 0.9
			cv.draw_arc(item.pos, 6.0, 0.0, TAU, 12, Color(0.9, 0.8, 0.4, qa * 0.7), 1.5)
			_label_on(cv, item.pos + Vector2(-4, 5), "?", Color(0.9, 0.8, 0.4, qa))

	# Floating "heh heh / SMASH / OI!" text.
	for f in _floaters:
		var a: float = clampf(f.life / f.max, 0.0, 1.0)
		var c: Color = f.color
		_label_on(cv, f.pos, f.text, Color(c.r, c.g, c.b, a))

func _label_on(cv: CanvasItem, pos: Vector2, text: String, color: Color) -> void:
	if _font != null:
		cv.draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)

## The memory fog: a near-black rect over every cell, alpha = how forgotten it is.
class _FogDraw extends Node2D:
	var probe
	func _draw() -> void:
		if probe != null:
			probe._draw_fog(self)

func _draw_fog(cv: CanvasItem) -> void:
	for row in range(ROWS):
		for col in range(COLS):
			var m := _mem[_cell_idx(col, row)]
			if m >= SEEN_T:
				continue                              # clear — skip (free)
			var a := 1.0 - m
			if a <= 0.02:
				continue
			cv.draw_rect(Rect2(col * CELL, row * CELL, CELL, CELL), Color(0.02, 0.02, 0.05, a))
