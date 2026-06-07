extends CharacterBody2D
## The player goblin — a greedy little menace (greybox).
##
## Walk, or hold Shift to sneak. You auto-grab shinies by touching them; the
## fuller your sack the slower AND louder you get. Wreck pots/lanterns (handled
## by the level) to fill the CHAOS meter, then hit GOBLIN MODE: a feral frenzy
## where weight doesn't slow you, you're loud as sin, and you can smash your way
## out. This is the M1/M2 "Goblin Mode frenzy" (decision J) in crude greybox form.

const WALK_SPEED := 145.0
const SNEAK_SPEED := 70.0
const FRENZY_SPEED := 215.0
const WEIGHT_DRAG := 0.035       # how much each unit of sack-weight slows you
const FRENZY_TIME := 5.0
const FRENZY_COST := 0.5         # chaos needed (and spent) to go feral
const STEP_INTERVAL := 0.34      # seconds between footstep-noise events while walking
const FRENZY_STEP_INTERVAL := 0.16   # feral feet are loud and fast
const DASH_SPEED := 300.0            # dodge-roll burst speed (open brawl)
const DASH_TIME := 0.16
const DASH_CD := 0.7

signal noise_made(pos, loudness)     # a footstep — the level routes it to listeners

var noise := 0.0
var chaos := 0.0                 # 0..1, fills from grabbing & wrecking
var is_sneaking := false
var is_lit := false
var sack := 0                    # shinies grabbed (value)
var weight := 0.0                # sack weight (slows + loudens you)
var carry := 1.0                 # brawn stat: >1 lugs a heavy sack with less drag/noise (1.0 = neutral)
var dashing := false             # dodge-roll burst (open brawl) — grants brief i-frames
var _dash_dir := Vector2.RIGHT
var _dash_t := 0.0
var _dash_cd := 0.0
var _move_dir := Vector2.ZERO
var frenzy := false
var frenzy_timer := 0.0
var facing := Vector2.RIGHT
var _wiggle := 0.0               # waddle animation phase
var _step_t := 0.0               # countdown to the next footstep noise

func _ready() -> void:
	collision_layer = 0b10
	collision_mask = 0b01
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	cs.shape = rect
	add_child(cs)

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

	# Face / aim toward the mouse (twin-stick): movement is WASD, but you LOOK where
	# the cursor is — so the vision cone follows the mouse (peek without moving).
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() > 1.0:
		facing = to_mouse.normalized()

	# Dodge-roll (open brawl): a quick burst with brief i-frames, on a cooldown.
	_move_dir = dir
	_dash_cd = maxf(0.0, _dash_cd - delta)
	if dashing:
		_dash_t -= delta
		if _dash_t <= 0.0:
			dashing = false

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
		speed = base * clampf(1.0 - weight * WEIGHT_DRAG / carry, 0.45, 1.0)

	if dashing:
		velocity = _dash_dir * DASH_SPEED
	else:
		velocity = dir * speed
	move_and_slide()

	# Noise: max in frenzy; otherwise rises while moving, with a weight-based
	# floor so a heavily-laden goblin can never be truly silent.
	if frenzy:
		noise = 1.0
	else:
		var floor_n := clampf(weight * 0.025 / carry, 0.0, 0.5)
		if dir != Vector2.ZERO:
			var gain := (0.10 if is_sneaking else 0.45)
			noise = clampf(noise + gain * delta, 0.0, 1.0)
		else:
			noise = noise - 0.8 * delta
		noise = clampf(maxf(noise, floor_n), 0.0, 1.0)

	if dir != Vector2.ZERO:
		_wiggle += delta * 13.0
		# Footsteps as discrete noise events the guard can hear (and chase).
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = FRENZY_STEP_INTERVAL if frenzy else STEP_INTERVAL
			# A footstep carries its IMPACT, not the just-started noise ramp, so the
			# first step (and burst-walking) is audible. Sneaking stays below the
			# guard's hearing threshold by design.
			var step_loud := noise
			if not frenzy:
				step_loud = maxf(noise, 0.10 if is_sneaking else 0.42)
			noise_made.emit(global_position, step_loud)
	else:
		_step_t = 0.0            # standing still — next step fires the moment you move

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

## A dodge-roll: burst in the movement direction (or where you're aiming if still).
func start_dash() -> void:
	if _dash_cd > 0.0 or frenzy:
		return
	_dash_dir = (_move_dir if _move_dir != Vector2.ZERO else facing).normalized()
	dashing = true
	_dash_t = DASH_TIME
	_dash_cd = DASH_CD

func _draw() -> void:
	var wob := sin(_wiggle) * 2.0    # waddle
	# Noise ring (turns angry-red in frenzy).
	var r := noise_radius()
	if r > 6.0:
		var ring := Color(1, 0.35, 0.3, 0.32) if frenzy else Color(1.0, 0.8, 0.35, 0.26)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, ring, 2.0)
	var col := Color(0.6, 1.0, 0.2) if frenzy else Color(0.5, 0.85, 0.35)
	# Big goblin ears.
	draw_colored_polygon(PackedVector2Array([Vector2(-8, -5 + wob), Vector2(-4, -13 + wob), Vector2(-1, -5 + wob)]), col)
	draw_colored_polygon(PackedVector2Array([Vector2(8, -5 + wob), Vector2(4, -13 + wob), Vector2(1, -5 + wob)]), col)
	# Body.
	draw_rect(Rect2(-7, -7 + wob, 14, 14), col)
	# Mean little eyes.
	draw_circle(Vector2(-3, -2 + wob), 1.4, Color.BLACK)
	draw_circle(Vector2(3, -2 + wob), 1.4, Color.BLACK)
	# Loot sack on the back, grows with weight.
	if sack > 0:
		var s := clampf(4.0 + weight * 0.6, 4.0, 15.0)
		draw_circle(Vector2(0, 9 + wob), s, Color(0.55, 0.42, 0.28))
	# "You're lit!" warning.
	if is_lit and not frenzy:
		draw_rect(Rect2(-10, -10 + wob, 20, 20), Color(1, 0.95, 0.3, 0.9), false, 2.0)
	# Facing tick.
	draw_line(Vector2(0, wob), facing * 12.0 + Vector2(0, wob), Color.WHITE, 1.5)
