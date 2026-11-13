class_name BattleStyle
extends RefCounted
## Tokens, fonts and drawing helpers for the "Server Floor" battle scene
## (Brandon's "Daemon — Battle Scene Implementation Spec", 2026-11-13).
## Every coordinate in the battle UI is in the 960x640 design frame (BattleScene.FRAME).

const FRAME := Vector2(960, 640)

# --- fixed UI tokens (all zones) ---
const HOST := Color("3ee6ff")          # player side: pad, console border, prompt, selected command
const WILD := Color("ff7a3d")          # wild side: pad, wild card border, WILD/UNVERIFIED tags
const PANEL := Color("0c1626")         # status cards, zone tag, command panel background
const CONSOLE := Color("050a12")       # terminal body, UP bar track
const CONSOLE_HEADER := Color("0b1424")
const TEXT_PRIMARY := Color("e8f1ff")  # levels, numbers
const TEXT_CONSOLE := Color("d9fbe6")  # terminal text, cursor block
const TEXT_MUTED := Color("8fa8cf")    # title bar text, man line, key hints
const LABEL := Color("9fb4d6")         # "UP" label
const BAR_EDGE := Color("2a3a58")      # UP bar border, unselected button border, empty signal bar
const SEG_EMPTY := Color("16223a")
const UP_HIGH := Color("3dff9a")
const UP_MID := Color("ffc43d")
const UP_LOW := Color("ff4d4d")
const SHADOW := Color.BLACK
const SHADOW_OFFSET := 6
const BUTTON_FILL := Color("08111f")
const DISCONNECT_TEXT := Color("ff9a6b")
const ON_HOST := Color("031318")       # text on a host-colored fill
const ON_WILD := Color("1a0800")       # text on a wild-colored fill
const HINT_ON_HOST := Color("0b3a44")
const TITLE_RULE := Color("1c2a44")
const EXP := Color("4080e0")           # our addition: the player's EXP strip

## Zone palettes: only the arena changes color by area; the UI tokens above stay the same.
const ZONES := {
	"server_floor": {"name": "SERVER FLOOR", "bg": "0a1120", "rack": "111c31", "rack_edge": "22344f",
		"unit": "0d1729", "floor": "070e1a", "grid": "1f5b78", "trim": "3ee6ff",
		"leds": ["3dff9a", "3dff9a", "3ee6ff", "ffc43d"]},
	"coolant_loop": {"name": "COOLANT LOOP", "bg": "05181b", "rack": "0b2428", "rack_edge": "1b4a4f",
		"unit": "082024", "floor": "041214", "grid": "1f7f78", "trim": "7dfff0",
		"leds": ["7dfff0", "7dfff0", "b9f6ff", "3dff9a"]},
	"overheat": {"name": "OVERHEAT", "bg": "170909", "rack": "261111", "rack_edge": "4a2020",
		"unit": "1e0d0d", "floor": "120606", "grid": "7a2e1c", "trim": "ffb03d",
		"leds": ["ff5a3d", "ffb03d", "ff5a3d", "ffe07d"]},
}
const DEFAULT_ZONE := "server_floor"

static var _pixelify: Dictionary = {}  # weight -> FontVariation
static var _silkscreen: Font
static var _vt323: Font


## Pixelify Sans (Daemon names, levels, command labels). weight 500 or 700.
static func pixelify(weight: int = 700) -> Font:
	if not _pixelify.has(weight):
		var v := FontVariation.new()
		v.base_font = load("res://assets/fonts/PixelifySans-Variable.ttf")
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_pixelify[weight] = v
	return _pixelify[weight]


## Silkscreen (small-caps labels: tags, the UP label, title bars, zone tag, key hints).
static func silkscreen() -> Font:
	if _silkscreen == null:
		_silkscreen = load("res://assets/fonts/Silkscreen-Regular.ttf")
	return _silkscreen


## VT323 (terminal text, the > prompt, HP numbers, percentages).
static func vt323() -> Font:
	if _vt323 == null:
		_vt323 = load("res://assets/fonts/VT323-Regular.ttf")
	return _vt323


static func zone(id: String) -> Dictionary:
	var z: Dictionary = ZONES.get(id, ZONES[DEFAULT_ZONE])
	return z


static func zone_color(id: String, key: String) -> Color:
	return Color(String(zone(id)[key]))


## UP bar color for a fraction 0..1: green above 50%, amber 21-50%, red 20% and below.
static func up_color(fraction: float) -> Color:
	var pct := fraction * 100.0
	if pct > 50.0:
		return UP_HIGH
	if pct > 20.0:
		return UP_MID
	return UP_LOW


## Filled segments out of 20: round(UP% / 5), clamped 0..20.
static func segments(fraction: float) -> int:
	return clampi(roundi(clampf(fraction, 0.0, 1.0) * 100.0 / 5.0), 0, 20)


## A hard-edged panel: solid black drop shadow (offset 6, no blur), fill, and a border.
static func draw_panel(ci: CanvasItem, rect: Rect2, fill: Color, border: Color, border_width: int = 3,
		shadow: bool = true) -> void:
	if shadow:
		ci.draw_rect(Rect2(rect.position + Vector2(SHADOW_OFFSET, SHADOW_OFFSET), rect.size), SHADOW)
	ci.draw_rect(rect, border)
	ci.draw_rect(rect.grow(-border_width), fill)


## An outline-only rectangle `width` px thick, drawn inside `rect`.
static func draw_frame(ci: CanvasItem, rect: Rect2, color: Color, width: int) -> void:
	ci.draw_rect(Rect2(rect.position, Vector2(rect.size.x, width)), color)
	ci.draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - width), Vector2(rect.size.x, width)), color)
	ci.draw_rect(Rect2(rect.position, Vector2(width, rect.size.y)), color)
	ci.draw_rect(Rect2(rect.position + Vector2(rect.size.x - width, 0), Vector2(width, rect.size.y)), color)


## A small tag (WILD / HOST / UNVERIFIED / status). filled = solid side color with dark text; otherwise
## a 2 px outline with side-colored text. Returns the tag's width.
static func draw_tag(ci: CanvasItem, at: Vector2, text: String, color: Color, filled: bool,
		text_on_fill: Color, font_size: int = 12) -> float:
	var font := silkscreen()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 12
	var h := font_size + 8
	var r := Rect2(at, Vector2(w, h))
	if filled:
		ci.draw_rect(r, color)
	else:
		draw_frame(ci, r, color, 2)
	ci.draw_string(font, at + Vector2(6, h - 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		text_on_fill if filled else color)
	return w


## The 20-segment UP bar: console track, 2 px barEdge border, 3 px padding, 2 px gaps.
static func draw_up_bar(ci: CanvasItem, rect: Rect2, fraction: float, segment_height: int) -> void:
	ci.draw_rect(rect, BAR_EDGE)
	ci.draw_rect(rect.grow(-2), CONSOLE)
	var inner := rect.grow(-5)
	var gap := 2.0
	var seg_w := (inner.size.x - gap * 19) / 20.0
	var filled := segments(fraction)
	var color := up_color(fraction)
	var y := inner.position.y + (inner.size.y - segment_height) / 2.0
	for i in 20:
		var x0 := roundf(inner.position.x + i * (seg_w + gap))
		var x1 := roundf(inner.position.x + i * (seg_w + gap) + seg_w)
		ci.draw_rect(Rect2(x0, y, x1 - x0, segment_height), color if i < filled else SEG_EMPTY)
