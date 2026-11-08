class_name MenuList
extends Panel
## A scrolling list menu for field screens (pause, stack, bag, CMDB, rack, shop).
## choose() shows it and returns {"action": "pick" | "cancel" | "left" | "right", "index": i}.
## Up/down move (holding repeats), accept picks, cancel backs out, left/right only when allow_lr.
## Mouse/touch: hover moves the cursor, click/tap picks; "<" and ">" in the title switch pages.

signal _done(result: Dictionary)

const ROW_H := 11

var visible_rows := 10
var allow_lr := false
var cancellable := true
var describe: Callable  # optional (index) -> String shown in the footer

var _title: Label
var _left_arrow: Button
var _right_arrow: Button
var _rows: Array[Button] = []
var _footer: Label
var _more_up: Label
var _more_down: Label
var _items := PackedStringArray()
var _enabled: Array = []
var _cursor := 0
var _top := 0
var _open := false


## Places the panel (offsets from anchors, like Control offsets) and builds `rows` row buttons.
## footer_lines > 0 adds a description area at the bottom.
func setup(anchors: Vector4, offsets: Vector4, rows: int, footer_lines: int = 0) -> void:
	anchor_left = anchors.x
	anchor_top = anchors.y
	anchor_right = anchors.z
	anchor_bottom = anchors.w
	offset_left = offsets.x
	offset_top = offsets.y
	offset_right = offsets.z
	offset_bottom = offsets.w
	visible_rows = rows
	_title = Label.new()
	_title.position = Vector2(8, 5)
	add_child(_title)
	_left_arrow = _arrow_button("<", "left")
	_right_arrow = _arrow_button(">", "right")
	var box := VBoxContainer.new()
	box.position = Vector2(4, 17)
	box.add_theme_constant_override("separation", 0)
	add_child(box)
	for i in rows:
		var row := Button.new()
		row.flat = true
		row.focus_mode = Control.FOCUS_NONE
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(0, ROW_H)
		row.mouse_entered.connect(_hover.bind(i))
		row.pressed.connect(func() -> void: _try_pick(_top + i))
		box.add_child(row)
		_rows.append(row)
	_more_up = _corner_label("^", 6)
	_more_down = _corner_label("v", 17 + rows * ROW_H - 8)
	if footer_lines > 0:
		_footer = Label.new()
		_footer.anchor_right = 1.0
		_footer.anchor_top = 1.0
		_footer.anchor_bottom = 1.0
		_footer.offset_left = 8
		_footer.offset_right = -8
		_footer.offset_top = -6 - footer_lines * 11
		_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_footer.add_theme_color_override("font_color", Color("505068"))
		add_child(_footer)
	visible = false


func choose(title: String, items: PackedStringArray, enabled: Array = [], start: int = 0) -> Dictionary:
	_items = items
	_enabled = enabled
	_title.text = title
	_cursor = clampi(start, 0, maxi(0, items.size() - 1))
	_top = 0
	_scroll_to_cursor()
	_refresh()
	visible = true
	_open = true
	var result: Dictionary = await _done
	return result


func close() -> void:
	_open = false
	visible = false


func is_choosing() -> bool:
	return _open


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("ui_up", true):
		_move(-1)
	elif event.is_action_pressed("ui_down", true):
		_move(1)
	elif event.is_action_pressed("ui_accept"):
		_try_pick(_cursor)
	elif event.is_action_pressed("ui_cancel") and cancellable:
		_finish("cancel", _cursor)
	elif allow_lr and event.is_action_pressed("ui_left"):
		_finish("left", _cursor)
	elif allow_lr and event.is_action_pressed("ui_right"):
		_finish("right", _cursor)
	else:
		return
	get_viewport().set_input_as_handled()


func _move(step: int) -> void:
	if _items.is_empty():
		return
	_cursor = wrapi(_cursor + step, 0, _items.size())
	_scroll_to_cursor()
	_refresh()


func _hover(row: int) -> void:
	if _open and _top + row < _items.size():
		_cursor = _top + row
		_refresh()


func _try_pick(index: int) -> void:
	if not _open or index < 0 or index >= _items.size():
		return
	if not _enabled.is_empty() and not bool(_enabled[index]):
		return
	AudioManager.play_sfx("select")
	_finish("pick", index)


## Delivered a frame later so callers never resume inside a button's own signal.
func _finish(action: String, index: int) -> void:
	_open = false
	_done.emit.call_deferred({"action": action, "index": index})


func _scroll_to_cursor() -> void:
	if _cursor < _top:
		_top = _cursor
	elif _cursor >= _top + visible_rows:
		_top = _cursor - visible_rows + 1


func _refresh() -> void:
	for i in _rows.size():
		var index := _top + i
		var row := _rows[i]
		row.visible = index < _items.size()
		if not row.visible:
			continue
		row.text = ("> " if index == _cursor else "  ") + _items[index]
		var enabled := _enabled.is_empty() or bool(_enabled[index])
		row.add_theme_color_override("font_color", UiTheme.INK if enabled else UiTheme.MUTED)
		row.add_theme_color_override("font_hover_color", UiTheme.INK if enabled else UiTheme.MUTED)
	_more_up.visible = _top > 0
	_more_down.visible = _top + visible_rows < _items.size()
	_left_arrow.visible = allow_lr
	_right_arrow.visible = allow_lr
	if _footer != null:
		_footer.text = describe.call(_cursor) if describe.is_valid() and not _items.is_empty() else ""


func _arrow_button(text: String, action: String) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.anchor_left = 1.0 if action == "right" else 1.0
	button.anchor_right = 1.0
	button.offset_left = -18 if action == "right" else -34
	button.offset_top = 2
	button.visible = false
	button.pressed.connect(func() -> void:
		if _open and allow_lr:
			_finish(action, _cursor))
	add_child(button)
	return button


func _corner_label(text: String, y: float) -> Label:
	var label := Label.new()
	label.text = text
	label.anchor_left = 1.0
	label.anchor_right = 1.0
	label.offset_left = -14
	label.offset_top = y
	label.visible = false
	add_child(label)
	return label
