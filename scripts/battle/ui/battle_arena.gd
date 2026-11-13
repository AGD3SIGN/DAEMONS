class_name BattleArena
extends Control
## The "Server Floor" battle arena, drawn in code from the zone palette (no art): back wall, a row of
## server racks with status LEDs, a glowing raised-floor grid, the horizon trim, the two socket pads
## and the zone tag. Coordinates are in the 960x640 design frame; on wider or taller screens the wall,
## racks and floor keep going past the frame (`view_rect`) instead of letterboxing.

const HORIZON := 300.0
const TRIM_Y := 298.0
const RACK_BOTTOM := 302.0
const RACK_W := 92.0
const RACK_GAP := 14.0
const RACK_X0 := 10.0
const RACK_HEIGHTS := [232, 244, 220, 244, 236, 244, 224, 244, 232]
const LED_LOOP := 2.6
const LED_FLICKER := 0.14        # seconds at 15% per loop
const GRID_STEP := 96.0
const GRID_DEPTH := 260.0        # perspective strength of the floor plane
const FADE := 70.0
const WILD_PAD := Rect2(590, 318, 290, 64)
const HOST_PAD := Rect2(40, 420, 400, 92)
const WILD_INSET := Vector2(26, 10)
const HOST_INSET := Vector2(38, 14)
const PAD_PULSE := 2.0
const ZONE_TAG_TEXT := Color("cfe3ff")

var zone_id := BattleStyle.DEFAULT_ZONE:
	set(value):
		zone_id = value if BattleStyle.ZONES.has(value) else BattleStyle.DEFAULT_ZONE
		queue_redraw()
## Visible area in frame coordinates (set by BattleScene on resize).
var view_rect := Rect2(Vector2.ZERO, BattleStyle.FRAME):
	set(value):
		view_rect = value
		queue_redraw()
var show_unknown_host := true:
	set(value):
		show_unknown_host = value
		queue_redraw()
var animate := true
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if animate and not Settings.wants_reduced_motion():
		_time += delta
		queue_redraw()


func z(key: String) -> Color:
	return BattleStyle.zone_color(zone_id, key)


func _draw() -> void:
	var v := view_rect
	draw_rect(v, z("bg"))
	_draw_racks(v)
	_draw_floor(v)
	_draw_trim(v)
	_draw_pad(WILD_PAD, BattleStyle.WILD, WILD_INSET)
	_draw_pad(HOST_PAD, BattleStyle.HOST, HOST_INSET)
	if show_unknown_host:
		draw_string(BattleStyle.silkscreen(), Vector2(WILD_PAD.position.x, 388 + 14), "UNKNOWN HOST",
			HORIZONTAL_ALIGNMENT_CENTER, WILD_PAD.size.x, 12, Color(BattleStyle.WILD, 0.85))
	_draw_zone_tag()


# --- racks -------------------------------------------------------------------

## Rack i sits at x = 10 + i * 106; indices outside 0..8 repeat the pattern past the frame.
func rack_rect(i: int) -> Rect2:
	var h := float(RACK_HEIGHTS[posmod(i, RACK_HEIGHTS.size())])
	return Rect2(RACK_X0 + i * (RACK_W + RACK_GAP), RACK_BOTTOM - h, RACK_W, h)


static func slot_count(height: float) -> int:
	return floori((height - 20.0) / 20.0)


## The two LED colors of a rack slot (LED 2 can be off).
func led_colors(rack: int, slot: int) -> Array[Color]:
	var leds: Array = BattleStyle.zone(zone_id)["leds"]
	var k := posmod(rack * 7 + slot * 3, 11)
	var led1 := Color(String(leds[k % 4]))
	var led2 := BattleStyle.BAR_EDGE if k % 3 == 0 else Color(String(leds[(k + 1) % 4]))
	return [led1, led2]


func _draw_racks(v: Rect2) -> void:
	var step := RACK_W + RACK_GAP
	var first := floori((v.position.x - RACK_X0) / step) - 1
	var last := ceili((v.end.x - RACK_X0) / step) + 1
	var edge := z("rack_edge")
	for i in range(first, last + 1):
		var r := rack_rect(i)
		draw_rect(r, edge)
		draw_rect(Rect2(r.position.x + 2, r.position.y + 2, r.size.x - 4, r.size.y - 2), z("rack"))
		var inner_x := r.position.x + 7
		var inner_w := r.size.x - 14
		draw_rect(Rect2(inner_x, r.position.y + 8, inner_w, 6), edge)  # cap bar
		var y := r.position.y + 8 + 6 + 6
		for s in slot_count(r.size.y):
			var slot := Rect2(inner_x, y, inner_w, 14)
			draw_rect(slot, edge)
			draw_rect(slot.grow(-1), z("unit"))
			var colors := led_colors(i, s)
			var k := posmod(i * 7 + s * 3, 11)
			draw_rect(Rect2(inner_x + 4, y + 5, 4, 4), _flicker(colors[0], fmod(k * 0.37, LED_LOOP)))
			draw_rect(Rect2(inner_x + 11, y + 5, 4, 4), _flicker(colors[1], fmod(k * 0.61 + 0.4, LED_LOOP)))
			draw_rect(Rect2(inner_x + 19, y + 6, inner_w - 23, 2), edge)  # vent line
			y += 14 + 6


## LEDs drop to 15% for a brief stepped flicker once per 2.6 s loop, offset per LED.
func _flicker(color: Color, offset: float) -> Color:
	if fmod(_time + offset, LED_LOOP) < LED_FLICKER and _time > 0.0:
		return Color(color, 0.15)
	return color


# --- floor -------------------------------------------------------------------

## Screen y of a floor line at plane depth `depth` (0 = the frame's bottom edge).
static func floor_y(depth: float) -> float:
	return HORIZON + (BattleStyle.FRAME.y - HORIZON) * GRID_DEPTH / (GRID_DEPTH + depth)


static func floor_depth(y: float) -> float:
	return GRID_DEPTH * (BattleStyle.FRAME.y - HORIZON) / maxf(0.5, y - HORIZON) - GRID_DEPTH


func _draw_floor(v: Rect2) -> void:
	var bottom := maxf(v.end.y, BattleStyle.FRAME.y)
	draw_rect(Rect2(v.position.x, HORIZON, v.size.x, bottom - HORIZON + 1), z("floor"))
	var grid := z("grid")
	var cx := BattleStyle.FRAME.x / 2.0
	# Lines across: every 96 px of plane depth, from the bottom of the view back to the horizon.
	var depth := floorf(floor_depth(bottom) / GRID_STEP) * GRID_STEP
	while true:
		var y := floor_y(depth)
		if y - HORIZON < 3.0:
			break
		if y <= bottom:
			draw_rect(Rect2(v.position.x, roundf(y) - 1, v.size.x, 3), grid)
		depth += GRID_STEP
	# Lines toward the vanishing point (centered on the horizon), one per 96 px of plane width.
	var near := floor_depth(bottom)
	var scale_near := GRID_DEPTH / (GRID_DEPTH + near)
	var half := maxf(cx - v.position.x, v.end.x - cx) / scale_near + GRID_STEP
	var n := ceili(half / GRID_STEP)
	for j in range(-n, n + 1):
		var x_plane := j * GRID_STEP
		var a := Vector2(cx + x_plane * scale_near, bottom)
		var b := Vector2(cx + x_plane * GRID_DEPTH / (GRID_DEPTH + 40000.0), floor_y(40000.0))
		draw_line(a, b, grid, 3.0)
	# The top 70 px fade from floor color to transparent so the grid dissolves into the horizon.
	var f := z("floor")
	var clear := Color(f, 0.0)
	draw_polygon(PackedVector2Array([Vector2(v.position.x, HORIZON), Vector2(v.end.x, HORIZON),
		Vector2(v.end.x, HORIZON + FADE), Vector2(v.position.x, HORIZON + FADE)]),
		PackedColorArray([f, f, clear, clear]))


func _draw_trim(v: Rect2) -> void:
	var trim := z("trim")
	# 18 px glow above and below, fading out, then the 4 px line itself.
	for i in 9:
		var a := 0.22 * (1.0 - i / 9.0)
		draw_rect(Rect2(v.position.x, TRIM_Y - 2 - i * 2, v.size.x, 2), Color(trim, a))
		draw_rect(Rect2(v.position.x, TRIM_Y + 4 + i * 2, v.size.x, 2), Color(trim, a))
	draw_rect(Rect2(v.position.x, TRIM_Y, v.size.x, 4), trim)


# --- pads --------------------------------------------------------------------

static func ellipse(rect: Rect2, points: int = 64) -> PackedVector2Array:
	var out := PackedVector2Array()
	var c := rect.get_center()
	var r := rect.size / 2.0
	for i in points:
		var t := TAU * i / points
		out.append(c + Vector2(cos(t) * r.x, sin(t) * r.y))
	return out


func pad_ring_alpha() -> float:
	if _time <= 0.0:
		return 1.0
	var p := 0.5 - 0.5 * cos(TAU * _time / PAD_PULSE)  # ease in-out 0 -> 1 -> 0
	return lerpf(0.55, 1.0, p)


func _draw_pad(rect: Rect2, color: Color, inset: Vector2) -> void:
	# Outer glow, about 30 px.
	for i in range(6, 0, -1):
		var g := rect.grow_individual(i * 5, i * 2.5, i * 5, i * 2.5)
		draw_colored_polygon(ellipse(g), Color(color, 0.07))
	draw_colored_polygon(ellipse(rect), Color(color, 0.11))
	var outline := ellipse(rect)
	outline.append(outline[0])
	draw_polyline(outline, color, 3.0)
	# Dashed inner ring, pulsing.
	var inner := ellipse(rect.grow_individual(-inset.x, -inset.y, -inset.x, -inset.y), 48)
	var ring := Color(color, pad_ring_alpha())
	for i in range(0, inner.size(), 2):
		draw_line(inner[i], inner[(i + 1) % inner.size()], ring, 2.0)


# --- zone tag ----------------------------------------------------------------

func zone_tag_rect() -> Rect2:
	var font := BattleStyle.silkscreen()
	var text := "ZONE // " + String(BattleStyle.zone(zone_id)["name"])
	var w := 12 + font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 10 + 22 + 12
	var h := 6 + 16 + 6
	return Rect2(BattleStyle.FRAME.x - 28 - w, 28, w, h)


func _draw_zone_tag() -> void:
	var r := zone_tag_rect()
	var trim := z("trim")
	BattleStyle.draw_panel(self, r, BattleStyle.PANEL, trim, 2, false)
	var text := "ZONE // " + String(BattleStyle.zone(zone_id)["name"])
	draw_string(BattleStyle.silkscreen(), r.position + Vector2(12, 6 + 13), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		ZONE_TAG_TEXT)
	var x := r.end.x - 12 - 22
	var heights := [5, 8, 11, 14]
	for i in 4:
		var h: float = heights[i]
		draw_rect(Rect2(x + i * 6, r.position.y + 6 + 16 - h, 4, h), trim if i < 3 else BattleStyle.BAR_EDGE)
