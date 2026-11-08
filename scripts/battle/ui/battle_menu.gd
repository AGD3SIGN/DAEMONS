class_name BattleMenu
extends Control
## All battle menus. Each choose_* call shows a menu, waits, and returns the choice:
##   choose_command()  -> "fight" | "stack" | "bag" | "run"
##   choose_move(d)    -> slot 0..3, or -1 for back
##   choose_from_list(title, options, enabled, cancellable) -> index, or -1 for back
##   confirm()         -> true / false
## X/Esc (ui_cancel) or the on-screen BACK button goes back where allowed.

signal _picked(value: Variant)

const NO_CANCEL := "__no_cancel__"

var _cancel_value: Variant = NO_CANCEL
var _command_panel: Panel
var _command_buttons: Array[CursorButton] = []
var _move_panel: Panel
var _move_buttons: Array[CursorButton] = []
var _move_pp: Label
var _move_type: Label
var _move_back: CursorButton
var _list_panel: Panel
var _list_title: Label
var _list_box: VBoxContainer
var _confirm_panel: Panel
var _confirm_buttons: Array[CursorButton] = []
var _shown_moves: DaemonInstance


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_command_panel()
	_build_move_panel()
	_build_list_panel()
	_build_confirm_panel()
	_hide_all()


func choose_command() -> String:
	_hide_all()
	_command_panel.visible = true
	_command_buttons[0].grab_focus()
	var result: Variant = await _await_pick(NO_CANCEL)
	_hide_all()
	return result


## needs_pp: grey out moves with 0 PP (choosing a move to use; not when replacing one).
func choose_move(d: DaemonInstance, needs_pp: bool = false) -> int:
	_hide_all()
	_shown_moves = d
	for i in 4:
		var button := _move_buttons[i]
		if i < d.moves.size():
			button.label_text = DataRegistry.get_move(d.moves[i]["id"])["name"]
			button.set_enabled(not needs_pp or int(d.moves[i]["pp"]) > 0)
		else:
			button.label_text = "-"
			button.set_enabled(false)
	_move_panel.visible = true
	_move_buttons[0].grab_focus()
	_show_move_info(0)
	var result: Variant = await _await_pick(-1)
	_hide_all()
	return int(result)


func choose_from_list(title: String, options: PackedStringArray, enabled: Array = [], cancellable: bool = true) -> int:
	_hide_all()
	_list_title.text = title
	for child in _list_box.get_children():
		child.queue_free()
	var first: CursorButton = null
	for i in options.size():
		var button := CursorButton.new(options[i])
		button.custom_minimum_size = Vector2(0, 11)
		button.set_enabled(enabled.is_empty() or bool(enabled[i]))
		button.pressed.connect(func() -> void: _pick(i))
		_list_box.add_child(button)
		if first == null and not button.disabled:
			first = button
	if cancellable:
		var back := CursorButton.new("BACK")
		back.custom_minimum_size = Vector2(0, 11)
		back.pressed.connect(func() -> void: _pick(-1))
		_list_box.add_child(back)
		if first == null:
			first = back
	_list_panel.visible = true
	if first != null:
		first.grab_focus()
	var result: Variant = await _await_pick(-1 if cancellable else NO_CANCEL)
	_hide_all()
	return int(result)


func confirm() -> bool:
	_hide_all()
	_confirm_panel.visible = true
	_confirm_buttons[0].grab_focus()
	var result: Variant = await _await_pick(false)
	_hide_all()
	return bool(result)


func is_open() -> bool:
	return _command_panel.visible or _move_panel.visible or _list_panel.visible or _confirm_panel.visible


func _await_pick(cancel_value: Variant) -> Variant:
	_cancel_value = cancel_value
	var value: Variant = await _picked
	_cancel_value = NO_CANCEL
	return value


func _unhandled_input(event: InputEvent) -> void:
	if not is_open() or not event.is_action_pressed("ui_cancel"):
		return
	if typeof(_cancel_value) == TYPE_STRING and _cancel_value == NO_CANCEL:
		return
	get_viewport().set_input_as_handled()
	_pick(_cancel_value)


## Picks are delivered a frame later so the waiting code never resumes inside a button's
## own `pressed` signal (which could free that button while it's still emitting).
func _pick(value: Variant) -> void:
	_emit_pick.call_deferred(value)


func _emit_pick(value: Variant) -> void:
	_picked.emit(value)


func _hide_all() -> void:
	for panel in [_command_panel, _move_panel, _list_panel, _confirm_panel]:
		panel.visible = false
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()


# --- building ----------------------------------------------------------------

func _anchored_panel(left: float, top: float, right: float, bottom: float, anchors: Vector4) -> Panel:
	var panel := Panel.new()
	panel.anchor_left = anchors.x
	panel.anchor_top = anchors.y
	panel.anchor_right = anchors.z
	panel.anchor_bottom = anchors.w
	panel.offset_left = left
	panel.offset_top = top
	panel.offset_right = right
	panel.offset_bottom = bottom
	add_child(panel)
	return panel


func _build_command_panel() -> void:
	_command_panel = _anchored_panel(-134, -48, -2, -2, Vector4(1, 1, 1, 1))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.position = Vector2(4, 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.add_theme_constant_override("h_separation", 4)
	_command_panel.add_child(grid)
	for entry: Array in [["FIGHT", "fight"], ["STACK", "stack"], ["BAG", "bag"], ["RUN", "run"]]:
		var button := CursorButton.new(entry[0])
		button.custom_minimum_size = Vector2(56, 12)
		var value: String = entry[1]
		button.pressed.connect(func() -> void: _pick(value))
		grid.add_child(button)
		_command_buttons.append(button)


func _build_move_panel() -> void:
	_move_panel = _anchored_panel(2, -48, -2, -2, Vector4(0, 1, 1, 1))
	var list := VBoxContainer.new()
	list.position = Vector2(4, 4)
	list.add_theme_constant_override("separation", -1)
	_move_panel.add_child(list)
	for i in 4:
		var button := CursorButton.new("-")
		button.custom_minimum_size = Vector2(160, 10)
		button.pressed.connect(func() -> void: _pick(i))
		button.focus_entered.connect(func() -> void: _show_move_info(i))
		list.add_child(button)
		_move_buttons.append(button)
	var info := VBoxContainer.new()
	info.anchor_left = 1.0
	info.anchor_right = 1.0
	info.offset_left = -112
	info.offset_top = 5
	info.add_theme_constant_override("separation", 3)
	_move_panel.add_child(info)
	_move_pp = Label.new()
	_move_type = Label.new()
	info.add_child(_move_pp)
	info.add_child(_move_type)
	_move_back = CursorButton.new("BACK")
	_move_back.custom_minimum_size = Vector2(0, 10)
	_move_back.pressed.connect(func() -> void: _pick(-1))
	info.add_child(_move_back)


func _show_move_info(slot: int) -> void:
	if _shown_moves == null or slot >= _shown_moves.moves.size():
		return
	var move_slot: Dictionary = _shown_moves.moves[slot]
	var move := DataRegistry.get_move(move_slot["id"])
	_move_pp.text = "PP %d/%d" % [int(move_slot["pp"]), int(move["max_pp"])]
	var type_data: Dictionary = DataRegistry.types[move["type"]]
	_move_type.text = String(type_data["name"]).to_upper()
	_move_type.add_theme_color_override("font_color", Color(type_data["color"]).darkened(0.3))


func _build_list_panel() -> void:
	_list_panel = _anchored_panel(6, 6, -6, -52, Vector4(0, 0, 1, 1))
	_list_title = Label.new()
	_list_title.position = Vector2(8, 6)
	_list_panel.add_child(_list_title)
	_list_box = VBoxContainer.new()
	_list_box.position = Vector2(4, 20)
	_list_box.add_theme_constant_override("separation", 0)
	_list_panel.add_child(_list_box)


func _build_confirm_panel() -> void:
	_confirm_panel = _anchored_panel(-64, -94, -2, -52, Vector4(1, 1, 1, 1))
	var box := VBoxContainer.new()
	box.position = Vector2(4, 6)
	box.add_theme_constant_override("separation", 4)
	_confirm_panel.add_child(box)
	for entry: Array in [["YES", true], ["NO", false]]:
		var button := CursorButton.new(entry[0])
		button.custom_minimum_size = Vector2(48, 12)
		var value: bool = entry[1]
		button.pressed.connect(func() -> void: _pick(value))
		box.add_child(button)
		_confirm_buttons.append(button)
