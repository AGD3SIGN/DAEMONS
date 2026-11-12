extends GutTest
## Phase 0 sanity checks: pixel settings, autoloads and input actions are in place.


func test_base_resolution_is_320x180() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 320)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 180)


func test_pixel_perfect_stretch_settings() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/scale_mode"), "integer")
	# 0 = Nearest
	assert_eq(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"), 0)


func test_autoloads_are_loaded() -> void:
	for autoload_name in ["DataRegistry", "GameState", "SaveManager", "AudioManager", "SceneRouter"]:
		assert_not_null(get_tree().root.get_node_or_null(autoload_name), "%s autoload missing" % autoload_name)


func test_input_actions_exist_with_bindings() -> void:
	for action in ["move_up", "move_down", "move_left", "move_right", "ui_accept", "ui_cancel", "menu", "run"]:
		assert_true(InputMap.has_action(action), "missing action %s" % action)
		assert_gt(InputMap.action_get_events(action).size(), 1, "%s needs keyboard + gamepad bindings" % action)


func test_game_state_reset_clears_everything() -> void:
	GameState.credits = 500
	GameState.flags["met_kevin"] = true
	GameState.reset()
	assert_eq(GameState.credits, 0)
	assert_true(GameState.flags.is_empty())


func test_title_scene_loads() -> void:
	var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	assert_not_null(scene)
	var title := scene.instantiate()
	add_child_autofree(title)
	assert_not_null(title.get_node_or_null("Stage"), "the 1280x720 title stage")
	assert_true("NEW GAME" in title.items)
