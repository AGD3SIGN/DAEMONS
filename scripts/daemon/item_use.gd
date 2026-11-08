class_name ItemUse
extends RefCounted
## Using items outside battle (from the Bag). Battle item use lives in BattleSim.
## use_on() returns {"ok": bool, "messages": [lines to show]}; the item is used up only when ok.

## Items that need you to pick a Daemon.
const TARGETED: PackedStringArray = ["heal_uptime", "full_restore", "revive", "level_up", "evolve"]


static func needs_target(item_id: String) -> bool:
	return _effect(item_id) in TARGETED


## Uses a targeted item on a Daemon and takes one out of the bag if it worked.
static func use_on(item_id: String, d: DaemonInstance) -> Dictionary:
	if int(GameState.bag.get(item_id, 0)) <= 0:
		return {"ok": false, "messages": ["You don't have any."]}
	var params: Dictionary = DataRegistry.get_item(item_id)["effect"]["params"]
	var result := _apply(_effect(item_id), params, item_id, d)
	if result["ok"]:
		_consume(item_id)
	return result


## Items used on nothing in particular (Firewall Rule, Ctrl+Z, keys). Same return shape.
static func use_in_field(item_id: String) -> Dictionary:
	if int(GameState.bag.get(item_id, 0)) <= 0:
		return {"ok": false, "messages": ["You don't have any."]}
	var item := DataRegistry.get_item(item_id)
	match _effect(item_id):
		"repel":
			if GameState.repel_steps > 0:
				return {"ok": false, "messages": ["A Firewall Rule is already active."]}
			GameState.repel_steps = int(item["effect"]["params"]["steps"])
			_consume(item_id)
			return {"ok": true, "messages": ["You applied a %s. Weaker wild Daemons will be blocked." % item["name"]]}
		"escape":
			return {"ok": false, "messages": ["Ctrl+Z only works inside dungeons."]}
		"capture":
			return {"ok": false, "messages": ["Quarantine Keys only work in wild battles."]}
	return {"ok": false, "messages": ["That can't be used right now."]}


static func _apply(effect: String, params: Dictionary, item_id: String, d: DaemonInstance) -> Dictionary:
	var name := d.display_name()
	var no_effect := {"ok": false, "messages": ["It won't have any effect."]}
	match effect:
		"heal_uptime":
			if d.is_fainted() or d.current_uptime >= d.max_uptime():
				return no_effect
			var healed := mini(int(params["amount"]), d.max_uptime() - d.current_uptime)
			d.current_uptime += healed
			return {"ok": true, "messages": ["%s restored %d Uptime." % [name, healed]]}
		"full_restore":
			if d.is_fainted() or (d.current_uptime >= d.max_uptime() and d.status.is_empty()):
				return no_effect
			d.current_uptime = d.max_uptime()
			d.status = ""
			d.status_turns = 0
			return {"ok": true, "messages": ["%s is fully restored!" % name]}
		"revive":
			if not d.is_fainted():
				return no_effect
			d.current_uptime = maxi(1, floori(d.max_uptime() * float(params["fraction"])))
			return {"ok": true, "messages": ["%s rebooted!" % name]}
		"level_up":
			if d.level >= DaemonInstance.MAX_LEVEL:
				return no_effect
			var messages: Array[String] = []
			for e in d.level_up():
				match e["type"]:
					"level_up":
						messages.append("%s patched up to Lv %d!" % [name, e["level"]])
					"move_learned":
						messages.append("%s installed %s!" % [name, DataRegistry.get_move(e["move"])["name"]])
					"move_learn_pending":
						messages.append("%s wanted to install %s, but all 4 slots are full." % [name, DataRegistry.get_move(e["move"])["name"]])
			var target := d.check_evolution("level")
			if not target.is_empty() and not d.is_fainted():
				d.evolve(target)
				GameState.cmdb_seen[target] = true
				GameState.cmdb_caught[target] = true
				messages.append("%s upgraded into %s!" % [name, d.display_name()])
			return {"ok": true, "messages": messages}
		"evolve":
			var into := d.check_evolution("item", item_id)
			if into.is_empty():
				return no_effect
			d.evolve(into)
			GameState.cmdb_seen[into] = true
			GameState.cmdb_caught[into] = true
			return {"ok": true, "messages": ["%s upgraded into %s!" % [name, d.display_name()]]}
	return no_effect


static func _effect(item_id: String) -> String:
	return DataRegistry.get_item(item_id).get("effect", {}).get("id", "")


static func _consume(item_id: String) -> void:
	GameState.bag[item_id] = int(GameState.bag[item_id]) - 1
	if int(GameState.bag[item_id]) <= 0:
		GameState.bag.erase(item_id)
