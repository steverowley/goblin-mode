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
const MELEE_R := 38.0            # reach of a sword swipe (Bite 2.5)
const STAB_CD := 0.3             # gap between swipes (quick — guard swings are uninterruptible, so no flinch-lock)
const SWIPE_HALF := deg_to_rad(20.0)   # half-angle of the goblin's narrow stab
const SWIPE_TIME := 0.14         # how long the stab thrust is drawn
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

## Emitted once the raid is over (won or lost) AND the player has acknowledged
## the result, carrying {outcome, loot}. The M2 spine listens for this to slink
## back to the warren; launched directly, nothing is connected.
signal raid_finished(result: Dictionary)

## Set true by the M2 spine before it adds this raid as a child. Default false ->
## launched directly, the Fun Probe behaves exactly as the standalone greybox
## always has (banner + R to restart, no return-to-warren handoff).
var embedded := false
var _awaiting_return := false        # embedded + resolved: next key returns to the warren

# --- Morning loadout (issue #8): the one kit the Den packed, read from GameState.
# None when launched directly -> the Fun Probe plays exactly as the base greybox.
const STINK_R := 220.0               # stink-cloud radius that pulls guards in to investigate
const STINK_TIME := 3.5              # how long the pong lingers
var _kit_lockpicks := false          # the barred gate becomes a quiet 2nd exit (no frenzy needed)
var _stink_charges := 0              # one-shot stink bombs in the sack
var _stink_pos := Vector2.ZERO
var _stink_t := 0.0                  # remaining stink-cloud time
var _sent_name := ""                 # the goblin the Den sent (issue #9); "" when launched directly

# --- Goblin stats the raid reads (Bite 2a). Neutral when launched directly. ---
const IFRAME_TIME := 1.2             # invulnerable window after wriggling free of a grab
var _hp := 1                         # sent goblin's Health = grabs it can take before it's nabbed
var _hp_max := 1
var _iframe_t := 0.0                 # remaining scramble i-frames
var _stab_cd := 0.0                  # cooldown between sword swipes
var _swipe_t := 0.0                  # swipe-arc draw timer
var _swipe_dir := Vector2.RIGHT
var _noise_mult := 1.0               # Sneak stat: <1 = quieter to guards (1.0 = neutral/standalone)

var _player: GoblinScript
var _guards: Array = []       # the tall-folk on patrol (noise routed to all)

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
var _fog_img: Image                # COLS x ROWS image the fog texture is built from
var _fog_tex: ImageTexture         # the fog, drawn as one stretched quad
var _astar := AStarGrid2D.new()    # guard navigation grid (paths through doorways)
var _ray := PhysicsRayQueryParameters2D.new()   # reused ray query (avoids per-call allocs)
var _lantern_baked := false        # have we baked each lantern's lit cells yet?
var _font: Font

func _ready() -> void:
	_font = ThemeDB.fallback_font
	_init_fog()
	_build_walls()
	_build_nav()
	_build_stuff()
	_build_actors()
	_build_hud()
	_apply_loadout()

func _init_fog() -> void:
	# The memory fog lives on its own CanvasLayer above the world (so it covers
	# the self-drawing walls/player/guard) but below the crit-cue overlay + HUD.
	# It's drawn as ONE small COLS x ROWS texture stretched over the play area.
	_mem.resize(COLS * ROWS)
	_mem.fill(0.0)
	_ray.collision_mask = 0b01
	_fog_img = Image.create(COLS, ROWS, false, Image.FORMAT_RGBA8)
	_fog_img.fill(Color(0.02, 0.02, 0.05, 1.0))   # start fully black (no startup flash before the first update)
	_fog_tex = ImageTexture.create_from_image(_fog_img)
	var fog_layer := CanvasLayer.new()
	fog_layer.layer = 1
	add_child(fog_layer)
	var fog := _FogDraw.new()
	fog.probe = self
	fog.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # crisp fog cells
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

	# Guard A — a big slow "brute" looping the central room (R3), the chokepoint.
	var brute := GuardScript.new()
	brute.nav = self           # pathfinds through doorways via the level's A* grid
	brute.hp = 4               # the big brute soaks more hits in an open fight
	add_child(brute)
	brute.setup(PackedVector2Array([
		Vector2(400, 100), Vector2(560, 100), Vector2(560, 460), Vector2(400, 460),
	]), _player)
	_guards.append(brute)

	# Guard B — a faster "scout" prowling the right-side rooms (R4 <-> R5); now that
	# guards pathfind, its patrol route crosses the doorway between them.
	var scout := GuardScript.new()
	scout.nav = self
	scout.patrol_speed = 64.0
	scout.chase_speed = 122.0
	scout.view_dist = 235.0
	scout.body_color = Color(0.85, 0.5, 0.2)   # orange — tells it apart from the brute
	scout.hp = 2               # the fast scout is fragile
	add_child(scout)
	scout.setup(PackedVector2Array([
		Vector2(760, 100), Vector2(900, 130), Vector2(900, 450), Vector2(720, 440),
	]), _player)
	_guards.append(scout)

	for g in _guards:
		g.caught_player.connect(_on_caught.bind(g))
		g.spotted.connect(_on_spotted.bind(g))
	# Footsteps reach every guard's ears through the noise router.
	_player.noise_made.connect(_emit_noise)

func _build_hud() -> void:
	# Crit-cue overlay on its own CanvasLayer (above the fog), so loot, guard
	# markers, floaters, and the dawn vignette stay readable through the dark.
	var overlay_layer := CanvasLayer.new()
	overlay_layer.layer = 2
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

## Read the morning loadout the Den wrote into GameState (issue #8). Launched
## directly, GameState.loadout is "" -> no kit -> the raid plays exactly as the
## base greybox cut always has.
func _apply_loadout() -> void:
	match GameState.loadout:
		GameState.KIT_LOCKPICKS:
			_kit_lockpicks = true
		GameState.KIT_STINK:
			_stink_charges = 1
	var sent := GameState.sent_goblin()
	if not sent.is_empty():
		_sent_name = String(sent.name)
		var st: Dictionary = sent.get("stats", {})
		_hp_max = maxi(1, int(st.get("health", 1)))
		_hp = _hp_max
		var lo := float(GameState.STAT_MIN)
		var hi := float(GameState.STAT_MAX)
		var sneak_t := clampf((float(int(st.get("sneak", 2))) - lo) / (hi - lo), 0.0, 1.0)
		var brawn_t := clampf((float(int(st.get("brawn", 2))) - lo) / (hi - lo), 0.0, 1.0)
		_noise_mult = lerpf(1.25, 0.55, sneak_t)       # higher Sneak = quieter
		_player.carry = lerpf(0.7, 1.8, brawn_t)       # higher Brawn = lugs loot with less drag

func _physics_process(delta: float) -> void:
	if _state != "play":
		return
	_iframe_t = maxf(0.0, _iframe_t - delta)
	_stab_cd = maxf(0.0, _stab_cd - delta)
	_swipe_t = maxf(0.0, _swipe_t - delta)

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
	var tension := clampf(1.0 - _time_left / DAWN_RAMP, 0.0, 1.0)
	for g in _guards:
		g.set_tension(tension)

	# Stink bomb (issue #8): while the cloud lingers it keeps pulling nearby guards
	# in to investigate the pong — drop it to drag them off a chokepoint, then slip by.
	if _stink_t > 0.0:
		_stink_t -= delta
		for g in _guards:
			if g.global_position.distance_to(_stink_pos) < STINK_R:
				g.hear_noise(_stink_pos, 1.0)

	# Win first, so reaching the OUT door (with loot) or leaving via the gate on the
	# very last frame counts as a win, not a dawn loss. The gate is a frenzy smash-out
	# OR, with the lockpicks kit, a quiet exit you can stroll through carrying loot.
	if _player.sack > 0 and _player.global_position.distance_to(EXIT_POS) < EXIT_R:
		_win()
	elif _player.global_position.distance_to(GATE_POS) < GATE_R and (_player.frenzy or (_kit_lockpicks and _player.sack > 0)):
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
	if _player != null:
		# Flicker while scrambling free OR mid dodge-roll — but snap opaque the moment
		# the raid ends, since those timers stop ticking once _state leaves "play".
		var inv: bool = (_iframe_t > 0.0 or _player.dashing) and _state == "play"
		_player.modulate.a = 0.45 if inv else 1.0
	_update_info()
	queue_redraw()
	if _overlay != null:
		_overlay.queue_redraw()
	if _fog != null:
		_fog.queue_redraw()

func _input(event: InputEvent) -> void:
	# Strike (LMB) — a melee stealth takedown on an unaware guard.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _state == "play":
			_try_takedown()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if _state == "play":
			_player.start_dash()
		return
	if not (event is InputEventKey and event.pressed):
		return
	# Embedded under the M2 spine and the raid is over: any key slinks home.
	if _awaiting_return:
		_awaiting_return = false
		raid_finished.emit({"outcome": _state, "loot": _banked})
		return
	if event.keycode == KEY_R and not embedded:
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
	elif event.keycode == KEY_F:
		_deploy_stink()

## Route a noise event from somewhere in the world to everything that can hear.
## (One guard today; a loop over a guard list tomorrow.)
func _emit_noise(pos: Vector2, loudness: float) -> void:
	for g in _guards:
		g.hear_noise(pos, loudness * _noise_mult)

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
	_ray.from = from
	_ray.to = to
	return get_world_2d().direct_space_state.intersect_ray(_ray).is_empty()

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
	if not _lantern_baked:
		_bake_lanterns()     # one-time: which cells each lantern lights (walls are live now)
		_lantern_baked = true

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

	# (b) Lit lanterns light up their room. The lantern->cell visibility is baked
	# once (walls are static); each frame we only test the goblin's line-of-sight,
	# so a lit room behind a wall stays dark until you can see into it.
	for L in _lanterns:
		if not L.lit:
			continue
		for idx in L.cells:
			if _mem[idx] >= 1.0:
				continue
			if _clear(gp, _cell_center(idx % COLS, idx / COLS)):
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

	# Bake the grid into the fog texture (drawn as one quad in _draw_fog).
	for i in range(_mem.size()):
		var m := _mem[i]
		var a := 0.0 if m >= SEEN_T else 1.0 - m
		_fog_img.set_pixel(i % COLS, i / COLS, Color(0.02, 0.02, 0.05, a))
	_fog_tex.update(_fog_img)

func _bake_lanterns() -> void:
	# Per lantern, the cells within reach that have line-of-sight to it. Walls are
	# static so this never changes; smashing a lantern just stops it being used.
	for L in _lanterns:
		var cells := PackedInt32Array()
		var lb := _reveal_box(L.pos, L.radius)
		for row in range(lb.position.y, lb.position.y + lb.size.y + 1):
			for col in range(lb.position.x, lb.position.x + lb.size.x + 1):
				var c := _cell_center(col, row)
				if c.distance_to(L.pos) <= L.radius and _clear(L.pos, c):
					cells.append(_cell_idx(col, row))
		L["cells"] = cells

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

## Lob the one stink bomb at the goblin's feet (issue #8). The cloud then lures
## nearby guards in to investigate (handled each frame in _physics_process).
func _deploy_stink() -> void:
	if _stink_charges <= 0:
		return
	_stink_charges -= 1
	_stink_pos = _player.global_position
	_stink_t = STINK_TIME
	_spawn_text(_stink_pos, "*PHWOAR* stink bomb!", Color(0.6, 1.0, 0.3))

## A quick STAB (LMB): a narrow thrust where you're aiming. An UNAWARE guard is a
## silent takedown; an ALERTED one takes a chip of HP (it swings back). Precise —
## aim it at the guard.
func _try_takedown() -> void:
	if _stab_cd > 0.0:
		return
	_stab_cd = STAB_CD
	var f: Vector2 = _player.facing
	_swipe_t = SWIPE_TIME
	_swipe_dir = f
	var hit_any := false
	for g in _guards:
		if g.downed:
			continue
		var v: Vector2 = g.global_position - _player.global_position
		var d := v.length()
		if d > MELEE_R:
			continue
		if d > 8.0 and absf(f.angle_to(v)) > SWIPE_HALF:
			continue                 # outside the swipe arc
		hit_any = true
		if g.alerted:
			if g.take_hit(1):
				_spawn_text(g.global_position, "DOWNED!", Color(1.0, 0.5, 0.3))
			else:
				_spawn_text(g.global_position, "*hit!*", Color(1.0, 0.7, 0.4))
		else:
			g.take_down()
			_spawn_text(g.global_position, "*shhk*", Color(0.7, 1.0, 0.4))
	if hit_any:
		_emit_noise(_player.global_position, 0.5)   # a scuffle — nearby guards may come looking
		_player.add_chaos(0.06)

func _on_caught(g) -> void:
	if _state != "play":
		return
	if _iframe_t > 0.0 or _player.dashing:
		g.shake_off()               # scrambling or mid dodge-roll — re-arm this guard, no hit lands
		return
	_hp -= 1
	if _hp <= 0:
		_lose("NABBED! A great tall-folk fist scoops you up by the scruff.")
		return
	# Had health to spare — wriggle free and bolt (brief i-frames; the guard loses its grip).
	_iframe_t = IFRAME_TIME
	_player.velocity = Vector2.ZERO
	_spawn_text(_player.global_position, "GRABBED! -1 (%d left)" % _hp, Color(1, 0.4, 0.4))
	g.shake_off()

func _on_spotted(g) -> void:
	if _state == "play":
		_spawn_text(g.global_position, "OI!!", Color(1, 0.3, 0.3))

func _win() -> void:
	if _state != "play":
		return
	_state = "won"
	_banked = _player.sack
	var head := "LEGGED IT with %d shinies! What a menace." % _banked
	if embedded:
		_awaiting_return = true
		_show_banner(head + "\n(press any key to slink back to the warren)")
	else:
		_show_banner(head + "\nPress R to raid again.")

func _lose(reason: String) -> void:
	if _state != "play":
		return
	_state = "lost"
	var lugging := "\n(You were lugging %d shinies.)" % _player.sack
	if embedded:
		_awaiting_return = true
		_show_banner(reason + lugging + "\n(press any key to slink back to the warren)")
	else:
		_show_banner(reason + lugging + " Press R to try again.")

func _show_banner(text: String) -> void:
	_banner.text = text
	_banner.visible = true
	# Freeze the world behind the banner.
	_player.velocity = Vector2.ZERO
	_player.set_physics_process(false)
	for g in _guards:
		g.velocity = Vector2.ZERO
		g.set_physics_process(false)

func _update_info() -> void:
	var lines := PackedStringArray()
	lines.append("WASD move   Mouse aim   LMB stab   RMB dash   Shift sneak   E smash   SPACE Goblin Mode   R restart")
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
	var any_inv := false
	var any_search := false
	var any_alert := false
	for g in _guards:
		any_inv = any_inv or g.investigating
		any_search = any_search or g.searching
		any_alert = any_alert or g.alerted
	if any_inv:
		flags += "[GUARD HEARD SOMETHING]  "
	if any_search:
		flags += "[GUARD SEARCHING]  "
	if any_alert:
		flags += "[GUARD ON YOU!]"
	if flags != "":
		lines.append(flags.strip_edges())
	# Kit line (issue #8) — only shown when a morning kit is packed, so the
	# standalone Fun Probe's HUD is unchanged.
	if _kit_lockpicks:
		lines.append("KIT: lockpicks — the barred gate is a quiet way out (reach it carrying loot).")
	elif _stink_t > 0.0:
		lines.append("KIT: *stink cloud active* — slip past while they cough!")
	elif _stink_charges > 0:
		lines.append("KIT: stink bomb x%d — press F near a chokepoint to lure the guards." % _stink_charges)
	if _sent_name != "":
		lines.append("On the line: %s   HP [%s%s]   (get 'em home alive)" % [
			_sent_name, "#".repeat(_hp), "-".repeat(maxi(0, _hp_max - _hp))])
	_info.text = "\n".join(lines)

func _meter(v: float, cells: int) -> String:
	var filled := int(round(clampf(v, 0.0, 1.0) * cells))
	return "[" + "#".repeat(filled) + "-".repeat(cells - filled) + "]"

func _draw() -> void:
	draw_rect(Rect2(0, 0, 960, 540), Color(0.08, 0.08, 0.12))
	# Lanterns: a warm danger-pool for lit ones, drawn on the world canvas under
	# the memory fog — you only see a pool where a cell is currently revealed.
	for L in _lanterns:
		if L.lit:
			draw_circle(L.pos, L.radius, Color(1.0, 0.82, 0.4, 0.34))
			draw_circle(L.pos, L.radius * 0.6, Color(1.0, 0.86, 0.48, 0.34))
			draw_circle(L.pos, L.radius * 0.3, Color(1.0, 0.92, 0.62, 0.4))
		draw_circle(L.pos, 5.0, Color(1.0, 0.95, 0.65) if L.lit else Color(0.25, 0.25, 0.3))
	# Walls.
	for r in _wall_rects:
		draw_rect(r, Color(0.18, 0.18, 0.24))
	# Barred gate — smash out in Goblin Mode, OR (with the lockpicks kit) a quiet exit.
	if _kit_lockpicks:
		var carrying := _player != null and _player.sack > 0
		var gcol := Color(0.3, 0.7, 1.0, 0.5) if carrying else Color(0.3, 0.7, 1.0, 0.22)
		draw_rect(Rect2(GATE_POS.x - 6, GATE_POS.y - 28, 12, 56), gcol)
		_label(GATE_POS + Vector2(-150, 2), "picked — slip out ->", Color(0.6, 0.85, 1.0, 0.9))
	else:
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
	# (Loot and its forgotten "?" are drawn on the overlay, above the fog, so they
	# read crisp — see _draw_overlay.)

func _label(pos: Vector2, text: String, color: Color) -> void:
	if _font != null:
		draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)

## A canvas above the fog: redraws the gameplay-critical cues (loot, guard
## markers, floaters, dawn vignette) so they stay readable through the dark.
class _OverlayDraw extends Node2D:
	var probe
	func _draw() -> void:
		if probe != null:
			probe._draw_overlay(self)

func _draw_overlay(cv: CanvasItem) -> void:
	# Goblin STAB (Bite 2.5) — a quick pointed thrust where you're aiming.
	if _swipe_t > 0.0 and _player != null:
		var sd: Vector2 = _swipe_dir
		var salpha := clampf(_swipe_t / SWIPE_TIME, 0.0, 1.0)
		var tip := _player.global_position + sd * MELEE_R
		var base := _player.global_position + sd * 6.0
		var perp := Vector2(-sd.y, sd.x) * 5.0
		cv.draw_colored_polygon(PackedVector2Array([base - perp, base + perp, tip]), Color(0.95, 0.98, 1.0, 0.95 * salpha))
	# Stink cloud (issue #8) — a green pall, kept bright above the fog, that lures guards in.
	if _stink_t > 0.0:
		var sa: float = clampf(_stink_t / STINK_TIME, 0.0, 1.0)
		cv.draw_circle(_stink_pos, STINK_R, Color(0.5, 0.9, 0.3, 0.08 * sa))
		cv.draw_arc(_stink_pos, STINK_R, 0.0, TAU, 48, Color(0.6, 1.0, 0.3, 0.5 * sa), 2.0)
		cv.draw_circle(_stink_pos, 8.0, Color(0.7, 1.0, 0.35, 0.85 * sa))
	# Where each guard is heading to investigate a noise / search after losing you.
	for g in _guards:
		if g.investigating:
			cv.draw_arc(g.heard_pos, 15.0, 0.0, TAU, 24, Color(1, 0.55, 0.1, 0.6), 2.0)
			_label_on(cv, g.heard_pos + Vector2(-3, 5), "?", Color(1, 0.6, 0.15, 0.95))
		elif g.searching:
			cv.draw_arc(g.last_seen, 15.0, 0.0, TAU, 24, Color(0.4, 0.8, 1.0, 0.6), 2.0)
			_label_on(cv, g.last_seen + Vector2(-30, 5), "where'd it go?", Color(0.5, 0.85, 1.0, 0.9))
	# Dawn closing in — warm red creeps from the edges (kept bright over the fog).
	if _state == "play" and _time_left < DAWN_RAMP:
		var t: float = clampf(1.0 - _time_left / DAWN_RAMP, 0.0, 1.0)
		cv.draw_rect(Rect2(0, 0, 960, 540), Color(0.95, 0.2, 0.1, 0.7 * t), false, 6.0 + 22.0 * t)
	# Shinies the goblin sees / freshly remembers — drawn above the fog so they
	# read crisp (never muddied by a half-faded fog cell).
	for item in _loot:
		if item.taken or item.get("mem", 0.0) < REAL_THRESH:
			continue
		var s: float = 9.0 if item.value >= 3 else 6.0
		var p: Vector2 = item.pos
		cv.draw_colored_polygon(PackedVector2Array([
			p + Vector2(0, -s), p + Vector2(s * 0.8, 0), p + Vector2(0, s), p + Vector2(-s * 0.8, 0),
		]), Color(1.0, 0.85, 0.2))
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

## The memory fog: one small COLS x ROWS texture (built in _update_fog), stretched
## over the play area in a single draw instead of thousands of per-cell rects.
class _FogDraw extends Node2D:
	var probe
	func _draw() -> void:
		if probe != null:
			probe._draw_fog(self)

func _draw_fog(cv: CanvasItem) -> void:
	cv.draw_texture_rect(_fog_tex, Rect2(0, 0, COLS * CELL, ROWS * CELL), false)
