class_name UiTheme
extends RefCounted
## Shared look for menus and battle UI: light "paper" panels with a dark border,
## 8px pixel font, flat text buttons (the cursor is drawn by CursorButton).

const INK := Color("282830")
const PAPER := Color("f4f4ec")
const BORDER := Color("384058")
const MUTED := Color("9898a8")

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = load("res://assets/fonts/PressStart2P-Regular.ttf")
	t.default_font_size = 8

	var panel := StyleBoxFlat.new()
	panel.bg_color = PAPER
	panel.border_color = BORDER
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(3)
	panel.set_content_margin_all(4)
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PanelContainer", panel)

	t.set_color("font_color", "Label", INK)

	var empty := StyleBoxEmpty.new()
	for style_name in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		t.set_stylebox(style_name, "Button", empty)
	for color_name in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(color_name, "Button", INK)
	t.set_color("font_disabled_color", "Button", MUTED)
	_theme = t
	return t
