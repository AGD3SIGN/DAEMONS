extends SceneTree
## Turns an AI-generated overworld character sheet into the game's walking sheet:
## assets/sprites/characters/<id>.png, 3 frames (stand, step A, step B) x 4 rows (down, up, left, right)
## of 16x24, standing on the bottom of each frame (the character fills one 16x16 tile and stands 8 px taller).
##
##   godot --headless -s tools/art_import/import_character.gd -- <source image> <id>
##   godot --headless -s tools/art_import/import_character.gd -- --all
##
## --all imports every art_src/characters/<id>_gpt*.png|webp (newest file wins per id).
## Source layout: 3 columns x 4 rows of poses on any canvas (e.g. 1254x1254), any background the Daemon
## importer handles (magenta, plain or transparent). The poses don't sit on an even grid (the block is
## centered with margins), so columns and rows are cut at the widest empty gaps between the art.
## All 12 frames share one scale (the tallest/widest pose fits), and each pose is anchored by its feet
## so walking doesn't jitter.

const ImportSheet := preload("res://tools/art_import/import_sheet.gd")
const OUT_DIR := "res://assets/sprites/characters/"
const SRC_DIR := "res://art_src/characters/"
const FRAME := Vector2i(16, 24)
const COLS := 3
const ROWS := 4


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 1 and args[0] == "--all":
		var failed := 0
		for pair: Array in ImportSheet.find_sources(ProjectSettings.globalize_path(SRC_DIR)):
			if not import_character(pair[0], pair[1]).is_empty():
				failed += 1
		quit(1 if failed > 0 else 0)
		return
	if args.size() < 2:
		printerr("usage: godot --headless -s tools/art_import/import_character.gd -- <image> <id> | --all")
		quit(1)
		return
	quit(0 if import_character(args[0], args[1]).is_empty() else 1)


static func import_character(source: String, id: String) -> String:
	var src := Image.load_from_file(source)
	if src == null or src.is_empty():
		printerr("Can't read ", source)
		return "unreadable"
	src.convert(Image.FORMAT_RGBA8)
	var bg := src.get_pixel(2, 2)
	var transparent := bg.a < 0.5
	var magenta := not transparent and ImportSheet._is_magenta(bg)
	# 1. Find the pose grid from the gaps in the art, then cut out each pose and box its art.
	var full_mask := ImportSheet.clear_mask(src, bg, magenta, transparent)
	var xs := _cuts(full_mask, src.get_width(), src.get_height(), true, COLS)
	var ys := _cuts(full_mask, src.get_width(), src.get_height(), false, ROWS)
	var cells: Array[Image] = []
	var masks: Array[PackedByteArray] = []
	var boxes: Array[Rect2i] = []
	for row in ROWS:
		for col in COLS:
			var rect := Rect2i(xs[col], ys[row], xs[col + 1] - xs[col], ys[row + 1] - ys[row])
			var img := src.get_region(rect)
			var mask := PackedByteArray()
			mask.resize(rect.size.x * rect.size.y)
			for y in rect.size.y:
				for x in rect.size.x:
					mask[y * rect.size.x + x] = full_mask[(rect.position.y + y) * src.get_width() + rect.position.x + x]
			cells.append(img)
			masks.append(mask)
			boxes.append(_art_box(mask, img.get_width(), img.get_height()))
	# 2. One scale for every frame: the biggest pose fits in 16x24 (1 px spare at the top).
	var biggest := Vector2i.ZERO
	for b in boxes:
		biggest = biggest.max(b.size)
	if biggest == Vector2i.ZERO:
		printerr("No art found in ", source)
		return "empty"
	var step := maxf(biggest.x / float(FRAME.x), biggest.y / float(FRAME.y - 1))
	# 3. Sample each pose into its frame, feet on the bottom row, centered on the art's middle.
	var out := Image.create(FRAME.x * COLS, FRAME.y * ROWS, false, Image.FORMAT_RGBA8)
	for i in cells.size():
		var b := boxes[i]
		var feet := Vector2(b.position.x + b.size.x / 2.0, b.end.y)
		var origin := feet - Vector2(FRAME.x / 2.0, FRAME.y) * step  # source point for frame pixel (0,0)
		var w := cells[i].get_width()
		for fy in FRAME.y:
			for fx in FRAME.x:
				var r := Rect2i(Vector2i((origin + Vector2(fx, fy) * step).floor()), Vector2i(ceili(step), ceili(step)))
				r = r.intersection(Rect2i(Vector2i.ZERO, cells[i].get_size()))
				if r.size.x <= 0 or r.size.y <= 0:
					continue
				var c := ImportSheet._block_color(cells[i], masks[i], w, r)
				if c.a > 0.0:
					out.set_pixel((i % COLS) * FRAME.x + fx, (i / COLS) * FRAME.y + fy, c)
	var path := OUT_DIR + id + ".png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	if out.save_png(ProjectSettings.globalize_path(path)) != OK:
		printerr("Couldn't save ", path)
		return "save failed"
	print("Saved ", path, " from ", source.get_file(), " (", "%.1f" % step, " source px per pixel)")
	return ""


## Cut positions (count + 1 values, from 0 to the image edge) that split the art into `count` columns
## (vertical = true) or rows, at the midpoints of the widest empty gaps between the art.
static func _cuts(mask: PackedByteArray, w: int, h: int, vertical: bool, count: int) -> Array[int]:
	var n := w if vertical else h
	var other := h if vertical else w
	var has := PackedByteArray()
	has.resize(n)
	for i in n:
		for j in range(0, other, 2):
			var idx := (j * w + i) if vertical else (i * w + j)
			if mask[idx] == 0:
				has[i] = 1
				break
	var first := has.find(1)
	var last := n - 1
	while last > 0 and has[last] == 0:
		last -= 1
	var gaps: Array[Vector2i] = []  # (start, length)
	var start := -1
	for i in range(maxi(first, 0), last + 1):
		if has[i] == 0:
			if start < 0:
				start = i
		elif start >= 0:
			gaps.append(Vector2i(start, i - start))
			start = -1
	gaps.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y > b.y)
	var mids: Array[int] = []
	for g in gaps.slice(0, count - 1):
		mids.append(g.x + g.y / 2)
	mids.sort()
	var cuts: Array[int] = [0]
	cuts.append_array(mids)
	# Not enough gaps (art touching): fall back to even splits for the rest.
	while cuts.size() < count:
		cuts.append(n * cuts.size() / count)
	cuts.sort()
	cuts.append(n)
	return cuts


## Bounding box of the non-background pixels.
static func _art_box(mask: PackedByteArray, w: int, h: int) -> Rect2i:
	var lo := Vector2i(w, h)
	var hi := Vector2i(-1, -1)
	for y in h:
		for x in w:
			if mask[y * w + x] == 0:
				lo = lo.min(Vector2i(x, y))
				hi = hi.max(Vector2i(x, y))
	if hi.x < 0:
		return Rect2i()
	return Rect2i(lo, hi - lo + Vector2i.ONE)
