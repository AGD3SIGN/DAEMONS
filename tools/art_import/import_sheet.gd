extends SceneTree
## Turns an AI-generated sprite sheet (4x4 poses, any size, magenta or plain background) into the
## game's battle sheet: assets/sprites/daemons/<id>_sheet.png, 256x256 = 4x4 frames of 64x64.
##
##   godot --headless -s tools/art_import/import_sheet.gd -- <source image> <species_id>
##   godot --headless -s tools/art_import/import_sheet.gd -- --all
##
## --all imports every art_src/daemons/**/<species_id>_gpt*.png|webp (e.g. 02-Pingo/pengwan_gpt_v2.png);
## the species id is the part of the file name before "_gpt".
##
## Per cell: removes the background (already-transparent pixels; magenta anywhere; any other flat color
## only where it touches the cell edge, so a white belly survives), then shrinks to 64x64 by taking the most common color in
## each block. It's a rough import: open the result in Aseprite to tidy stray pixels.
## Frame order (row by row): idle A, idle B, physical, special / hurt, faint, happy, asleep /
## back idle A, back idle B, back attack, back hurt / evolve-or-signature, overheated, throttled, icon.
##
## Two source layouts are understood:
##   4x4 (square image): the 16 poses above, one per equal cell.
##   6x2 (wide image, e.g. 1536x1024): the first 12 poses in two rows of 6 floating on the canvas.
##     Rows are found from the empty gap between them; each pose is cut as a square aligned to its
##     row's bottom (the feet), using only its own column, with one square size for the whole sheet so
##     every pose keeps the same scale. The 4 missing poses are filled in: a white silhouette of the
##     idle pose for "evolve", and the idle pose for overheated, throttled and icon.

const OUT_DIR := "res://assets/sprites/daemons/"
const SRC_DIR := "res://art_src/daemons/"
const FRAME := 64
const GRID := 4


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 1 and args[0] == "--all":
		var failed := 0
		for pair: Array in find_sources(ProjectSettings.globalize_path(SRC_DIR)):
			if not import_sheet(pair[0], pair[1]).is_empty():
				failed += 1
		quit(1 if failed > 0 else 0)
		return
	if args.size() < 2:
		printerr("usage: godot --headless -s tools/art_import/import_sheet.gd -- <image> <species_id>")
		quit(1)
		return
	var err := import_sheet(args[0], args[1])
	quit(0 if err.is_empty() else 1)


## [[path, species_id], ...] for every *_gpt* image under dir (any depth), sorted by species id.
static func find_sources(dir: String) -> Array:
	var found := {}
	_scan(dir, found)
	var out := []
	for species_id: String in found.keys():
		out.append([found[species_id], species_id])
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
	return out


static func _scan(dir: String, found: Dictionary) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_scan(dir.path_join(sub), found)
	for file in DirAccess.get_files_at(dir):
		var ext := file.get_extension().to_lower()
		var at := file.find("_gpt")
		if at <= 0 or not ext in ["png", "webp", "jpg", "jpeg"]:
			continue
		var species_id := file.substr(0, at).to_lower()
		var path := dir.path_join(file)
		# Two images for one Daemon: keep the newest file.
		if not found.has(species_id) or FileAccess.get_modified_time(path) > FileAccess.get_modified_time(found[species_id]):
			found[species_id] = path


static func import_sheet(source: String, species_id: String) -> String:
	var src := Image.load_from_file(source)
	if src == null or src.is_empty():
		printerr("Can't read ", source)
		return "unreadable"
	src.convert(Image.FORMAT_RGBA8)
	var out := Image.create(FRAME * GRID, FRAME * GRID, false, Image.FORMAT_RGBA8)
	var bg := src.get_pixel(2, 2)
	var transparent := bg.a < 0.5
	var magenta := not transparent and _is_magenta(bg)
	var cells: Array[Image] = []
	if float(src.get_width()) / src.get_height() > 1.3:
		cells = _wide_cells(src, bg, magenta, transparent)
		if cells.is_empty():
			printerr("Couldn't find two rows of poses in ", source)
			return "layout"
	else:
		var cell := Vector2(src.get_width(), src.get_height()) / GRID
		for row in GRID:
			for col in GRID:
				cells.append(src.get_region(Rect2i(Vector2i(Vector2(col, row) * cell), Vector2i(cell))))
	var frames: Array[Image] = []
	for img in cells:
		frames.append(_process_cell(img, bg, magenta, transparent))
	if frames.size() == 12:
		frames.append(_silhouette(frames[0]))  # evolve
		frames.append(frames[0])               # overheated
		frames.append(frames[0])               # throttled
		frames.append(frames[0])               # icon
	for i in frames.size():
		out.blit_rect(frames[i], Rect2i(0, 0, FRAME, FRAME), Vector2i((i % GRID) * FRAME, (i / GRID) * FRAME))
	var path := OUT_DIR + species_id + "_sheet.png"
	var err := out.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		printerr("Couldn't save ", path)
		return "save failed"
	var kind := "transparent" if transparent else ("magenta" if magenta else bg.to_html(false))
	print("Saved ", path, " from ", source.get_file(), " (background: ", kind, ")")
	return ""


## 6x2 layout: 12 square cells (row by row), background outside each pose's own column.
static func _wide_cells(src: Image, bg: Color, magenta: bool, transparent: bool) -> Array[Image]:
	var w := src.get_width()
	var h := src.get_height()
	var is_bg := func(c: Color) -> bool:
		return c.a < 0.6 or (magenta and _is_key(c, bg)) or (not magenta and not transparent and _close(c, bg, 0.12))
	# Which pixel rows have any art in them.
	var has := PackedByteArray()
	has.resize(h)
	for y in h:
		for x in range(0, w, 2):
			if not is_bg.call(src.get_pixel(x, y)):
				has[y] = 1
				break
	var top := has.find(1)
	var bottom := h - 1
	while bottom > 0 and has[bottom] == 0:
		bottom -= 1
	if top < 0:
		return []
	# The two rows are split at the longest empty stretch between the top and bottom of the art.
	var best_start := -1
	var best_len := 0
	var run_start := -1
	for y in range(top, bottom + 1):
		if has[y] == 0:
			if run_start < 0:
				run_start = y
			if y - run_start + 1 > best_len:
				best_len = y - run_start + 1
				best_start = run_start
		else:
			run_start = -1
	if best_start < 0:
		return []
	var rows := [Vector2i(top, best_start - 1), Vector2i(best_start + best_len, bottom)]
	var col_w := w / 6
	var size := col_w
	for r: Vector2i in rows:
		size = maxi(size, r.y - r.x + 1 + 8)
	var cells: Array[Image] = []
	for r: Vector2i in rows:
		for col in 6:
			var cell := Image.create(size, size, false, Image.FORMAT_RGBA8)
			cell.fill(bg)
			var left := col * col_w + col_w / 2 - size / 2   # cell's left edge in the source
			var y0 := r.y + 4 - size + 1                      # cell's top edge (feet near the bottom)
			var src_x0 := maxi(col * col_w, left)
			var src_x1 := mini((col + 1) * col_w, left + size)
			var src_y0 := maxi(0, y0)
			var src_y1 := mini(h, y0 + size)
			if src_x1 > src_x0 and src_y1 > src_y0:
				var part := Rect2i(src_x0, src_y0, src_x1 - src_x0, src_y1 - src_y0)
				cell.blit_rect(src, part, Vector2i(src_x0 - left, src_y0 - y0))
			cells.append(cell)
	return cells


## White silhouette (dark outline kept) for the evolve pose.
static func _silhouette(frame: Image) -> Image:
	var out := frame.duplicate() as Image
	for y in out.get_height():
		for x in out.get_width():
			var c := out.get_pixel(x, y)
			if c.a > 0.0 and c.get_luminance() > 0.3:
				out.set_pixel(x, y, Color.WHITE)
	return out


## Is this sheet's background magenta? (Loose test, only used on the background sample.)
static func _is_magenta(c: Color) -> bool:
	return minf(c.r, c.b) - c.g > 0.35


## Background pixel on a magenta sheet: close to the sheet's own background color. Kept strict so
## hot-pink and purple parts of the art (Botgeon's ruff, Wormhole's portal) aren't cut out.
static func _is_key(c: Color, bg: Color) -> bool:
	return _close(c, bg, 0.26)


static func _process_cell(img: Image, bg: Color, magenta: bool, transparent: bool = false) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var clear := PackedByteArray()
	clear.resize(w * h)
	# Already cut out: clear see-through pixels, including the faint halos background removers leave.
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a < 0.6:
				clear[y * w + x] = 1
	if transparent:
		pass
	elif magenta:
		for y in h:
			for x in w:
				if _is_key(img.get_pixel(x, y), bg):
					clear[y * w + x] = 1
		# Soft edges: magenta-ish pixels touching the background are blends of art and background (the
		# purple fringe and stray specks). Peel them off twice. Pinks inside the art are walled off by the
		# dark outline, so they stay.
		for _pass in 2:
			var peel: Array[int] = []
			for y in h:
				for x in w:
					var i := y * w + x
					if clear[i] == 1 or not _is_magenta(img.get_pixel(x, y)):
						continue
					if (x > 0 and clear[i - 1] == 1) or (x < w - 1 and clear[i + 1] == 1) \
							or (y > 0 and clear[i - w] == 1) or (y < h - 1 and clear[i + w] == 1):
						peel.append(i)
			for i in peel:
				clear[i] = 1
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
