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
	"config_profiles": "config_profiles.json",
	"tiles": "tiles.json",
	"certifications": "certifications.json",
	"title_screen": "title_screen.json",
}
const MAPS_DIR := "res://data/maps/"
const DIALOGUE_DIR := "res://data/dialogue/"
const ENCOUNTERS_DIR := "res://data/encounters/"
const TRAINERS_DIR := "res://data/trainers/"

var types: Dictionary = {}       # id -> {id, name, color}
var type_chart: Dictionary = {}  # attacker id -> {defender id -> multiplier}; missing = 1
var moves: Dictionary = {}
var species: Dictionary = {}
var items: Dictionary = {}
var config_profiles: Dictionary = {}  # id -> {id, name, up, down}; up/down null = neutral
var tiles: Dictionary = {}            # tile name -> {name, atlas, collision, behavior}
var dialogues: Dictionary = {}        # dialogue id -> list of steps (from every data/dialogue/*.json)
var encounters: Dictionary = {}       # map id -> wild encounter table (data/encounters/<map>.json)
var trainers: Dictionary = {}         # trainer id -> trainer (every data/trainers/*.json)
var certifications: Dictionary = {}   # cert id -> {id, name, department, type, order}
var title_screen: Dictionary = {}     # title screen copy + featured legendaries (data/title_screen.json)

var _validator: DataValidator
var _maps: Dictionary = {}            # map id -> validated map data (loaded on first use)

## Problems from the last load. Empty means the data is clean.
var errors: PackedStringArray = []


func _ready() -> void:
	load_all()
	# `<game> --headless -- --check-data`: load and check every map too, then quit (non-zero on errors).
	# Used by tools/smoke_test_mac_build.sh on the exported app, where file layout differs from the project.
	if "--check-data" in OS.get_cmdline_user_args():
		var bad := 0
		var ids := map_ids()
		for map_id in ids:
			if get_map(map_id).is_empty():
				bad += 1
		print("DataRegistry: %d maps checked, %d broken" % [ids.size(), bad])
		get_tree().quit(1 if bad > 0 or not errors.is_empty() else 0)


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
	var dialogue_files := {}
	for file in DirAccess.get_files_at(DIALOGUE_DIR):
		if not file.ends_with(".json"):
			continue
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(DIALOGUE_DIR + file)) != OK:
			out_errors.append("%s%s line %d: %s" % [DIALOGUE_DIR, file, json.get_error_line(), json.get_error_message()])
			continue
		dialogue_files[file] = json.data
	raw["dialogue"] = dialogue_files
	raw["encounters"] = _read_dir(ENCOUNTERS_DIR, out_errors)
	raw["trainers"] = _read_dir(TRAINERS_DIR, out_errors)
	return raw


## {file base name: parsed JSON} for every .json in a folder.
func _read_dir(dir: String, out_errors: PackedStringArray) -> Dictionary:
	var out := {}
	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".json"):
			continue
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(dir + file)) != OK:
			out_errors.append("%s%s line %d: %s" % [dir, file, json.get_error_line(), json.get_error_message()])
			continue
		out[file.get_basename()] = json.data
	return out


## Validates already-parsed data and swaps it in. Used by load_all() and by tests.
func load_from(raw: Dictionary, report: bool = true) -> bool:
	var validator := DataValidator.new()
	_validator = validator
	_maps = {}
	errors = validator.validate(raw)
	types = validator.types
	type_chart = validator.type_chart
	moves = validator.moves
	species = validator.species
	items = validator.items
	config_profiles = validator.config_profiles
	tiles = validator.tiles
	dialogues = validator.dialogues
	encounters = validator.encounters
	trainers = validator.trainers
	certifications = validator.certifications
	title_screen = validator.title_screen
	if report:
		_report()
	return errors.is_empty()


## Loads data/maps/<id>.json on first use and validates it. Returns {} (and reports why)
## if it's missing or broken.
func get_map(map_id: String) -> Dictionary:
	if _maps.has(map_id):
		return _maps[map_id]
	var path := MAPS_DIR + map_id + ".json"
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("DataRegistry: can't read map %s" % path)
		return {}
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("DataRegistry: %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	var map_errors := _validator.validate_map(json.data, map_id)
	for e in map_errors:
		push_error("DataRegistry: " + e)
	if not map_errors.is_empty():
		return {}
	_maps[map_id] = json.data
	return json.data


## Every map id in data/maps/.
func map_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for file in DirAccess.get_files_at(MAPS_DIR):
		if file.ends_with(".json"):
			ids.append(file.get_basename())
	return ids


## Checks a map without caching or reporting (for tests).
func check_map(map_data: Variant, map_id: String) -> PackedStringArray:
	return _validator.validate_map(map_data, map_id)


func get_dialogue(id: String) -> Array:
	return dialogues.get(id, [])


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
		print("DataRegistry: %d types, %d moves, %d species, %d items, %d config profiles, %d tiles, %d dialogues loaded" % [types.size(), moves.size(), species.size(), items.size(), config_profiles.size(), tiles.size(), dialogues.size()])
		return
	for e in errors:
		push_error("DataRegistry: " + e)
	push_error("DataRegistry: %d data error(s). Fix them in res://data/." % errors.size())
