extends GutTest
## Phase 8: touch controls, input prompts, app lifecycle (pause + autosave), export presets.

const TEST_SLOTS: PackedStringArray = ["user://test_platform_a.json", "user://test_platform_b.json"]


func before_each() -> void:
	TouchControls.points_scale_override = 0.75  # an iPhone (3x) at 4x game scale
	TouchControls.safe_margins_override = Vector4.ZERO
	TouchControls.set_shown(true)
	GameState.reset()
	SaveManager.slot_paths = TEST_SLOTS
	SaveManager.delete_saves()


func after_each() -> void:
	TouchControls.set_shown(false)
	TouchControls.points_scale_override = -1.0
	TouchControls.safe_margins_override = null
	InputPrompts.scheme = "keyboard"
	Settings.autosave_on_suspend = true
	SaveManager.delete_saves()
	SaveManager.slot_paths = SaveManager.SLOT_PATHS
	SceneRouter.params = {}
	GameState.reset()


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	TouchControls._input(e)


func _drag(index: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	TouchControls._input(e)


# --- touch controls ----------------------------------------------------------

func test_buttons_are_at_least_44pt_and_inside_the_safe_area() -> void:
	assert_eq(TouchControls.points_to_logical(44.0), 33.0)
	assert_gte(TouchControls.button_radius() * 2.0, TouchControls.points_to_logical(44.0))
	TouchControls.safe_margins_override = Vector4(30, 0, 30, 10)  # notch + home indicator
	var view := get_viewport().get_visible_rect().size
	var l := TouchControls.layout()
	for key in ["a", "b"]:
		var c: Vector2 = l[key]
		assert_lte(c.x + l["r"], view.x - 30, key + " clears the right inset")
		assert_lte(c.y + l["r"], view.y - 10, key + " clears the bottom inset")
		assert_gte(c.x - l["r"], 0.0)
	assert_gte(l["dpad_zone"].position.x, 30.0, "d-pad zone starts after the left inset")


func test_a_and_b_buttons_press_confirm_and_back() -> void:
	var l := TouchControls.layout()
	_touch(0, l["a"], true)
	await wait_process_frames(1)
	assert_true(Input.is_action_pressed("ui_accept"))
	_touch(0, l["a"], false)
	await wait_process_frames(1)
	assert_false(Input.is_action_pressed("ui_accept"))
	_touch(1, l["b"], true)
	await wait_process_frames(1)
	assert_true(Input.is_action_pressed("ui_cancel"))
	_touch(1, l["b"], false)
	_touch(2, l["menu"], true)
	await wait_process_frames(1)
	assert_true(Input.is_action_pressed("menu"))
	_touch(2, l["menu"], false)


func test_dpad_is_a_fixed_cross() -> void:
	# A real D-pad: directions come from the pad's center, wherever on it your thumb lands.
	var l := TouchControls.layout()
	var home: Vector2 = l["dpad_home"]
	var ring: float = l["ring"]
	_touch(0, home + Vector2(ring * 0.1, -ring * 0.7), true)  # straight onto the up arm
	await wait_process_frames(1)
	assert_true(Input.is_action_pressed("move_up"), "pressing the up arm moves up right away")
	_drag(0, home + Vector2(-ring * 0.7, 0))
	await wait_process_frames(1)
	assert_true(Input.is_action_pressed("move_left"), "roll the thumb to the left arm")
	assert_false(Input.is_action_pressed("move_up"))
	_touch(0, home, false)
	await wait_process_frames(1)
	assert_false(Input.is_action_pressed("move_left"))
	_touch(1, home + Vector2(ring * 3.0, -ring * 2.0), true)  # well off the pad
	await wait_process_frames(1)
	assert_false(Input.is_action_pressed("move_right"), "touches away from the pad don't move you")
	_touch(1, home + Vector2(ring * 3.0, -ring * 2.0), false)


func test_dpad_moves_and_runs() -> void:
	var l := TouchControls.layout()
	var start: Vector2 = l["dpad_zone"].get_center()
	_touch(0, start, true)
	_drag(0, start + Vector2(0, -l["ring"] * 0.8))
	await wait_process_frames(1)
	assert_true(Input.is_action_pressed("move_up"), "drag up = walk up")
	assert_true(Input.is_action_pressed("ui_up"), "and moves menu cursors")
	assert_false(Input.is_action_pressed("run"))
	_drag(0, start + Vector2(l["ring"] * 2.0, 0))
	await wait_process_frames(1)
	assert_false(Input.is_action_pressed("move_up"))
	assert_true(Input.is_action_pressed("move_right"))
	assert_true(Input.is_action_pressed("run"), "pushed past the ring = run")
	_touch(0, start, false)
	await wait_process_frames(1)
	for action in ["move_right", "ui_right", "run"]:
		assert_false(Input.is_action_pressed(action), action + " released")


func test_fake_mouse_clicks_on_controls_are_swallowed() -> void:
	var click := InputEventMouseButton.new()
	click.device = InputEvent.DEVICE_ID_EMULATION
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = TouchControls.layout()["a"]
	TouchControls._input(click)
	assert_true(get_viewport().is_input_handled(), "a tap on A doesn't also click the menu under it")
	assert_true(TouchControls.in_control_zone(TouchControls.layout()["dpad_home"]))
	assert_false(TouchControls.in_control_zone(Vector2(160, 20)), "taps up top still reach menus")


func test_gamepad_hides_touch_controls() -> void:
	TouchControls._on_joy_connection_changed(0, true)
	assert_false(TouchControls.shown)
	TouchControls.set_shown(true)
	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_A
	press.pressed = true
	TouchControls._input(press)
	assert_false(TouchControls.shown, "pressing a pad button hides them too")


# --- prompts -----------------------------------------------------------------

func test_controller_brands_and_labels() -> void:
	assert_eq(InputPrompts.brand_from_name("Xbox Wireless Controller"), "xbox")
	assert_eq(InputPrompts.brand_from_name("DualSense Wireless Controller"), "playstation")
	assert_eq(InputPrompts.brand_from_name("Nintendo Switch Pro Controller"), "nintendo")
	assert_eq(InputPrompts.brand_from_name("8BitDo Ultimate"), "xbox", "unknown pads use the Xbox layout")
	assert_eq(InputPrompts.label("ui_accept", "keyboard"), "Z")
	assert_eq(InputPrompts.label("ui_accept", "xbox"), "A")
	assert_eq(InputPrompts.label("ui_accept", "playstation"), "Cross")
	assert_eq(InputPrompts.label("ui_accept", "nintendo"), "B", "Nintendo's confirm (south) button is labelled B")
	assert_eq(InputPrompts.label("menu", "playstation"), "Options")


func test_scheme_follows_the_last_input_and_updates_the_title() -> void:
	var key := InputEventKey.new()
	key.pressed = true
	assert_eq(InputPrompts.detect(key), "keyboard")
	var touch := InputEventScreenTouch.new()
	assert_eq(InputPrompts.detect(touch), "touch")
	var title: Control = load("res://scenes/ui/title_screen.tscn").instantiate()
	add_child_autofree(title)
	InputPrompts._input(touch)
	assert_true(title.vertical, "touch: the title menu stacks vertically")
	InputPrompts._input(key)
	assert_false(title.vertical, "keyboard: one row")


# --- app lifecycle -----------------------------------------------------------

func test_autosave_on_suspend_only_when_safe() -> void:
	var rng := RandomNumberGenerator.new()
	GameState.add_daemon(DaemonInstance.create("pingo", 8, rng, 1))
	GameState.flags["got_starter"] = true
	SceneRouter.params = {"map": "onboarding_town"}
	var world: Overworld = load(Overworld.SCENE).instantiate()
	add_child_autofree(world)
	await wait_process_frames(2)
	assert_true(AppLifecycle.autosave_if_safe(world), "idle in the overworld: saved")
	assert_true(SaveManager.has_save())
	SaveManager.delete_saves()
	world._busy = true
	assert_false(AppLifecycle.autosave_if_safe(world), "mid-dialogue: not saved")
	world._busy = false
	Settings.autosave_on_suspend = false
	assert_false(AppLifecycle.autosave_if_safe(world), "turned off in Options")
	assert_false(AppLifecycle.autosave_if_safe(Node.new()), "not in the overworld (e.g. battle)")
	Settings.autosave_on_suspend = true
	AppLifecycle.suspend(false)
	assert_true(AppLifecycle.is_suspended)
	AppLifecycle.resume()
	assert_false(AppLifecycle.is_suspended)
	assert_false(get_tree().paused)


# --- export presets ----------------------------------------------------------

func test_export_presets_ship_the_data_and_not_the_tests() -> void:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK)
	var platforms := []
	for i in 5:
		var section := "preset.%d" % i
		platforms.append(cfg.get_value(section, "platform"))
		assert_string_contains(cfg.get_value(section, "include_filter"), "*.json", "data files are included")
		assert_string_contains(cfg.get_value(section, "exclude_filter"), "tests/*")
	assert_eq(platforms, ["macOS", "Windows Desktop", "iOS", "Android", "Web"])
	assert_eq(cfg.get_value("preset.4.options", "variant/thread_support"), false,
		"web build without threads: no special server headers needed (itch.io, GitHub Pages)")
	assert_eq(cfg.get_value("preset.0.options", "binary_format/architecture"), "universal")
	assert_eq(ProjectSettings.get_setting("display/window/handheld/orientation"), 4, "sensor landscape on phones")


func test_battles_hide_the_touch_overlay() -> void:
	assert_true(TouchControls.is_active())
	var scene: BattleScene = load(BattleScene.SCENE).instantiate()
	var team: Array[DaemonInstance] = [DaemonInstance.create("pingo", 9, RandomNumberGenerator.new(), 1)]
	scene.setup({"foe": [["dustbunny", 3]], "player_stack": team, "items": {}, "auto": true, "time_scale": 0.0})
	add_child(scene)
	assert_false(TouchControls.is_active(), "hidden during battle")
	assert_true(TouchControls.shown, "but still switched on")
	await wait_for_signal(scene.finished, 30.0)
	scene.free()
	assert_true(TouchControls.is_active(), "back after the battle")


func test_touching_the_screen_shows_controls_even_with_a_pad_paired() -> void:
	# The iOS Simulator (and a phone with a controller paired) reports a joypad; a touch still wins.
	TouchControls._on_joy_connection_changed(0, true)
	assert_false(TouchControls.shown)
	_touch(0, Vector2(160, 20), true)
	assert_true(TouchControls.shown, "a touch brings the overlay back")
	_touch(0, Vector2(160, 20), false)


func test_full_screen_panels_let_taps_through() -> void:
	# Panels swallow taps by default, so "tap to start / continue" never fired on phones.
	var title: Control = load("res://scenes/ui/title_screen.tscn").instantiate()
	add_child_autofree(title)
	assert_eq(title.mouse_filter, Control.MOUSE_FILTER_IGNORE, "title root")
	assert_eq(title.get_node("Background").mouse_filter, Control.MOUSE_FILTER_IGNORE, "title background")
	for panel: Control in [TextBox.new(), CmdbPanel.new(), SummaryPanel.new(), TrainerCardPanel.new()]:
		add_child_autofree(panel)
		assert_eq(panel.mouse_filter, Control.MOUSE_FILTER_IGNORE, panel.get_class() + " " + str(panel.get_script().resource_path))


func test_desktop_ignores_menu_bar_safe_area() -> void:
	TouchControls.safe_margins_override = null
	if not OS.has_feature("mobile"):
		assert_eq(TouchControls.safe_margins(), Vector4.ZERO)
	var zone: Rect2 = TouchControls.layout()["dpad_zone"]
	assert_gt(zone.size.x, 0.0)
	assert_gt(zone.size.y, 0.0)


func test_title_menu_fits_the_frame() -> void:
	var title: Control = load("res://scenes/ui/title_screen.tscn").instantiate()
	add_child_autofree(title)
	await wait_process_frames(2)
	for vertical in [false, true]:
		title.vertical = vertical
		for r: Rect2 in title.menu_rects():
			assert_true(Rect2(0, 0, 1280, 720).encloses(r), "%s inside the 1280x720 frame (vertical %s)" % [r, vertical])
			assert_gte(r.size.y, 44.0, "touch targets at least 44 px tall")


func test_web_build_loads_the_phone_control_deck() -> void:
	# Upright phones: the page shrinks the game to a screen at the top and draws a deck below it.
	var cfg := ConfigFile.new()
	cfg.load("res://export_presets.cfg")
	assert_string_contains(cfg.get_value("preset.4.options", "html/head_include"), "touch_deck.js")
	assert_eq(cfg.get_value("preset.4.options", "html/canvas_resize_policy"), 0, "the page sizes the canvas")
	assert_true(FileAccess.file_exists("res://web/touch_deck.js"))
	for script in ["res://tools/serve_web.sh", "res://.github/workflows/web.yml"]:
		assert_string_contains(FileAccess.get_file_as_string(script), "web/touch_deck.js", script + " ships it")
	# The deck's d-pad is one solid cross (a single outline), not two overlapping bars with a seam.
	var deck := FileAccess.get_file_as_string("res://web/touch_deck.js")
	assert_string_contains(deck, "const CROSS")
	assert_eq(deck.count("class=\"tri\""), 4, "an arrow per direction")
	assert_eq(deck.count("class=\"press\""), 4, "each arm shows when it's pressed")
	assert_false(deck.contains("arm v") or deck.contains("arm h"), "no separate bars")


func test_deck_mode_hides_the_overlay_and_drives_input() -> void:
	TouchControls.set_deck(true)
	assert_false(TouchControls._view.visible, "the deck replaces the overlay")
	TouchControls._on_deck_message(["dir", 0, -1])
	await wait_process_frames(1)
	assert_true(Input.is_action_pressed("move_up"))
	assert_true(Input.is_action_pressed("ui_up"))
	TouchControls._on_deck_message(["dir", 1, 1])
	await wait_process_frames(1)
	assert_false(Input.is_action_pressed("move_up"), "diagonals count as no direction")
	TouchControls._on_deck_message(["button", "ui_accept", true])
	await wait_process_frames(1)
	assert_true(Input.is_action_pressed("ui_accept"))
	TouchControls._on_deck_message(["button", "ui_accept", false])
	TouchControls._on_deck_message(["button", "quit", true])  # not a deck action: ignored
	TouchControls._on_deck_message(["dir", 0, 0])
	await wait_process_frames(1)
	assert_false(Input.is_action_pressed("ui_accept"))
	TouchControls.suppress("battle")
	TouchControls._on_deck_message(["button", "ui_cancel", true])
	await wait_process_frames(1)
	assert_true(Input.is_action_pressed("ui_cancel"), "the deck still works in battle")
	TouchControls._on_deck_message(["button", "ui_cancel", false])
	TouchControls.release("battle")
	TouchControls._on_deck_message(["shown", false])
	assert_false(TouchControls.deck)
	assert_true(TouchControls._view.visible, "overlay back in landscape")


func test_text_box_stops_short_of_the_touch_buttons() -> void:
	# Phone held sideways: A and B sat on top of the right end of the dialogue box.
	GameState.add_daemon(DaemonInstance.create("pingo", 8, RandomNumberGenerator.new(), 1))
	SceneRouter.params = {"map": "onboarding_town"}
	var world: Overworld = load(Overworld.SCENE).instantiate()
	add_child_autofree(world)
	await wait_process_frames(2)
	var l := TouchControls.layout()
	var box_right := world.text_box.get_global_rect().end.x
	var b: Vector2 = l["b"]
	assert_lt(box_right, b.x - l["r"], "box ends left of B")
	assert_lt(box_right, (l["a"] as Vector2).x - l["r"], "and of A")
	var home: Vector2 = l["dpad_home"]
	assert_gt(world.text_box.get_global_rect().position.x, home.x + l["ring"], "and starts right of the d-pad")
	TouchControls.set_shown(false)
	await wait_process_frames(1)
	assert_almost_eq(world.text_box.get_global_rect().end.x, get_viewport().get_visible_rect().size.x - 2.0, 0.5,
		"full width with a keyboard or gamepad")
	TouchControls.set_deck(true)
	TouchControls.set_shown(true)
	await wait_process_frames(1)
	assert_almost_eq(world.text_box.get_global_rect().end.x, get_viewport().get_visible_rect().size.x - 2.0, 0.5,
		"full width under the phone deck (the buttons are below the game)")
	TouchControls.set_deck(false)


func test_dpad_arms_are_big_enough_to_hit() -> void:
	var ring: float = TouchControls.layout()["ring"]
	assert_gte(ring * 2.0 / 3.0, TouchControls.points_to_logical(44.0), "each arm is at least 44pt wide")


# --- controllers (desktop, web and app all use the same input actions) --------

func _pad_button(button: JoyButton, pressed: bool) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = button
	e.pressed = pressed
	return e


func test_every_gameplay_action_has_a_gamepad_binding() -> void:
	var needed := ["ui_accept", "ui_cancel", "menu", "run", "move_up", "move_down", "move_left", "move_right",
		"ui_up", "ui_down", "ui_left", "ui_right"]
	for action: String in needed:
		var pad := InputMap.action_get_events(action).filter(func(e: InputEvent) -> bool:
			return e is InputEventJoypadButton or e is InputEventJoypadMotion)
		assert_false(pad.is_empty(), "%s works on a gamepad" % action)
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	assert_true(InputMap.event_is_action(stick, "ui_right"), "the left stick moves menu cursors too")


func test_battle_menu_works_with_a_gamepad() -> void:
	var holder := Control.new()
	holder.size = BattleStyle.FRAME
	add_child_autofree(holder)
	var menu := BattleMenu.new()
	holder.add_child(menu)
	await wait_process_frames(1)
	var drive := func() -> void:
		for e: InputEvent in [_pad_button(JOY_BUTTON_DPAD_RIGHT, true), _pad_button(JOY_BUTTON_DPAD_RIGHT, false),
				_pad_button(JOY_BUTTON_A, true), _pad_button(JOY_BUTTON_A, false)]:
			Input.parse_input_event(e)
			await get_tree().process_frame
	drive.call_deferred()
	assert_eq(await menu.choose_command(), "stack", "D-pad right then A picks DAEMONS")
	await wait_process_frames(1)


func test_battle_hints_follow_the_controller() -> void:
	var b := TermButton.new("EXECUTE", "[1]")
	var back := TermButton.new("BACK")
	back.hint_action = "ui_cancel"
	add_child_autofree(b)
	add_child_autofree(back)
	var saved := InputPrompts.scheme
	InputPrompts.scheme = "keyboard"
	assert_eq(b.shown_hint(), "[1]", "number keys on a keyboard")
	assert_eq(back.shown_hint(), "[X]")
	InputPrompts.scheme = "xbox"
	assert_eq(b.shown_hint(), "", "no number keys on a pad")
	assert_eq(back.shown_hint(), "[B]")
	InputPrompts.scheme = "playstation"
	assert_eq(back.shown_hint(), "[CIRCLE]")
	InputPrompts.scheme = "touch"
	assert_eq(back.shown_hint(), "", "nothing to press on touch")
	InputPrompts.scheme = saved
