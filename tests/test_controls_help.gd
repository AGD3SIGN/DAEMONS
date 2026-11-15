extends GutTest
## Player feedback (2026-11-14): in the browser nothing says how to open the menu. The overworld shows
## a corner tag with the right buttons, pause > CONTROLS lists them all, and the title says which key.

var world: Overworld
var _saved_scheme: String
var _saved_hints: bool


func before_each() -> void:
	GameState.reset()
	GameState.flags["got_starter"] = true
	GameState.location = {"map": "port_city", "x": 17, "y": 12, "facing": "up"}
	_saved_scheme = InputPrompts.scheme
	_saved_hints = Settings.control_hints


func after_each() -> void:
	InputPrompts.scheme = _saved_scheme
	Settings.control_hints = _saved_hints
	SceneRouter.params = {}
	GameState.reset()


func _open() -> void:
	SceneRouter.params = {"map": "port_city", "spawn": "default"}
	world = load(Overworld.SCENE).instantiate()
	world.allow_scene_change = false
	world.auto_advance_text = true
	add_child_autofree(world)
	world.set_time_scale(0.0)
	await wait_process_frames(3)


func test_corner_hint_names_the_buttons_for_each_scheme() -> void:
	await _open()
	InputPrompts.scheme = "keyboard"
	world.control_hint.refresh()
	assert_eq(world.control_hint.text(), "Space MENU  Z TALK")
	assert_true(world.control_hint.should_show(), "shown while walking around")
	InputPrompts.scheme = "playstation"
	assert_eq(world.control_hint.text(), "Options MENU  Cross TALK")
	InputPrompts.scheme = "touch"
	assert_false(world.control_hint.should_show(), "touch has real on-screen buttons")
	InputPrompts.scheme = "keyboard"
	Settings.control_hints = false
	assert_false(world.control_hint.should_show(), "can be turned off in Options")
	Settings.control_hints = true
	world.text_box.visible = true
	assert_false(world.control_hint.should_show(), "out of the way during dialogue")
	world.text_box.visible = false
	var rect := world.control_hint.get_global_rect()
	assert_true(get_viewport().get_visible_rect().encloses(rect), "on screen: %s" % rect)


func test_controls_page_lists_every_action() -> void:
	for s in InputPrompts.SCHEMES:
		var rows: Array = InputPrompts.controls(s)
		var actions := rows.map(func(r: Array) -> String: return r[0])
		for needed in ["MOVE", "TALK / OK", "BACK", "MENU"]:
			assert_has(actions, needed, "%s lists %s" % [s, needed])
	assert_eq(InputPrompts.controls("keyboard")[4], ["MENU", "Space / Tab"])
	var source := FileAccess.get_file_as_string("res://scripts/ui/field_menus.gd")
	assert_string_contains(source, "\"SAVE\", \"CONTROLS\", \"OPTIONS\"")


func test_title_prompt_matches_the_input() -> void:
	InputPrompts.scheme = "keyboard"
	assert_eq(InputPrompts.start_prompt("PRESS START"), "PRESS ENTER")
	InputPrompts.scheme = "xbox"
	assert_eq(InputPrompts.start_prompt("PRESS START"), "PRESS START")
	InputPrompts.scheme = "touch"
	assert_eq(InputPrompts.start_prompt("PRESS START"), "TAP TO START")
