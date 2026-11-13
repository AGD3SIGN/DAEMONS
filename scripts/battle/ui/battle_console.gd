class_name BattleConsole
extends TextBox
## The battle's terminal window (replaces the plain text box in battle): console body, 3 px host border,
## 6 px black drop shadow, a title bar ("daemon@field ~/encounter.log ... TTY1"), a "> " prompt, VT323 text,
## a blinking block cursor and a pixel continue-arrow. Typing, paging and "press to continue" all come
## from TextBox.
##
## Menu mode (the command menu is open): the console shrinks to the left part of the screen, line 1 uses
## a slightly smaller font and line 2 is a "man <command> — <description>" hint.

const TITLE_H := 26
const BORDER := 3
const TEXT_SIZE := 46
const MENU_TEXT_SIZE := 42
const MAN_SIZE := 26
const CURSOR := Vector2(18, 36)
const ARROW := Vector2(22, 14)
const PROMPT_W := 30.0

var full_width := 928.0
var menu_width := 496.0
var menu_mode := false
var man_command := ""
var man_text := ""
var _t := 0.0


func _ready() -> void:
	super._ready()
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_arrow.self_modulate = Color.TRANSPARENT  # drawn in _draw instead
	max_lines = 2
	var vt := BattleStyle.vt323()
	_label.add_theme_font_override("font", vt)
	_label.add_theme_color_override("font_color", BattleStyle.TEXT_CONSOLE)
	_label.add_theme_constant_override("line_spacing", -8)
	_apply_mode()


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	queue_redraw()


## TextBox calls this with 0 before every message and the battle calls it with a width when the command
## menu opens; here it just switches between full width and menu mode.
func set_reserved_right(px: int) -> void:
	set_menu_mode(px > 0)


func set_menu_mode(on: bool) -> void:
	menu_mode = on
	if not on:
		man_command = ""
		man_text = ""
	_apply_mode()


func set_man(command: String, text: String) -> void:
	man_command = command
	man_text = text
	queue_redraw()


func _apply_mode() -> void:
	if _label == null:
		return
	size.x = menu_width if menu_mode else full_width
	_label.add_theme_font_size_override("font_size", MENU_TEXT_SIZE if menu_mode else TEXT_SIZE)
	_label.offset_left = BORDER + 14 + PROMPT_W
	_label.offset_top = BORDER + TITLE_H + 6
	_label.offset_right = -(BORDER + 14 + CURSOR.x + 8)
	_label.offset_bottom = -(BORDER + 6)
	queue_redraw()


func text_size() -> int:
	return MENU_TEXT_SIZE if menu_mode else TEXT_SIZE


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	BattleStyle.draw_panel(self, r, BattleStyle.CONSOLE, BattleStyle.HOST, BORDER)
	# Title bar.
	var bar := Rect2(BORDER, BORDER, size.x - BORDER * 2, TITLE_H)
	draw_rect(bar, BattleStyle.CONSOLE_HEADER)
	draw_rect(Rect2(bar.position.x, bar.end.y - 2, bar.size.x, 2), BattleStyle.TITLE_RULE)
	var sk := BattleStyle.silkscreen()
	var base := bar.position.y + (TITLE_H + sk.get_ascent(11)) / 2.0 - 1
	draw_string(sk, Vector2(bar.position.x + 10, base), "daemon@field", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, BattleStyle.HOST)
	var user_w := sk.get_string_size("daemon@field", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(sk, Vector2(bar.position.x + 10 + user_w + 8, base), "~/encounter.log", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		BattleStyle.TEXT_MUTED)
	draw_string(sk, Vector2(bar.position.x, base), "TTY1", HORIZONTAL_ALIGNMENT_RIGHT, bar.size.x - 10, 11,
		BattleStyle.TEXT_MUTED)
	# Prompt.
	var vt := BattleStyle.vt323()
	var line_top := _label.offset_top
	draw_string(vt, Vector2(BORDER + 14, line_top + vt.get_ascent(text_size())), ">", HORIZONTAL_ALIGNMENT_LEFT, -1,
		text_size(), BattleStyle.HOST)
	# Blinking block cursor after the text once it's done typing (1 s, 50% duty).
	if not _typing and fmod(_t, 1.0) < 0.5:
		var at := cursor_position()
		draw_rect(Rect2(at, CURSOR), BattleStyle.TEXT_CONSOLE)
	# man line (menu mode only).
	if menu_mode and not man_command.is_empty():
		var y := line_top + text_size() + 12 + vt.get_ascent(MAN_SIZE)
		var cmd := "man " + man_command
		draw_string(vt, Vector2(BORDER + 14, y), cmd, HORIZONTAL_ALIGNMENT_LEFT, -1, MAN_SIZE, BattleStyle.HOST)
		var cmd_w := vt.get_string_size(cmd + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, MAN_SIZE).x
		draw_string(vt, Vector2(BORDER + 14 + cmd_w, y), "— " + man_text, HORIZONTAL_ALIGNMENT_LEFT,
			size.x - BORDER * 2 - 28 - cmd_w, MAN_SIZE, BattleStyle.TEXT_MUTED)
	# Continue arrow: drops 4 px and back, stepped (1 s, 2 steps).
	if _waiting:
		var drop := 4.0 if fmod(_t, 1.0) >= 0.5 else 0.0
		var origin := Vector2(size.x - 22 - ARROW.x, size.y - 16 - ARROW.y + drop)
		for i in 6:
			var w := ARROW.x - i * 4
			draw_rect(Rect2(origin + Vector2((ARROW.x - w) / 2.0, i * 2 + 1), Vector2(w, 2)), BattleStyle.HOST)


## Where the block cursor goes: just after the last visible character (or at the line start).
func cursor_position() -> Vector2:
	var start := Vector2(_label.offset_left, _label.offset_top + 4)
	var count := _label.get_total_character_count() if _label.visible_characters < 0 else _label.visible_characters
	if count <= 0 or _label.text.is_empty():
		return start
	var bounds: Rect2 = _label.get_character_bounds(count - 1)
	if bounds.size == Vector2.ZERO:
		return start
	return Vector2(_label.position.x + bounds.end.x + 4, _label.position.y + bounds.position.y + 4)
