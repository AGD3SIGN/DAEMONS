class_name DemoEnd
extends Control
## End of the Acts 1–3 demo (2026-11-15): the "END OF THE DEMO / Act 4: Escalation / coming soon" card, then the
## credits roll, then "Thanks for playing" and back to the title. Text comes from data/demo_end.json.
## Reached through the "end_demo" dialogue command (after Major Kalb's trace; the story cliffhanger goes before it).
## Accept speeds things up; after the credits it returns to the title.

const SCENE := "res://scenes/ui/demo_end.tscn"
const TITLE := "res://scenes/ui/title_screen.tscn"
const BG := Color("070b14")
const INK := Color("e8f1ff")
const ACCENT := Color("3ee6ff")
const MUTED := Color("8090a8")
const SCROLL_SPEED := 18.0  # base pixels per second

var time_scale := 1.0
var finished := false

var _card := VBoxContainer.new()
var _roll := VBoxContainer.new()
var _prompt := Label.new()
var _speed := 1.0
var _rolling := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var data := DataRegistry.demo_end
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_card.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.add_theme_constant_override("separation", 8)
	add_child(_card)
	var lines: Array = data.get("card", [])
	for i in lines.size():
		var l := _label(String(lines[i]), ACCENT if i == 1 else INK)
		l.modulate.a = 0.0
		_card.add_child(l)
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_roll.add_theme_constant_override("separation", 3)
	_roll.visible = false
	add_child(_roll)
	for c: Array in data.get("credits", []):
		_roll.add_child(_label(String(c[0]).to_upper(), MUTED))
		_roll.add_child(_label(String(c[1]), INK))
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 10)
		_roll.add_child(gap)
	_roll.add_child(_label(String(data.get("thanks", "")), ACCENT))
	_prompt.text = InputPrompts.press("ui_accept").to_upper() + " FOR THE TITLE"
	_prompt.add_theme_color_override("font_color", MUTED)
	_prompt.visible = false
	add_child(_prompt)
	_run()


func _label(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(280, 0)
	l.add_theme_color_override("font_color", color)
	return l


func _wait(seconds: float) -> void:
	if time_scale <= 0.0:
		await get_tree().process_frame
		return
	await get_tree().create_timer(seconds * time_scale / _speed).timeout


func _run() -> void:
	await _wait(0.6)
	for l in _card.get_children():
		var t := create_tween()
		t.tween_property(l, "modulate:a", 1.0, 0.6 * time_scale / _speed)
		await _wait(1.1)
	await _wait(2.0)
	var out := create_tween()
	out.tween_property(_card, "modulate:a", 0.0, 0.6 * time_scale / _speed)
	await _wait(0.8)
	_card.visible = false
	_roll.visible = true
	_roll.size = Vector2(size.x, _roll.get_combined_minimum_size().y)
	_roll.position = Vector2(0, size.y)
	_rolling = true
	while _rolling and _roll.position.y + _roll.size.y > size.y * 0.55:
		await get_tree().process_frame
	_rolling = false
	_prompt.position = Vector2((size.x - _prompt.get_combined_minimum_size().x) / 2.0, size.y - 16)
	_prompt.visible = true
	finished = true


func _process(delta: float) -> void:
	if not _rolling:
		return
	if time_scale <= 0.0:
		_roll.position.y = size.y * 0.55 - _roll.size.y  # tests: skip straight to the end
	else:
		_roll.position.y -= SCROLL_SPEED * _speed * delta / time_scale


func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("menu") \
		or (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if finished:
		SceneRouter.goto(TITLE)
	else:
		_speed = 4.0  # hold on, let them skip ahead
