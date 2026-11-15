class_name MoveText
extends RefCounted
## One-line move details shared by the battle and field menus: "NETWORK · PWR 40 · CYC 30/30".


## pp < 0 shows the move's full Cycles (for a move you don't have yet).
static func line(move_id: String, pp: int = -1) -> String:
	var move := DataRegistry.get_move(move_id)
	if move.is_empty():
		return ""
	var type_name := String(DataRegistry.types.get(move["type"], {}).get("name", move["type"])).to_upper()
	var power := "PWR %d" % int(move["power"]) if int(move["power"]) > 0 else "STATUS"
	var max_pp := int(move["max_pp"])
	return "%s · %s · CYC %d/%d" % [type_name, power, max_pp if pp < 0 else pp, max_pp]


static func name_of(move_id: String) -> String:
	return String(DataRegistry.get_move(move_id).get("name", move_id))


## A short "what it does" line for footers: the move's description if it has one, else its details.
static func describe(move_id: String, pp: int = -1) -> String:
	var desc := String(DataRegistry.get_move(move_id).get("description", ""))
	return line(move_id, pp) + ("\n" + desc if not desc.is_empty() else "")
