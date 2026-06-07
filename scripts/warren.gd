extends Control
## M2-1 placeholder Warren (the day room).
##
## The real Recruitment/Breeding Den, economy, and job assignment arrive in
## later M2 issues (#8, #12). For the tracer bullet this is just a readout of the
## persistent GameState plus one button that fires the raid — enough to SEE the
## day->night->return loop run end to end (last night's loot lands in the hoard).
##
## Built in code to match the project's style (the raid level is built in code
## too — the .tscn is a bare root node).

signal go_raid

var _hoard: Label
var _roster: Label
var _target: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.12, 0.09)   # mossy day-warren murk
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var title := Label.new()
	title.text = "THE WARREN — day"
	title.position = Vector2(40, 36)
	title.add_theme_font_size_override("font_size", 28)
	add_child(title)

	_hoard = _stat(Vector2(40, 110))
	_roster = _stat(Vector2(40, 140))
	_target = _stat(Vector2(40, 170))

	var btn := Button.new()
	btn.text = "Go raid  >"
	btn.position = Vector2(40, 232)
	btn.size = Vector2(220, 56)
	btn.pressed.connect(func() -> void: go_raid.emit())
	add_child(btn)

	var hint := Label.new()
	hint.text = "Night falls when you raid. Nick shinies, slink home, watch the hoard grow."
	hint.position = Vector2(40, 320)
	hint.modulate = Color(1, 1, 1, 0.6)
	add_child(hint)

	_refresh()

func _stat(pos: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	add_child(l)
	return l

func _refresh() -> void:
	_hoard.text = "Shinies in the hoard: %d" % int(GameState.resources.get("shinies", 0))
	_roster.text = "Goblins in the warren: %d" % GameState.roster.size()
	_target.text = "Tonight's mark: %s" % str(GameState.chosen_target.get("name", "—"))
