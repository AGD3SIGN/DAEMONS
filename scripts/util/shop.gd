class_name Shop
extends RefCounted
## Supply Closet buying and selling. Items sell back for half their price.
## Items with price 0 (key items, Root Key) can't be bought or sold.

const MAX_STACK := 99


static func price(item_id: String) -> int:
	return int(DataRegistry.get_item(item_id).get("price", 0))


static func sell_price(item_id: String) -> int:
	return price(item_id) / 2


static func can_sell(item_id: String) -> bool:
	return sell_price(item_id) > 0 and DataRegistry.get_item(item_id).get("pocket", "") != "key_items"


## Most you can buy right now (credits and the 99-per-item cap).
static func max_buyable(item_id: String) -> int:
	if price(item_id) <= 0:
		return 0
	return mini(GameState.credits / price(item_id), MAX_STACK - int(GameState.bag.get(item_id, 0)))


## Returns "" on success or a reason.
static func buy(item_id: String, qty: int) -> String:
	if qty <= 0 or price(item_id) <= 0:
		return "That's not for sale."
	if qty > max_buyable(item_id):
		return "You can't afford that." if price(item_id) * qty > GameState.credits else "You can't carry any more."
	GameState.credits -= price(item_id) * qty
	GameState.bag[item_id] = int(GameState.bag.get(item_id, 0)) + qty
	return ""


static func sell(item_id: String, qty: int) -> String:
	if not can_sell(item_id):
		return "The Supply Closet doesn't take those."
	if qty <= 0 or qty > int(GameState.bag.get(item_id, 0)):
		return "You don't have that many."
	GameState.credits += sell_price(item_id) * qty
	GameState.bag[item_id] = int(GameState.bag[item_id]) - qty
	if int(GameState.bag[item_id]) <= 0:
		GameState.bag.erase(item_id)
	return ""
