class_name HiddenItemEvent
extends MapEvent
## An invisible item on a walkable tile. Press A facing it to find it, once (tracked by `flag`).

@export var item_id: String = ""
@export var count: int = 1
@export var flag: String = ""


func configure(data: Dictionary) -> void:
	super.configure(data)
	item_id = data["item"]
	count = int(data.get("count", 1))
	flag = data["flag"]


func can_interact() -> bool:
	return not GameState.flags.get(flag, false)


func interact() -> void:
	GameState.flags[flag] = true
	GameState.bag[item_id] = int(GameState.bag.get(item_id, 0)) + count
	AudioManager.play_sfx("confirm")
	var item_name: String = DataRegistry.get_item(item_id)["name"]
	await world.show_message("You found %s%s!" % [item_name, " x%d" % count if count > 1 else ""])
