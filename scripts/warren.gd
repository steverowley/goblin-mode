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
		"blurb": "Lockpicks — pick the gate for a quiet 2nd way out (carry loot through it).",
	},
	GameState.KIT_STINK: {
		"label": "Stink bomb",
		"blurb": "Stink bomb — one F-throw lures guards off a chokepoint so you slip past.",
	},
}

## The weapons on offer (combat v3). Keys MUST match GameState.WEAPON_* — the raid
## reads GameState.weapon back. The blurb is the one-line pitch shown in the Den.
const WEAPONS := {
	GameState.WEAPON_KNIFE: {
		"label": "Knife",
		"blurb": "Knife — silent melee stab, unlimited. Sneak right up. (default)",
	},
	GameState.WEAPON_BOW: {
		"label": "Bow",
		"blurb": "Bow — silent arrows, pick guards off from range. Only 3 shots.",
	},
	GameState.WEAPON_WAND: {
		"label": "Wand",
		"blurb": "Wand — bolt chips + STUNS a guard, but it's loud. 3 charges.",
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

	_lbl("THE WARREN — Night %d        Legacy %d" % [GameState.night, GameState.legacy], Vector2(36, 14), 22)
	_lbl("Food %d   Shinies %d   Scrap %d   Holes %d/%d   Unrest [%s%s]" % [
		int(GameState.resources.get("food", 0)), int(GameState.resources.get("shinies", 0)),
		int(GameState.resources.get("scrap", 0)),
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
		if GameState.just_collapsed:
			_lbl(GameState.night_event, Vector2(36, 105), 15, Color(1.0, 0.45, 0.35))
		else:
			_lbl(GameState.night_event, Vector2(36, 106), 14, Color(0.55, 0.9, 1.0))

	_build_roster()
	_build_actions()

func _build_roster() -> void:
	_lbl("Click a name = send raiding   ·   [job] = assign overnight work   —   H hits  S sneak  B brawn", Vector2(36, 132), 12)
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
			_btn("%s  [%s]%s%s" % [g.name, _stat_str(g), _trait_tag(g), "   <- SENT" if sent else ""],
				Vector2(36, ry), Vector2(290, 30),
				_on_pick_sent.bind(g.id), false,
				Color(0.6, 1.0, 0.5) if sent else Color.WHITE)
			# Overnight job toggle (#12) — disabled for the raider (it's out tonight).
			_btn(_job_label(g), Vector2(332, ry), Vector2(126, 30), _on_cycle_job.bind(g.id), sent,
				Color(1, 1, 1, 0.35) if sent else _job_tint(g))
		else:
			var mtag: String = "  *MUTANT*" if g.get("mutant", false) else ""
			_lbl("%s  [%s]%s (pup — grows up tonight)%s" % [g.name, _stat_str(g), _trait_tag(g), mtag], Vector2(40, ry + 6), 13, Color(1, 0.9, 0.6) if mtag != "" else Color(1, 1, 1, 0.5))
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
	_btn("Dig a mud-hole   (%d scrap)" % GameState.DIG_SCRAP, Vector2(470, 80), Vector2(260, 30), _on_dig, not GameState.can_dig())
	_btn("Breed a pup   (%d food)" % GameState.BREED_FOOD, Vector2(470, 114), Vector2(260, 30), _on_breed, not GameState.can_breed())
	_lbl(_breed_hint(), Vector2(470, 148), 12, Color(1, 1, 1, 0.55))

	# Forced kit choice (issue #8) — two options side by side, locks in for the night.
	_lbl("Pack a kit tonight:", Vector2(470, 180), 14)
	var kx := 470
	for kit_id in KITS:
		var info: Dictionary = KITS[kit_id]
		var chosen: bool = (GameState.loadout == kit_id)
		var locked: bool = (GameState.loadout != "")
		_btn(info.label + ("  *" if chosen else ""), Vector2(kx, 204), Vector2(128, 30),
			_on_pick_kit.bind(kit_id), locked,
			Color(0.6, 1.0, 0.5) if chosen else (Color(1, 1, 1, 0.4) if locked else Color.WHITE))
		kx += 134
	_lbl(_kit_blurb(), Vector2(470, 238), 11, Color(1, 1, 1, 0.6))

	# Weapon choice (combat v3) — craft ranged gear from scrap, then it's yours for good.
	_lbl("Weapon (craft from scrap — kept for good):", Vector2(470, 268), 13)
	var wx := 470
	for wid in WEAPONS:
		var winfo: Dictionary = WEAPONS[wid]
		var owned: bool = GameState.owns_weapon(wid)
		var cur: bool = (GameState.weapon == wid)
		var wlabel: String = winfo.label
		var wdis := false
		var wtint := Color.WHITE
		if owned:
			if cur:
				wlabel += "  *"
				wtint = Color(0.6, 1.0, 0.5)
		else:
			wlabel += "  (%dsc)" % GameState.weapon_cost(wid)
			if GameState.can_unlock_weapon(wid):
				wtint = Color(1.0, 0.9, 0.5)        # affordable craft — gold
			else:
				wdis = true                          # can't afford yet — tinker for scrap
				wtint = Color(1, 1, 1, 0.35)
		_btn(wlabel, Vector2(wx, 292), Vector2(120, 30), _on_pick_weapon.bind(wid), wdis, wtint)
		wx += 126
	_lbl(WEAPONS[GameState.weapon].blurb, Vector2(470, 326), 11, Color(1, 1, 1, 0.6))

	# Night actions: raid (risky) OR forage (safe). One of them spends the night.
	var can_raid := (not GameState.sent_goblin().is_empty()) and GameState.loadout != ""
	_btn("Go raid  >", Vector2(470, 360), Vector2(200, 42), func() -> void: go_raid.emit(), not can_raid)
	_btn("Forage tonight", Vector2(685, 360), Vector2(180, 42), _on_forage, false, Color(0.7, 0.9, 1.0))
	_lbl(_night_hint(can_raid), Vector2(470, 410), 12, Color(1, 0.85, 0.55))

# --- Action handlers (mutate GameState, then rebuild) ---------------------

func _on_dig() -> void:
	GameState.dig_hut()
	GameState.save_game()
	_build.call_deferred()

func _on_breed() -> void:
	GameState.breed_pup()
	GameState.save_game()
	_build.call_deferred()

func _on_pick_sent(id: int) -> void:
	GameState.set_sent(id)
	_build.call_deferred()

func _on_pick_kit(kit_id: String) -> void:
	if GameState.loadout == "":
		GameState.loadout = kit_id   # locks the choice for tonight
	_build.call_deferred()

func _on_pick_weapon(wid: String) -> void:
	# Owned -> just equip it. Locked but affordable -> craft it (spends scrap) and equip.
	if GameState.owns_weapon(wid):
		GameState.weapon = wid
	elif GameState.can_unlock_weapon(wid):
		GameState.unlock_weapon(wid)
		GameState.weapon = wid
	GameState.save_game()
	_build.call_deferred()

func _on_cycle_job(id: int) -> void:
	GameState.cycle_job(id)          # idle -> cook -> tinker -> idle
	GameState.save_game()
	_build.call_deferred()

func _on_forage() -> void:
	GameState.forage_night()         # +food, ages pups, night advances — no risk
	GameState.loadout = ""           # a brand new morning
	GameState.clear_sent()
	_build.call_deferred()

# --- Hint text ------------------------------------------------------------

func _kit_blurb() -> String:
	if GameState.loadout != "" and KITS.has(GameState.loadout):
		return KITS[GameState.loadout].blurb
	return "Tap a kit to pack it — it locks in for tonight's raid."

func _breed_hint() -> String:
	if GameState.can_breed():
		return "Breeds a pup into a free mud-hole. It can raid once it grows up."
	if GameState.living().size() >= GameState.huts:
		return "No free mud-holes — dig one first (needs scrap; set a Tinker)."
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

## A goblin's trait shown as " {Keen}" (or "" if it has none). The raid effect lives
## in fun_probe; here it's just a badge so you can pick a raider for their perk.
func _trait_tag(g: Dictionary) -> String:
	var t := String(g.get("trait", ""))
	if t != "" and GameState.TRAITS.has(t):
		return " {%s}" % GameState.TRAITS[t].name
	return ""

## The job-toggle button's text + tint for an adult (#12). Cook brings food,
## Tinker scavenges scrap (which digs holes), Idle does nowt.
func _job_label(g: Dictionary) -> String:
	match String(g.get("job", GameState.JOB_IDLE)):
		GameState.JOB_COOK:
			return "[Cook +%d food]" % GameState.COOK_FOOD
		GameState.JOB_TINKER:
			return "[Tinker +%d scrap]" % GameState.TINKER_SCRAP
		_:
			return "[Idle — tap]"

func _job_tint(g: Dictionary) -> Color:
	match String(g.get("job", GameState.JOB_IDLE)):
		GameState.JOB_COOK:
			return Color(0.7, 1.0, 0.7)
		GameState.JOB_TINKER:
			return Color(0.7, 0.85, 1.0)
		_:
			return Color(1, 1, 1, 0.6)

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
