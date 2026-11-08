class_name MapEvent
extends Node2D
## Base for things placed on a map: warps, signs, NPCs, trigger zones, hidden items.
## The Overworld builds them from the map JSON's "events" list (see docs/data-format.md).
## Properties are exported so events could also be placed by hand in a scene later.

@export var cell: Vector2i = Vector2i.ZERO

var world: Overworld


## Reads this event's fields from its JSON entry.
func configure(data: Dictionary) -> void:
	cell = Vector2i(int(data["x"]), int(data["y"]))
	position = Vector2(cell * OverworldTiles.TILE_SIZE)


## True if pressing A while facing this event does something right now.
func can_interact() -> bool:
	return false


## What happens when the player presses A facing this event. Awaitable.
func interact() -> void:
	pass
