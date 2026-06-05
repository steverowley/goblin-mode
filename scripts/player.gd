extends CharacterBody2D
## The player goblin — a greedy little menace with Zomboid-style sight.
##
## You only SEE your facing cone (plus a small circle around you); walls block
## your view and everything else is fog. A camera follows you across the bigger
## city map. Grab everything (a heavy sack slows + loudens you), smash pots and
## lanterns, and trigger GOBLIN MODE to go feral and smash out.

const WALK_SPEED := 145.0
const SNEAK_SPEED := 70.0
const FRENZY_SPEED := 215.0
const WEIGHT_DRAG := 0.035
const FRENZY_TIME := 5.0
const FRENZY_COST := 0.5

var noise := 0.0
var chaos := 0.0
var is_sneaking := false
var is_lit := false
var sack := 0
var weight := 0.0
var frenzy := false
var frenzy_timer := 0.0
var facing := Vector2.RIGHT
var _wiggle := 0.0
var _vision: PointLight2D

func _ready() -> void:
	collision_layer = 0b10
	collision_mask = 0b01
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	cs.shape = rect
	add_child(cs)

	# Camera follows the goblin around the city.
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	add_child(cam)
	cam.make_current()

	# Vision: a facing cone of light (+ small near-circle). shadow_enabled lets
	# wall occluders block it, so you can't see through/around walls.
	_vision = PointLight2D.new()
	_vision.texture = _make_cone_texture()
	_vision.texture_scale = 2.4          # cone reach ~ 300 px
	_vision.energy = 1.35
	_vision.shadow_enabled = true
	add_child(_vision)

func _make_cone_texture() -> ImageTexture:
	var sz := 256
	var c := sz / 2.0
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var half_fov := deg_to_rad(42.0)
	var near_r := 46.0
	var cone_r := float(c)
	for y in range(sz):
		for x in range(sz):
			var dx := float(x) - c
			var dy := float(y) - c
			var dist := sqrt(dx * dx + dy * dy)
			var a := 0.0
			if dist < near_r:
				a = 1.0 - (dist / near_r) * 0.25
			elif dist < cone_r:
				var ang := atan2(dy, dx)          # 0 == +X (the facing direction)
				if absf(ang) <= half_fov:
					var edge := 1.0 - (absf(ang) / half_fov)
					var falloff := 1.0 - (dist / cone_r)
					a = clampf(falloff * (0.45 + 0.55 * edge), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	dir = dir.normalized()

	if frenzy:
		frenzy_timer -= delta
		if frenzy_timer <= 0.0:
			frenzy = false

	is_sneaking = Input.is_key_pressed(KEY_SHIFT) and not frenzy

	var speed: float
	if frenzy:
		speed = FRENZY_SPEED
	else:
		var base := SNEAK_SPEED if is_sneaking else WALK_SPEED
		speed = base * clampf(1.0 - weight * WEIGHT_DRAG, 0.45, 1.0)

	velocity = dir * speed
	move_and_slide()

	if frenzy:
		noise = 1.0
	else:
		var floor_n := clampf(weight * 0.025, 0.0, 0.5)
		if dir != Vector2.ZERO:
			facing = dir
			var gain := (0.10 if is_sneaking else 0.45)
			noise = clampf(noise + gain * delta, 0.0, 1.0)
		else:
			noise = noise - 0.8 * delta
		noise = clampf(maxf(noise, floor_n), 0.0, 1.0)

	# Point the vision cone where we're facing.
	if _vision != null:
		_vision.rotation = facing.angle()

	if dir != Vector2.ZERO:
		_wiggle += delta * 13.0

	queue_redraw()

func noise_radius() -> float:
	return 205.0 * noise

func add_loot(value: int, w: float) -> void:
	sack += value
	weight += w

func bump_noise(v: float) -> void:
	noise = maxf(noise, v)

func add_chaos(amount: float) -> void:
	chaos = clampf(chaos + amount, 0.0, 1.0)

func can_frenzy() -> bool:
	return not frenzy and chaos >= FRENZY_COST

func start_frenzy() -> void:
	frenzy = true
	frenzy_timer = FRENZY_TIME
	chaos = maxf(0.0, chaos - FRENZY_COST)

func _draw() -> void:
	var wob := sin(_wiggle) * 2.0
	var col := Color(0.6, 1.0, 0.2) if frenzy else Color(0.5, 0.85, 0.35)
	# ears
	draw_colored_polygon(PackedVector2Array([Vector2(-8, -5 + wob), Vector2(-4, -13 + wob), Vector2(-1, -5 + wob)]), col)
	draw_colored_polygon(PackedVector2Array([Vector2(8, -5 + wob), Vector2(4, -13 + wob), Vector2(1, -5 + wob)]), col)
	# body
	draw_rect(Rect2(-7, -7 + wob, 14, 14), col)
	draw_circle(Vector2(-3, -2 + wob), 1.4, Color.BLACK)
	draw_circle(Vector2(3, -2 + wob), 1.4, Color.BLACK)
	# sack
	if sack > 0:
		var s := clampf(4.0 + weight * 0.6, 4.0, 15.0)
		draw_circle(Vector2(0, 9 + wob), s, Color(0.55, 0.42, 0.28))
	if is_lit and not frenzy:
		draw_rect(Rect2(-10, -10 + wob, 20, 20), Color(1, 0.95, 0.3, 0.9), false, 2.0)
	draw_line(Vector2(0, wob), facing * 12.0 + Vector2(0, wob), Color.WHITE, 1.5)
