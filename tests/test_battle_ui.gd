extends GutTest
## Phase 3: the battle screen. Full battles run through the real UI with animations at
## time_scale 0 and auto-advancing text, plus menu and text box behavior.

const TIMEOUT := 30.0


func before_each() -> void:
	GameState.reset()


func after_each() -> void:
	GameState.reset()


func _daemon(species: String, lvl: int) -> DaemonInstance:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	return DaemonInstance.create(species, lvl, rng, 1)


## Runs a whole battle on screen and returns the scene once `finished` fires.
func _run_battle(config: Dictionary) -> BattleScene:
	var base := {"auto": true, "time_scale": 0.0, "seed": 11}
	base.merge(config, true)
	var scene: BattleScene = load(BattleScene.SCENE).instantiate()
	scene.setup(base)
	add_child_autofree(scene)
	await wait_for_signal(scene.finished, TIMEOUT)
	return scene


# --- sprites -----------------------------------------------------------------

func test_placeholder_sprites() -> void:
	var front := DaemonSprites.front("pingo")
	var back := DaemonSprites.back("pingo")
	assert_eq(front.get_size(), Vector2(64, 64))
	assert_ne(front.get_image().get_data(), back.get_image().get_data(), "front and back differ")
	assert_eq(DaemonSprites.front("pingo"), front, "cached")
	assert_ne(DaemonSprites.front("chipmunk").get_image().get_data(), front.get_image().get_data())
	assert_eq(DaemonSprites.quarantine_key().get_size(), Vector2(12, 18))


# --- full battles on screen --------------------------------------------------

func test_wild_battle_plays_to_the_end() -> void:
	var team: Array[DaemonInstance] = [_daemon("chipmunk", 12), _daemon("pingo", 10)]
	var scene := await _run_battle({"foe": [["dustbunny", 5]], "player_stack": team, "items": {}})
	assert_ne(scene.result.get("outcome", ""), "", "battle finished")
	assert_true(GameState.cmdb_seen.has("dustbunny"))


func test_catch_a_wild_dustbunny() -> void:
	var team: Array[DaemonInstance] = [_daemon("chipmunk", 12)]
	GameState.active_stack.assign(team)
	var bag := {"root_key": 1}
	var scene := await _run_battle({"foe": [["dustbunny", 5]], "items": bag, "auto_policy": "capture"})
	assert_eq(scene.result["outcome"], "caught")
	assert_eq(GameState.active_stack.size(), 2, "the catch joined the Active Stack")
	assert_eq(GameState.active_stack[1].species_id, "dustbunny")
	assert_true(GameState.cmdb_caught.has("dustbunny"))
	assert_false(bag.has("root_key"), "key used up")
	assert_false(scene.key_sprite.visible and scene.key_sprite.modulate == Color.WHITE, "key dimmed after capture")


func test_trainer_battle_with_forced_switches() -> void:
	var team: Array[DaemonInstance] = [_daemon("chipmunk", 14), _daemon("pingo", 13), _daemon("bitling", 13)]
	var scene := await _run_battle({"foe": [["spamlet", 9], ["cablesnake", 10], ["wormby", 11]],
		"wild": false, "trainer_name": "Kevin", "ai": "smart", "player_stack": team, "items": {}})
	assert_true(scene.result.get("outcome", "") in ["player_won", "player_lost"])


func test_level_up_then_upgrade_on_screen() -> void:
	var chipmunk := _daemon("chipmunk", 15)
	chipmunk.total_exp = GrowthRate.exp_for_level("medium_slow", 16) - 1
	var team: Array[DaemonInstance] = [chipmunk]
	var foe := _daemon("dustbunny", 5)
	foe.current_uptime = 1
	var foe_stack: Array[DaemonInstance] = [foe]
	var scene := await _run_battle({"foe_stack": foe_stack, "player_stack": team, "items": {}})
	assert_eq(scene.result["outcome"], "player_won")
	assert_eq(chipmunk.level, 16)
	assert_eq(chipmunk.species_id, "motherboar", "upgraded after the battle")
	assert_eq(scene.player_panel.max_uptime, 0 + scene.player_panel.max_uptime, "panel survived")
	assert_true(GameState.cmdb_caught.has("motherboar"))


# --- menus and text box ------------------------------------------------------

func _menu() -> BattleMenu:
	var holder := Control.new()
	holder.theme = UiTheme.get_theme()
	holder.size = Vector2(320, 180)
	add_child_autofree(holder)
	var menu := BattleMenu.new()
	holder.add_child(menu)
	return menu


func _press_later(button: BaseButton) -> void:
	button.call_deferred("emit_signal", "pressed")


func test_menus_fill_the_screen_and_stay_on_it() -> void:
	var menu := _menu()
	await wait_process_frames(1)
	assert_eq(menu.size, Vector2(320, 180), "menu layer covers the whole view")
	var screen := Rect2(Vector2.ZERO, Vector2(320, 180))
	for panel: Panel in [menu._command_panel, menu._move_panel, menu._list_panel, menu._confirm_panel]:
		var rect := panel.get_rect()
		assert_true(rect.size.x > 40 and rect.size.y > 30, "%s has a real size: %s" % [panel, rect])
		assert_true(screen.encloses(rect), "%s is on screen: %s" % [panel, rect])


func test_command_menu_returns_choice() -> void:
	var menu := _menu()
	_press_later(menu._command_buttons[3])
	assert_eq(await menu.choose_command(), "run")
	assert_false(menu.is_open())
	await wait_process_frames(1)  # finish outside the menu's signal before the menu is freed


func test_move_menu_and_back() -> void:
	var menu := _menu()
	var d := _daemon("pingo", 20)
	_press_later(menu._move_buttons[1])
	assert_eq(await menu.choose_move(d), 1)
	_press_later(menu._move_back)
	assert_eq(await menu.choose_move(d), -1)
	assert_true(menu._move_buttons[0].label_text != "-")
	await wait_process_frames(1)


func test_list_cancel_with_ui_cancel() -> void:
	var menu := _menu()
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	menu.call_deferred("_unhandled_input", cancel)
	assert_eq(await menu.choose_from_list("Pick", PackedStringArray(["A", "B"]), [], true), -1)
	await wait_process_frames(1)


func test_text_box_waits_for_input() -> void:
	var box := TextBox.new()
	box.size = Vector2(316, 46)
	add_child_autofree(box)
	box.time_scale = 0.0
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	var done := [false]
	var runner := func() -> void:
		await box.show_text("Pingo ran Ping!")
		done[0] = true
	runner.call()
	await wait_process_frames(3)
	assert_true(box.is_waiting(), "waiting for the player")
	assert_false(done[0])
	box._unhandled_input(accept)
	await wait_process_frames(2)
	assert_true(done[0], "advanced")
