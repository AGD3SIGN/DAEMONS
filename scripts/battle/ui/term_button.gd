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
var font_size := 22


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
	var f := font if font != null else BattleStyle.pixelify(700)
	var text_color := BattleStyle.ON_HOST if sel else (BattleStyle.DISCONNECT_TEXT if danger else BattleStyle.TEXT_PRIMARY)
	if disabled:
		text_color = Color(BattleStyle.TEXT_MUTED, 0.6)
	var base := (size.y + f.get_ascent(font_size) - f.get_descent(font_size)) / 2.0
	if sel:
		draw_string(f, Vector2(10, base), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
	var hint_w := 0.0
	var hint := shown_hint()
	if not hint.is_empty():
		var sk := BattleStyle.silkscreen()
		hint_w = sk.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 10
		draw_string(sk, Vector2(0, (size.y + sk.get_ascent(11)) / 2.0 - 1), hint, HORIZONTAL_ALIGNMENT_RIGHT,
			size.x - 10, 11, BattleStyle.HINT_ON_HOST if sel else BattleStyle.TEXT_MUTED)
	draw_string(f, Vector2(10 + CARET_W, base), label_text, HORIZONTAL_ALIGNMENT_LEFT,
		size.x - 20 - CARET_W - hint_w, font_size, text_color)
