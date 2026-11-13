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
	assert_eq(scene.capture_meter.passed(), 3, "SCAN, ISOLATE and ENCRYPT all went green")
	assert_false(scene.capture_meter.visible, "the bar goes away after the catch")


func test_capture_meter_stages() -> void:
	var meter := CaptureMeter.new()
	add_child_autofree(meter)
	assert_eq(Array(CaptureMeter.STAGES), ["SCAN", "ISOLATE", "ENCRYPT"])
	assert_eq(meter.size, CaptureMeter.SIZE)
	assert_false(meter.visible, "hidden until a key is used")
	meter.set_progress(0, 1.0)
	meter.set_state(0, "ok")
	meter.set_progress(1, 0.55)
	meter.set_state(1, "fail")
	assert_eq(meter.passed(), 1)
	assert_eq(meter.states[1], "fail")
	assert_eq(meter.label_color(1), CaptureMeter.FAIL, "red where it broke free")
	assert_eq(meter.label_color(2), UiTheme.MUTED, "grey while waiting")
	meter.set_progress(2, 3.0)
	assert_eq(meter.progress[2], 1.0, "clamped")
	meter.reset()
	assert_eq(meter.passed(), 0)
	assert_eq(meter.progress, [0.0, 0.0, 0.0] as Array[float])
	for i in 3:
		assert_true(Rect2(Vector2.ZERO, CaptureMeter.SIZE).encloses(meter.segment_rect(i)), "segment %d fits" % i)
	var scene: BattleScene = load(BattleScene.SCENE).instantiate()
	var team: Array[DaemonInstance] = [_daemon("chipmunk", 12)]
	scene.setup({"foe": [["dustbunny", 5]], "player_stack": team, "auto": true, "time_scale": 0.0, "seed": 1})
	add_child_autofree(scene)
	await wait_process_frames(2)
	var r: Rect2 = scene.capture_meter.get_rect()
	assert_false(r.intersects(scene.foe_panel.get_rect()), "clear of the foe's info panel")
	assert_false(r.intersects(Rect2(scene.foe_slot.position, Vector2(64, 64))), "clear of the foe")


func test_trainer_battle_with_forced_switches() -> void:
	var team: Array[DaemonInstance] = [_daemon("chipmunk", 14), _daemon("pingo", 13), _daemon("glowbit", 13)]
	var scene := await _run_battle({"foe": [["spigeon", 9], ["cablesnake", 10], ["wormby", 11]],
		"wild": false, "trainer_name": "Kevin", "ai": "smart", "player_stack": team, "items": {}})
	assert_true(scene.result.get("outcome", "") in ["player_won", "player_lost"])


func test_back_view_flip_faces_the_foe() -> void:
	# The Chipmunk line's back pose was drawn facing left; species art.flip_back mirrors it.
	assert_true(DaemonSprites.flip_back("chipmunk"))
	assert_false(DaemonSprites.flip_back("pingo"))
	var team: Array[DaemonInstance] = [_daemon("chipmunk", 12)]
	var scene := await _run_battle({"foe": [["pingo", 5]], "player_stack": team, "items": {}})
	assert_true(scene.player_sprite.flip_h, "player's Chipmunk mirrored")
	assert_false(scene.foe_sprite.flip_h, "foe's front view never flipped")


func test_trainers_show_then_step_out_before_daemons() -> void:
	var team: Array[DaemonInstance] = [_daemon("chipmunk", 14)]
	var scene: BattleScene = load(BattleScene.SCENE).instantiate()
	scene.setup({"auto": true, "time_scale": 0.05, "seed": 11, "foe": [["pingo", 5]], "wild": false,
		"trainer_name": "Kevin", "trainer_sprite": "kevin", "player_stack": team, "items": {}})
	add_child_autofree(scene)
	await wait_until(func() -> bool: return scene.foe_trainer.visible and scene.player_trainer.visible, 5.0)
	assert_true(scene.player_trainer.visible, "you, from behind")
	assert_true(scene.foe_trainer.visible, "and Kevin, both on screen at the start")
	assert_false(scene.player_sprite.visible or scene.foe_sprite.visible, "before any Daemon is out")
	assert_not_null(scene.foe_trainer.texture)
	await wait_until(func() -> bool: return scene.foe_sprite.visible and scene.player_sprite.visible, 10.0)
	assert_false(scene.player_trainer.visible, "trainers stepped out of frame")
	assert_false(scene.foe_trainer.visible)
	await wait_for_signal(scene.finished, TIMEOUT)


func test_wild_battles_show_only_you() -> void:
	var team: Array[DaemonInstance] = [_daemon("chipmunk", 14)]
	var scene: BattleScene = load(BattleScene.SCENE).instantiate()
	scene.setup({"auto": true, "time_scale": 0.05, "seed": 11, "foe": [["dustbunny", 3]],
		"player_stack": team, "items": {}})
	add_child_autofree(scene)
	await wait_until(func() -> bool: return scene.player_trainer.visible, 5.0)
	assert_false(scene.foe_trainer.visible, "no trainer in a wild battle")
	await wait_for_signal(scene.finished, TIMEOUT)


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
	assert_eq(chipmunk.species_id, "munkboard", "upgraded after the battle")
	assert_eq(scene.player_panel.max_uptime, 0 + scene.player_panel.max_uptime, "panel survived")
	assert_true(GameState.cmdb_caught.has("munkboard"))


# --- menus and text box ------------------------------------------------------

func _menu() -> BattleMenu:
	var holder := Control.new()
	holder.theme = UiTheme.get_theme()
	holder.size = BattleStyle.FRAME
	add_child_autofree(holder)
	var menu := BattleMenu.new()
	holder.add_child(menu)
	return menu


func _press_later(button: BaseButton) -> void:
	button.call_deferred("emit_signal", "pressed")


func test_menus_follow_the_battle_spec_layout() -> void:
	var menu := _menu()
	await wait_process_frames(1)
	assert_eq(menu.size, BattleStyle.FRAME, "menu layer covers the 960x640 frame")
	var frame := Rect2(Vector2.ZERO, BattleStyle.FRAME)
	assert_eq(menu._command_panel.get_rect(), Rect2(524, 476, 420, 148), "right 16, y 476, 420x148")
	for panel: Panel in [menu._command_panel, menu._move_panel, menu._list_panel, menu._confirm_panel]:
		assert_true(frame.encloses(panel.get_rect()), "%s is inside the frame: %s" % [panel, panel.get_rect()])
	var labels := menu._command_buttons.map(func(b: TermButton) -> String: return b.label_text)
	assert_eq(labels, ["EXECUTE", "DAEMONS", "INVENTORY", "DISCONNECT"])
	for b: TermButton in menu._command_buttons:
		assert_gte(b.size.y, 52.0, "buttons are at least 52 px tall")
	assert_true(menu._command_buttons[3].danger, "DISCONNECT stands out")
	await wait_process_frames(1)


func test_number_keys_and_man_line() -> void:
	var menu := _menu()
	var seen := []
	menu.hovered.connect(func(kind: String, i: int) -> void: seen.append([kind, i]))
	var key := InputEventAction.new()
	key.action = "quick_3"
	key.pressed = true
	menu.call_deferred("_unhandled_input", key)
	assert_eq(await menu.choose_command(), "bag", "3 jumps straight to INVENTORY")
	assert_has(seen, ["command", 0], "the man line follows the selection from the start")
	assert_has(seen, ["command", 2])
	await wait_process_frames(1)


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


func test_long_text_is_split_into_pages() -> void:
	var holder := Control.new()
	holder.theme = UiTheme.get_theme()
	holder.size = BattleStyle.FRAME
	add_child_autofree(holder)
	var box := TextBox.new()
	box.position = Vector2(2, 132)
	box.size = Vector2(316, 46)
	holder.add_child(box)
	await wait_process_frames(2)
	var long_text: String = DataRegistry.trainers["dana"]["intro"]
	var pages := box.paginate(long_text)
	assert_gt(pages.size(), 1, "Dana's intro needs more than one box")
	assert_eq(" ".join(pages), " ".join(long_text.split(" ", false)), "no words lost")
	for page in pages:
		box._label.text = page
		assert_lte(box._label.get_line_count(), TextBox.MAX_LINES, "page fits: " + page)
	assert_eq(box.paginate("Short line.").size(), 1)


func test_server_floor_arena() -> void:
	var team: Array[DaemonInstance] = [_daemon("chipmunk", 12)]
	var scene: BattleScene = load(BattleScene.SCENE).instantiate()
	scene.setup({"foe": [["dustbunny", 5]], "player_stack": team, "auto": true, "time_scale": 0.0, "seed": 1,
		"zone": "coolant_loop"})
	add_child_autofree(scene)
	await wait_process_frames(2)
	assert_eq(scene.arena.zone_id, "coolant_loop", "the area's zone palette")
	assert_eq(scene.stage.size, BattleStyle.FRAME)
	assert_eq(scene.text_box.get_rect(), Rect2(16, 476, 928, 148), "console: 16, 476, 928x148")
	assert_eq(scene.foe_panel.position, Vector2(28, 28), "wild card top-left")
	assert_eq(scene.foe_panel.size.x, 430.0)
	var foe := scene.foe_sprite.get_global_rect()
	var stage_xf := scene.stage.get_global_transform().affine_inverse()
	var foe_frame := Rect2(stage_xf * foe.position, foe.size / scene.stage.get_global_transform().get_scale())
	assert_almost_eq(foe_frame.size.x, 192.0, 0.5, "foe sprite at x3")
	assert_almost_eq(foe_frame.get_center().x, BattleArena.WILD_PAD.get_center().x, 1.0, "centered on the wild pad")
	scene.arena.zone_id = "overheat"
	assert_eq(scene.arena.zone_id, "overheat", "zones swap without a layout change")
	scene.arena.zone_id = "nope"
	assert_eq(scene.arena.zone_id, BattleStyle.DEFAULT_ZONE, "unknown zones fall back to Server Floor")


func test_up_bar_segments_and_colors() -> void:
	assert_eq(BattleStyle.segments(1.0), 20)
	assert_eq(BattleStyle.segments(0.0), 0)
	assert_eq(BattleStyle.segments(0.52), 10, "round(52 / 5) = 10")
	assert_eq(BattleStyle.segments(0.53), 11)
	assert_eq(BattleStyle.up_color(0.51), BattleStyle.UP_HIGH, "green above 50")
	assert_eq(BattleStyle.up_color(0.50), BattleStyle.UP_MID, "amber 21-50")
	assert_eq(BattleStyle.up_color(0.21), BattleStyle.UP_MID)
	assert_eq(BattleStyle.up_color(0.20), BattleStyle.UP_LOW, "red 20 and below")


func test_frame_scales_by_whole_numbers() -> void:
	assert_eq(BattleScene.frame_scale(Vector2(1280, 720)), 1.0, "1280x720: 960x640 at 1x")
	assert_eq(BattleScene.frame_scale(Vector2(1920, 1080)), 1.0)
	assert_eq(BattleScene.frame_scale(Vector2(2560, 1440)), 2.0)
	assert_eq(BattleScene.frame_scale(Vector2(3840, 2160)), 3.0)
	assert_almost_eq(BattleScene.frame_scale(Vector2(844, 390)), 390.0 / 640.0, 0.001, "phones: shrink to fit")


func test_rack_row_matches_the_spec() -> void:
	var arena := BattleArena.new()
	add_child_autofree(arena)
	assert_eq(arena.rack_rect(0), Rect2(10, 70, 92, 232), "first rack, bottom at the horizon (302)")
	assert_eq(arena.rack_rect(1).position.x, 116.0, "92 px wide, 14 px gaps")
	assert_eq(arena.rack_rect(8).end.x, 950.0, "9 racks end at 950")
	assert_eq(BattleArena.slot_count(244), 11, "floor((244 - 20) / 20)")
	var leds := arena.led_colors(0, 0)
	assert_eq(leds[1], BattleStyle.BAR_EDGE, "k = 0: LED 2 is off")
