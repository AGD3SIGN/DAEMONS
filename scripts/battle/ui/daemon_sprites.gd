class_name DaemonSprites
extends RefCounted
## Battle sprites (64x64). Looks for art in assets/sprites/daemons/, best first:
##   <id>_sheet.png  256x256, 4x4 poses (see POSES; made by tools/art_import/import_sheet.gd)
##   <id>_front.png / <id>_back.png  single stills
## otherwise generates a placeholder blob colored by the Daemon's types, shaped by its id, and sized
## by its base stat total (later stages are bigger). Results are cached.

const SIZE := 64
const ART_DIR := "res://assets/sprites/daemons/"

## Sheet frame index for each pose, row by row (same order as the art prompts).
const POSES := {
	"idle": 0, "idle_b": 1, "attack": 2, "special": 3,
	"hurt": 4, "faint": 5, "happy": 6, "asleep": 7,
	"back": 8, "back_b": 9, "back_attack": 10, "back_hurt": 11,
	"upgrade": 12, "overheated": 13, "throttled": 14, "icon": 15,
}

static var _cache: Dictionary = {}


static func has_sheet(species_id: String) -> bool:
	return _sheet(species_id) != null


## One pose from the Daemon's sheet, or null if it has no sheet yet.
static func pose(species_id: String, pose_name: String) -> Texture2D:
	var key := "%s#%s" % [species_id, pose_name]
	if _cache.has(key):
		return _cache[key]
	var sheet := _sheet(species_id)
	if sheet == null or not POSES.has(pose_name):
		return null
	var i: int = POSES[pose_name]
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2((i % 4) * SIZE, (i / 4) * SIZE, SIZE, SIZE)
	_cache[key] = atlas
	return atlas


static func _sheet(species_id: String) -> Texture2D:
	var key := species_id + "#sheet"
	if not _cache.has(key):
		var path := ART_DIR + species_id + "_sheet.png"
		_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _cache[key]


static func front(species_id: String) -> Texture2D:
	return _load(species_id, false)


static func back(species_id: String) -> Texture2D:
	return _load(species_id, true)


## A small USB-stick Quarantine Key for the capture animation.
static func quarantine_key() -> Texture2D:
	if _cache.has("__key"):
		return _cache["__key"]
	var img := Image.create(12, 18, false, Image.FORMAT_RGBA8)
	var body := Color("5868a0")
	var metal := Color("c8c8d0")
	for y in 18:
		for x in 12:
			if y < 6 and x >= 3 and x <= 8:
				img.set_pixel(x, y, Color("707080") if (y == 2 or y == 3) and (x == 4 or x == 7) else metal)
			elif y >= 6 and x >= 1 and x <= 10:
				var edge := x == 1 or x == 10 or y == 6 or y == 17
				img.set_pixel(x, y, body.darkened(0.5) if edge else body)
	img.set_pixel(5, 9, Color("60f080"))
	img.set_pixel(6, 9, Color("60f080"))
	var tex := ImageTexture.create_from_image(img)
	_cache["__key"] = tex
	return tex


static func _load(species_id: String, is_back: bool) -> Texture2D:
	var key := "%s_%s" % [species_id, "back" if is_back else "front"]
	if _cache.has(key):
		return _cache[key]
	var path := ART_DIR + key + ".png"
	var tex: Texture2D = pose(species_id, "back" if is_back else "idle")
	if tex == null:
		tex = load(path) if ResourceLoader.exists(path) else ImageTexture.create_from_image(_generate(species_id, is_back))
	_cache[key] = tex
	return tex


static func _generate(species_id: String, is_back: bool) -> Image:
	var data := DataRegistry.get_species(species_id)
	var types: Array = data.get("types", ["peripheral"])
	var main := Color(String(DataRegistry.types.get(types[0], {}).get("color", "#9a9aa6")))
	var accent := Color(String(DataRegistry.types.get(types[-1], {}).get("color", "#9a9aa6"))) if types.size() > 1 else main.lightened(0.35)
	if is_back:
		main = main.darkened(0.15)
		accent = accent.darkened(0.15)
	var outline := main.darkened(0.65)

	var seed_hash := absi(species_id.hash())
	var shape := seed_hash % 3
	var has_ears := (seed_hash >> 3) & 1 == 1
	var bst := 0
	for v: Variant in data.get("base_stats", {}).values():
		bst += int(v)
	var scale := clampf(0.68 + (bst - 250) / 700.0, 0.68, 1.0)

	# Decide which pixels are body (1) or accent (2), then outline the edge.
	var mask := PackedByteArray()
	mask.resize(SIZE * SIZE)
	for y in SIZE:
		for x in SIZE:
			# Scale around the feet (bottom center) so smaller Daemons still stand on the platform.
			var sx := (x - 32.0) / scale + 32.0
			var sy := (y - 60.0) / scale + 60.0
			mask[y * SIZE + x] = _shape_value(shape, has_ears, types.size() > 1, sx, sy)

	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var v := mask[y * SIZE + x]
			if v == 0:
				continue
			var edge := false
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + offset.x
				var ny := y + offset.y
				if nx < 0 or ny < 0 or nx >= SIZE or ny >= SIZE or mask[ny * SIZE + nx] == 0:
					edge = true
					break
			img.set_pixel(x, y, outline if edge else (accent if v == 2 else main))

	if not is_back:
		var eye_y := int(60 - (60 - 30) * scale)
		for eye_x in [int(32 - 7 * scale), int(32 + 7 * scale)]:
			_disc(img, eye_x, eye_y, 3, Color.WHITE)
			_disc(img, eye_x + 1, eye_y, 1, Color("202028"))
	return img


static func _shape_value(shape: int, ears: bool, dual: bool, x: float, y: float) -> int:
	var inside := false
	match shape:
		0:  # round blob
			inside = _in_ellipse(x, y, 32, 40, 22, 20)
			if ears:
				inside = inside or _in_ellipse(x, y, 20, 20, 6, 8) or _in_ellipse(x, y, 44, 20, 6, 8)
		1:  # boxy machine with antenna
			inside = x >= 12 and x <= 52 and y >= 18 and y <= 60 and not _outside_rounded(x, y, 12, 18, 52, 60, 6)
			inside = inside or (absf(x - 32) <= 1 and y >= 8 and y < 18) or _in_ellipse(x, y, 32, 7, 3, 3)
		2:  # tall body with arms
			inside = _in_ellipse(x, y, 32, 36, 16, 24) or _in_ellipse(x, y, 14, 40, 6, 6) or _in_ellipse(x, y, 50, 40, 6, 6)
			if ears:
				inside = inside or _in_ellipse(x, y, 32, 10, 5, 6)
	if not inside:
		return 0
	if dual and y >= 42 and y <= 48:
		return 2  # second type as a stripe
	if not dual and _in_ellipse(x, y, 32, 46, 10, 8):
		return 2  # lighter belly
	return 1


static func _in_ellipse(x: float, y: float, cx: float, cy: float, rx: float, ry: float) -> bool:
	var dx := (x - cx) / rx
	var dy := (y - cy) / ry
	return dx * dx + dy * dy <= 1.0


static func _outside_rounded(x: float, y: float, l: float, t: float, r: float, b: float, radius: float) -> bool:
	for corner: Vector2 in [Vector2(l + radius, t + radius), Vector2(r - radius, t + radius), Vector2(l + radius, b - radius), Vector2(r - radius, b - radius)]:
		var in_corner_zone := (x < l + radius or x > r - radius) and (y < t + radius or y > b - radius)
		if in_corner_zone and absf(x - corner.x) <= radius and absf(y - corner.y) <= radius:
			return Vector2(x, y).distance_to(corner) > radius
	return false


static func _disc(img: Image, cx: int, cy: int, r: int, color: Color) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if x >= 0 and y >= 0 and x < SIZE and y < SIZE and Vector2(x - cx, y - cy).length() <= r + 0.3:
				img.set_pixel(x, y, color)
