extends Node
## Saves GameState to JSON with a version number and a checksum. Writes alternate between two
## slots, so a crash mid-save can only damage the slot being written; the other one still loads.
## load_game() picks the newest slot that passes its checksum, migrating older versions.
##
## File shape: {"version": 1, "save_count": 7, "saved_at": unix, "checksum": sha256, "data": {...}}

const SAVE_VERSION := 1
const SLOT_PATHS: PackedStringArray = ["user://save_a.json", "user://save_b.json"]

## Tests point this somewhere else so they never touch real saves.
var slot_paths: PackedStringArray = SLOT_PATHS


func has_save() -> bool:
	return not _newest_valid().is_empty()


## Writes the game. Returns "" or an error message.
func save_game() -> String:
	var newest := _newest_valid()
	var count := int(newest.get("save_count", 0)) + 1
	var target := _slot_to_write(newest)
	# Round-trip through JSON first so the checksum is computed on exactly what load will see
	# (JSON turns ints into floats, which stringify differently).
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	var payload := JSON.stringify(data, "", true)
	var file_body := {
		"version": SAVE_VERSION,
		"save_count": count,
		"saved_at": int(Time.get_unix_time_from_system()),
		"checksum": payload.sha256_text(),
		"data": data,
	}
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		return "Couldn't write the save (%s)." % error_string(FileAccess.get_open_error())
	file.store_string(JSON.stringify(file_body))
	file.close()
	return ""


## Loads the newest valid save into GameState. Returns "" or an error message.
func load_game() -> String:
	var newest := _newest_valid()
	if newest.is_empty():
		return "No save data found."
	GameState.from_dict(newest["data"])
	return ""


## Summary for the title screen / save prompt: {"location", "play_time_sec", "caught", "certs"}.
func preview() -> Dictionary:
	var newest := _newest_valid()
	if newest.is_empty():
		return {}
	var data: Dictionary = newest["data"]
	return {"map": data.get("location", {}).get("map", ""), "play_time_sec": float(data.get("play_time_sec", 0.0)),
		"caught": data.get("cmdb_caught", []).size(), "certs": data.get("certifications", []).size()}


func delete_saves() -> void:
	for path in slot_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# --- internals ---------------------------------------------------------------

## The newest slot that reads, has a matching checksum, and can be migrated. {} if none.
func _newest_valid() -> Dictionary:
	var best := {}
	for path in slot_paths:
		var body := read_slot(path)
		if not body.is_empty() and int(body["save_count"]) > int(best.get("save_count", -1)):
			best = body
	return best


## Reads and checks one slot. Returns {} if it's missing or damaged.
func read_slot(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()  # quiet parse: a half-written file is expected after a crash, not an error
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var parsed: Variant = json.data
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("data") or not parsed.has("checksum"):
		return {}
	var body: Dictionary = parsed
	if typeof(body["data"]) != TYPE_DICTIONARY:
		return {}
	if JSON.stringify(body["data"], "", true).sha256_text() != body["checksum"]:
		return {}  # damaged or hand-edited
	var version := int(body.get("version", 0))
	if version > SAVE_VERSION:
		return {}  # from a newer build
	body["data"] = migrate(body["data"], version)
	body["save_count"] = int(body.get("save_count", 0))
	return body


## Upgrades older save data to the current shape. Add a step here whenever SAVE_VERSION goes up.
func migrate(data: Dictionary, from_version: int) -> Dictionary:
	var out := data
	# if from_version < 2: out = _v1_to_v2(out)
	if from_version < 1:
		pass
	return out


## Writes to whichever slot doesn't hold the newest save (or slot A on a fresh start).
func _slot_to_write(newest: Dictionary) -> String:
	for path in slot_paths:
		var body := read_slot(path)
		if body.is_empty() or int(body["save_count"]) < int(newest.get("save_count", 0)):
			return path
	return slot_paths[0]
