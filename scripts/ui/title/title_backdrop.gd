class_name TitleBackdrop
extends Node2D
## Title layers 2-4: circuit traces with traveling pulses, floating bits, and the scrolling
## perspective grid floor. Drawn in the 1280x720 frame; `view` is the visible area (wider or
## taller screens see more floor instead of bars).

const S := preload("res://scripts/ui/title/title_style.gd")

var time := 0.0          # always running
var motion := 0.0        # stops when reduced motion is on
var accent := S.ACCENT_DEFAULT
var view := Rect2(Vector2.ZERO, S.FRAME)
var body_font: Font

var _traces: Array[PackedVector2Array] = []
var _lengths: PackedFloat32Array = []


func _ready() -> void:
	for d: String in S.TRACES:
		var pts := S.parse_path(d)
		_traces.append(pts)
		var total := 0.0
		for i in range(1, pts.size()):
			total += pts[i - 1].distance_to(pts[i])
		_lengths.append(total)


func _draw() -> void:
	_draw_floor()
	_draw_traces()
	_draw_bits()


# --- circuit traces ----------------------------------------------------------

func _draw_traces() -> void:
	var idle := Color(S.TRACE_IDLE, S.TRACE_ALPHA)
	var lit := Color(accent, S.TRACE_ALPHA)
	for i in _traces.size():
		var pts := _traces[i]
		draw_polyline(pts, idle, 2.0)
		draw_circle(pts[pts.size() - 1], S.TRACE_PAD_R, idle)
		# Every other trace runs on the slower set (5.2 s, shorter dash, started 2 s early).
		var slow := i % 2 == 1
		var period := S.T_TRACE_B if slow else S.T_TRACE_A
		var dash := 18.0 if slow else 28.0
		var t := motion - (S.T_TRACE_B_START if slow else 0.0)
		var head := fposmod(t / period, 1.0) * 520.0
		_draw_dash(pts, head, head + dash, lit)


## Draws the part of a polyline between distances a and b with 3 px round caps.
func _draw_dash(pts: PackedVector2Array, a: float, b: float, color: Color) -> void:
	var walked := 0.0
	var seg := PackedVector2Array()
	for i in range(1, pts.size()):
		var p := pts[i - 1]
		var q := pts[i]
		var l := p.distance_to(q)
		var s0 := clampf(a - walked, 0.0, l)
		var s1 := clampf(b - walked, 0.0, l)
		if s1 > s0:
			var from := p.lerp(q, s0 / l)
			var to := p.lerp(q, s1 / l)
			if seg.is_empty():
				seg.append(from)
			seg.append(to)
		walked += l
	if seg.size() >= 2:
		draw_polyline(seg, color, 3.0)
		draw_circle(seg[0], 1.5, color)
		draw_circle(seg[seg.size() - 1], 1.5, color)


# --- floating bits -----------------------------------------------------------

func _draw_bits() -> void:
	if body_font == null:
		return
	for i in S.BIT_COUNT:
		var dur := 9.0 + 7.0 * S.hash01(i, 1.0)
		var p := fposmod(motion / dur + S.hash01(i, 2.0), 1.0)
		var alpha := 0.0
		if p < 0.1:
			alpha = 0.7 * p / 0.1
		elif p < 0.9:
			alpha = lerpf(0.7, 0.5, (p - 0.1) / 0.8)
		else:
			alpha = 0.5 * (1.0 - p) / 0.1
		var size: int = S.BIT_SIZES[i % S.BIT_SIZES.size()]
		var color: Color = S.LIME if i % 3 == 2 else accent
		var glyph := S.BIT_GLYPHS[int(S.hash01(i, 3.0) * S.BIT_GLYPHS.length())]
		var x := S.hash01(i, 4.0) * (S.FRAME.x - 40.0) + 20.0
		var y := 740.0 - 760.0 * p
		draw_string(body_font, Vector2(x, y), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color, 0.6 * alpha))


# --- grid floor --------------------------------------------------------------

## A point on the floor plane (u across from the center, v down the plane from its top edge)
## projected like CSS perspective(360px) rotateX(62deg) with the origin at the top center.
func project(u: float, v: float) -> Vector2:
	var tilt := deg_to_rad(S.FLOOR_TILT_DEG)
	var z := v * sin(tilt)
	var k := S.FLOOR_PERSPECTIVE / maxf(S.FLOOR_PERSPECTIVE - z, 1.0)
	return Vector2(S.FRAME.x / 2.0 + u * k, S.FLOOR_TOP + v * cos(tilt) * k)


## Plane depth that projects to screen y (inverse of project's y).
func depth_at(y: float) -> float:
	var tilt := deg_to_rad(S.FLOOR_TILT_DEG)
	var dy := y - S.FLOOR_TOP
	return dy * S.FLOOR_PERSPECTIVE / (cos(tilt) * S.FLOOR_PERSPECTIVE + dy * sin(tilt))


func _draw_floor() -> void:
	var tilt := deg_to_rad(S.FLOOR_TILT_DEG)
	var v_max := minf(S.FLOOR_DEPTH, depth_at(view.end.y + 8.0))
	var fade_v := S.FLOOR_DEPTH * S.FLOOR_FADE
	# Plane width: the guide's 1920 px, widened so wide screens still see floor to their edges.
	var half_w := maxf(S.FLOOR_WIDTH / 2.0, maxf(S.FRAME.x / 2.0 - view.position.x, view.end.x - S.FRAME.x / 2.0) + S.FLOOR_CELL)
	# Horizontal lines scroll toward the viewer, one cell per 1.4 s.
	var offset := fposmod(motion / S.T_FLOOR, 1.0) * S.FLOOR_CELL
	var v := offset
	while v <= v_max:
		var a := project(-half_w, v)
		var b := project(half_w, v)
		var k := S.FLOOR_PERSPECTIVE / (S.FLOOR_PERSPECTIVE - v * sin(tilt))
		draw_line(a, b, S.FLOOR_LINE_H, maxf(2.0 * k * cos(tilt), 1.0))
		v += S.FLOOR_CELL
	# Vertical lines run from the horizon to the bottom, getting wider as they come closer.
	var cols := ceili(half_w / S.FLOOR_CELL)
	for j in range(-cols, cols + 1):
		var u := j * S.FLOOR_CELL
		var steps := 6
		for s in steps:
			var v0 := v_max * s / steps
			var v1 := v_max * (s + 1) / steps
			var p0 := project(u, v0)
			var p1 := project(u, v1)
			var k0 := p0.distance_to(project(u + 2.0, v0))
			var k1 := p1.distance_to(project(u + 2.0, v1))
			var quad := PackedVector2Array([p0 - Vector2(k0 / 2, 0), p0 + Vector2(k0 / 2, 0), p1 + Vector2(k1 / 2, 0), p1 - Vector2(k1 / 2, 0)])
			draw_colored_polygon(quad, S.FLOOR_LINE_V)
	# The top 45% of the plane (lines included) fades into the background.
	var y_fade := project(0, fade_v).y
	draw_polygon(PackedVector2Array([Vector2(view.position.x, S.FLOOR_TOP), Vector2(view.end.x, S.FLOOR_TOP),
		Vector2(view.end.x, y_fade), Vector2(view.position.x, y_fade)]),
		PackedColorArray([S.BG_VOID, S.BG_VOID, Color(S.BG_VOID, 0.0), Color(S.BG_VOID, 0.0)]))
