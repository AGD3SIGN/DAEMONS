class_name TextBox
extends Panel
## The text box along the bottom of the screen (battles and overworld dialogue). Types text out character by character;
## Z/Enter/X, a click or a tap skips the typing, then advances once the arrow shows.

signal advanced

const AUTO_PAUSE := 0.6   # seconds a line stays up when it doesn't wait for input
const MAX_LINES := 3      # longer text is split into pages at word boundaries

var time_scale: float = 1.0   # 0 = instant (tests)
var auto_advance: bool = false  # never wait for input (AI-vs-AI / tests)
var max_lines: int = MAX_LINES  # BattleConsole fits 2 lines of its big terminal font

var _label: Label
var _arrow: Label
var _typing := false
var _waiting := false
var _blink := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # let taps reach _unhandled_input (tap anywhere to continue)
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 8
	_label.offset_top = 7
	_label.offset_right = -14
	_label.offset_bottom = -4
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_constant_override("line_spacing", 4)
	add_child(_label)
	_arrow = Label.new()
	_arrow.text = "v"
	_arrow.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_arrow.offset_left = -14
	_arrow.offset_top = -14
	_arrow.visible = false
	add_child(_arrow)


func _process(delta: float) -> void:
	if _waiting:
		_blink += delta
		_arrow.visible = fmod(_blink, 0.8) < 0.5


## Leaves room on the right for the command menu.
func set_reserved_right(px: int) -> void:
	_label.offset_right = -14 - px


## Shows text immediately with no typing and no waiting (e.g. "Pingo is awaiting input.").
func show_now(text: String) -> void:
	_label.text = text
	_label.visible_characters = -1


func clear() -> void:
	_label.text = ""


func is_waiting() -> bool:
	return _waiting


## Types the text out, then waits for input (wait = true) or pauses briefly (wait = false).
## Text longer than the box is split into pages; every page but the last waits for input.
func show_text(text: String, wait: bool = true) -> void:
	if text.is_empty():
		return
	set_reserved_right(0)
	var pages := paginate(text)
	for i in pages.size():
		await _show_page(pages[i], wait or i < pages.size() - 1)


## Splits text into pages that fit MAX_LINES at the box's current width.
func paginate(text: String) -> PackedStringArray:
	if _label.size.x < 40.0:
		return PackedStringArray([text])  # not laid out yet; show it as one page
	var pages := PackedStringArray()
	var page := ""
	for word in text.split(" ", false):
		var candidate := word if page.is_empty() else page + " " + word
		_label.text = candidate
		if _label.get_line_count() > max_lines and not page.is_empty():
			pages.append(page)
			page = word
		else:
			page = candidate
	if not page.is_empty():
		pages.append(page)
	return pages


func _show_page(text: String, wait: bool) -> void:
	_label.text = text
	_label.visible_characters = 0
	_typing = true
	var total := _label.get_total_character_count()
	var shown := 0.0
	var speed := Settings.chars_per_second()  # Options > Text speed; 0 = instant
	while _typing and time_scale > 0.0 and speed > 0.0 and _label.visible_characters < total:
		await get_tree().process_frame
		shown += get_process_delta_time() * speed / time_scale
		_label.visible_characters = mini(total, int(shown))
	_typing = false
	_label.visible_characters = -1
	if auto_advance or not wait:
		await get_tree().create_timer(AUTO_PAUSE * time_scale).timeout
		return
	await wait_for_advance()


## Waits for Z/Enter/X/click/tap (or a short pause in auto mode).
func wait_for_advance() -> void:
	if auto_advance:
		await get_tree().create_timer(AUTO_PAUSE * time_scale).timeout
		return
	_waiting = true
	_blink = 0.0
	await advanced
	_waiting = false
	_arrow.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not (_typing or _waiting):
		return
	var pressed: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if _typing:
		_typing = false
	elif _waiting:
		advanced.emit()
