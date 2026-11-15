class_name TermButton
extends Button
## A battle-menu button in the terminal style (Battle Scene spec): hard edges, 2 px border, a caret
## slot, a label and an optional key hint like [1] on the right.
##   Unselected: dark fill, barEdge border, light text.   Selected (focused): host fill, dark text, "> " caret.
## Hovering (mouse) or tapping (touch) moves focus to it, like CursorButton, so every input shares one cursor.

const CARET_W := 14.0

var label_text := "":
	set(value):
		label_text = value
		queue_redraw()
var key_hint := ""             # e.g. "[1]": a keyboard shortcut, only shown while playing on a keyboard
var hint_action := ""          # e.g. "ui_cancel": shows that action's button for the current controller
var danger := false            # DISCONNECT: orange text so the flee option stands out
var font: Font
var font_size := 18
var size_cap := 0              # set by share_size(): every button in a panel uses the same text size


func _init(p_text: String = "", p_hint: String = "") -> void:
	label_text = p_text
	key_hint = p_hint
	text = ""
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(0, 52)
	var empty := StyleBoxEmpty.new()
	for style in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(style, empty)
	mouse_entered.connect(func() -> void:
		if not disabled:
			grab_focus())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	InputPrompts.scheme_changed.connect(func(_s: String) -> void: queue_redraw())


## The hint for the current input scheme: number keys only on a keyboard; an action's button
## ("[B]", "[Circle]", "[X]") on a gamepad or keyboard; nothing on touch.
func shown_hint() -> String:
	var scheme := InputPrompts.scheme
	if not hint_action.is_empty():
		return "" if scheme == "touch" else "[%s]" % InputPrompts.label(hint_action).to_upper()
	return key_hint if scheme == "keyboard" else ""


func set_enabled(enabled: bool) -> void:
	disabled = not enabled
	focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	queue_redraw()


func selected() -> bool:
	return has_focus() and not disabled


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var sel := selected()
	draw_rect(r, BattleStyle.HOST if sel else BattleStyle.BAR_EDGE)
	draw_rect(r.grow(-2), BattleStyle.HOST if sel else BattleStyle.BUTTON_FILL)
	var f := font if font != null else BattleStyle.press_start()
	var text_color := BattleStyle.ON_HOST if sel else (BattleStyle.DISCONNECT_TEXT if danger else BattleStyle.TEXT_PRIMARY)
	if disabled:
		text_color = Color(BattleStyle.TEXT_MUTED, 0.6)
	var hint := shown_hint()
	if not hint.is_empty():
		var sk := BattleStyle.silkscreen()
		draw_string(sk, Vector2(0, (size.y + sk.get_ascent(11)) / 2.0 - 1), hint, HORIZONTAL_ALIGNMENT_RIGHT,
			size.x - 10, 11, BattleStyle.HINT_ON_HOST if sel else BattleStyle.TEXT_MUTED)
	var room := text_room()
	var lines := fit_lines(f, label_text, room, size_cap if size_cap > 0 else font_size)
	var s: int = lines[0]
	var gap := 6.0
	var block := (lines.size() - 2) * (s + gap) + f.get_ascent(s) - f.get_descent(s)
	var line_y := roundf((size.y - block) / 2.0 + f.get_ascent(s))
	if sel:
		draw_string(f, Vector2(10, line_y), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, s, text_color)
	for i in range(1, lines.size()):
		draw_string(f, Vector2(10 + CARET_W, line_y), lines[i], HORIZONTAL_ALIGNMENT_LEFT, room, s, text_color)
		line_y += s + gap


## Width left for the label. Room for the key hint is always kept, so switching controllers never changes the size.
func text_room() -> float:
	var hint_w := 0.0
	if not key_hint.is_empty() or not hint_action.is_empty():
		var longest := key_hint if hint_action.is_empty() else "[%s]" % InputPrompts.label(hint_action).to_upper()
		hint_w = BattleStyle.silkscreen().get_string_size(longest, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 10
	return size.x - 20 - CARET_W - hint_w


## One text size for a whole panel (the biggest every label fits at), so the buttons match.
static func share_size(buttons: Array[TermButton]) -> void:
	var shared := 0
	for b in buttons:
		var f := b.font if b.font != null else BattleStyle.press_start()
		var s: int = b.fit_lines(f, b.label_text, b.text_room(), b.font_size)[0]
		shared = s if shared == 0 else mini(shared, s)
	for b in buttons:
		b.size_cap = shared
		b.queue_redraw()


## [size, line, line...]: the label on one line at `wanted`, or split onto two lines at the space nearest the
## middle ("Special Delivery" in a desktop move button), whichever is bigger; shrinking only as a last resort.
func fit_lines(f: Font, label: String, room: float, wanted: int) -> Array:
	var one := BattleStyle.fit_size(f, label, room, wanted, 8)
	if f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, wanted).x <= room or not label.contains(" "):
		return [one, label]
	var best := label.find(" ")
	var at := best
	while at != -1:
		if absi(at - label.length() / 2) < absi(best - label.length() / 2):
			best = at
		at = label.find(" ", at + 1)
	var a := label.substr(0, best)
	var b := label.substr(best + 1)
	var two := BattleStyle.fit_size(f, a if a.length() >= b.length() else b, room, wanted, 8)
	if lines_fit(two, size.y):
		return [two, a, b] if two > one else [one, label]
	return [one, label]


static func lines_fit(s: int, height: float) -> bool:
	return s * 2 + 6 <= height - 12
