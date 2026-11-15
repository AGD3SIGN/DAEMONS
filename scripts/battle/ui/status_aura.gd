class_name StatusAura
extends Control
## A looping effect over a battling Daemon that shows its lasting status at a glance, from the front or the back
## (the back view has no status poses). Player report 2026-11-15: an Overheated Pingo only showed the OVH tag.
##   overheated: embers rising off it and a heat shimmer at its feet (orange)
##   throttled:  a loading spinner over its head (yellow)
##   infected:   glitch blocks flickering across it (purple)
##   standby:    z's drifting up
## Drawn in the sprite's own space: one "unit" is one pixel of the 64x64 Daemon art.

const COLORS := {
	"overheated": [Color("ff7a3d"), Color("ffd23f")],
	"throttled": [Color("f2c63a"), Color("fff4a0")],
	"infected": [Color("b070e0"), Color("ff40c0")],
	"standby": [Color("8fa8cf"), Color("f4f4ff")],
}

var status := "":
	set(value):
		if value != status:
			status = value
			_t = 0.0
			visible = COLORS.has(status)
			queue_redraw()
var speed := 1.0  # 0 = animations off: a still frame

var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta * speed
	queue_redraw()


func _draw() -> void:
	if not COLORS.has(status):
		return
	var u := size.x / 64.0
	var c: Array = COLORS[status]
	match status:
		"overheated":
			_embers(u, c)
		"throttled":
			_spinner(u, c)
		"infected":
			_glitch(u, c)
		"standby":
			_zs(u, c)


## A pixel block in art units.
func _px(x: float, y: float, w: float, h: float, color: Color, u: float) -> void:
	draw_rect(Rect2(Vector2(floorf(x), floorf(y)) * u, Vector2(w, h) * u), color)


func _embers(u: float, c: Array) -> void:
	for k in 12:  # flames licking up around its feet, flickering
		var x := 8.0 + k * 4.0
		var h := 4.0 + 3.0 * absf(sin(_t * 7.0 + k * 1.7)) + float(k % 3)
		var outer: Color = c[0]
		outer.a = 0.8
		_px(x, 60.0 - h, 3, h, outer, u)
		var inner: Color = c[1]
		inner.a = 0.9
		_px(x + 1, 61.0 - h * 0.5, 1, h * 0.5, inner, u)
	for i in 16:  # embers rising off it and past its head, fading as they go
		var phase := fmod(_t * 0.7 + i * 0.0625 + float(i % 5) * 0.13, 1.0)
		var x := 6.0 + fmod(i * 29.0, 52.0) + sin(_t * 3.0 + i) * 3.0
		var y := 56.0 - phase * 62.0
		var col: Color = c[1] if i % 3 == 0 else c[0]
		col.a = 1.0 - phase * phase
		var s := 3.0 if phase < 0.35 else 2.0
		_px(x, y, s, s, col, u)


func _spinner(u: float, c: Array) -> void:
	var center := Vector2(32, 4)
	for i in 8:  # eight dots around a ring; the bright one walks around (buffering...)
		var a := TAU * i / 8.0
		var p := center + Vector2(cos(a), sin(a)) * 7.0
		var lit := int(_t * 8.0) % 8
		var age := (lit - i + 8) % 8
		var col: Color = c[1] if age == 0 else c[0]
		col.a = 1.0 - age * 0.11
		_px(p.x - 1, p.y - 1, 3, 3, col, u)


func _glitch(u: float, c: Array) -> void:
	var tick := int(_t * 10.0)
	for i in 6:  # blocks jump to new spots ~10 times a second; positions are deterministic, not random
		var h := hash(Vector2i(tick, i))
		if h % 3 == 0:
			continue
		var x := 8.0 + float(h % 44)
		var y := 10.0 + float((h / 44) % 44)
		var w := 3.0 + float((h / 7) % 8)
		var col: Color = c[(h / 3) % 2]
		col.a = 0.75
		_px(x, y, w, 2, col, u)


func _zs(u: float, c: Array) -> void:
	for i in 3:
		var phase := fmod(_t * 0.4 + i / 3.0, 1.0)
		var x := 40.0 + phase * 10.0
		var y := 18.0 - phase * 14.0
		var col: Color = c[1]
		col.a = 1.0 - phase
		var s := 4.0 if i == 0 else 3.0
		# a tiny pixel "z": top bar, diagonal, bottom bar
		_px(x, y, s, 1, col, u)
		for k in int(s) - 1:
			_px(x + s - 2 - k, y + 1 + k, 1, 1, col, u)
		_px(x, y + s - 1, s, 1, col, u)
