extends Node
## Writes GameState to JSON with a version number and checksum, alternating between two
## slots so a crash mid-save never corrupts both. Implemented in Phase 6.

const SAVE_VERSION := 1
const SLOT_PATHS: PackedStringArray = ["user://save_a.json", "user://save_b.json"]


func has_save() -> bool:
	for path in SLOT_PATHS:
		if FileAccess.file_exists(path):
			return true
	return false
