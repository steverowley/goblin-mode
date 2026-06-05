extends StaticBody2D
## A simple greybox door: blocks movement AND sight (it's a light occluder)
## until the goblin creeps within range, then swings open and stays open.

const OPEN_RANGE := 48.0

var _player: Node2D
var _size := Vector2(44, 12)
var is_open := false

var _cs: CollisionShape2D
var _occ: LightOccluder2D

func setup(player: Node2D, sz: Vector2) -> void:
	_player = player
	_size = sz

func _ready() -> void:
	collision_layer = 0b01           # same as walls: blocks movement + sight
	collision_mask = 0
	_cs = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = _size
	_cs.shape = shape
	add_child(_cs)

	_occ = LightOccluder2D.new()
	var op := OccluderPolygon2D.new()
	var hw := _size.x / 2.0
	var hh := _size.y / 2.0
	op.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh),
	])
	_occ.occluder = op
	add_child(_occ)

func _physics_process(_delta: float) -> void:
	if is_open or _player == null:
		return
	if global_position.distance_to(_player.global_position) < OPEN_RANGE:
		_open()

func _open() -> void:
	is_open = true
	_cs.set_deferred("disabled", true)
	if _occ != null:
		_occ.queue_free()
		_occ = null
	queue_redraw()

func _draw() -> void:
	if is_open:
		return
	var hw := _size.x / 2.0
	var hh := _size.y / 2.0
	draw_rect(Rect2(-hw, -hh, _size.x, _size.y), Color(0.5, 0.36, 0.2))
	draw_rect(Rect2(-hw, -hh, _size.x, _size.y), Color(0.3, 0.22, 0.12), false, 1.5)
