extends Node
## The GameState autoload (decisions log, decision U).
##
## Holds ONLY serializable data — the goblin roster as plain data, resources,
## housing, the night count, and the chosen raid params — and NEVER live
## scene-node references. Because it's pure data, this same object can later
## double as the save payload (issue #10). Rule of thumb: if it can't be written
## to JSON, it does not belong in here.

const SCHEMA_VERSION := 1

## The morning loadout the Recruitment Den writes (issue #8): the one kit the
## player packs for tonight's raid, which the raid reads to change HOW it plays.
const KIT_LOCKPICKS := "lockpicks"
const KIT_STINK := "stink"

## Lives-loop tuning (issue #9 + the food/housing breeding loop). Plain numbers,
## easy to retune on feel. Goblins are lives: you send one adult on the raid, and
## losing it is permanent. New goblins are bred from FOOD into a free mud-HOLE,
## then grow up over one night. Stats + breeding genetics are the next slice.
const STAGE_PUP := "pup"
const STAGE_ADULT := "adult"
const START_HUTS := 4          # mud-holes = population cap (pups included)
const START_FOOD := 6
const BREED_FOOD := 4          # food to breed one pup
const DIG_SHINIES := 8         # shinies to dig a new mud-hole (+1 capacity)
const RAID_FOOD := 5           # grub nicked from a farm on a successful raid (raids are the larder)

## Goblin stats (Bite 2a). Each 1..STAT_MAX. Health = hits survived on a raid;
## Sneak = quieter; Brawn = lugs loot with less drag. Starters skew LOW health so
## early raids reward stealth — combat-readiness comes from gear/meta later.
const STAT_MIN := 1
const STAT_MAX := 4
const CONCEIVE_CHANCE := 80      # % chance a breeding actually produces a pup
const MUTATION_CHANCE := 14      # % chance a bred pup mutates one stat to a wild value

## Warren upkeep + nightly events (#12 economy + Bite-3 stakes groundwork). Each
## night gold pays upkeep per living goblin; a shortfall breeds UNREST, and at the
## cap a goblin deserts. (The full run-end collapse waits for meta-progression.)
const UPKEEP_PER_GOBLIN := 2
const UNREST_MAX := 5

var schema_version := SCHEMA_VERSION
var roster: Array = []              # every goblin ever (alive flag marks the living), each a Dictionary
var resources: Dictionary = {}      # {"shinies": int, "food": int}
var unlocks: Array = []             # unlocked things, as string ids
var chosen_target: Dictionary = {}  # the raid the player picked for tonight
var loadout := ""                   # this morning's packed kit (KIT_* or "")
var huts := START_HUTS              # housing capacity = max LIVING goblins
var night := 1                      # which night the warren is on
var sent_id := -1                   # id of the goblin sent on tonight's raid (-1 = none chosen)
var fallen: Array = []              # the wall of the dead: [{name, feat}]
var last_raid: Dictionary = {}      # summary of the most recent raid's outcome
var last_event := ""                # short "what just happened" line (raid/forage outcome)
var unrest := 0                     # 0..UNREST_MAX; rises when upkeep goes unpaid
var night_event := ""               # the random thing that happened in the warren overnight
var upkeep_note := ""               # last night's upkeep summary (shown in the Den)

var _next_id := 0                   # hands out stable unique goblin ids
var _pup_n := 0                     # rolls through the pup-name pool

const _PUP_NAMES := ["Nib", "Squig", "Gob", "Razza", "Mogg", "Krick", "Dribble", "Snot", "Wretch", "Fang"]

func _ready() -> void:
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
		_make_goblin("Wort", STAGE_ADULT, {"health": 2, "sneak": 2, "brawn": 2}),    # all-rounder
	]
	resources = {"shinies": 0, "food": START_FOOD}
	unlocks = []
	chosen_target = {"name": "Millfield Cottage", "difficulty": 1}
	loadout = ""
	huts = START_HUTS
	night = 1
	sent_id = -1
	fallen = []
	last_raid = {}
	last_event = ""
	unrest = 0
	night_event = ""
	upkeep_note = ""

func _make_goblin(gname: String, stage: String, stats: Dictionary) -> Dictionary:
	var g := {"id": _next_id, "name": gname, "stage": stage, "alive": true, "best": 0, "stats": stats}
	_next_id += 1
	return g

## Random starting stats for a fresh recruit (bred pup / free runt). Health skews
## low for now; genetics (Bite 2b) will replace this with parent inheritance.
func _random_stats() -> Dictionary:
	return {"health": randi_range(1, 2), "sneak": randi_range(STAT_MIN, STAT_MAX), "brawn": randi_range(STAT_MIN, STAT_MAX)}

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
	return int(resources.get("shinies", 0)) >= DIG_SHINIES

func dig_hut() -> bool:
	if not can_dig():
		return false
	resources.shinies -= DIG_SHINIES
	huts += 1
	return true

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
	var pup := _make_goblin(_pup_name(), STAGE_PUP, stats)
	pup["mutant"] = mutated
	roster.append(pup)
	last_event = "Bred %s! (H%d S%d B%d)%s" % [pup.name, stats.health, stats.sneak, stats.brawn, "  — a MUTATION!" if mutated else ""]
	return true

## A pup's inherited stats: a blend of the two STRONGEST adults' (your bloodline),
## with small jitter. Falls back to random stats if there aren't two to breed from.
func _breed_stats() -> Dictionary:
	var ad := adults()
	if ad.size() < 2:
		return _random_stats()
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
	var who: String = String(g.name) if not g.is_empty() else "The goblin"
	if String(result.get("outcome", "lost")) == "won":
		var loot := int(result.get("loot", 0))
		resources.shinies += loot
		resources.food += RAID_FOOD                 # robbed a farm -> grub for the warren
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
	advance_night()

## Tick to the next morning: pups grow into adults, the night advances, and the
## anti-softlock backstop guarantees you're never wiped out — if every goblin is
## dead, a free runt wanders in.
func advance_night() -> void:
	night += 1
	# Pups grow up.
	for g in roster:
		if g.alive and g.stage == STAGE_PUP:
			g.stage = STAGE_ADULT
	# Upkeep: the warren eats gold; a shortfall breeds unrest, paying it calms things.
	var cost := living().size() * UPKEEP_PER_GOBLIN
	var have := int(resources.get("shinies", 0))
	resources.shinies = maxi(0, have - cost)
	if have < cost:
		unrest = mini(UNREST_MAX, unrest + 1)
		upkeep_note = "Upkeep %d shinies — couldn't pay it! Unrest rising." % cost
	else:
		if unrest > 0:
			unrest = maxi(0, unrest - 1)
		upkeep_note = "Upkeep paid: -%d shinies." % cost
	# One thing happens overnight: a desertion if the warren's boiling over, else a
	# random warren event. Mutually exclusive — you never lose two goblins in a night.
	if unrest >= UNREST_MAX and living().size() > 1:
		night_event = _desert()
	else:
		night_event = _roll_night_event()
	# Anti-softlock backstop: never fully wiped out.
	if living().is_empty():
		roster.append(_make_goblin(_pup_name(), STAGE_ADULT, _random_stats()))

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
			roster.append(_make_goblin(_pup_name(), STAGE_ADULT, _random_stats()))
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
