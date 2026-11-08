extends GutTest
## Phase 7: the vertical slice. Intro, puzzle, Department boss + cert, gate, music hooks, and a
## balance check that Dana is beatable around level 12-14 without grinding.

var world: Overworld


func before_each() -> void:
	GameState.reset()


func after_each() -> void:
	SceneRouter.params = {}
	GameState.reset()
	AudioManager.stop_music()


func _daemon(species: String, lvl: int, seed_value: int = 41) -> DaemonInstance:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return DaemonInstance.create(species, lvl, rng, 1)


func _open(map_id: String, spawn: String = "default") -> void:
	SceneRouter.params = {"map": map_id, "spawn": spawn}
	world = load(Overworld.SCENE).instantiate()
	world.allow_scene_change = false
	world.auto_advance_text = true
	world.auto_choice = true
	add_child_autofree(world)
	world.set_time_scale(0.0)


func _logged(part: String) -> bool:
	for line in world.dialogue_log:
		if part in line:
			return true
	return false


# --- story -------------------------------------------------------------------

func test_new_game_intro_names_you() -> void:
	_open("player_house", "new_game")
	await wait_until(func() -> bool: return GameState.flags.get("intro_done", false) and world.is_idle(), 10.0)
	assert_eq(GameState.player_name, "Alex")
	assert_true(_logged("...Alex. That's you."))
	assert_true(_logged("Your manager is waiting at the Help Desk"))


func test_patch_panel_puzzle() -> void:
	GameState.add_daemon(_daemon("pingo", 12))
	GameState.flags["department_welcomed"] = true
	_open("department_1")
	var door: BarrierEvent
	for event in world.events:
		if event is BarrierEvent:
			door = event
	assert_false(door.is_open(), "starts locked")
	assert_false(world.map.is_walkable(Vector2i(7, 9)))
	for port_x in [2, 10]:  # odd ports 1 and 3
		world.player.setup(world.map, Vector2i(port_x, 12), Vector2i.UP)
		await world.interact()
	assert_true(door.is_open(), "ports 1 and 3 live -> door opens")
	assert_true(world.map.is_walkable(Vector2i(7, 9)))
	world.player.setup(world.map, Vector2i(6, 12), Vector2i.UP)
	await world.interact()  # the honeypot
	assert_false(door.is_open(), "plugging port 2 locks it again")
	await world.interact()
	assert_true(door.is_open())


func test_dana_awards_the_desktop_support_cert() -> void:
	var team: Array[DaemonInstance] = [_daemon("emperoute", 40)]
	var config := BattleScene.trainer_config("dana")
	assert_eq(config["music"], "battle_boss")
	config.merge({"player_stack": team, "items": {}, "auto": true, "time_scale": 0.0, "seed": 2}, true)
	var scene: BattleScene = load(BattleScene.SCENE).instantiate()
	scene.setup(config)
	add_child_autofree(scene)
	await wait_for_signal(scene.finished, 30.0)
	assert_eq(scene.result["outcome"], "player_won")
	assert_true("desktop_support" in GameState.certifications)
	assert_eq(AudioManager.current_music, "victory")


func test_patch_town_gate_needs_the_cert() -> void:
	GameState.add_daemon(_daemon("pingo", 12))
	_open("patch_town")
	world.player.setup(world.map, Vector2i(14, 3), Vector2i.UP)
	await world.interact()
	assert_true(_logged("Desktop Support Cert holders only"))
	assert_false(GameState.flags.get("patch_gate_open", false))
	GameState.certifications.append("desktop_support")
	await world.interact()
	assert_true(GameState.flags.get("patch_gate_open", false))
	assert_eq(world.find_npc("gate_guard").cell, Vector2i(13, 2), "stepped aside")
	assert_eq(await world.player.try_step(Vector2i.UP), "moved", "the road is open")


# --- music and mood ----------------------------------------------------------

func test_music_hooks_and_dead_zone_tint() -> void:
	GameState.add_daemon(_daemon("pingo", 12))
	GameState.flags["got_starter"] = true
	_open("onboarding_town")
	assert_eq(AudioManager.current_music, "town")
	world.load_map("route_1")
	assert_eq(AudioManager.current_music, "route")
	world.load_map("wifi_dead_zone")
	assert_eq(AudioManager.current_music, "dead_zone")
	assert_ne(world._tint.color, Color.WHITE, "it's dark in the dead zone")
	world.load_map("help_desk")
	assert_eq(AudioManager.current_music, "help_desk")
	world.player.setup(world.map, Vector2i(6, 4), Vector2i.UP)
	await world.interact()
	assert_eq(AudioManager.last_jingle, "heal")
	assert_eq(BattleScene.trainer_config("intern_ian")["music"], "battle_trainer")
	assert_eq(BattleScene.trainer_config("kevin_rival_1_pingo")["music"], "battle_rival")


# --- balance -----------------------------------------------------------------

## Plays a whole battle headless: the basic AI plays you (always uses its best attack, like a new
## player; no items), the boss uses its own AI tier. Returns the outcome.
func _sim(player: Array[DaemonInstance], foe: Array[DaemonInstance], seed_value: int, foe_tier: String) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var state := BattleState.new(BattleSide.new("You", player), BattleSide.new("Dana", foe), rng, false)
	while not state.is_over() and state.turn < 200:
		for side in 2:
			if state.needs_switch[side]:
				BattleSim.forced_switch(state, side, BattleAI.choose_replacement(state, side, "basic" if side == 0 else foe_tier))
		var events := BattleSim.run_turn(state, BattleAI.choose_action(state, 0, "basic"), BattleAI.choose_action(state, 1, foe_tier))
		if events.size() == 1 and events[0]["type"] == "invalid_action":
			break
	return state.outcome


## Wins out of 60 for a starter at `level` with a Cablesnake and a Ramster a bit lower.
func _dana_wins(starter: String, level: int) -> int:
	var wins := 0
	for i in 60:
		var team: Array[DaemonInstance] = [
			_daemon(starter, level, i), _daemon("cablesnake", level - 2, i + 100), _daemon("ramster", level - 3, i + 200)]
		var foe: Array[DaemonInstance] = []
		for entry: Array in DataRegistry.trainers["dana"]["team"]:
			foe.append(_daemon(entry[0], int(entry[1]), i + 300))
		if _sim(team, foe, i, DataRegistry.trainers["dana"]["ai"]) == "player_won":
			wins += 1
	return wins


func test_dana_is_beatable_around_level_13() -> void:
	var report := PackedStringArray()
	for starter in ["chipmunk", "pingo", "glowbit"]:
		var at_14 := _dana_wins(starter, 14)
		var at_12 := _dana_wins(starter, 12)
		report.append("%-8s Lv14 team: %2d/60   Lv12 team: %2d/60" % [starter, at_14, at_12])
		assert_gte(at_14, 18, "%s path at Lv14 should usually win (30%%+)" % starter)
		assert_gte(at_12, 6, "%s path at Lv12 should be possible (10%%+)" % starter)
	gut.p("Dana balance (no items, basic-AI player):\n" + "\n".join(report))


func test_typed_name_box_fits_and_can_back_out() -> void:
	_open("player_house", "new_game")
	world.auto_choice = null
	var menus: FieldMenus = world.field_menus
	var result := []
	var run := func() -> void: result.append(await menus._type_name())
	run.call()
	await wait_process_frames(2)
	var panel: Panel = menus.get_node("NameEntry")
	for part in ["Prompt", "Edit", "Hint"]:
		var c: Control = panel.get_node(part)
		var right: float = c.position.x + maxf(c.size.x, c.get_combined_minimum_size().x)
		assert_lte(right, panel.size.x - 4.0, part + " fits inside the box")
	assert_lte(panel.size.x, get_viewport().get_visible_rect().size.x, "box fits the screen")
	var edit: LineEdit = panel.get_node("Edit")
	edit.text_submitted.emit("  Z@ra_9!  ")
	await wait_process_frames(2)
	assert_eq(result, ["Zra9"], "symbols stripped, trimmed")
	assert_eq(FieldMenus.clean_name("ABCDEFGHIJKLMN"), "ABCDEFGHIJ", "10 letters max")
	assert_eq(FieldMenus.clean_name("   "), "", "blank goes back to the presets")
