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
##   {"cmd": "start_battle", "trainer": "kevin_town"}   or  "foe": [["spigeon", 9]] (ends the dialogue)
##   {"cmd": "give_cert", "cert": "desktop_support"}
##   {"if_cert": "networking", "then": [steps], "else": [steps]}
##   {"cmd": "move_npc", "npc": "kid", "path": ["left", "right"]}   npc "self" = whoever is talking
##   {"cmd": "open_shop", "stock": ["coffee", "thumb_drive"]}   Supply Closet buy/sell
##   {"cmd": "open_rack"}                                         Server Rack storage
##   {"cmd": "name_player"}                                       pick or type the player's name
##   {"cmd": "choose_starter", "options": ["chipmunk", "pingo", "glowbit"], "level": 5}
##        sets flags got_starter and starter_<species>
##   {"cmd": "move_player", "path": ["down"]}                     walk the player in a cutscene
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
	elif step.has("if_cert"):
		var has_cert: bool = step["if_cert"] in GameState.certifications
		await run(step.get("then" if has_cert else "else", []))
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
			GameState.heal_stack()
			AudioManager.play_jingle("heal")
			# Black-outs bring you back to the last place you healed.
			GameState.last_help_desk = GameState.location.duplicate()
		"start_battle":
			stopped = true
			var config: Dictionary
			if step.has("trainer"):
				config = BattleScene.trainer_config(step["trainer"])
			else:
				config = {"foe": step["foe"], "wild": false, "trainer_name": step.get("trainer_name", ""),
					"ai": step.get("ai", "basic")}
			world.start_battle(config)
		"give_cert":
			if not step["cert"] in GameState.certifications:
				GameState.certifications.append(step["cert"])
				AudioManager.play_sfx("confirm")
				await world.show_message("You earned the %s!" % DataRegistry.certifications[step["cert"]]["name"])
		"open_shop":
			await world.field_menus.shop(step["stock"])
		"open_rack":
			await world.field_menus.rack_screen()
		"name_player":
			GameState.player_name = await world.field_menus.choose_name()
		"choose_starter":
			var species_id := await world.field_menus.choose_starter(step["options"])
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			var starter := DaemonInstance.create(species_id, int(step.get("level", 5)), rng, GameState.trainer_id)
			GameState.add_daemon(starter)
			GameState.flags["got_starter"] = true
			GameState.flags["starter_" + species_id] = true
			AudioManager.play_jingle("heal")
			await world.show_message("You received %s!" % starter.display_name())
		"move_player":
			await world.move_player(step["path"])
		"move_npc":
			var who: NpcEvent = npc if step["npc"] == "self" else world.find_npc(step["npc"])
			if who != null:
				var run: bool = step.get("run", false)
				if step.get("to", "") == "player":
					await who.move_path(who.path_to_player(), run)
					who.face(world.player.cell - who.cell)
					world.player.face(who.cell - world.player.cell)
				else:
					await who.move_path(step["path"], run)
		"show_npc":
			var shown: NpcEvent = world.find_npc(step["npc"])
			if shown != null:
				shown.appear()
				if step.has("facing"):
					shown.face(NpcEvent.FACINGS.get(step["facing"], shown.facing))
		"hide_npc":
			var gone: NpcEvent = world.find_npc(step["npc"])
			if gone != null:
				gone.disappear()


static func _fill(text: String) -> String:
	var player_name := GameState.player_name if not GameState.player_name.is_empty() else DEFAULT_PLAYER_NAME
	return text.replace("{player}", player_name)
