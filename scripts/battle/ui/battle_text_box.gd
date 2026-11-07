class_name BattleTextBox
extends Panel
## The text box along the bottom of the battle screen. Types text out character by character;
## Z/Enter/X, a click or a tap skips the typing, then advances once the arrow shows.

signal advanced

const CHARS_PER_SEC := 60.0
const AUTO_PAUSE := 0.6   # seconds a line stays up when it doesn't wait for input

var time_scale: float = 1.0   # 0 = instant (tests)
var auto_advance: bool = false  # never wait for input (AI-vs-AI / tests)

var _label: Label
var _arrow: Label
var _typing := false
var _waiting := false
var _blink := 0.0


func _ready() -> void:
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


## Shows text immediately with no typing and no waiting (e.g. "What will Pingo do?").
func show_now(text: String) -> void:
	_label.text = text
	_label.visible_characters = -1


func clear() -> void:
	_label.text = ""


func is_waiting() -> bool:
	return _waiting


## Types the text out, then waits for input (wait = true) or pauses briefly (wait = false).
func show_text(text: String, wait: bool = true) -> void:
	if text.is_empty():
		return
	set_reserved_right(0)
	_label.text = text
	_label.visible_characters = 0
	_typing = true
	var total := _label.get_total_character_count()
	var shown := 0.0
	while _typing and time_scale > 0.0 and _label.visible_characters < total:
		await get_tree().process_frame
		shown += get_process_delta_time() * CHARS_PER_SEC / time_scale
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
