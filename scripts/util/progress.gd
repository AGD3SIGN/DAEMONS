class_name Progress
extends RefCounted
## Help desk tickets and Kudos (GDD §6). Both are data (data/tickets.json, data/kudos.json) and both finish on a
## condition, checked by Overworld.check_progress() whenever the player is back in control (after a dialogue, a
## battle, the phone, a map change). collect() applies rewards and returns what to tell the player.
##
## A condition is a dictionary; every key in it must hold:
##   {"flag": "read_321_note"}                         a story flag is set
##   {"any_flags": ["trainer_a", "trainer_b"]}         at least one of these flags is set
##   {"stat": "caught", "at_least": 1}                 a play stat (STATS) has reached a number
##   {"certs": 1}                                       holding at least this many Certifications
##   {"stack_size": 6}                                  this many Forgelings in the Active Stack
##   {"cmdb_caught": 10}                                this many species quarantined (CMDB)
##
## Ticket states in GameState.tickets: "open" (in the queue), "resolved" (goal met, reward paid), "skipped"
## (onboarding skipped by a veteran; the reward is paid anyway).

## Play stats kept in GameState.counters as "stat_<name>" (count() adds to them).
const STATS: PackedStringArray = ["battles_won", "wild_wins", "trainer_wins", "caught", "items_used", "upgrades",
	"tickets_resolved"]
const CONDITION_KEYS: PackedStringArray = ["flag", "any_flags", "stat", "at_least", "certs", "stack_size", "cmdb_caught"]
const PRIORITIES: PackedStringArray = ["urgent", "high", "medium", "low"]  # shown as P1..P4


## Adds n to a play stat.
static func count(stat: String, n: int = 1) -> void:
	var key := "stat_" + stat
	GameState.counters[key] = int(GameState.counters.get(key, 0)) + n


static func stat(name: String) -> int:
	return int(GameState.counters.get("stat_" + name, 0))


static func met(cond: Dictionary) -> bool:
	if cond.has("flag") and not GameState.flags.get(cond["flag"], false):
		return false
	if cond.has("any_flags"):
		var any := false
		for flag: String in cond["any_flags"]:
			any = any or bool(GameState.flags.get(flag, false))
		if not any:
			return false
	if cond.has("stat") and stat(cond["stat"]) < int(cond.get("at_least", 1)):
		return false
	if cond.has("certs") and GameState.certifications.size() < int(cond["certs"]):
		return false
	if cond.has("stack_size") and GameState.active_stack.size() < int(cond["stack_size"]):
		return false
	if cond.has("cmdb_caught") and GameState.cmdb_caught.size() < int(cond["cmdb_caught"]):
		return false
	return true


## "P2" for high, etc.
static func priority_label(priority: String) -> String:
	return "P%d" % (PRIORITIES.find(priority) + 1)


static func ticket_number(id: String) -> String:
	return "#%04d" % int(DataRegistry.tickets[id]["number"])


## Puts a ticket in the queue (dialogue "open_ticket"). Already open or done: nothing happens.
static func open_ticket(id: String) -> bool:
	if GameState.tickets.has(id):
		return false
	GameState.tickets[id] = "open"
	return true


## Open tickets first (most urgent first), then the closed ones, each group by ticket number.
static func ticket_queue() -> Array[String]:
	var ids: Array[String] = []
	for id: String in GameState.tickets:
		ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ka := _sort_key(a)
		var kb := _sort_key(b)
		return ka < kb)
	return ids


static func _sort_key(id: String) -> String:
	var t: Dictionary = DataRegistry.tickets[id]
	var closed := 0 if GameState.tickets[id] == "open" else 1
	return "%d%d%06d" % [closed, PRIORITIES.find(String(t["priority"])), int(t["number"])]


## Veterans skip training: every unresolved ticket of a category is closed as skipped and its reward is paid.
## Returns the reward lines.
static func skip_tickets(category: String) -> PackedStringArray:
	var lines := PackedStringArray()
	for id: String in DataRegistry.tickets:
		var t: Dictionary = DataRegistry.tickets[id]
		if String(t["category"]) != category or GameState.tickets.get(id, "") in ["resolved", "skipped"]:
			continue
		GameState.tickets[id] = "skipped"
		lines.append_array(_pay(t.get("reward", {})))
	return lines


## Resolves every open ticket whose goal is met, opens tickets whose "opens_when" is now true, and unlocks Kudos.
## Repeats until nothing changes (a resolved ticket can unlock a Kudos). Returns notes in the order they happened:
## {"kind": "resolved" | "new_ticket" | "kudos", "id": id, "lines": [text, ...]}.
static func collect() -> Array[Dictionary]:
	var notes: Array[Dictionary] = []
	var changed := true
	while changed:
		changed = false
		for id: String in DataRegistry.tickets:
			var t: Dictionary = DataRegistry.tickets[id]
			var state: String = GameState.tickets.get(id, "")
			if state == "open" and met(t["goal"]):
				GameState.tickets[id] = "resolved"
				count("tickets_resolved")
				var lines := PackedStringArray(["Ticket %s resolved: %s" % [ticket_number(id), t["title"]]])
				if t.has("resolved"):
					lines.append(String(t["resolved"]))
				lines.append_array(_pay(t.get("reward", {})))
				notes.append({"kind": "resolved", "id": id, "lines": lines})
				changed = true
			elif state.is_empty() and t.has("opens_when") and met(t["opens_when"]):
				GameState.tickets[id] = "open"
				notes.append({"kind": "new_ticket", "id": id, "lines": PackedStringArray([
					"Your phone buzzes. New ticket %s from %s: %s" % [ticket_number(id), t["from"], t["title"]]])})
				changed = true
		for id: String in DataRegistry.kudos:
			if not GameState.kudos.has(id) and met(DataRegistry.kudos[id]["goal"]):
				GameState.kudos[id] = true
				notes.append({"kind": "kudos", "id": id, "lines": PackedStringArray([
					"Kudos unlocked: %s!" % DataRegistry.kudos[id]["name"]])})
				changed = true
	return notes


## Pays a reward {"credits": n, "items": {id: count}} and returns what to say about it.
static func _pay(reward: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	var credits := int(reward.get("credits", 0))
	if credits > 0:
		GameState.credits += credits
		lines.append("You got %d CR." % credits)
	var items: Dictionary = reward.get("items", {})
	for item_id: String in items:
		var n := int(items[item_id])
		GameState.bag[item_id] = int(GameState.bag.get(item_id, 0)) + n
		lines.append("You got %s%s." % [DataRegistry.get_item(item_id)["name"], " x%d" % n if n > 1 else ""])
	return lines
