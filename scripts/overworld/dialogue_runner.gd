class_name DialogueRunner
extends RefCounted
## Runs a dialogue script (a list of steps from data/dialogue/*.json) in the overworld:
##   {"text": "Hi!", "speaker": "Mom"}
##   {"choice": "Heal your Daemons?", "yes": [steps], "no": [steps]}
##   {"if_flag": "got_coffee", "then": [steps], "else": [steps]}
##   {"cmd": "set_flag", "flag": "x", "value": true}      value defaults to true
##   {"cmd": "give_item", "item": "coffee", "count": 2}
##   {"cmd": "give_daemon", "species": "dustbunny", "level": 5}
##   {"cmd": "heal_party"}
##   {"cmd": "start_battle", "foe": [["spamlet", 9]], "trainer_name": "Kevin", "ai": "smart"}  (ends the dialogue)
##   {"cmd": "move_npc", "npc": "kid", "path": ["left", "right"]}   npc "self" = whoever is talking
## Text can use {player} for the player's name.

## Until the intro asks for a name (Phase 7).
const DEFAULT_PLAYER_NAME := "New Hire"

var world: Overworld
var npc: NpcEvent
var stopped := false


func _init(p_world: Overworld, p_npc: NpcEvent = null) -> void:
	world = p_world
	npc = p_npc


func run(steps: Array) -> void:
	for step: Dictionary in steps:
		if stopped:
			return
		await _run_step(step)


func _run_step(step: Dictionary) -> void:
	if step.has("text"):
		await world.say(_fill(step["text"]), step.get("speaker", ""))
	elif step.has("choice"):
		var yes := await world.ask(_fill(step["choice"]), step.get("speaker", ""))
		await run(step.get("yes" if yes else "no", []))
	elif step.has("if_flag"):
		var flag_set: bool = GameState.flags.get(step["if_flag"], false)
		await run(step.get("then" if flag_set else "else", []))
	else:
		await _command(step)


func _command(step: Dictionary) -> void:
	match step["cmd"]:
		"set_flag":
			GameState.flags[step["flag"]] = step.get("value", true)
		"give_item":
			var count := int(step.get("count", 1))
			GameState.bag[step["item"]] = int(GameState.bag.get(step["item"], 0)) + count
			AudioManager.play_sfx("confirm")
			var item_name: String = DataRegistry.get_item(step["item"])["name"]
			await world.show_message("You received %s%s!" % [item_name, " x%d" % count if count > 1 else ""])
		"give_daemon":
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			var d := DaemonInstance.create(step["species"], int(step["level"]), rng, 1)
			var where := GameState.add_daemon(d)
			AudioManager.play_sfx("confirm")
			await world.show_message("You received %s!" % d.display_name())
			if where == "rack":
				await world.show_message("Your stack is full, so %s went to the Server Rack." % d.display_name())
		"heal_party":
			for d: DaemonInstance in GameState.active_stack:
				d.heal_full()
		"start_battle":
			stopped = true
			var config := {"foe": step["foe"], "wild": false, "trainer_name": step.get("trainer_name", ""),
				"ai": step.get("ai", "basic")}
			world.start_battle(config)
		"move_npc":
			var who: NpcEvent = npc if step["npc"] == "self" else world.find_npc(step["npc"])
			if who != null:
				await who.move_path(step["path"])


static func _fill(text: String) -> String:
	var player_name := GameState.player_name if not GameState.player_name.is_empty() else DEFAULT_PLAYER_NAME
	return text.replace("{player}", player_name)
