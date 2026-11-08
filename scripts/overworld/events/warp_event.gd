class_name WarpEvent
extends MapEvent
## Stepping onto this cell moves the player to another map's spawn point (with a fade).
## Put it on a door or exit mat, or on the edge of a map for route exits.

@export var to_map: String = ""
@export var to_spawn: String = "default"


func configure(data: Dictionary) -> void:
	super.configure(data)
	to_map = data["to_map"]
	to_spawn = data.get("to_spawn", "default")
