extends GutTest
## Accessibility basics for the demo (GDD §9): type shapes + tags (not color alone), a SHAKE & FLASH switch,
## and RUN BUTTON hold or toggle.

var _saved := {}


func before_each() -> void:
	_saved = {"shake_flash": Settings.shake_flash, "run_toggle": Settings.run_toggle, "path": Settings.path}


func after_each() -> void:
	Settings.shake_flash = _saved["shake_flash"]
	Settings.run_toggle = _saved["run_toggle"]
	Settings.path = _saved["path"]
	Input.action_release("run")


func test_every_type_has_its_own_shape_and_tag() -> void:
	var shapes := {}
	var tags := {}
	for type_id: String in DataRegistry.types:
		assert_true(TypeMarks.SHAPES.has(type_id), "%s has a shape" % type_id)
		shapes[TypeMarks.shape(type_id)] = type_id
		tags[TypeMarks.tag(type_id)] = type_id
		assert_between(TypeMarks.tag(type_id).length(), 2, 3)
	assert_eq(shapes.size(), DataRegistry.types.size(), "no two types share a shape")
	assert_eq(tags.size(), DataRegistry.types.size(), "no two types share a tag")


func test_filled_shapes_have_outlines() -> void:
	for kind: String in ["square", "diamond", "triangle", "circle", "hexagon", "shield", "bar", "tall", "star"]:
		assert_gte(TypeMarks.points(kind, Vector2(8, 8), 12.0).size(), 3, kind)


func test_a_typed_button_keeps_room_for_its_tag() -> void:
	var b := TermButton.new("Packet Burst", "[1]")
	b.size = Vector2(300, 52)
	var plain := b.text_room()
	b.type_id = "network"
	assert_lt(b.text_room(), plain + 0.01)
	b.free()


func test_new_options_are_saved() -> void:
	Settings.path = "user://test_settings.cfg"
	Settings.shake_flash = false
	Settings.run_toggle = true
	Settings.save_settings()
	Settings.shake_flash = true
	Settings.run_toggle = false
	Settings.load_settings()
	assert_false(Settings.shake_flash)
	assert_true(Settings.run_toggle)
	assert_true(Settings.calm_effects())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))


func _key_event(pressed: bool) -> InputEventKey:
	var e := InputEventKey.new()
	var events := InputMap.action_get_events("run")
	for ev in events:
		if ev is InputEventKey:
			e.physical_keycode = (ev as InputEventKey).physical_keycode
			e.keycode = (ev as InputEventKey).keycode
	e.pressed = pressed
	return e


func test_run_button_hold_or_toggle() -> void:
	var p := PlayerController.new()
	add_child_autofree(p)
	Settings.run_toggle = false
	Input.action_press("run")
	assert_true(p.is_running(), "HOLD: running while held")
	Input.action_release("run")
	assert_false(p.is_running())
	Settings.run_toggle = true
	p._input(_key_event(true))
	p._input(_key_event(false))
	assert_true(p.is_running(), "TOGGLE: one press and you keep running")
	p._input(_key_event(true))
	assert_false(p.is_running(), "the next press walks again")
	var touch := InputEventAction.new()
	touch.action = "run"
	touch.pressed = true
	p._input(touch)
	assert_true(p.is_running(), "the touch RUN pill still works in TOGGLE mode")
	touch.pressed = false
	p._input(touch)
	assert_false(p.is_running())


func test_a_battle_plays_through_with_shake_and_flash_off() -> void:
	Settings.shake_flash = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var team: Array[DaemonInstance] = [DaemonInstance.create("munkboard", 30, rng, 1)]
	var scene: BattleScene = load(BattleScene.SCENE).instantiate()
	scene.setup({"auto": true, "time_scale": 0.01, "seed": 4, "foe": [["dustbunny", 6]], "wild": true,
		"player_stack": team, "items": {}})
	add_child_autofree(scene)
	await wait_for_signal(scene.finished, 30.0)
	assert_eq(scene.result["outcome"], "player_won")
