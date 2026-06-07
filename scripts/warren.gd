extends Control
## M2-3 (#8): the Recruitment / Breeding Den — the one hand-built warren room the
## vertical slice commits to (decision L). Cursor-driven, greybox.
##
## Each MORNING forces exactly ONE consequential choice (decision I) that changes
## HOW tonight's raid plays, not just raw power: the player packs ONE kit
## (lockpicks OR stink bomb) — picking one locks out the other for that raid.
## The choice is written into GameState.loadout; the raid reads it. The raid can't
## be launched until the choice is made.
##
## Built in code to match the project's style (the raid level is built in code
## too — the .tscn is a bare root node). Recruitment/breeding proper, the economy,
## and job assignment arrive in later M2 issues (#9, #12).

signal go_raid

## The kits on offer this morning. Keys MUST match GameState.KIT_* ids; the raid
## (fun_probe.gd) reads the same ids back to decide how it plays.
const KITS := {
	GameState.KIT_LOCKPICKS: {
		"label": "Lockpicks",
		"short": "lockpicks",
		"blurb": "Pick the barred gate open -> a second, QUIET way out.\nNo need to go Goblin Mode to smash out that side.",
	},
	GameState.KIT_STINK: {
		"label": "Stink bomb",
		"short": "stink bomb",
		"blurb": "One throw (press F in the raid) -> guards rush the pong,\npulling them off a chokepoint so you slip past.",
	},
}

var _hoard: Label
var _go_btn: Button
var _choice_hint: Label
var _kit_btns := {}        # kit id -> Button

func _ready() -> void:
	GameState.loadout = ""   # a fresh morning: the choice must be made again
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.12, 0.09)   # mossy day-warren murk
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var title := Label.new()
	title.text = "THE WARREN — Breeding Den  (morning)"
	title.position = Vector2(40, 30)
	title.add_theme_font_size_override("font_size", 26)
	add_child(title)

	# --- Roster + hoard panel (left) ---
	_label("Yer goblins:", Vector2(40, 86), 16)
	var y := 112
	for g in GameState.roster:
		var nm: String = str(g.get("name", "?"))
		var alive: bool = bool(g.get("alive", true))
		var line := _label("  - %s%s" % [nm, "" if alive else "  (dead)"], Vector2(40, y), 14)
		if not alive:
			line.modulate = Color(1, 1, 1, 0.4)
		y += 24
	_hoard = _label("", Vector2(40, y + 8), 14)
	_label("Tonight's mark: %s" % str(GameState.chosen_target.get("name", "—")),
		Vector2(40, y + 32), 14).modulate = Color(1, 0.9, 0.6)

	# --- The forced morning choice (right column, STACKED so nothing overlaps) ---
	_label("Pack ONE kit for tonight — the other's locked out:", Vector2(360, 84), 16)
	var ky := 116
	for kit_id in KITS:
		var info: Dictionary = KITS[kit_id]
		var btn := Button.new()
		btn.text = info.label
		btn.position = Vector2(360, ky)
		btn.size = Vector2(240, 40)
		btn.pressed.connect(_on_pick.bind(kit_id))
		add_child(btn)
		_kit_btns[kit_id] = btn
		# Blurb under each button, width-constrained + word-wrapped so a long line
		# can never run into the next column.
		var blurb := _label(info.blurb, Vector2(360, ky + 44), 12)
		blurb.size = Vector2(560, 36)
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD
		blurb.modulate = Color(1, 1, 1, 0.7)
		ky += 100

	# --- Launch (gated on the choice) ---
	_go_btn = Button.new()
	_go_btn.text = "Go raid  >"
	_go_btn.position = Vector2(360, ky + 16)
	_go_btn.size = Vector2(240, 52)
	_go_btn.disabled = true
	_go_btn.pressed.connect(func() -> void: go_raid.emit())
	add_child(_go_btn)

	_choice_hint = _label("Choose a kit first.", Vector2(360, ky + 78), 14)
	_choice_hint.modulate = Color(1, 0.8, 0.5)

	_refresh()

func _on_pick(kit_id: String) -> void:
	if GameState.loadout != "":
		return   # already packed this morning — the choice is locked
	GameState.loadout = kit_id
	for id in _kit_btns:
		var b: Button = _kit_btns[id]
		b.disabled = true                                # lock out further picks
		if id == kit_id:
			b.text = "%s  (PACKED)" % KITS[id].label
			b.modulate = Color(0.6, 1.0, 0.5)            # chosen — green
		else:
			b.modulate = Color(1, 1, 1, 0.35)            # locked out — greyed
	_go_btn.disabled = false
	_choice_hint.text = "Packed the %s. Slink out when ready." % KITS[kit_id].short
	_choice_hint.modulate = Color(0.6, 1.0, 0.5)

func _label(text: String, pos: Vector2, size := 14) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	add_child(l)
	return l

func _refresh() -> void:
	_hoard.text = "Shinies in the hoard: %d" % int(GameState.resources.get("shinies", 0))
