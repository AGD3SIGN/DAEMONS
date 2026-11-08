class_name BattleFx
extends Control
## Move effects on the battle screen, played between "X ran Y!" and the hit. Each move lists its
## effect in data/moves.json as "fx": a list of steps built from the small pixel-art pieces below,
## played one after another (a step with "parallel": true starts the next one right away).
##
## Step keys (all optional except kind):
##   kind      one of KINDS
##   color     "#rrggbb" or "type" (the move's type color, the default)
##   on        "user" or "target" (default "target") for effects that happen at one spot
##   count, size, radius, width, turns, alpha, spread, glyph, travel, reverse: per kind, see below
##   parallel  true = don't wait for this step before starting the next
##
## Everything is drawn as hard-edged pixel squares (no smoothing), in the 320x180 game view.

const KINDS: PackedStringArray = [
	"burst", "stream", "rings", "beam", "bolt", "rise", "fall", "orbit", "glitch",
	"flash", "dim", "cover", "shield", "wall", "xmark", "slices",
]
const GLYPHS: PackedStringArray = [
	"square", "dot", "plus", "arrow_up", "arrow_down", "z", "key", "envelope", "cell", "code",
	"wave", "hook", "drop",
]

## Tiny bitmaps (rows top to bottom; # = filled, o = second color, . = empty).
const BITMAPS := {
	"dot": ["##", "##"],
	"plus": [".#.", "###", ".#."],
	"arrow_up": ["..#..", ".###.", "#####", "..#..", "..#.."],
	"arrow_down": ["..#..", "..#..", "#####", ".###.", "..#.."],
	"z": ["####", "..#.", ".#..", "####"],
	"key": ["#####", "#ooo#", "#ooo#", "#####"],
	"envelope": ["#######", "##ooo##", "#o#o#o#", "#oo#oo#", "#######"],
	"cell": ["####", "#oo#", "####"],
	"code": ["#....", ".#...", "#..##"],
	"wave": [".#..", "#...", ".#..", "..#.", ".#.."],
	"hook": [".##.", "...#", "...#", "#..#", ".##."],
	"drop": [".#.", "###", "###", ".#."],
}

var time_scale := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Plays a move's fx steps from user to target (positions in this layer's space).
func play(steps: Array, user: Vector2, target: Vector2, type_color: Color) -> void:
	if time_scale <= 0.0 or steps.is_empty():
		return
	for step: Dictionary in steps:
		if step.get("parallel", false):
			_play_step(step, user, target, type_color)
		else:
			await _play_step(step, user, target, type_color)


## Each step draws into its own box and frees only that box, so parallel steps don't clear each other.
func _play_step(s: Dictionary, user: Vector2, target: Vector2, type_color: Color) -> void:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(box)
	await _run_step(box, s, user, target, type_color)
	if is_instance_valid(box):
		box.queue_free()


func _run_step(box: Control, s: Dictionary, user: Vector2, target: Vector2, type_color: Color) -> void:
	var color := _color(s.get("color", "type"), type_color)
	var at := user if s.get("on", "target") == "user" else target
	match String(s["kind"]):
		"burst": await _burst(box, at, color, int(s.get("count", 10)), int(s.get("size", 2)), float(s.get("radius", 18)))
		"stream":
			var a := target if s.get("reverse", false) else user
			var b := user if s.get("reverse", false) else target
			await _stream(box, a, b, color, int(s.get("count", 10)), String(s.get("glyph", "square")), int(s.get("size", 2)), float(s.get("spread", 6)))
		"rings": await _rings(box, user, at, color, int(s.get("count", 2)), float(s.get("radius", 16)), bool(s.get("travel", false)))
		"beam": await _beam(box, user, target, color, int(s.get("width", 4)))
		"bolt": await _bolt(box, user, target, color, int(s.get("count", 1)))
		"rise": await _drift(box, at, color, int(s.get("count", 6)), String(s.get("glyph", "square")), float(s.get("spread", 16)), -1)
		"fall": await _drift(box, at, color, int(s.get("count", 6)), String(s.get("glyph", "square")), float(s.get("spread", 16)), 1)
		"orbit": await _orbit(box, at, color, int(s.get("count", 6)), float(s.get("radius", 18)), float(s.get("turns", 1.5)))
		"glitch": await _glitch(box, at, color, int(s.get("count", 12)))
		"flash": await _screen(box, color, float(s.get("alpha", 0.6)), 0.08, 0.25)
		"dim": await _screen(box, Color.BLACK, float(s.get("alpha", 0.6)), 0.15, 0.45)
		"cover": await _cover(box, at, color)
		"shield": await _shield(box, at, color)
		"wall": await _wall(box, user, target, color)
		"xmark": await _xmark(box, at, color)
		"slices": await _slices(box, at, color, int(s.get("count", 4)))


static func _color(spec: Variant, type_color: Color) -> Color:
	var text := String(spec)
	return type_color if text == "type" or text.is_empty() else Color(text)


func _secs(base: float) -> float:
	return base * time_scale


# --- pieces --------------------------------------------------------------------

## A pixel particle: a filled square or a small bitmap glyph. Second-color cells are a lighter tint.
class Pixel extends Control:
	var bitmap: Array = []
	var color := Color.WHITE
	var px := 1

	func setup(glyph: String, c: Color, pixel_size: int) -> Pixel:
		color = c
		px = maxi(1, pixel_size) if glyph == "square" else 2
		bitmap = ["#"] if glyph == "square" else BattleFx.BITMAPS.get(glyph, ["#"])
		custom_minimum_size = Vector2(bitmap[0].length(), bitmap.size()) * px
		size = custom_minimum_size
		pivot_offset = size / 2.0
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return self

	func _draw() -> void:
		var light := color.lerp(Color.WHITE, 0.6)
		for y in bitmap.size():
			var row: String = bitmap[y]
			for x in row.length():
				if row[x] == "#":
					draw_rect(Rect2(x * px, y * px, px, px), color)
				elif row[x] == "o":
					draw_rect(Rect2(x * px, y * px, px, px), light)


func _pixel(box: Control, glyph: String, color: Color, pixel_size: int, center: Vector2) -> Pixel:
	var p := Pixel.new().setup(glyph, color, pixel_size)
	box.add_child(p)
	p.position = (center - p.size / 2.0).round()
	return p


func _rect(box: Control, rect: Rect2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.position = rect.position.round()
	r.size = rect.size.round()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(r)
	return r


## Square bits fly outward from a point and fade.
func _burst(box: Control, at: Vector2, color: Color, count: int, bit: int, radius: float) -> void:
	var t := create_tween().set_parallel(true)
	var flash := _rect(box, Rect2(at - Vector2(5, 5), Vector2(10, 10)), Color.WHITE)
	var cross_h := _rect(box, Rect2(at - Vector2(9, 1), Vector2(18, 3)), color.lerp(Color.WHITE, 0.6))
	var cross_v := _rect(box, Rect2(at - Vector2(1, 9), Vector2(3, 18)), color.lerp(Color.WHITE, 0.6))
	for c in [flash, cross_h, cross_v]:
		t.tween_property(c, "modulate:a", 0.0, _secs(0.18)).set_delay(_secs(0.06))
	for i in count:
		var dir := Vector2.RIGHT.rotated(TAU * i / count + randf_range(-0.2, 0.2))
		var p := _pixel(box, "square", color if i % 2 else Color.WHITE, bit + 1, at)
		var end := p.position + dir * radius * randf_range(0.6, 1.0)
		t.tween_property(p, "position", end.round(), _secs(0.35)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		t.tween_property(p, "modulate:a", 0.0, _secs(0.2)).set_delay(_secs(0.25))
	await t.finished


## Bits or glyphs travel from a to b, one after another, wobbling a little.
func _stream(box: Control, a: Vector2, b: Vector2, color: Color, count: int, glyph: String, bit: int, spread: float) -> void:
	var t := create_tween().set_parallel(true)
	var normal := (b - a).normalized().orthogonal()
	for i in count:
		var off := normal * randf_range(-spread, spread)
		var p := _pixel(box, glyph, color, bit + 1, a + off)
		p.modulate.a = 0.0
		var delay := _secs(0.05) * i
		t.tween_property(p, "modulate:a", 1.0, 0.01).set_delay(delay)
		t.tween_property(p, "position", (b + off * 0.4 - p.size / 2.0).round(), _secs(0.35)).set_delay(delay)
		t.tween_property(p, "modulate:a", 0.0, _secs(0.08)).set_delay(delay + _secs(0.33))
	await t.finished


## Square outline rings that grow and fade; with travel they start at the user and move to the target.
func _rings(box: Control, user: Vector2, at: Vector2, color: Color, count: int, radius: float, travel: bool) -> void:
	for i in count:
		var ring := _Ring.new()
		ring.color = color
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(ring)
		var start := user if travel else at
		ring.center = start
		ring.radius = 2.0
		var t := create_tween().set_parallel(true)
		t.tween_property(ring, "radius", radius, _secs(0.3))
		if travel:
			t.tween_property(ring, "center", at, _secs(0.3))
		t.tween_property(ring, "modulate:a", 0.0, _secs(0.12)).set_delay(_secs(0.24))
		await get_tree().create_timer(_secs(0.14)).timeout
	await get_tree().create_timer(_secs(0.36)).timeout


class _Ring extends Control:
	var color := Color.WHITE
	var center := Vector2.ZERO:
		set(v):
			center = v
			queue_redraw()
	var radius := 2.0:
		set(v):
			radius = v
			queue_redraw()

	func _draw() -> void:
		var r := roundf(radius)
		var box := Rect2(center.round() - Vector2(r, r), Vector2(r, r) * 2.0)
		draw_rect(box, color, false, 2.0)


## A straight beam from user to target that grows, holds, then thins out.
func _beam(box: Control, user: Vector2, target: Vector2, color: Color, width: int) -> void:
	var line := _Line.new()
	line.color = color
	line.from = user
	line.to = user
	line.width = width + 2
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line)
	var t := create_tween()
	t.tween_property(line, "to", target, _secs(0.15))
	t.tween_interval(_secs(0.22))
	t.tween_property(line, "width", 0.0, _secs(0.18))
	await t.finished


class _Line extends Control:
	var color := Color.WHITE
	var from := Vector2.ZERO
	var to := Vector2.ZERO:
		set(v):
			to = v
			queue_redraw()
	var width := 3.0:
		set(v):
			width = v
			queue_redraw()

	func _draw() -> void:
		if width < 0.5:
			return
		draw_line(from.round(), to.round(), color, roundf(width), false)
		draw_line(from.round(), to.round(), color.lerp(Color.WHITE, 0.6), maxf(1.0, roundf(width / 3.0)), false)


## Jagged lightning from user to target, flickering.
func _bolt(box: Control, user: Vector2, target: Vector2, color: Color, count: int) -> void:
	for n in count:
		var points := PackedVector2Array([user])
		for i in range(1, 6):
			var p := user.lerp(target, i / 6.0) + Vector2(randf_range(-6, 6), randf_range(-6, 6))
			points.append(p.round())
		points.append(target)
		var bolt := _Bolt.new()
		bolt.points = points
		bolt.color = color
		bolt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(bolt)
		var t := create_tween()
		for i in 3:
			t.tween_property(bolt, "modulate:a", 0.2, _secs(0.04))
			t.tween_property(bolt, "modulate:a", 1.0, _secs(0.04))
		t.tween_property(bolt, "modulate:a", 0.0, _secs(0.1))
		await t.finished
		bolt.queue_free()


class _Bolt extends Control:
	var points := PackedVector2Array()
	var color := Color.WHITE

	func _draw() -> void:
		draw_polyline(points, color, 4.0, false)
		draw_polyline(points, Color.WHITE, 2.0, false)


## Particles rise (dir -1) or fall (dir 1) around a point, fading at the end.
func _drift(box: Control, at: Vector2, color: Color, count: int, glyph: String, spread: float, dir: int) -> void:
	var t := create_tween().set_parallel(true)
	for i in count:
		var x := at.x + randf_range(-spread, spread)
		var start := Vector2(x, at.y + (8.0 if dir < 0 else -30.0))
		var p := _pixel(box, glyph, color, 3, start)
		p.modulate.a = 0.0
		var delay := _secs(0.06) * i
		t.tween_property(p, "modulate:a", 1.0, 0.01).set_delay(delay)
		t.tween_property(p, "position:y", p.position.y + 30.0 * dir, _secs(0.45)).set_delay(delay)
		t.tween_property(p, "modulate:a", 0.0, _secs(0.12)).set_delay(delay + _secs(0.38))
	await t.finished


## Dots circle a point (a spinner / loop).
func _orbit(box: Control, at: Vector2, color: Color, count: int, radius: float, turns: float) -> void:
	var dots: Array[Pixel] = []
	for i in count:
		dots.append(_pixel(box, "square", color if i else Color.WHITE, 3, at))
	var spin := func(a: float) -> void:
		for i in dots.size():
			var ang := a + TAU * i / dots.size()
			dots[i].position = (at + Vector2(cos(ang), sin(ang) * 0.6) * radius - dots[i].size / 2.0).round()
	var t := create_tween()
	t.tween_method(spin, 0.0, TAU * turns, _secs(0.7))
	await t.finished


## Random blocks flicker over a point in the color and its complement (corruption).
func _glitch(box: Control, at: Vector2, color: Color, count: int) -> void:
	for frame in 5:
		for c in box.get_children():
			c.queue_free()
		for i in count:
			var w := randi_range(4, 14)
			var tint := color if i % 2 else Color(1.0 - color.r, 1.0 - color.g, 1.0 - color.b)
			_rect(box, Rect2(at + Vector2(randf_range(-22, 18), randf_range(-24, 20)), Vector2(w, randi_range(2, 4))), tint)
		await get_tree().create_timer(_secs(0.06)).timeout


## Whole-screen tint up then back down.
func _screen(box: Control, color: Color, alpha: float, up: float, down: float) -> void:
	var r := _rect(box, Rect2(Vector2.ZERO, size), Color(color, 0.0))
	var t := create_tween()
	t.tween_property(r, "color:a", alpha, _secs(up))
	t.tween_interval(_secs(0.1))
	t.tween_property(r, "color:a", 0.0, _secs(down))
	await t.finished


## A "blue screen": a panel slams over the target with lines of white text.
func _cover(box: Control, at: Vector2, color: Color) -> void:
	var area := Rect2(at - Vector2(26, 22), Vector2(52, 40))
	_rect(box, area, color)
	_rect(box, Rect2(area.position + Vector2(5, 2), Vector2(4, 2)), Color.WHITE)  # ":(" face stub
	for i in 4:
		_rect(box, Rect2(area.position + Vector2(5, 9 + i * 7), Vector2(randi_range(16, 40), 2)), Color.WHITE)
	var t := create_tween()
	t.tween_interval(_secs(0.45))
	t.tween_property(box, "modulate:a", 0.0, _secs(0.15))
	await t.finished


## A square barrier around a point that pulses twice.
func _shield(box: Control, at: Vector2, color: Color) -> void:
	var ring := _Ring.new()
	ring.color = color
	ring.center = at
	ring.radius = 24.0
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(ring)
	var inner := _Ring.new()
	inner.color = color.lerp(Color.WHITE, 0.5)
	inner.center = at
	inner.radius = 21.0
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(inner)
	var t := create_tween()
	for i in 2:
		t.tween_property(box, "modulate:a", 0.3, _secs(0.1))
		t.tween_property(box, "modulate:a", 1.0, _secs(0.1))
	t.tween_interval(_secs(0.15))
	await t.finished


## A brick wall rises between the user and the target, then fades.
func _wall(box: Control, user: Vector2, target: Vector2, color: Color) -> void:
	var base := user.lerp(target, 0.35) + Vector2(0, 16)
	var dark := color.darkened(0.4)
	var bricks: Array[ColorRect] = []
	for row in 5:
		for col in 3:
			var x := base.x - 12 + col * 8 + (4 if row % 2 else 0)
			var r := _rect(box, Rect2(x, base.y - (row + 1) * 5, 7, 4), color if (row + col) % 2 else dark)
			r.modulate.a = 0.0
			bricks.append(r)
	var t := create_tween()
	for b in bricks:
		t.tween_property(b, "modulate:a", 1.0, _secs(0.03))
	t.tween_interval(_secs(0.3))
	t.tween_property(box, "modulate:a", 0.0, _secs(0.2))  # after the hold (not alongside it)
	await t.finished


## A big pixel X stamped on the target.
func _xmark(box: Control, at: Vector2, color: Color) -> void:
	for i in range(-9, 10):
		_rect(box, Rect2(at + Vector2(i, i) - Vector2(1, 1), Vector2(3, 3)), color)
		_rect(box, Rect2(at + Vector2(i, -i) - Vector2(1, 1), Vector2(3, 3)), color)
	var t := create_tween()
	t.tween_interval(_secs(0.35))
	t.tween_property(box, "modulate:a", 0.0, _secs(0.15))  # after the hold (not alongside it)
	await t.finished


## Horizontal bars sweep across the point from alternating sides (take apart / reassemble).
func _slices(box: Control, at: Vector2, color: Color, count: int) -> void:
	var t := create_tween().set_parallel(true)
	for i in count:
		var y := at.y - 18 + i * (36.0 / count)
		var from_left := i % 2 == 0
		var bar := _rect(box, Rect2(at.x + (-60 if from_left else 30), y, 30, 4), color if i % 2 else color.lerp(Color.WHITE, 0.4))
		t.tween_property(bar, "position:x", at.x + (30 if from_left else -60), _secs(0.35)).set_delay(_secs(0.04) * i)
		t.tween_property(bar, "modulate:a", 0.0, _secs(0.1)).set_delay(_secs(0.3) + _secs(0.04) * i)
	await t.finished

