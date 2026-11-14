class_name BattleMenu
extends Control
## All battle menus, in the 960x640 battle frame (Battle Scene spec, 2026-11-13). Each choose_* call shows
## a menu, waits, and returns the choice:
##   choose_command()  -> "fight" | "stack" | "bag" | "run"   (EXECUTE / DAEMONS / INVENTORY / DISCONNECT)
##   choose_move(d)    -> slot 0..3, or -1 for back
##   choose_from_list(title, options, enabled, cancellable) -> index, or -1 for back
##   confirm()         -> true / false
## Arrows / D-pad / stick move around the 2x2 grids, number keys 1-4 (quick_1..quick_4) jump straight to an
## entry, mouse and touch select on tap. X/Esc (ui_cancel) or the BACK button go back where allowed; on the
## root command menu back does nothing. Every selection change emits `hovered` so the console's man line
## can follow it.

signal _picked(value: Variant)
## kind: "command" or "move"; index: the entry under the cursor.
signal hovered(kind: String, index: int)

const NO_CANCEL := "__no_cancel__"
const COMMAND_RECT := Rect2(524, 476, 420, 148)   # right 16, y 476, 420x148, 12 px gap from the console
const BACK_RECT := Rect2(358, 568, 130, 44)        # inside the console's lower right, menu mode only
const LIST_RECT := Rect2(16, 16, 928, 454)
const PADDING := 12
const GAP := 10
const COMMANDS := [
	["EXECUTE", "fight", "run one of your Daemon's moves."],
	["DAEMONS", "stack", "swap in another Daemon."],
	["INVENTORY", "bag", "open your gear and patches."],
	["DISCONNECT", "run", "drop the connection and flee."],
]

var _cancel_value: Variant = NO_CANCEL
var _command_panel: Panel
var _command_buttons: Array[TermButton] = []
var _move_panel: Panel
var _move_buttons: Array[TermButton] = []
var _move_back: TermButton
var _list_panel: Panel
var _list_title := ""
var _list_box: VBoxContainer
var _confirm_panel: Panel
var _confirm_buttons: Array[TermButton] = []
var _shown_moves: DaemonInstance


func _ready() -> void:
	position = Vector2.ZERO
	size = BattleStyle.FRAME
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
	hovered.emit("command", 0)
	var result: Variant = await _await_pick(NO_CANCEL)
	_hide_all()
	return result


## needs_pp: grey out moves with no Cycles left (choosing a move to use; not when replacing one).
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
	_move_back.visible = true
	var first := 0
	for i in 4:
		if not _move_buttons[i].disabled:
			first = i
			break
	_move_buttons[first].grab_focus()
	hovered.emit("move", first)
	var result: Variant = await _await_pick(-1)
	_hide_all()
	return int(result)


## The man-line text for a move: type, category, power and Cycles.
func move_man(slot: int) -> String:
	if _shown_moves == null or slot >= _shown_moves.moves.size():
		return ""
	var move_slot: Dictionary = _shown_moves.moves[slot]
	var move := DataRegistry.get_move(move_slot["id"])
	var type_name := String(DataRegistry.types[move["type"]]["name"]).to_upper()
	var power := "PWR %d" % int(move["power"]) if int(move["power"]) > 0 else "STATUS"
	return "%s · %s · CYC %d/%d" % [type_name, power, int(move_slot["pp"]), int(move["max_pp"])]


func choose_from_list(title: String, options: PackedStringArray, enabled: Array = [], cancellable: bool = true) -> int:
	_hide_all()
	_list_title = title
	for child in _list_box.get_children():
		child.queue_free()
	var first: TermButton = null
	for i in options.size():
		var button := _list_button(options[i])
		button.set_enabled(enabled.is_empty() or bool(enabled[i]))
		button.pressed.connect(func() -> void: _pick(i))
		_list_box.add_child(button)
		if first == null and not button.disabled:
			first = button
	if cancellable:
		var back := _list_button("BACK")
		back.hint_action = "ui_cancel"
		back.pressed.connect(func() -> void: _pick(-1))
		_list_box.add_child(back)
		if first == null:
			first = back
	_list_panel.visible = true
	_list_panel.queue_redraw()
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
	if not is_open():
		return
	for i in 4:
		if event.is_action_pressed("quick_%d" % (i + 1)):
			var buttons := _command_buttons if _command_panel.visible else (_move_buttons if _move_panel.visible else [])
			if i < buttons.size() and not buttons[i].disabled:
				get_viewport().set_input_as_handled()
				buttons[i].grab_focus()
				buttons[i].pressed.emit()
			return
	if not event.is_action_pressed("ui_cancel"):
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
	if _move_back != null:
		_move_back.visible = false
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()


# --- building ----------------------------------------------------------------

## A hard-edged panel (fill, 3 px host border, 6 px shadow) drawn in code.
func _panel(rect: Rect2) -> Panel:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.draw.connect(func() -> void:
		BattleStyle.draw_panel(panel, Rect2(Vector2.ZERO, panel.size), BattleStyle.PANEL, BattleStyle.HOST))
	add_child(panel)
	return panel


func _grid(panel: Panel, count: int) -> Array[Rect2]:
	var w := (panel.size.x - PADDING * 2 - GAP) / 2.0
	var h := (panel.size.y - PADDING * 2 - GAP) / 2.0
	var out: Array[Rect2] = []
	for i in count:
		out.append(Rect2(PADDING + (i % 2) * (w + GAP), PADDING + (i / 2) * (h + GAP), w, h))
	return out


func _build_command_panel() -> void:
	_command_panel = _panel(COMMAND_RECT)
	var cells := _grid(_command_panel, 4)
	for i in COMMANDS.size():
		var button := TermButton.new(COMMANDS[i][0], "[%d]" % (i + 1))
		button.danger = COMMANDS[i][1] == "run"
		button.position = cells[i].position
		button.size = cells[i].size
		var value: String = COMMANDS[i][1]
		button.pressed.connect(func() -> void: _pick(value))
		button.focus_entered.connect(func() -> void: hovered.emit("command", i))
		_command_panel.add_child(button)
		_command_buttons.append(button)
	_link_grid(_command_buttons)


func _build_move_panel() -> void:
	_move_panel = _panel(COMMAND_RECT)
	var cells := _grid(_move_panel, 4)
	for i in 4:
		var button := TermButton.new("-", "[%d]" % (i + 1))
		button.font_size = 18
		button.position = cells[i].position
		button.size = cells[i].size
		button.pressed.connect(func() -> void: _pick(i))
		button.focus_entered.connect(func() -> void: hovered.emit("move", i))
		_move_panel.add_child(button)
		_move_buttons.append(button)
	_link_grid(_move_buttons)
	_move_back = TermButton.new("BACK")
	_move_back.hint_action = "ui_cancel"
	_move_back.font_size = 18
	_move_back.position = BACK_RECT.position
	_move_back.size = BACK_RECT.size
	_move_back.custom_minimum_size = Vector2(0, BACK_RECT.size.y)
	_move_back.pressed.connect(func() -> void: _pick(-1))
	add_child(_move_back)


## Explicit focus neighbors for a 2x2 grid (wrapping), so arrows and the D-pad behave predictably.
func _link_grid(buttons: Array[TermButton]) -> void:
	for i in buttons.size():
		var b := buttons[i]
		var right := buttons[i ^ 1]
		var down := buttons[i ^ 2]
		b.focus_neighbor_left = b.get_path_to(right)
		b.focus_neighbor_right = b.get_path_to(right)
		b.focus_neighbor_top = b.get_path_to(down)
		b.focus_neighbor_bottom = b.get_path_to(down)


func _list_button(label: String) -> TermButton:
	var button := TermButton.new(label)
	button.font = BattleStyle.vt323()
	button.font_size = 30
	button.custom_minimum_size = Vector2(0, 44)
	return button


func _build_list_panel() -> void:
	_list_panel = _panel(LIST_RECT)
	_list_panel.draw.connect(func() -> void:
		var bar := Rect2(3, 3, _list_panel.size.x - 6, BattleConsole.TITLE_H)
		_list_panel.draw_rect(bar, BattleStyle.CONSOLE_HEADER)
		_list_panel.draw_rect(Rect2(bar.position.x, bar.end.y - 2, bar.size.x, 2), BattleStyle.TITLE_RULE)
		var sk := BattleStyle.silkscreen()
		var base := bar.position.y + (bar.size.y + sk.get_ascent(11)) / 2.0 - 1
		_list_panel.draw_string(sk, Vector2(13, base), "daemon@field", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, BattleStyle.HOST)
		_list_panel.draw_string(sk, Vector2(13 + sk.get_string_size("daemon@field ", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 6, base),
			_list_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, BattleStyle.TEXT_MUTED))
	_list_box = VBoxContainer.new()
	_list_box.position = Vector2(PADDING, 3 + BattleConsole.TITLE_H + 8)
	_list_box.size = Vector2(LIST_RECT.size.x - PADDING * 2, LIST_RECT.size.y - BattleConsole.TITLE_H - 20)
	_list_box.add_theme_constant_override("separation", 2)
	_list_panel.add_child(_list_box)


func _build_confirm_panel() -> void:
	_confirm_panel = _panel(COMMAND_RECT)
	var w := (COMMAND_RECT.size.x - PADDING * 2 - GAP) / 2.0
	for i in 2:
		var entry: Array = [["YES", true, "[1]"], ["NO", false, "[2]"]][i]
		var button := TermButton.new(entry[0], entry[2])
		button.position = Vector2(PADDING + i * (w + GAP), PADDING)
		button.size = Vector2(w, COMMAND_RECT.size.y - PADDING * 2)
		var value: bool = entry[1]
		button.pressed.connect(func() -> void: _pick(value))
		_confirm_panel.add_child(button)
		_confirm_buttons.append(button)
	_confirm_buttons[0].focus_neighbor_right = _confirm_buttons[0].get_path_to(_confirm_buttons[1])
	_confirm_buttons[1].focus_neighbor_left = _confirm_buttons[1].get_path_to(_confirm_buttons[0])
