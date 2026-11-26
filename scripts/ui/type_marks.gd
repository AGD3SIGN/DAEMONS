class_name TypeMarks
extends RefCounted
## Accessibility (GDD §9): a type is never shown by color alone. Every type has its own shape as well as its
## color, plus a 3-letter tag (HAR, NET, SOF...), so color-blind players can tell them apart.
##   TypeMarks.draw(canvas, center, size, "network")   draws the shape (type color, dark outline)
##   TypeMarks.tag("network") -> "NET"

const SHAPES := {
	"hardware": "square", "network": "ring", "software": "diamond", "power": "triangle", "cloud": "circle",
	"data": "hexagon", "security": "shield", "malware": "x", "legacy": "bar", "mobile": "tall",
	"ai": "star", "peripheral": "plus",
}
const OUTLINE := Color("10141c")


static func shape(type_id: String) -> String:
	return SHAPES.get(type_id, "square")


static func tag(type_id: String) -> String:
	var data: Dictionary = DataRegistry.types.get(type_id, {})
	return String(data.get("name", type_id)).left(3).to_upper()


static func color(type_id: String) -> Color:
	return Color(String(DataRegistry.types.get(type_id, {}).get("color", "#ffffff")))


## The shape's outline points, for a mark `size` px across centered on `c` (ring, x and plus are drawn as lines).
static func points(kind: String, c: Vector2, size: float) -> PackedVector2Array:
	var r := size / 2.0
	match kind:
		"square":
			return PackedVector2Array([c + Vector2(-r, -r), c + Vector2(r, -r), c + Vector2(r, r), c + Vector2(-r, r)])
		"diamond":
			return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
		"triangle":
			return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, r), c + Vector2(-r, r)])
		"hexagon", "circle", "ring":
			var n := 6 if kind == "hexagon" else 16
			var out := PackedVector2Array()
			for i in n:
				var a := TAU * i / n - PI / 2.0
				out.append(c + Vector2(cos(a), sin(a)) * r)
			return out
		"shield":
			return PackedVector2Array([c + Vector2(-r, -r), c + Vector2(r, -r), c + Vector2(r, 0.1 * r),
				c + Vector2(0, r), c + Vector2(-r, 0.1 * r)])
		"bar":
			return PackedVector2Array([c + Vector2(-r, -0.45 * r), c + Vector2(r, -0.45 * r), c + Vector2(r, 0.45 * r),
				c + Vector2(-r, 0.45 * r)])
		"tall":
			return PackedVector2Array([c + Vector2(-0.55 * r, -r), c + Vector2(0.55 * r, -r), c + Vector2(0.55 * r, r),
				c + Vector2(-0.55 * r, r)])
		"star":
			var out := PackedVector2Array()
			for i in 8:
				var a := TAU * i / 8 - PI / 2.0
				out.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else 0.42 * r))
			return out
	return PackedVector2Array()


static func draw(canvas: CanvasItem, c: Vector2, size: float, type_id: String) -> void:
	var kind := shape(type_id)
	var col := color(type_id)
	var w := maxf(2.0, roundf(size / 6.0))
	match kind:
		"ring":
			canvas.draw_arc(c, size / 2.0 - w / 2.0, 0, TAU, 20, OUTLINE, w + 2.0)
			canvas.draw_arc(c, size / 2.0 - w / 2.0, 0, TAU, 20, col, w)
		"x", "plus":
			var r := size / 2.0
			var lines := [[Vector2(-r, -r), Vector2(r, r)], [Vector2(-r, r), Vector2(r, -r)]] if kind == "x" \
				else [[Vector2(0, -r), Vector2(0, r)], [Vector2(-r, 0), Vector2(r, 0)]]
			for pass_i in 2:
				for l: Array in lines:
					canvas.draw_line(c + l[0], c + l[1], OUTLINE if pass_i == 0 else col, w + (2.0 if pass_i == 0 else 0.0))
		_:
			var pts := points(kind, c, size)
			canvas.draw_colored_polygon(pts, col)
			var closed := pts.duplicate()
			closed.append(pts[0])
			canvas.draw_polyline(closed, OUTLINE, 2.0)
