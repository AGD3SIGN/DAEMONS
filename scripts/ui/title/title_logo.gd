class_name TitleLogo
extends Node2D
## One line of display text with an optional drop shadow and soft glow, used for the "DAEMONS"
## logo and its two glitch copies. `band` (0-1 of the line height) clips it to a horizontal slice
## during glitch frames.

var text := ""
var font: Font
var font_size := 16
var line_height := 16.0
var color := Color.WHITE
var shadow_color := Color.TRANSPARENT
var shadow_drop := 0.0
var glow_color := Color.TRANSPARENT
var glow_radius := 0.0
var band := Vector2(0, 1):
	set(value):
		band = value
		_apply_clip()


func width() -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if font else 0.0


func _ready() -> void:
	_apply_clip()


func _apply_clip() -> void:
	if not is_inside_tree():
		return
	var rid := get_canvas_item()
	var whole := band == Vector2(0, 1)
	var pad := glow_radius + 16.0
	var rect := Rect2(-pad, line_height * band.x, width() + pad * 2.0, line_height * (band.y - band.x))
	if whole:
		rect = Rect2(-pad, -pad, width() + pad * 2.0, line_height + pad * 2.0)
	RenderingServer.canvas_item_set_custom_rect(rid, true, rect)
	RenderingServer.canvas_item_set_clip(rid, not whole)
	queue_redraw()


func baseline() -> float:
	var asc := font.get_ascent(font_size)
	var desc := font.get_descent(font_size)
	return (line_height - (asc + desc)) / 2.0 + asc


func _draw() -> void:
	if font == null or text.is_empty():
		return
	var at := Vector2(0, baseline())
	if glow_color.a > 0.0 and glow_radius > 0.0:
		TitleLogo.glow_text(self, font, at, text, font_size, glow_color, glow_radius)
	if shadow_color.a > 0.0:
		draw_string(font, at + Vector2(0, shadow_drop), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow_color)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## CSS text-shadow "0 0 <radius> <color>" approximated by stamping the text around itself.
static func glow_text(ci: CanvasItem, f: Font, at: Vector2, s: String, size: int, glow: Color, radius: float) -> void:
	for ring in 3:
		var r := radius * (ring + 1) / 3.0
		var a := glow.a * 0.13 * (1.0 - ring * 0.28)
		for i in 8:
			var off := Vector2.from_angle(TAU * i / 8.0 + ring * 0.39) * r
			ci.draw_string(f, at + off, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(glow, a))
