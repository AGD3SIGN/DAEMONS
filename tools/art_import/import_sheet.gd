extends SceneTree
## Turns an AI-generated sprite sheet (4x4 poses, any size, magenta or plain background) into the
## game's battle sheet: assets/sprites/daemons/<id>_sheet.png, 256x256 = 4x4 frames of 64x64.
##
##   godot --headless -s tools/art_import/import_sheet.gd -- <source image> <species_id>
##
## Per cell: removes the background (magenta anywhere; any other flat color only where it touches the
## cell edge, so a white belly survives), then shrinks to 64x64 by taking the most common color in
## each block. It's a rough import: open the result in Aseprite to tidy stray pixels.
## Frame order (row by row): idle A, idle B, physical, special / hurt, faint, happy, asleep /
## back idle A, back idle B, back attack, back hurt / evolve-or-signature, overheated, throttled, icon.

const OUT_DIR := "res://assets/sprites/daemons/"
const FRAME := 64
const GRID := 4


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: godot --headless -s tools/art_import/import_sheet.gd -- <image> <species_id>")
		quit(1)
		return
	var err := import_sheet(args[0], args[1])
	quit(0 if err.is_empty() else 1)


static func import_sheet(source: String, species_id: String) -> String:
	var src := Image.load_from_file(source)
	if src == null or src.is_empty():
		printerr("Can't read ", source)
		return "unreadable"
	src.convert(Image.FORMAT_RGBA8)
	var out := Image.create(FRAME * GRID, FRAME * GRID, false, Image.FORMAT_RGBA8)
	var cell := Vector2(src.get_width(), src.get_height()) / GRID
	var bg := src.get_pixel(2, 2)
	var magenta := _is_magenta(bg)
	for row in GRID:
		for col in GRID:
			var rect := Rect2i(Vector2i(Vector2(col, row) * cell), Vector2i(cell))
			var frame := _process_cell(src.get_region(rect), bg, magenta)
			out.blit_rect(frame, Rect2i(0, 0, FRAME, FRAME), Vector2i(col * FRAME, row * FRAME))
	var path := OUT_DIR + species_id + "_sheet.png"
	var err := out.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		printerr("Couldn't save ", path)
		return "save failed"
	print("Saved ", path, " (background: ", "magenta" if magenta else bg.to_html(false), ")")
	return ""


static func _is_magenta(c: Color) -> bool:
	return minf(c.r, c.b) - c.g > 0.35


static func _process_cell(img: Image, bg: Color, magenta: bool) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var clear := PackedByteArray()
	clear.resize(w * h)
	if magenta:
		for y in h:
			for x in w:
				if _is_magenta(img.get_pixel(x, y)):
					clear[y * w + x] = 1
	else:
		# Flood from the cell's edges through pixels close to the background color.
		var stack: Array[Vector2i] = []
		for x in w:
			stack.append(Vector2i(x, 0))
			stack.append(Vector2i(x, h - 1))
		for y in h:
			stack.append(Vector2i(0, y))
			stack.append(Vector2i(w - 1, y))
		while not stack.is_empty():
			var p: Vector2i = stack.pop_back()
			if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h or clear[p.y * w + p.x] == 1:
				continue
			if not _close(img.get_pixel(p.x, p.y), bg, 0.12):
				continue
			clear[p.y * w + p.x] = 1
			stack.append(p + Vector2i.RIGHT)
			stack.append(p + Vector2i.LEFT)
			stack.append(p + Vector2i.DOWN)
			stack.append(p + Vector2i.UP)
	var out := Image.create(FRAME, FRAME, false, Image.FORMAT_RGBA8)
	var step := Vector2(w, h) / FRAME
	for oy in FRAME:
		for ox in FRAME:
			out.set_pixel(ox, oy, _block_color(img, clear, w, Rect2i(Vector2i(Vector2(ox, oy) * step), Vector2i(step.ceil()))))
	return out


## Most common (coarsely bucketed) opaque color in the block; transparent if mostly background.
static func _block_color(img: Image, clear: PackedByteArray, w: int, r: Rect2i) -> Color:
	var counts := {}
	var colors := {}
	var opaque := 0
	var total := 0
	for y in range(r.position.y, mini(r.end.y, img.get_height())):
		for x in range(r.position.x, mini(r.end.x, w)):
			total += 1
			if clear[y * w + x] == 1:
				continue
			opaque += 1
			var c := img.get_pixel(x, y)
			var key := (int(c.r * 15.0) << 8) | (int(c.g * 15.0) << 4) | int(c.b * 15.0)
			counts[key] = counts.get(key, 0) + 1
			colors[key] = c
	if total == 0 or opaque * 2 < total:
		return Color(0, 0, 0, 0)
	var best: int = counts.keys()[0]
	for key: int in counts:
		if counts[key] > counts[best]:
			best = key
	var c: Color = colors[best]
	c.a = 1.0
	return c


static func _close(a: Color, b: Color, tolerance: float) -> bool:
	return absf(a.r - b.r) < tolerance and absf(a.g - b.g) < tolerance and absf(a.b - b.b) < tolerance
