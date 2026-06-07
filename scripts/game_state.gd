extends Node
## The GameState autoload (decisions log, decision U).
##
## Holds ONLY serializable data — the goblin roster as plain data, resources,
## housing, the night count, and the chosen raid params — and NEVER live
## scene-node references. Because it's pure data, this same object can later
## double as the save payload (issue #10). Rule of thumb: if it can't be written
## to JSON, it does not belong in here.

const SCHEMA_VERSION := 1
const SAVE_PATH := "user://goblin_save.json"

## The morning loadout the Recruitment Den writes (issue #8): the one kit the
## player packs for tonight's raid, which the raid reads to change HOW it plays.
const KIT_LOCKPICKS := "lockpicks"
const KIT_STINK := "stink"

## The weapon the goblin carries on the raid (combat v3). Knife = the original
## melee stab (unlimited), Bow = a silent ranged pick-off (limited arrows), Wand =
## a noisy magic bolt that chips AND stuns (limited charges). Unlike the kit, the
## weapon persists across mornings (it's gear, not a one-night consumable). Default
## Knife keeps the standalone Fun Probe byte-identical.
const WEAPON_KNIFE := "knife"
const WEAPON_BOW := "bow"
const WEAPON_WAND := "wand"
## Weapons are CRAFTED from scrap (the gear-progression curve: stealth early with
## the free knife, ranged power later once you've tinkered up the scrap). Knife is
## always owned; once crafted a weapon is kept for good — even across a collapse.
const WEAPON_COST := {WEAPON_BOW: 8, WEAPON_WAND: 10}

## Lives-loop tuning (issue #9 + the food/housing breeding loop). Plain numbers,
## easy to retune on feel. Goblins are lives: you send one adult on the raid, and
## losing it is permanent. New goblins are bred from FOOD into a free mud-HOLE,
## then grow up over one night. Stats + breeding genetics are the next slice.
const STAGE_PUP := "pup"
const STAGE_ADULT := "adult"
const START_HUTS := 4          # mud-holes = population cap (pups included)
const START_FOOD := 6
const START_SHINIES := 8       # a gold buffer so the opening isn't a forced collapse (balance pass)
const START_SCRAP := 0
const BREED_FOOD := 4          # food to breed one pup
const DIG_SCRAP := 5           # SCRAP to dig a new mud-hole (+1 capacity) — tinkers make scrap
const RAID_FOOD := 5           # grub nicked from a farm on a successful raid (raids are the larder)

## Jobs (#12). Idle stay-home adults can WORK overnight: a Cook brings in food, a
## Tinker scavenges scrap (which digs mud-holes). The raider who's out tonight
## can't also work. Goblins also EAT each night — go hungry and unrest rises.
const JOB_IDLE := "idle"
const JOB_COOK := "cook"
const JOB_TINKER := "tinker"
const JOB_CYCLE := [JOB_IDLE, JOB_COOK, JOB_TINKER]   # order the Den button cycles through
const COOK_FOOD := 2           # food a Cook brings in per night
const TINKER_SCRAP := 2        # scrap a Tinker scavenges per night
const FOOD_PER_GOBLIN := 1     # food each living goblin eats per night (starvation -> unrest)

## Goblin stats (Bite 2a). Each 1..STAT_MAX. Health = hits survived on a raid;
## Sneak = quieter; Brawn = lugs loot with less drag. Starters skew LOW health so
## early raids reward stealth — combat-readiness comes from gear/meta later.
const STAT_MIN := 1
const STAT_MAX := 4
const CONCEIVE_CHANCE := 80      # % chance a breeding actually produces a pup
const MUTATION_CHANCE := 14      # % chance a bred pup mutates one stat to a wild value

## Traits (#11): a born-with perk that VISIBLY changes a raid. Data-driven — the
## raid reads the id and applies the effect (see fun_probe._apply_trait), so adding
## a new trait is just another entry here + one match arm. A normal birth/recruit
## has TRAIT_CHANCE to roll one; a MUTANT pup always does (mutation = a wild trait).
const TRAIT_CHANCE := 16
const TRAITS := {
	"nimble": {"name": "Nimble", "blurb": "quick feet — faster, dodges sooner"},
	"brute":  {"name": "Brute",  "blurb": "thick hide — soaks an extra clout (+1 hit)"},
	"lucky":  {"name": "Lucky",  "blurb": "magpie eyes — every shiny's worth more"},
	"keen":   {"name": "Keen",   "blurb": "sharp eyes — sees further, reads rooms sooner"},
	"feral":  {"name": "Feral",  "blurb": "bad temper — hits Goblin Mode quicker, but louder"},
}

## Warren upkeep + nightly events (#12 economy + Bite-3 stakes groundwork). Each
## night gold pays upkeep per living goblin; a shortfall breeds UNREST, and at the
## cap a goblin deserts. (The full run-end collapse waits for meta-progression.)
const UPKEEP_PER_GOBLIN := 2
const UNREST_MAX := 5
const COLLAPSE_NIGHTS := 3       # consecutive nights at MAX unrest before the warren collapses (run ends)

var schema_version := SCHEMA_VERSION
var roster: Array = []              # every goblin ever (alive flag marks the living), each a Dictionary
var resources: Dictionary = {}      # {"shinies": int, "food": int}
var unlocks: Array = []             # unlocked things, as string ids
var chosen_target: Dictionary = {}  # the raid the player picked for tonight
var loadout := ""                   # this morning's packed kit (KIT_* or "")
var weapon := WEAPON_KNIFE           # the carried weapon (WEAPON_*); persists across mornings
var owned_weapons: Array = [WEAPON_KNIFE]   # weapons crafted so far (meta gear — kept across collapse)
var huts := START_HUTS              # housing capacity = max LIVING goblins
var night := 1                      # which night the warren is on
var sent_id := -1                   # id of the goblin sent on tonight's raid (-1 = none chosen)
var fallen: Array = []              # the wall of the dead: [{name, feat}]
var last_raid: Dictionary = {}      # summary of the most recent raid's outcome
var last_event := ""                # short "what just happened" line (raid/forage outcome)
var unrest := 0                     # 0..UNREST_MAX; rises when upkeep goes unpaid
var night_event := ""               # the random thing that happened in the warren overnight
var upkeep_note := ""               # last night's upkeep summary (shown in the Den)
var legacy := 0                     # bloodline renown (meta-progression); recruits scale with it
var collapse_pressure := 0         # consecutive nights at MAX unrest
var just_collapsed := false        # set the morning a warren falls and rises anew (Bite 3)

var _next_id := 0                   # hands out stable unique goblin ids
var _pup_n := 0                     # rolls through the pup-name pool

const _PUP_NAMES := ["Nib", "Squig", "Gob", "Razza", "Mogg", "Krick", "Dribble", "Snot", "Wretch", "Fang"]

func _ready() -> void:
	if not load_game():
		new_game()

## Seed a fresh game. (Persisting + loading this — with versioned migration — is
## issue #10; for now every launch starts a clean warren.)
func new_game() -> void:
	schema_version = SCHEMA_VERSION
	_next_id = 0
	_pup_n = 0
	roster = [
		_make_goblin("Snik", STAGE_ADULT, {"health": 1, "sneak": 4, "brawn": 1}),    # glass sneak — must ghost
		_make_goblin("Grubba", STAGE_ADULT, {"health": 2, "sneak": 1, "brawn": 4}),  # loud bruiser
		_make_goblin("Wort", STAGE_ADULT, {"health": 2, "sneak": 2, "brawn": 2}, "keen"),  # all-rounder, sharp-eyed (shows traits off from night 1)
	]
	resources = {"shinies": START_SHINIES, "food": START_FOOD, "scrap": START_SCRAP}
	unlocks = []
	chosen_target = {"name": "Millfield Cottage", "difficulty": 1}
	loadout = ""
	weapon = WEAPON_KNIFE
	owned_weapons = [WEAPON_KNIFE]
	huts = START_HUTS
	night = 1
	sent_id = -1
	fallen = []
	last_raid = {}
	last_event = ""
	unrest = 0
	night_event = ""
	upkeep_note = ""
	legacy = 0
	collapse_pressure = 0
	just_collapsed = false

# --- Save / load (issue #10). GameState is serializable-only by design, so this
# is a straight JSON dump, versioned for future migration. ----------------------

func _save_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"roster": roster, "resources": resources, "unlocks": unlocks,
		"chosen_target": chosen_target, "loadout": loadout, "weapon": weapon, "owned_weapons": owned_weapons, "huts": huts, "night": night,
		"sent_id": sent_id, "fallen": fallen, "last_raid": last_raid, "last_event": last_event,
		"unrest": unrest, "night_event": night_event, "upkeep_note": upkeep_note,
		"legacy": legacy, "collapse_pressure": collapse_pressure,
		"next_id": _next_id, "pup_n": _pup_n,
	}

func _apply_dict(data: Dictionary) -> bool:
	if int(data.get("schema_version", -1)) != SCHEMA_VERSION:
		return false   # incompatible save -> caller starts a new game
	# Reject a structurally-broken save cleanly, rather than leaning on engine error
	# recovery when a present-but-wrong-type field would throw on the typed assigns below.
	if typeof(data.get("roster", [])) != TYPE_ARRAY:
		return false
	if typeof(data.get("resources", {})) != TYPE_DICTIONARY:
		return false
	if typeof(data.get("fallen", [])) != TYPE_ARRAY:
		return false
	if typeof(data.get("unlocks", [])) != TYPE_ARRAY:
		return false
	if typeof(data.get("owned_weapons", [])) != TYPE_ARRAY:
		return false
	if typeof(data.get("chosen_target", {})) != TYPE_DICTIONARY:
		return false
	if typeof(data.get("last_raid", {})) != TYPE_DICTIONARY:
		return false
	roster = data.get("roster", [])
	resources = data.get("resources", {"shinies": 0, "food": START_FOOD})
	unlocks = data.get("unlocks", [])
	chosen_target = data.get("chosen_target", {})
	loadout = String(data.get("loadout", ""))
	weapon = String(data.get("weapon", WEAPON_KNIFE))
	owned_weapons = data.get("owned_weapons", [WEAPON_KNIFE])
	huts = int(data.get("huts", START_HUTS))
	night = int(data.get("night", 1))
	sent_id = int(data.get("sent_id", -1))
	fallen = data.get("fallen", [])
	last_raid = data.get("last_raid", {})
	last_event = String(data.get("last_event", ""))
	unrest = int(data.get("unrest", 0))
	night_event = String(data.get("night_event", ""))
	upkeep_note = String(data.get("upkeep_note", ""))
	legacy = int(data.get("legacy", 0))
	collapse_pressure = int(data.get("collapse_pressure", 0))
	_next_id = int(data.get("next_id", roster.size()))
	_pup_n = int(data.get("pup_n", 0))
	just_collapsed = false
	# JSON turns every number into a float — coerce the goblins' ints back.
	for g in roster:
		g.id = int(g.get("id", 0))
		g.best = int(g.get("best", 0))
		var s: Dictionary = g.get("stats", {})
		for k in s.keys():
			s[k] = int(s[k])
	return true

## Autosave the warren to disk. Skipped under --headless so tests don't clobber a
## real save.
func save_game() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_save_dict()))
		f.close()

## Load a saved warren. False (state untouched) if there's no save, it's
## unreadable, or the schema version mismatches — caller then starts a new game.
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		return false
	return _apply_dict(data)

func _make_goblin(gname: String, stage: String, stats: Dictionary, trait_id := "") -> Dictionary:
	var g := {"id": _next_id, "name": gname, "stage": stage, "alive": true, "best": 0, "stats": stats, "trait": trait_id, "job": JOB_IDLE}
	_next_id += 1
	return g

## A random trait id, or "" — used at each birth/recruit site. Mutant pups force a
## trait (pass force=true); everyone else only rolls one TRAIT_CHANCE of the time.
func _roll_trait(force := false) -> String:
	if not force and randi() % 100 >= TRAIT_CHANCE:
		return ""
	var keys := TRAITS.keys()
	return String(keys[randi() % keys.size()])

## Random starting stats for a fresh recruit (bred pup / free runt). Health skews
## low for now; genetics (Bite 2b) will replace this with parent inheritance.
func _random_stats() -> Dictionary:
	return {"health": randi_range(1, 2), "sneak": randi_range(STAT_MIN, STAT_MAX), "brawn": randi_range(STAT_MIN, STAT_MAX)}

## A fresh recruit's stats (free runt / a stray that joins): random PLUS the
## warren's accumulated META bonus — so as your legacy grows, recruits arrive
## tougher (bred pups use genetics instead). This is what carries across a run.
func _recruit_stats() -> Dictionary:
	var b := _legacy_bonus()
	var s := _random_stats()
	for k in s.keys():
		s[k] = clampi(int(s[k]) + b, STAT_MIN, STAT_MAX)
	return s

func _legacy_bonus() -> int:
	return clampi(legacy / 8, 0, 2)

# --- Queries --------------------------------------------------------------

func living() -> Array:
	return roster.filter(func(g): return g.alive)

func adults() -> Array:
	return roster.filter(func(g): return g.alive and g.stage == STAGE_ADULT)

func pups() -> Array:
	return roster.filter(func(g): return g.alive and g.stage == STAGE_PUP)

func goblin_by_id(id: int) -> Dictionary:
	for g in roster:
		if g.id == id:
			return g
	return {}

## The goblin packed off on tonight's raid — empty {} if none chosen yet, or if
## the chosen one is no longer a living adult (it must be re-picked).
func sent_goblin() -> Dictionary:
	var g := goblin_by_id(sent_id)
	if g.is_empty() or not g.alive or g.stage != STAGE_ADULT:
		return {}
	return g

# --- Day actions (instant, repeatable while affordable) -------------------

func can_dig() -> bool:
	return int(resources.get("scrap", 0)) >= DIG_SCRAP

func dig_hut() -> bool:
	if not can_dig():
		return false
	resources.scrap = int(resources.get("scrap", 0)) - DIG_SCRAP
	huts += 1
	return true

## --- Weapon crafting (gear progression). Knife is free/always owned; bow & wand
## are crafted from scrap and then kept for good (across collapse). ---
func weapon_cost(wid: String) -> int:
	return int(WEAPON_COST.get(wid, 0))

func owns_weapon(wid: String) -> bool:
	return wid == WEAPON_KNIFE or wid in owned_weapons

func can_unlock_weapon(wid: String) -> bool:
	return not owns_weapon(wid) and int(resources.get("scrap", 0)) >= weapon_cost(wid)

func unlock_weapon(wid: String) -> bool:
	if not can_unlock_weapon(wid):
		return false
	resources.scrap = int(resources.get("scrap", 0)) - weapon_cost(wid)
	owned_weapons.append(wid)
	return true

## Cycle a goblin's overnight job (idle -> cook -> tinker -> idle). The Den drives
## this; the raider's job is skipped the night it's out raiding.
func cycle_job(id: int) -> void:
	var g := goblin_by_id(id)
	if g.is_empty():
		return
	var cur := String(g.get("job", JOB_IDLE))
	var i: int = JOB_CYCLE.find(cur)
	g.job = JOB_CYCLE[(i + 1) % JOB_CYCLE.size()]

func can_breed() -> bool:
	return living().size() < huts and int(resources.get("food", 0)) >= BREED_FOOD

func breed_pup() -> bool:
	if not can_breed():
		return false
	resources.food -= BREED_FOOD
	# The pair don't always take (the attempt still costs food).
	if randi() % 100 >= CONCEIVE_CHANCE:
		last_event = "The breeding pair didn't take this time."
		return false
	# Genetics: the pup inherits a BLEND of the two best adults' stats, with a rare
	# mutation throwing one stat wild.
	var stats := _breed_stats()
	var mutated := false
	if randi() % 100 < MUTATION_CHANCE:
		mutated = true
		var keys := ["health", "sneak", "brawn"]
		var k: String = keys[randi() % keys.size()]
		stats[k] = randi_range(STAT_MIN, STAT_MAX)
	# A mutant ALWAYS expresses a trait; an ordinary pup might inherit one.
	var trait_id := _roll_trait(mutated)
	var pup := _make_goblin(_pup_name(), STAGE_PUP, stats, trait_id)
	pup["mutant"] = mutated
	roster.append(pup)
	var trait_bit := "  [%s]" % TRAITS[trait_id].name if trait_id != "" else ""
	last_event = "Bred %s! (H%d S%d B%d)%s%s" % [pup.name, stats.health, stats.sneak, stats.brawn, trait_bit, "  — a MUTATION!" if mutated else ""]
	return true

## A pup's inherited stats: a blend of the two STRONGEST adults' (your bloodline),
## with small jitter. Falls back to random stats if there aren't two to breed from.
func _breed_stats() -> Dictionary:
	var ad := adults()
	if ad.size() < 2:
		return _recruit_stats()
	var best: Dictionary = ad[0]
	var second: Dictionary = ad[1]
	if _stat_sum(second) > _stat_sum(best):
		var t := best; best = second; second = t
	for i in range(2, ad.size()):
		var g: Dictionary = ad[i]
		if _stat_sum(g) > _stat_sum(best):
			second = best
			best = g
		elif _stat_sum(g) > _stat_sum(second):
			second = g
	return _inherit(best, second)

func _stat_sum(g: Dictionary) -> int:
	var s: Dictionary = g.get("stats", {})
	return int(s.get("health", 0)) + int(s.get("sneak", 0)) + int(s.get("brawn", 0))

func _inherit(a: Dictionary, b: Dictionary) -> Dictionary:
	var sa: Dictionary = a.get("stats", {})
	var sb: Dictionary = b.get("stats", {})
	var out := {}
	for k in ["health", "sneak", "brawn"]:
		var avg := (int(sa.get(k, 2)) + int(sb.get(k, 2))) / 2.0
		out[k] = clampi(int(round(avg + randf_range(-0.6, 0.6))), STAT_MIN, STAT_MAX)
	return out

func set_sent(id: int) -> void:
	sent_id = id

func clear_sent() -> void:
	sent_id = -1

# --- Night resolution -----------------------------------------------------

## A safe night: forage for food while the warren minds itself. Time still passes
## (pups grow), but there's no raid and no risk. The always-available
## anti-softlock action (decision K).
func forage_night() -> void:
	var got := _forage_roll()
	resources.food += got
	last_event = ("Foraged: +%d food." % got) if got > 0 else "Foraged: slim pickings — found nowt."
	advance_night()

## Luck-based and meagre — most food should come from RAIDS, not foraging. Usually
## slim, occasionally a decent find.
func _forage_roll() -> int:
	var r := randi() % 100
	if r < 35:
		return 0
	elif r < 80:
		return 1
	elif r < 95:
		return 2
	return 3

## Apply a raid's outcome to the sent goblin, then tick the night over. An ESCAPE
## ("won") banks the loot and the goblin lives; any LOSS (caught or caught by
## dawn) is permadeath — un-banked loot is lost, the goblin is gone for good and
## its name + best feat go on the wall of the dead.
func resolve_raid(result: Dictionary) -> void:
	var g := sent_goblin()
	var rid: int = int(g.id) if not g.is_empty() else -1
	var who: String = String(g.name) if not g.is_empty() else "The goblin"
	if String(result.get("outcome", "lost")) == "won":
		var loot := int(result.get("loot", 0))
		resources.shinies += loot
		resources.food += RAID_FOOD                 # robbed a farm -> grub for the warren
		legacy += 1                                 # the bloodline's renown grows with every score
		if not g.is_empty():
			g.best = maxi(int(g.best), loot)
		last_event = "%s legged it: +%d shinies, +%d grub." % [who, loot, RAID_FOOD]
	else:
		if not g.is_empty():
			g.alive = false
			fallen.append({"name": g.name, "feat": _feat_for(g)})
		last_event = "%s got nabbed — gone for good." % who
	last_raid = result
	clear_sent()
	loadout = ""
	advance_night(rid)

## Tick to the next morning: pups grow into adults, the night advances, and the
## anti-softlock backstop guarantees you're never wiped out — if every goblin is
## dead, a free runt wanders in.
func advance_night(raider_id := -1) -> void:
	night += 1
	just_collapsed = false

	# Jobs (#12): stay-home adults work overnight. The raider's out tonight, so it
	# doesn't pull a shift — pups can't work yet (they grow up below).
	var prod_food := 0
	var prod_scrap := 0
	for g in roster:
		if g.alive and g.stage == STAGE_ADULT and g.id != raider_id:
			match String(g.get("job", JOB_IDLE)):
				JOB_COOK:
					prod_food += COOK_FOOD
				JOB_TINKER:
					prod_scrap += TINKER_SCRAP
	resources.food = int(resources.get("food", 0)) + prod_food
	resources.scrap = int(resources.get("scrap", 0)) + prod_scrap

	# Pups grow up.
	for g in roster:
		if g.alive and g.stage == STAGE_PUP:
			g.stage = STAGE_ADULT

	# Compose ONE overnight economy line (workers / hunger / upkeep) for the Den.
	var report := PackedStringArray()
	if prod_food > 0 or prod_scrap > 0:
		var bits := PackedStringArray()
		if prod_food > 0:
			bits.append("+%d food" % prod_food)
		if prod_scrap > 0:
			bits.append("+%d scrap" % prod_scrap)
		report.append("Workers: " + ", ".join(bits))

	# The warren EATS (food). A shortfall is hunger -> unrest.
	var mouths := living().size() * FOOD_PER_GOBLIN
	var food_have := int(resources.get("food", 0))
	var ate := mini(food_have, mouths)
	resources.food = food_have - ate
	var hungry := mouths - ate
	if hungry > 0:
		unrest = mini(UNREST_MAX, unrest + 1)
		report.append("HUNGRY! short %d food — unrest rising" % hungry)

	# Upkeep (gold). Pay what you can; only a DESTITUTE night (couldn't pay a single
	# shiny) builds collapse pressure, so a won or part-paid night treads water — it's
	# rock-bottom destitution for COLLAPSE_NIGHTS running that ends a run, not merely
	# being a bit short (balance pass — fixes the night-4 force-collapse).
	var cost := living().size() * UPKEEP_PER_GOBLIN
	var have := int(resources.get("shinies", 0))
	var paid := mini(have, cost)
	resources.shinies = have - paid
	if paid >= cost:
		collapse_pressure = 0
		report.append("Upkeep paid: -%d shinies" % cost)
		# A fed, paid-up warren settles — but a hungry one won't be soothed by gold.
		if hungry == 0 and unrest > 0:
			unrest = maxi(0, unrest - 1)
	elif paid > 0:
		collapse_pressure = 0           # part-paid still keeps the lid on the riot
		unrest = mini(UNREST_MAX, unrest + 1)
		report.append("Upkeep part-paid: -%d of %d shinies — grumbling" % [paid, cost])
	else:
		unrest = mini(UNREST_MAX, unrest + 1)
		collapse_pressure += 1
		report.append("Upkeep %d shinies — NOTHING in the pot! Unrest rising" % cost)
	upkeep_note = "  |  ".join(report)

	# Too many broke nights unable to pay gold upkeep -> the warren collapses (run-end; meta carries on).
	if collapse_pressure >= COLLAPSE_NIGHTS:
		start_new_run()
		return
	# One thing happens overnight: a desertion if the warren's boiling over, else a
	# random warren event. Mutually exclusive — you never lose two goblins in a night.
	if unrest >= UNREST_MAX and living().size() > 1:
		night_event = _desert()
	else:
		night_event = _roll_night_event()
	# Anti-softlock backstop: never fully wiped out.
	if living().is_empty():
		roster.append(_make_goblin(_pup_name(), STAGE_ADULT, _recruit_stats(), _roll_trait()))
	save_game()

## The warren has fallen (sustained unrest). A roguelike run-end: the LEGACY carries
## forward (+ a bump for the fallen warren's renown) and the wall of the dead is
## kept, but the warren itself resets — a fresh, legacy-boosted gang rises to try
## again. (The full run-end collapse the user chose; needs no extra "keep" plumbing
## because GameState already separates legacy/fallen from the warren state.)
func start_new_run() -> void:
	legacy += 2                      # the fallen warren's renown carries forward
	_next_id = 0
	_pup_n = 0
	roster = [
		_make_goblin("Snik", STAGE_ADULT, _recruit_stats(), _roll_trait()),
		_make_goblin("Grubba", STAGE_ADULT, _recruit_stats(), _roll_trait()),
		_make_goblin("Wort", STAGE_ADULT, _recruit_stats(), _roll_trait()),
	]
	resources = {"shinies": START_SHINIES, "food": START_FOOD, "scrap": START_SCRAP}
	huts = START_HUTS
	night = 1
	unrest = 0
	collapse_pressure = 0
	sent_id = -1
	loadout = ""
	last_event = ""
	upkeep_note = ""
	just_collapsed = true
	night_event = "Warren COLLAPSED — risen anew. Legacy %d carries on." % legacy
	save_game()

## One random overnight happening, applied + described (shown in the Den next
## morning). Greybox flavour with light economy nudges.
func _roll_night_event() -> String:
	var r := randi() % 100
	if r < 14:
		var n := randi_range(2, 5)
		resources.shinies += n
		return "A goblin dug up an old stash — +%d shinies." % n
	elif r < 28:
		var n := randi_range(2, 4)
		resources.food += n
		return "A good night's foraging out back — +%d food." % n
	elif r < 40:
		if living().size() < huts:
			roster.append(_make_goblin(_pup_name(), STAGE_ADULT, _recruit_stats(), _roll_trait()))
			return "A stray goblin wandered in an' stayed."
		return "A stray sniffed about but found no free hole."
	elif r < 56:
		var n := mini(int(resources.get("food", 0)), randi_range(1, 3))
		resources.food -= n
		return ("Rats got into the stores — -%d food." % n) if n > 0 else "Rats nosed about but found nowt to nick."
	elif r < 70:
		unrest = mini(UNREST_MAX, unrest + 1)
		return "A scrap broke out in the pit — the warren's restless."
	elif r < 78:
		var a := living()
		if a.size() > 1:
			var g: Dictionary = a[randi() % a.size()]
			g.alive = false
			fallen.append({"name": g.name, "feat": "slunk off into the night"})
			return "%s slunk off in the night — gone." % g.name
		return "A restless night, but the gang held."
	return "A quiet night in the warren."

## Unrest at the cap: a fed-up goblin deserts (recoverable — breed more). Never the
## last one (anti-softlock). Returns its own short headline for the Den.
func _desert() -> String:
	var a := living()
	if a.size() <= 1:
		return night_event
	var g: Dictionary = a[randi() % a.size()]
	g.alive = false
	fallen.append({"name": g.name, "feat": "deserted in the uproar"})
	unrest = maxi(0, unrest - 2)
	return "%s had enough of the squalor — DESERTED!" % g.name

func _feat_for(g: Dictionary) -> String:
	if int(g.get("best", 0)) > 0:
		return "best haul: %d shinies" % int(g.best)
	return "fell on night %d, never scored" % night

func _pup_name() -> String:
	var nm: String = _PUP_NAMES[_pup_n % _PUP_NAMES.size()]
	if _pup_n >= _PUP_NAMES.size():
		nm += str(_pup_n)   # keep names unique once we've cycled the pool
	_pup_n += 1
	return nm
