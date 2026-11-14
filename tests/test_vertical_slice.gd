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
	var box := Rect2(Vector2.ZERO, panel.size).grow(-2.0)
	var rects := []
	for part in ["Prompt", "Edit", "Hint"]:
		var c: Control = panel.get_node(part)
		# What's actually drawn: never smaller than the control's (theme) minimum size.
		var r := Rect2(c.position, c.size.max(c.get_combined_minimum_size()))
		assert_true(box.encloses(r), "%s %s fits inside the box %s" % [part, r, box])
		rects.append(r)
	assert_false(rects[0].intersects(rects[1]), "prompt and text field don't overlap")
	assert_false(rects[1].intersects(rects[2]), "text field and hint don't overlap")
	assert_true(get_viewport().get_visible_rect().encloses(panel.get_global_rect()), "box fits the screen")
	var edit: LineEdit = panel.get_node("Edit")
	edit.text_submitted.emit("  Z@ra_9!  ")
	await wait_process_frames(2)
	assert_eq(result, ["Zra9"], "symbols stripped, trimmed")
	assert_eq(FieldMenus.clean_name("ABCDEFGHIJKLMN"), "ABCDEFGHIJ", "10 letters max")
	assert_eq(FieldMenus.clean_name("   "), "", "blank goes back to the presets")


func test_name_entry_works_with_a_gamepad() -> void:
	_open("player_house", "new_game")
	world.auto_choice = null
	var saved := InputPrompts.scheme
	InputPrompts.scheme = "xbox"
	var menus: FieldMenus = world.field_menus
	var result := []
	var run := func() -> void: result.append(await menus._type_name())
	run.call()
	await wait_process_frames(2)
	var panel: Panel = menus.get_node("NameEntry")
	var keys: Control = panel.get_node("Keys")
	assert_true(panel.get_rect().encloses(Rect2(panel.position + keys.position, keys.get_combined_minimum_size())),
		"the letter grid fits in the box")
	var first: Button = keys.get_child(0).get_child(0)
	assert_true(first.has_focus(), "on a pad the cursor starts on the letter grid")
	for e: InputEvent in [_pad(JOY_BUTTON_A, true), _pad(JOY_BUTTON_A, false), _pad(JOY_BUTTON_DPAD_RIGHT, true),
			_pad(JOY_BUTTON_DPAD_RIGHT, false), _pad(JOY_BUTTON_A, true), _pad(JOY_BUTTON_A, false)]:
		Input.parse_input_event(e)
		await wait_process_frames(1)
	var edit: LineEdit = panel.get_node("Edit")
	assert_eq(edit.text, "AB", "A types the letter under the cursor")
	Input.parse_input_event(_pad(JOY_BUTTON_B, true))
	Input.parse_input_event(_pad(JOY_BUTTON_B, false))
	await wait_process_frames(2)
	assert_eq(result, [""], "B backs out to the name list")
	InputPrompts.scheme = saved


func _pad(button: JoyButton, pressed: bool) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = button
	e.pressed = pressed
	return e


## Ping (Networking, Act 2): a starter that has upgraded once, plus two catches from Route 2 / Port City.
func _ping_wins(starter: String, level: int) -> int:
	var wins := 0
	for i in 60:
		var team: Array[DaemonInstance] = [
			_daemon(starter, level, i), _daemon("spigeon", level - 2, i + 100), _daemon("calfiber", level - 3, i + 200)]
		var foe: Array[DaemonInstance] = []
		for entry: Array in DataRegistry.trainers["ping_okoro"]["team"]:
			foe.append(_daemon(entry[0], int(entry[1]), i + 300))
		if _sim(team, foe, i, DataRegistry.trainers["ping_okoro"]["ai"]) == "player_won":
			wins += 1
	return wins


func test_ping_is_beatable_around_level_20() -> void:
	var report := PackedStringArray()
	for starter in ["munkboard", "pengwan", "scriptfly"]:
		var at_21 := _ping_wins(starter, 21)
		var at_19 := _ping_wins(starter, 19)
		report.append("%-9s Lv21 team: %2d/60   Lv19 team: %2d/60" % [starter, at_21, at_19])
		assert_gte(at_21, 18, "%s path at Lv21 should usually win (30%%+)" % starter)
		assert_gte(at_19, 6, "%s path at Lv19 should be possible (10%%+)" % starter)
	gut.p("Ping balance (no items, basic-AI player):\n" + "\n".join(report))


## Devi (DevOps, Act 2): a once-upgraded starter plus two catches from the road there.
func _devi_wins(starter: String, level: int) -> int:
	var wins := 0
	for i in 60:
		var team: Array[DaemonInstance] = [
			_daemon(starter, level, i), _daemon("spigeon", level - 2, i + 100), _daemon("dillodisk", level - 3, i + 200)]
		var foe: Array[DaemonInstance] = []
		for entry: Array in DataRegistry.trainers["devi_shah"]["team"]:
			foe.append(_daemon(entry[0], int(entry[1]), i + 300))
		if _sim(team, foe, i, DataRegistry.trainers["devi_shah"]["ai"]) == "player_won":
			wins += 1
	return wins


func test_devi_is_beatable_around_level_26() -> void:
	var report := PackedStringArray()
	for starter in ["munkboard", "pengwan", "scriptfly"]:
		var at_28 := _devi_wins(starter, 28)
		var at_26 := _devi_wins(starter, 26)
		report.append("%-9s Lv28 team: %2d/60   Lv26 team: %2d/60" % [starter, at_28, at_26])
		assert_gte(at_28, 18, "%s path at Lv28 should usually win (30%%+)" % starter)
		assert_gte(at_26, 6, "%s path at Lv26 should be possible (10%%+)" % starter)
	gut.p("Devi balance (no items, basic-AI player):\n" + "\n".join(report))


func _boss_wins(boss: String, starter: String, partners: Array, level: int) -> int:
	var wins := 0
	for i in 60:
		var team: Array[DaemonInstance] = [_daemon(starter, level, i)]
		for j in partners.size():
			team.append(_daemon(partners[j], level - 2 - j, i + 100 * (j + 1)))
		var foe: Array[DaemonInstance] = []
		for entry: Array in DataRegistry.trainers[boss]["team"]:
			foe.append(_daemon(entry[0], int(entry[1]), i + 300))
		if _sim(team, foe, i, DataRegistry.trainers[boss]["ai"]) == "player_won":
			wins += 1
	return wins


func test_rolf_and_kalb_are_beatable_on_every_path() -> void:
	var report := PackedStringArray()
	var bosses := {"rolf_brandt": [35, ["botgeon", "patchviper"]], "major_kalb": [41, ["botgeon", "orcable", "patchviper"]]}
	for boss: String in bosses:
		var ace: int = bosses[boss][0]
		for starter in ["munkboard", "pengwan", "scriptfly"]:
			var at_ace_plus_2 := _boss_wins(boss, starter, bosses[boss][1], ace + 2)
			var at_ace := _boss_wins(boss, starter, bosses[boss][1], ace)
			report.append("%-12s %-9s Lv%d: %2d/60   Lv%d: %2d/60" % [boss, starter, ace + 2, at_ace_plus_2, ace, at_ace])
			assert_gte(at_ace_plus_2, 18, "%s, %s path at Lv%d should usually win" % [boss, starter, ace + 2])
			assert_gte(at_ace, 6, "%s, %s path at Lv%d should be possible" % [boss, starter, ace])
	gut.p("Act 3 boss balance (no items, basic-AI player):\n" + "\n".join(report))
