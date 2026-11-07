extends Node
## Loads and validates all game data from res://data/ at startup. Everything else reads game
## data through here. Records are plain Dictionaries straight from JSON (numbers are floats;
## cast with int() where needed). See docs/data-format.md for the file formats.

const DATA_DIR := "res://data/"
const FILES := {
	"types": "types.json",
	"moves": "moves.json",
	"species": "species.json",
	"items": "items.json",
}

var types: Dictionary = {}       # id -> {id, name, color}
var type_chart: Dictionary = {}  # attacker id -> {defender id -> multiplier}; missing = 1
var moves: Dictionary = {}
var species: Dictionary = {}
var items: Dictionary = {}

## Problems from the last load. Empty means the data is clean.
var errors: PackedStringArray = []


func _ready() -> void:
	load_all()


## Reads every data file, validates, and indexes it. Returns true if there were no errors.
func load_all() -> bool:
	var read_errors := PackedStringArray()
	var raw := read_raw(read_errors)
	var ok := load_from(raw, false)
	errors = read_errors + errors
	_report()
	return ok and read_errors.is_empty()


## Parses each JSON file. Parse problems go into out_errors with file + line.
func read_raw(out_errors: PackedStringArray = PackedStringArray()) -> Dictionary:
	var raw := {}
	for key: String in FILES:
		var path: String = DATA_DIR + FILES[key]
		var text := FileAccess.get_file_as_string(path)
		if text.is_empty():
			out_errors.append("%s: can't read file (%s)" % [path, error_string(FileAccess.get_open_error())])
			continue
		var json := JSON.new()
		if json.parse(text) != OK:
			out_errors.append("%s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
			continue
		raw[key] = json.data
	return raw


## Validates already-parsed data and swaps it in. Used by load_all() and by tests.
func load_from(raw: Dictionary, report: bool = true) -> bool:
	var validator := DataValidator.new()
	errors = validator.validate(raw)
	types = validator.types
	type_chart = validator.type_chart
	moves = validator.moves
	species = validator.species
	items = validator.items
	if report:
		_report()
	return errors.is_empty()


func get_species(id: String) -> Dictionary:
	return species.get(id, {})


func get_move(id: String) -> Dictionary:
	return moves.get(id, {})


func get_item(id: String) -> Dictionary:
	return items.get(id, {})


## Damage multiplier for an attack type hitting a Daemon with defender_types (1 or 2 types).
func type_multiplier(attack_type: String, defender_types: Array) -> float:
	var row: Dictionary = type_chart.get(attack_type, {})
	var multiplier := 1.0
	for def_type: Variant in defender_types:
		multiplier *= float(row.get(def_type, 1.0))
	return multiplier


func _report() -> void:
	if errors.is_empty():
		print("DataRegistry: %d types, %d moves, %d species, %d items loaded" % [types.size(), moves.size(), species.size(), items.size()])
		return
	for e in errors:
		push_error("DataRegistry: " + e)
	push_error("DataRegistry: %d data error(s). Fix them in res://data/." % errors.size())
