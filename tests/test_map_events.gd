extends GutTest
## Phase 4b: warps, signs, NPCs, triggers, hidden items, dialogue commands — on the real maps.

var world: Overworld


func before_each() -> void:
	GameState.reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	GameState.add_daemon(DaemonInstance.create("chipmunk", 10, rng, 1))


func after_each() -> void:
	SceneRouter.params = {}
	GameState.reset()


## Opens the overworld on a map/spawn with instant movement, auto text and no scene changes.
func _open(map_id: String, spawn: String = "default", choice: Variant = true) -> void:
	SceneRouter.params = {"map": map_id, "spawn": spawn}
	world = load(Overworld.SCENE).instantiate()
	add_child_autofree(world)
	world.allow_scene_change = false
	world.auto_advance_text = true
	world.auto_choice = choice
	world.set_time_scale(0.0)


func _place(cell: Vector2i, facing: Vector2i) -> void:
	world.player.setup(world.map, cell, facing)


func _wait_idle() -> void:
	await wait_until(func() -> bool: return world.is_idle(), 5.0)


func _logged(text_part: String) -> bool:
	for line in world.dialogue_log:
		if text_part in line:
			return true
	return false


# --- data --------------------------------------------------------------------

func test_every_warp_leads_to_a_real_spawn() -> void:
	for map_id in DataRegistry.map_ids():
		for e: Dictionary in DataRegistry.get_map(map_id).get("events", []):
			if e["type"] != "warp":
				continue
			var target := DataRegistry.get_map(e["to_map"])
			assert_false(target.is_empty(), "%s warps to missing map %s" % [map_id, e["to_map"]])
			assert_true(target.get("spawns", {}).has(e["to_spawn"]), "%s warps to missing spawn %s:%s" % [map_id, e["to_map"], e["to_spawn"]])


func test_dialogue_validator_catches_problems() -> void:
	var raw := DataRegistry.read_raw().duplicate(true)
	raw["dialogue"]["zz_bad.json"] = {"broken": [
		{"cmd": "give_item", "item": "golden_stapler"},
		{"cmd": "teleport"},
		{"text": "hi", "cmd": "heal_party"},
		{"cmd": "start_battle", "foe": [["missingno", 5]]},
	]}
	var errors := " | ".join(DataValidator.new().validate(raw))
	assert_string_contains(errors, "unknown item 'golden_stapler'")
	assert_string_contains(errors, "'cmd' is \"teleport\"")
	assert_string_contains(errors, "needs exactly one of")
	assert_string_contains(errors, "missingno")


# --- warps -------------------------------------------------------------------

func test_walk_out_of_the_house() -> void:
	_open("player_house")
	assert_eq(world.player.cell, Vector2i(4, 6))
	await world.player.try_step(Vector2i.DOWN)  # onto the exit mat
	await wait_until(func() -> bool: return world.map.map_id == "onboarding_town" and world.is_idle(), 5.0)
	assert_eq(world.map.map_id, "onboarding_town")
	assert_eq(world.player.cell, Vector2i(7, 8), "standing outside the front door")


func test_route_1_and_back() -> void:
	_open("onboarding_town", "route_1")
	await world.player.try_step(Vector2i.UP)
	await world.player.try_step(Vector2i.UP)
	await wait_until(func() -> bool: return world.map.map_id == "route_1" and world.is_idle(), 5.0)
	assert_eq(world.player.cell, Vector2i(9, 21))
	await world.player.try_step(Vector2i.DOWN)
	await world.player.try_step(Vector2i.DOWN)
	await wait_until(func() -> bool: return world.map.map_id == "onboarding_town" and world.is_idle(), 5.0)
	assert_eq(world.player.cell, Vector2i(14, 2))


# --- talking -----------------------------------------------------------------

func test_help_desk_heals_across_the_counter() -> void:
	var chipmunk: DaemonInstance = GameState.active_stack[0]
	chipmunk.current_uptime = 1
	chipmunk.status = "corrupted"
	GameState.flags["got_starter"] = true  # skip the starter cutscene (Kevin would stand in the way)
	_open("onboarding_town", "from_help_desk")
	await world.player.try_step(Vector2i.UP)  # through the door
	await wait_until(func() -> bool: return world.map.map_id == "help_desk" and world.is_idle(), 5.0)
	for i in 3:
		await world.player.try_step(Vector2i.UP)
	assert_eq(world.player.cell, Vector2i(6, 4))
	await world.interact()
	assert_true(_logged("turning it off and on again"))
	assert_eq(chipmunk.current_uptime, chipmunk.max_uptime())
	assert_eq(chipmunk.status, "")


func test_read_a_sign() -> void:
	_open("onboarding_town")
	_place(Vector2i(9, 8), Vector2i.RIGHT)
	await world.interact()
	assert_true(_logged("Wi-Fi password is on the fridge"))
	assert_true(world.is_idle())


func test_npc_gives_item_once_and_faces_you() -> void:
	_open("player_house")
	_place(Vector2i(5, 4), Vector2i.RIGHT)
	await world.interact()
	assert_eq(GameState.bag.get("coffee", 0), 3)
	assert_true(GameState.flags.get("got_mom_coffee", false))
	assert_eq(world.find_npc("mom").facing, Vector2i.LEFT, "Mom turned to face you")
	await world.interact()
	assert_eq(GameState.bag.get("coffee", 0), 3, "only once")
	assert_true(_logged("Go on, the Help Desk is the blue roof"))


func test_yes_no_choice() -> void:
	_open("help_desk", "default", false)
	_place(Vector2i(4, 6), Vector2i.LEFT)
	await world.interact()
	assert_eq(GameState.active_stack.size(), 1, "said no")
	world.auto_choice = true
	await world.interact()
	assert_eq(GameState.active_stack.size(), 2, "said yes")
	assert_eq(GameState.active_stack[1].species_id, "dustbunny")
	assert_true(GameState.flags.get("got_intern_dustbunny", false))


func test_town_exit_is_blocked_until_you_have_a_starter() -> void:
	GameState.reset()  # no Daemon, no got_starter flag
	_open("onboarding_town")
	_place(Vector2i(14, 5), Vector2i.UP)
	await world.player.try_step(Vector2i.UP)
	await _wait_idle()
	assert_true(_logged("Don't go into the cable tangles without a Daemon!"))
	assert_eq(world.player.cell, Vector2i(14, 5), "walked back down")
	GameState.flags["got_starter"] = true
	var lines := world.dialogue_log.size()
	await world.player.try_step(Vector2i.UP)
	await _wait_idle()
	assert_eq(world.dialogue_log.size(), lines, "free to go once you have one")
	assert_eq(world.player.cell, Vector2i(14, 4))


func test_hidden_item() -> void:
	_open("onboarding_town")
	_place(Vector2i(24, 20), Vector2i.RIGHT)
	await world.interact()
	assert_eq(GameState.bag.get("coffee", 0), 1)
	await world.interact()
	assert_eq(GameState.bag.get("coffee", 0), 1, "found only once")


func test_npcs_block_and_can_move() -> void:
	_open("onboarding_town")
	_place(Vector2i(12, 18), Vector2i.LEFT)
	assert_eq(await world.player.try_step(Vector2i.LEFT), "bumped", "the kid is in the way")
	await world.interact()
	assert_true(_logged("That was me"))
	assert_eq(world.find_npc("kid").cell, Vector2i(11, 18), "danced up and down, back home")


func test_manager_gives_a_starter_and_kevin_counter_picks() -> void:
	GameState.reset()
	SceneRouter.params = {"map": "help_desk"}
	world = load(Overworld.SCENE).instantiate()
	world.allow_scene_change = false
	world.auto_advance_text = true
	world.auto_choice = true  # takes the first starter (Chipmunk)
	watch_signals(world)
	add_child_autofree(world)
	world.set_time_scale(0.0)
	await wait_until(func() -> bool: return GameState.flags.get("got_starter", false) and world.is_idle(), 10.0)
	assert_eq(GameState.active_stack.size(), 1)
	assert_eq(GameState.active_stack[0].species_id, "chipmunk")
	assert_eq(GameState.active_stack[0].level, 5)
	assert_true(GameState.flags.get("starter_chipmunk", false))
	assert_signal_emitted(world, "battle_requested")
	var config: Dictionary = get_signal_parameters(world, "battle_requested")[0]
	assert_eq(config["trainer_id"], "kevin_rival_1_pingo", "Kevin picks the starter that beats yours")
	assert_true(config["story"])
	assert_eq(config["return_scene"], Overworld.SCENE)
	var kevin := world.find_npc("kevin_burst")
	assert_eq(world.player.cell, Vector2i(8, 6), "you walked up to the Manager")
	assert_true(kevin.visible and not kevin.off_map, "Kevin burst in through the door")
	assert_ne(kevin.cell, kevin.home, "and ran in from the doorway")
	assert_eq((kevin.cell - world.player.cell).length_squared(), 1, "and ran right up to the player")
	assert_eq(kevin.facing, world.player.cell - kevin.cell, "facing them")
	assert_eq(world.map.occupied.get(kevin.cell), kevin)


func test_kevin_stays_hidden_by_the_door_on_later_visits() -> void:
	GameState.flags["got_starter"] = true
	_open("help_desk")
	await wait_process_frames(2)
	var kevin := world.find_npc("kevin_burst")
	assert_false(kevin.visible)
	assert_false(world.map.occupied.has(kevin.cell), "not solid while hidden")
	assert_false(kevin.can_interact())


func test_returns_to_saved_location() -> void:
	GameState.location = {"map": "route_1", "x": 9, "y": 15, "facing": "up"}
	SceneRouter.params = {}
	world = load(Overworld.SCENE).instantiate()
	add_child_autofree(world)
	assert_eq(world.map.map_id, "route_1")
	assert_eq(world.player.cell, Vector2i(9, 15))
	assert_eq(world.player.facing, Vector2i.UP)
