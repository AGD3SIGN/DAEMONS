class_name TriggerEvent
extends MapEvent
## An invisible zone (w x h tiles from x, y). Walking into it runs its dialogue, gated by flags:
##   once_flag     — set after it runs; it won't run again while the flag is set
##   requires_flag — only runs if this flag is set
##   unless_flag   — doesn't run if this flag is set

@export var zone_size: Vector2i = Vector2i.ONE
@export var dialogue_id: String = ""
@export var once_flag: String = ""
@export var requires_flag: String = ""
@export var unless_flag: String = ""


func configure(data: Dictionary) -> void:
	super.configure(data)
	zone_size = Vector2i(int(data.get("w", 1)), int(data.get("h", 1)))
	dialogue_id = data["dialogue"]
	once_flag = data.get("once_flag", "")
	requires_flag = data.get("requires_flag", "")
	unless_flag = data.get("unless_flag", "")


func contains(at: Vector2i) -> bool:
	return Rect2i(cell, zone_size).has_point(at)


func is_active() -> bool:
	if not once_flag.is_empty() and GameState.flags.get(once_flag, false):
		return false
	if not requires_flag.is_empty() and not GameState.flags.get(requires_flag, false):
		return false
	if not unless_flag.is_empty() and GameState.flags.get(unless_flag, false):
		return false
	return true


func run() -> void:
	if not once_flag.is_empty():
		GameState.flags[once_flag] = true
	await world.run_dialogue(dialogue_id)
