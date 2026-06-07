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
var last_event := ""                # short "what just happened" line the Den shows

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
	roster = [_make_goblin("Snik", STAGE_ADULT), _make_goblin("Grubba", STAGE_ADULT), _make_goblin("Wort", STAGE_ADULT)]
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

func _make_goblin(gname: String, stage: String) -> Dictionary:
	var g := {"id": _next_id, "name": gname, "stage": stage, "alive": true, "best": 0}
	_next_id += 1
	return g

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
	roster.append(_make_goblin(_pup_name(), STAGE_PUP))
	return true

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
	for g in roster:
		if g.alive and g.stage == STAGE_PUP:
			g.stage = STAGE_ADULT
	if living().is_empty():
		roster.append(_make_goblin(_pup_name(), STAGE_ADULT))

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
