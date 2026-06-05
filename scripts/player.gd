class_name Goblin
extends CharacterBody2D
## The player goblin (greybox: a small green square, steered top-down).
##
## Walk (default) is faster but noisy; hold Shift to SNEAK (slow + quiet).
## Standing in a lamp's light pool makes you far easier for a guard to spot
## (the "light = danger, shadow = safety" pillar from the design docs).
##
## This is intentionally simple. The production goblin (components, traits,
## Goblin Mode frenzy) comes at M1/M2 — see docs/03-technical-design-document.md.

const WALK_SPEED := 150.0
const SNEAK_SPEED := 68.0
const CARRY_PENALTY := 0.62          # speed multiplier while carrying loot
const MAX_NOISE_RADIUS := 200.0      # px, at full noise

# Noise is 0..1: moving raises it (walking far more than sneaking), standing
# still bleeds it off. A guard can "hear" you if it's inside your noise radius.
var noise := 0.0
var is_sneaking := false
var is_lit := false                  # set by the level when in a light pool
var carrying := false                # has the loot
var facing := Vector2.RIGHT

func _ready() -> void:
	# Physics body: player is on collision layer 2, collides with walls (layer 1).
	collision_layer = 0b10
	collision_mask = 0b01
	# Top-down game: treat every collision as a wall so sliding is uniform in
	# all directions (the default GROUNDED mode mis-handles north/south walls).
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 20)
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

	is_sneaking = Input.is_key_pressed(KEY_SHIFT)
	var speed := SNEAK_SPEED if is_sneaking else WALK_SPEED
	if carrying:
		speed *= CARRY_PENALTY

	velocity = dir * speed
	move_and_slide()

	if dir != Vector2.ZERO:
		facing = dir
		var gain := (0.12 if is_sneaking else 0.5)
		noise = clampf(noise + gain * delta, 0.0, 1.0)
	else:
		noise = maxf(0.0, noise - 0.8 * delta)

	queue_redraw()

func noise_radius() -> float:
	return MAX_NOISE_RADIUS * noise

func _draw() -> void:
	var body_col := Color(0.45, 0.82, 0.32)        # goblin green
	if carrying:
		body_col = Color(0.7, 0.95, 0.45)
	# Noise ring (warm + visible, so you can see it reach a guard's ears).
	var r := noise_radius()
	if r > 6.0:
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(1.0, 0.8, 0.35, 0.28), 2.0)
	# "In the light" warning outline.
	if is_lit:
		draw_rect(Rect2(-13, -13, 26, 26), Color(1, 0.95, 0.3, 0.9), false, 2.0)
	# Body + facing tick.
	draw_rect(Rect2(-10, -10, 20, 20), body_col)
	draw_line(Vector2.ZERO, facing * 15.0, Color.WHITE, 2.0)
	if carrying:
		draw_circle(Vector2(0, -16), 4.0, Color(1, 0.85, 0.2))   # the shiny on your back
