extends Node2D
## Milestone 0.5 "Fun Probe" — the smallest test of: is sneaking around as a
## goblin actually fun?
##
## ONE hand-built room, ONE goblin (you), ONE patrolling guard with a vision
## cone, ONE light pool to avoid, ONE shiny to steal, and a dawn timer to beat.
## No warren, no procgen, no economy, no traits, no save — deliberately
## (see docs/00-decisions-log.md, decision D). Greybox art = coloured shapes.
##
## Goal: grab the shiny (top-right, sitting in the lamplight = risky) and carry
## it to the EXIT (top-left) before dawn — without getting caught.

const DAWN_SECONDS := 90.0

# Layout (fits the 960x540 viewport, so no camera needed).
const PLAYER_START := Vector2(80, 470)
const LOOT_POS := Vector2(820, 140)
const LAMP_POS := Vector2(820, 140)
const LAMP_RADIUS := 110.0
const EXIT_POS := Vector2(78, 78)
const EXIT_RADIUS := 34.0

var _player: Goblin
var _guard: Guard
var _loot: Area2D
var _exit: Area2D
var _loot_taken := false

var _wall_rects: Array[Rect2] = []
var _time_left := DAWN_SECONDS
var _state := "play"           # "play" | "won" | "lost"
var _hint := ""
var _hint_timer := 0.0

var _info: Label
var _banner: Label

func _ready() -> void:
	_build_walls()
	_build_items()
	_build_actors()
	_build_hud()

func _build_walls() -> void:
	# Boundary (thickness 20) around the 960x540 viewport...
	_add_wall(Rect2(0, 0, 960, 20))
	_add_wall(Rect2(0, 520, 960, 20))
	_add_wall(Rect2(0, 0, 20, 540))
	_add_wall(Rect2(940, 0, 20, 540))
	# ...plus interior cover so there are shadows/corners to sneak around.
	_add_wall(Rect2(300, 120, 40, 200))
	_add_wall(Rect2(480, 300, 220, 40))
	_add_wall(Rect2(300, 420, 260, 40))
	_add_wall(Rect2(640, 60, 40, 150))

func _add_wall(rect: Rect2) -> void:
	_wall_rects.append(rect)
	var body := StaticBody2D.new()
	body.collision_layer = 0b01   # walls on layer 1 (blocks movement + line of sight)
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	cs.position = rect.position + rect.size / 2.0
	body.add_child(cs)
	add_child(body)

func _build_items() -> void:
	_loot = _make_zone(LOOT_POS, 22.0, _on_loot_body)
	_exit = _make_zone(EXIT_POS, EXIT_RADIUS, _on_exit_body)

func _make_zone(pos: Vector2, radius: float, cb: Callable) -> Area2D:
	var area := Area2D.new()
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 0b10        # detect the player (layer 2)
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	cs.shape = circle
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(cb)
	return area

func _build_actors() -> void:
	_player = Goblin.new()
	_player.position = PLAYER_START
	add_child(_player)

	_guard = Guard.new()
	add_child(_guard)
	var patrol := PackedVector2Array([
		Vector2(700, 120), Vector2(880, 120),
		Vector2(880, 300), Vector2(700, 300),
	])
	_guard.setup(patrol, _player)
	_guard.caught_player.connect(_on_caught)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_info = Label.new()
	_info.position = Vector2(16, 10)
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
	# Light pool exposure (the lamp).
	_player.is_lit = _player.global_position.distance_to(LAMP_POS) < LAMP_RADIUS
	# Dawn.
	_time_left -= delta
	if _time_left <= 0.0:
		_time_left = 0.0
		_lose("DAWN BROKE — the tall folk woke up. You scarpered empty-handed.")

func _process(delta: float) -> void:
	if _hint_timer > 0.0:
		_hint_timer -= delta
		if _hint_timer <= 0.0:
			_hint = ""
	_update_info()
	queue_redraw()

func _input(event: InputEvent) -> void:
	# R restarts at any time (fast retries make the loop quick to test).
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()

func _on_loot_body(body: Node) -> void:
	if _state != "play" or _loot_taken:
		return
	if body == _player:
		_loot_taken = true
		_player.carrying = true
		_loot.queue_free()
		_flash("Snatched the shiny! Now leg it to the EXIT (top-left).", 3.0)

func _on_exit_body(body: Node) -> void:
	if _state != "play":
		return
	if body == _player:
		if _player.carrying:
			_win()
		else:
			_flash("That's the way out — but grab the shiny first!", 2.0)

func _on_caught() -> void:
	if _state == "play":
		_lose("CAUGHT! A tall-folk mitt closed round your scrawny neck.")

func _win() -> void:
	_state = "won"
	_show_banner("ESCAPED with the loot! — you little menace.\nPress R to go again.")

func _lose(reason: String) -> void:
	if _state != "play":
		return
	_state = "lost"
	_show_banner(reason + "\nPress R to try again.")

func _flash(text: String, secs: float) -> void:
	_hint = text
	_hint_timer = secs

func _show_banner(text: String) -> void:
	_banner.text = text
	_banner.visible = true
	# Freeze the world so the goblin and guard stop moving behind the banner.
	_player.velocity = Vector2.ZERO
	_guard.velocity = Vector2.ZERO
	_player.set_physics_process(false)
	_guard.set_physics_process(false)

func _update_info() -> void:
	var lines := PackedStringArray()
	lines.append("WASD / Arrows: move    Shift: sneak (quiet)    R: restart    Goal: grab the shiny -> reach the EXIT")
	lines.append("Dawn %0.0fs   Noise %s   Spotted %s%s%s%s" % [
		_time_left,
		_meter(_player.noise, 10),
		_meter(_guard.suspicion, 10),
		("   [CARRYING]" if _player.carrying else ""),
		("   [IN THE LIGHT!]" if _player.is_lit else ""),
		("   ALERTED!" if _guard.alerted else ""),
	])
	if _hint != "":
		lines.append(_hint)
	_info.text = "\n".join(lines)

func _meter(v: float, cells: int) -> String:
	var filled := int(round(clampf(v, 0.0, 1.0) * cells))
	return "[" + "#".repeat(filled) + "-".repeat(cells - filled) + "]"

func _draw() -> void:
	# Floor.
	draw_rect(Rect2(0, 0, 960, 540), Color(0.09, 0.09, 0.13))
	# Lamp light pool (the danger zone).
	draw_circle(LAMP_POS, LAMP_RADIUS, Color(1.0, 0.85, 0.35, 0.16))
	draw_circle(LAMP_POS, 10.0, Color(1.0, 0.9, 0.5))
	# Walls.
	for r in _wall_rects:
		draw_rect(r, Color(0.18, 0.18, 0.24))
	# Exit — brightens once you're carrying the loot (it's now your goal).
	var exit_fill := 0.4 if _loot_taken else 0.18
	var exit_w := 4.0 if _loot_taken else 2.0
	draw_circle(EXIT_POS, EXIT_RADIUS, Color(0.3, 0.7, 1.0, exit_fill))
	draw_arc(EXIT_POS, EXIT_RADIUS, 0.0, TAU, 40, Color(0.4, 0.85, 1.0, 0.9), exit_w)
	# Loot (if not yet grabbed) — a little shiny diamond.
	if not _loot_taken:
		var p := LOOT_POS
		var d := PackedVector2Array([
			p + Vector2(0, -9), p + Vector2(8, 0), p + Vector2(0, 9), p + Vector2(-8, 0),
		])
		draw_colored_polygon(d, Color(1.0, 0.85, 0.2))
