extends SceneTree
## One-shot tool that writes the project's input actions into project.godot.
## Run from the repo root:  godot --headless -s res://tools/setup_input_map.gd
## Re-running overwrites these actions with the defaults below.

const DEADZONE := 0.2

func _init() -> void:
	var dirs := {
		"move_up": [KEY_UP, KEY_W, JOY_BUTTON_DPAD_UP, [JOY_AXIS_LEFT_Y, -1.0]],
		"move_down": [KEY_DOWN, KEY_S, JOY_BUTTON_DPAD_DOWN, [JOY_AXIS_LEFT_Y, 1.0]],
		"move_left": [KEY_LEFT, KEY_A, JOY_BUTTON_DPAD_LEFT, [JOY_AXIS_LEFT_X, -1.0]],
		"move_right": [KEY_RIGHT, KEY_D, JOY_BUTTON_DPAD_RIGHT, [JOY_AXIS_LEFT_X, 1.0]],
	}
	for action: String in dirs:
		var d: Array = dirs[action]
		_set_action(action, [_key(d[0]), _key(d[1]), _joy_button(d[2]), _joy_axis(d[3][0], d[3][1])])
		# Built-in ui_* direction actions get WASD too, so Godot's Control focus works the same way.
		var ui_name: String = action.replace("move_", "ui_")
		_set_action(ui_name, [_key(d[0]), _key(d[1]), _joy_button(d[2]), _joy_axis(d[3][0], d[3][1])])

	_set_action("ui_accept", [_key(KEY_Z), _key(KEY_ENTER), _key(KEY_KP_ENTER), _joy_button(JOY_BUTTON_A)])
	_set_action("ui_cancel", [_key(KEY_X), _key(KEY_ESCAPE), _key(KEY_BACKSPACE), _joy_button(JOY_BUTTON_B)])
	_set_action("menu", [_key(KEY_SPACE), _key(KEY_TAB), _joy_button(JOY_BUTTON_START)])
	_set_action("run", [_key(KEY_SHIFT), _joy_button(JOY_BUTTON_X)])
	# Battle command shortcuts: number keys 1-4 jump straight to a command or move.
	var digits := [[KEY_1, KEY_KP_1], [KEY_2, KEY_KP_2], [KEY_3, KEY_KP_3], [KEY_4, KEY_KP_4]]
	for i in digits.size():
		_set_action("quick_%d" % (i + 1), [_key(digits[i][0]), _key(digits[i][1])])

	var err := ProjectSettings.save()
	print("Input map saved: ", error_string(err))
	quit(0 if err == OK else 1)


func _set_action(action: String, events: Array) -> void:
	ProjectSettings.set_setting("input/" + action, {"deadzone": DEADZONE, "events": events})


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.device = -1  # all devices
	e.physical_keycode = code
	return e


func _joy_button(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = -1  # all devices
	e.button_index = button
	return e


func _joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = -1  # all devices
	e.axis = axis
	e.axis_value = value
	return e
