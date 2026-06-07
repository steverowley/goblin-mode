extends Node
## M2-1 spine: the persistent flow controller (the day->night->return loop).
##
## It owns EXACTLY ONE big scene at a time — the warren OR the raid — and frees
## the old one before bringing in the next, so only one heavy scene is ever in
## memory. That keeps memory flat on integrated graphics (decision U).
##
## It holds no game data itself: all persistent state lives in the GameState
## autoload. This node only shuffles scenes and routes the result between them.

const RAID_SCENE := "res://scenes/fun_probe.tscn"
const WARREN_SCENE := preload("res://scenes/warren.tscn")
const MIN_LOADING := 0.6   # hold the loading screen at least this long, so a fast load never just flashes

var _current: Node = null            # the one live big scene (warren or raid); freed before the next
var _loading_layer: CanvasLayer = null
var _loading_label: Label = null

var _loading := false                # are we mid async-load right now?
var _load_path := ""
var _load_min_t := 0.0               # remaining minimum loading-screen time

func _ready() -> void:
	_build_loading_ui()
	_enter_warren()

# --- Warren (day) ---------------------------------------------------------

func _enter_warren() -> void:
	var warren := WARREN_SCENE.instantiate()
	warren.go_raid.connect(_on_go_raid)
	_set_current(warren)

# --- Raid (night) ---------------------------------------------------------

func _on_go_raid() -> void:
	if _loading:
		return   # already descending into a raid — ignore a repeat trigger
	# Free the warren BEFORE we generate the raid (memory stays flat), then kick
	# off the background load behind the loading screen.
	_set_current(null)
	_show_loading("descending into the town…")
	var err := ResourceLoader.load_threaded_request(RAID_SCENE)
	if err != OK:
		push_error("Raid load request failed (err %d) — falling back to the warren." % err)
		_hide_loading()
		_enter_warren()
		return
	_load_path = RAID_SCENE
	_load_min_t = MIN_LOADING
	_loading = true

func _process(delta: float) -> void:
	if not _loading:
		return
	_load_min_t -= delta
	var status := ResourceLoader.load_threaded_get_status(_load_path)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			pass
		ResourceLoader.THREAD_LOAD_LOADED:
			if _load_min_t > 0.0:
				return   # already loaded, but hold the screen a beat longer so it doesn't flash
			_loading = false
			_start_raid(ResourceLoader.load_threaded_get(_load_path))
		_:   # THREAD_LOAD_FAILED or THREAD_LOAD_INVALID_RESOURCE
			push_error("Raid load failed (status %d) — falling back to the warren." % status)
			_loading = false
			_hide_loading()
			_enter_warren()

func _start_raid(packed: PackedScene) -> void:
	var raid := packed.instantiate()
	raid.embedded = true                       # tell the Fun Probe it's hosted (returns control instead of reloading)
	raid.raid_finished.connect(_on_raid_finished)
	_set_current(raid)
	_hide_loading()

func _on_raid_finished(result: Dictionary) -> void:
	# Bank the haul or bury the goblin, then tick the night over (issue #9), and
	# slink back to the (new) morning.
	GameState.resolve_raid(result)
	_set_current(null)
	_enter_warren()

# --- Scene ownership ------------------------------------------------------

## Swap the single live scene: free whatever is there, then add the new node
## (or nothing, if null). This is the one place a big scene is added or freed.
func _set_current(node: Node) -> void:
	if _current != null:
		_current.queue_free()
		_current = null
	if node != null:
		_current = node
		add_child(node)

# --- Loading screen -------------------------------------------------------

func _build_loading_ui() -> void:
	_loading_layer = CanvasLayer.new()
	_loading_layer.layer = 100        # above everything
	_loading_layer.visible = false
	add_child(_loading_layer)

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.06)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_layer.add_child(bg)

	_loading_label = Label.new()
	_loading_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading_layer.add_child(_loading_label)

func _show_loading(text: String) -> void:
	_loading_label.text = text
	_loading_layer.visible = true

func _hide_loading() -> void:
	_loading_layer.visible = false
