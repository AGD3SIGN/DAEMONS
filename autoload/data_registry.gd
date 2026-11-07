extends Node
## Loads and validates all game data (species, moves, types, items, encounters, trainers)
## from res://data/. Everything else reads game data through here. Filled in during Phase 1.

const DATA_DIR := "res://data/"

var types: Dictionary = {}
var moves: Dictionary = {}
var species: Dictionary = {}
var items: Dictionary = {}

## Validation errors from the last load_all(). Empty means the data is clean.
var errors: PackedStringArray = []


func _ready() -> void:
	load_all()


## Phase 1 replaces this with real JSON loading + cross-reference validation.
func load_all() -> void:
	errors.clear()
