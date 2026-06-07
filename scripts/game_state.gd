extends Node
## The GameState autoload (decisions log, decision U).
##
## Holds ONLY serializable data — the living-goblin roster as plain data,
## resources, unlocks, and the chosen raid target — and NEVER live scene-node
## references. Because it's pure data, this same object can later double as the
## save payload (issue #10). The rule of thumb: if it can't be written to JSON,
## it does not belong in here.

const SCHEMA_VERSION := 1

var schema_version := SCHEMA_VERSION
var roster: Array = []              # living goblins, each a plain Dictionary
var resources: Dictionary = {}      # the warren's stockpiles, e.g. {"shinies": 0}
var unlocks: Array = []             # unlocked things, as string ids
var chosen_target: Dictionary = {}  # the raid the player picked for tonight
var last_raid: Dictionary = {}      # summary of the most recent raid's outcome

func _ready() -> void:
	new_game()

## Seed a fresh game's starting data. (Persisting + loading this — with versioned
## migration — is issue #10; for now every launch starts a clean warren.)
func new_game() -> void:
	schema_version = SCHEMA_VERSION
	roster = [
		{"name": "Snik", "alive": true},
		{"name": "Grubba", "alive": true},
		{"name": "Wort", "alive": true},
	]
	resources = {"shinies": 0}
	unlocks = []
	chosen_target = {"name": "Millfield Cottage", "difficulty": 1}
	last_raid = {}
