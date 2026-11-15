extends GutTest
## The GDD demo (Acts 1-2) ends after Cert 2 in Port City: a glitched "???" Hexforged you can't catch, CMDB
## "Status: UNKNOWN", gone after 2 turns. It sets demo_teaser_seen, never corruption_revealed. DEMO_BUILD then shows
## "Thanks for playing".

var world: Overworld


func before_each() -> void:
	GameState.reset()
	ProjectSettings.set_setting(Demo.SETTING, false)


func after_each() -> void:
	ProjectSettings.set_setting(Demo.SETTING, false)
	SceneRouter.params = {}
	GameState.reset()


func _team() -> Array[DaemonInstance]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var t: Array[DaemonInstance] = [DaemonInstance.create("pengwan", 20, rng, 1)]
	return t


func test_the_teaser_cant_be_caught_and_flees_after_two_turns() -> void:
	var config := Demo.teaser_battle_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var state := BattleState.new(BattleSide.new("You", _team(), {"thumb_drive": 5}),
		BattleSide.new("Wild", [DaemonInstance.create("cablesnake", 16, rng, 0)] as Array[DaemonInstance]), rng, true)
	state.uncatchable = true
	state.foe_flees_after = 2
	var key := BattleAction.item("thumb_drive", 0)
	var events := BattleSim.run_turn(state, key, BattleAction.fight(0))
	assert_eq(events[0]["type"], "invalid_action", "a Quarantine Key can't lock on")
	assert_string_contains(events[0]["reason"], "can't get a lock")
	BattleSim.run_turn(state, BattleAction.fight(1), BattleAction.fight(0))  # Pengwan's weakest hit
	assert_false(state.is_over(), "still there after turn 1")
	var turn2 := BattleSim.run_turn(state, BattleAction.fight(1), BattleAction.fight(0))
	if state.outcome == "foe_fled":
		assert_true(turn2.any(func(e: Dictionary) -> bool: return e["type"] == "foe_fled"))
	else:
		assert_eq(state.outcome, "player_won", "unless you knocked it out first")
	assert_eq(config["foe"][0][0], Demo.TEASER_SPECIES)
	assert_false(config.has("return_scene"), "full build: back to the map")


func test_teaser_sets_seen_not_revealed_and_cmdb_says_unknown() -> void:
	var config := Demo.teaser_battle_config()
	config.merge({"player_stack": _team(), "items": {}, "auto": true, "time_scale": 0.0, "seed": 3}, true)
	var scene: BattleScene = load(BattleScene.SCENE).instantiate()
	scene.setup(config)
	add_child_autofree(scene)
	assert_eq(scene.host_label(), "???")
	assert_eq(scene.state.sides[BattleState.FOE].active().display_name(), "???")
	await wait_for_signal(scene.finished, 30.0)
	assert_true(scene.result["outcome"] in ["foe_fled", "player_won"])
	assert_true(GameState.flags.get("demo_teaser_seen", false))
	assert_false(GameState.corruption_revealed(), "the real reveal is the Power Plant")
	assert_eq(CmdbPanel.status_line(Demo.TEASER_SPECIES), "Status: UNKNOWN")
	assert_false(GameState.cmdb_compromised.has(Demo.TEASER_SPECIES))


func test_demo_build_ends_on_thanks_for_playing() -> void:
	ProjectSettings.set_setting(Demo.SETTING, true)
	assert_true(Demo.is_demo_build())
	assert_eq(Demo.teaser_battle_config()["return_scene"], DemoEnd.SCENE)


func test_port_city_runs_the_teaser_only_after_ping() -> void:
	GameState.flags["got_starter"] = true
	GameState.flags["port_city_arrived"] = true
	GameState.active_stack.assign(_team())
	for beaten in [false, true]:
		if beaten:
			GameState.flags["trainer_ping_okoro"] = true
		SceneRouter.params = {"map": "port_city", "spawn": "from_department"}
		world = load(Overworld.SCENE).instantiate()
		world.allow_scene_change = false
		world.auto_advance_text = true
		watch_signals(world)
		add_child_autofree(world)
		world.set_time_scale(0.0)
		await wait_process_frames(3)
		await wait_until(func() -> bool: return world.is_idle(), 5.0)
		if beaten:
			assert_signal_emitted(world, "battle_requested", "after Cert 2 the teaser starts")
			var config: Dictionary = get_signal_parameters(world, "battle_requested")[0]
			assert_true(config.get("teaser", false))
		else:
			assert_signal_not_emitted(world, "battle_requested", "not before beating Ping")
		world.queue_free()
		await wait_process_frames(2)


func test_saves_round_trip_the_new_flags() -> void:
	GameState.flags["demo_teaser_seen"] = true
	GameState.cmdb_unknown["cablesnake"] = true
	var saved: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	GameState.reset()
	GameState.from_dict(saved)
	assert_true(GameState.flags.get("demo_teaser_seen", false))
	assert_false(GameState.flags.get("corruption_revealed", false))
	assert_true(GameState.cmdb_unknown.has("cablesnake"))
