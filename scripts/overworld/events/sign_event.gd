class_name SignEvent
extends MapEvent
## Press A facing it to read its dialogue.

@export var dialogue_id: String = ""


func configure(data: Dictionary) -> void:
	super.configure(data)
	dialogue_id = data["dialogue"]


func can_interact() -> bool:
	return true


func interact() -> void:
	await world.run_dialogue(dialogue_id)
