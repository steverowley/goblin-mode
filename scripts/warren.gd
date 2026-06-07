extends Control
## M2 Recruitment / Breeding Den — the warren-management day screen.
##
## #8 gave it the forced morning KIT choice. This slice (the "lives loop", ≈ #9
## + the food/housing breeding from #12) turns it into the real day phase:
##  - DIG a mud-hole (shinies) to raise the population cap.
##  - BREED a pup (food, into a free hole); pups GROW UP over one night.
##  - pick WHICH adult goes raiding — goblins are lives, and a lost raid is
##    permadeath (decision N/M/K).
##  - RAID (risky, for shinies) or FORAGE (safe, for food + time) to spend the night.
##
## Built in code (matching the project style) and rebuilt from GameState after
## every action, so the screen is always a straight read of the data.

signal go_raid

## The kits on offer. Keys MUST match GameState.KIT_* ids; the raid reads them back.
const KITS := {
	GameState.KIT_LOCKPICKS: {
		"label": "Lockpicks",
		"blurb": "Pick the gate open -> a quiet\n2nd way out (no Goblin Mode).",
	},
	GameState.KIT_STINK: {
		"label": "Stink bomb",
		"blurb": "One F-throw lures the guards off\na chokepoint so you slip past.",
	},
}

func _ready() -> void:
	# A fresh morning: last night's kit + raider pick are spent.
	GameState.loadout = ""
	GameState.clear_sent()
	_build()

# --- Build the whole screen from GameState --------------------------------

func _build() -> void:
	for c in get_children():
		c.queue_free()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.12, 0.09)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_lbl("THE WARREN — Night %d" % GameState.night, Vector2(36, 14), 22)
	_lbl("Food %d   Shinies %d   Holes %d/%d   Unrest [%s%s]" % [
		int(GameState.resources.get("food", 0)), int(GameState.resources.get("shinies", 0)),
		GameState.living().size(), GameState.huts,
		"#".repeat(GameState.unrest), "-".repeat(GameState.UNREST_MAX - GameState.unrest),
	], Vector2(36, 48), 14, Color(1, 0.9, 0.6))
	# Morning report — three loud lines: the raid/forage result, the upkeep drain,
	# and what happened in the warren overnight.
	if GameState.last_event != "":
		_lbl(GameState.last_event, Vector2(36, 70), 13, Color(0.75, 1.0, 0.7))
	if GameState.upkeep_note != "":
		_lbl(GameState.upkeep_note, Vector2(36, 88), 13, Color(1.0, 0.75, 0.4))
	if GameState.night_event != "":
		_lbl(GameState.night_event, Vector2(36, 106), 14, Color(0.55, 0.9, 1.0))

	_build_roster()
	_build_actions()

func _build_roster() -> void:
	_lbl("Send tonight (click an adult)    —    H = hits   S = sneak   B = brawn", Vector2(36, 132), 13)
	# Adults first (they're the pickable ones), then pups — so a sendable goblin is
	# always near the top, and the list is capped so it never runs off a big warren.
	var rows: Array = GameState.adults()
	rows.append_array(GameState.pups())

	var ry := 154
	var max_visible := 8
	for i in range(rows.size()):
		if i == max_visible - 1 and rows.size() > max_visible:
			_lbl("...and %d more snoozing in the holes." % (rows.size() - i), Vector2(40, ry + 6), 12, Color(1, 1, 1, 0.5))
			break
		var g: Dictionary = rows[i]
		if g.stage == GameState.STAGE_ADULT:
			var sent: bool = (g.id == GameState.sent_id)
			_btn("%s  [%s]%s" % [g.name, _stat_str(g), "   <- SENT" if sent else ""],
				Vector2(36, ry), Vector2(290, 30),
				_on_pick_sent.bind(g.id), false,
				Color(0.6, 1.0, 0.5) if sent else Color.WHITE)
		else:
			_lbl("%s  [%s] (pup — grows up tonight)" % [g.name, _stat_str(g)], Vector2(40, ry + 6), 13, Color(1, 1, 1, 0.5))
		ry += 36

	# Wall of the dead — anchored to a fixed lower-left spot, independent of roster size.
	_lbl("Wall of the dead: %d" % GameState.fallen.size(), Vector2(36, 452), 13, Color(1, 1, 1, 0.45))
	var shown := 0
	for i in range(GameState.fallen.size() - 1, -1, -1):
		if shown >= 3:
			break
		var d: Dictionary = GameState.fallen[i]
		_lbl("  + %s — %s" % [d.name, d.feat], Vector2(36, 472 + shown * 18), 11, Color(1, 0.6, 0.6, 0.7))
		shown += 1

func _build_actions() -> void:
	# Build actions (instant, repeatable while affordable).
	_lbl("Build (anytime):", Vector2(470, 54), 14)
	_btn("Dig a mud-hole   (%d shinies)" % GameState.DIG_SHINIES, Vector2(470, 80), Vector2(260, 32), _on_dig, not GameState.can_dig())
	_btn("Breed a pup   (%d food)" % GameState.BREED_FOOD, Vector2(470, 118), Vector2(260, 32), _on_breed, not GameState.can_breed())
	_lbl(_breed_hint(), Vector2(470, 156), 12, Color(1, 1, 1, 0.55))

	# The forced kit choice (issue #8).
	_lbl("Tonight — pack a kit:", Vector2(470, 198), 14)
	var ky := 222
	for kit_id in KITS:
		var info: Dictionary = KITS[kit_id]
		var chosen: bool = (GameState.loadout == kit_id)
		var locked: bool = (GameState.loadout != "")
		_btn(info.label + ("  (PACKED)" if chosen else ""), Vector2(470, ky), Vector2(260, 32),
			_on_pick_kit.bind(kit_id), locked,
			Color(0.6, 1.0, 0.5) if chosen else (Color(1, 1, 1, 0.4) if locked else Color.WHITE))
		_lbl(info.blurb, Vector2(470, ky + 36), 11, Color(1, 1, 1, 0.6))
		ky += 76

	# Night actions: raid (risky) OR forage (safe). One of them spends the night.
	var can_raid := (not GameState.sent_goblin().is_empty()) and GameState.loadout != ""
	_btn("Go raid  >", Vector2(470, ky + 10), Vector2(200, 42), func() -> void: go_raid.emit(), not can_raid)
	_btn("Forage tonight", Vector2(685, ky + 10), Vector2(180, 42), _on_forage, false, Color(0.7, 0.9, 1.0))
	_lbl(_night_hint(can_raid), Vector2(470, ky + 60), 12, Color(1, 0.85, 0.55))

# --- Action handlers (mutate GameState, then rebuild) ---------------------

func _on_dig() -> void:
	GameState.dig_hut()
	_build.call_deferred()

func _on_breed() -> void:
	GameState.breed_pup()
	_build.call_deferred()

func _on_pick_sent(id: int) -> void:
	GameState.set_sent(id)
	_build.call_deferred()

func _on_pick_kit(kit_id: String) -> void:
	if GameState.loadout == "":
		GameState.loadout = kit_id   # locks the choice for tonight
	_build.call_deferred()

func _on_forage() -> void:
	GameState.forage_night()         # +food, ages pups, night advances — no risk
	GameState.loadout = ""           # a brand new morning
	GameState.clear_sent()
	_build.call_deferred()

# --- Hint text ------------------------------------------------------------

func _breed_hint() -> String:
	if GameState.can_breed():
		return "Breeds a pup into a free mud-hole. It can raid once it grows up."
	if GameState.living().size() >= GameState.huts:
		return "No free mud-holes — dig one first (needs shinies from a raid)."
	return "Not enough food — forage tonight for more."

func _night_hint(can_raid: bool) -> String:
	if can_raid:
		return "Send 'em raiding for shinies (risky — a loss\nis for keeps), or forage for a safe night."
	var need := PackedStringArray()
	if GameState.sent_goblin().is_empty():
		need.append("pick an adult to send")
	if GameState.loadout == "":
		need.append("pack a kit")
	return "To raid: " + " + ".join(need) + ".\nOr just forage tonight."

# --- Tiny builders --------------------------------------------------------

func _stat_str(g: Dictionary) -> String:
	var s: Dictionary = g.get("stats", {})
	return "H%d S%d B%d" % [int(s.get("health", 1)), int(s.get("sneak", 2)), int(s.get("brawn", 2))]

func _lbl(text: String, pos: Vector2, size := 14, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.modulate = col
	add_child(l)
	return l

func _btn(text: String, pos: Vector2, size: Vector2, cb: Callable, disabled := false, tint := Color.WHITE) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.disabled = disabled
	b.modulate = tint
	b.pressed.connect(cb)
	add_child(b)
	return b
