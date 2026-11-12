extends SceneTree
## Makes a battle sheet (assets/sprites/daemons/<id>_sheet.png, 4x4 poses of 64x64) from a pixel
## map in data/title_screen.json "featured" (the LEFT half, mirrored), so a legendary looks the same
## in battle as on the title screen. Drawn at 2x: a 32-wide map fills the 64 px frame.
##
##   godot --headless -s tools/art_import/pixel_map_sheet.gd -- pyrewall
##
## Pose order matches DaemonSprites.POSES. Back views hide the face (eyes, core) behind the body color.
## The wings fill the frame width, so poses move up/down only (a sideways nudge would clip a wing).

const FRAME := 64
const SCALE := 2
const FLOOR := 60          # feet row
const BACK_COVER := {"e": "f", "c": "r", "w": "r"}
const OUT_DIR := "res://assets/sprites/daemons/"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: godot --headless -s tools/art_import/pixel_map_sheet.gd -- <featured id>")
		quit(1)
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/title_screen.json"))
	for f: Dictionary in data["featured"]:
		if f["id"] == args[0]:
			var path := OUT_DIR + args[0] + "_sheet.png"
			make_sheet(f["sprite"]).save_png(ProjectSettings.globalize_path(path))
			print("Saved ", path)
			quit(0)
			return
	printerr("No featured entry '%s' in data/title_screen.json" % args[0])
	quit(1)


static func make_sheet(sprite: Dictionary) -> Image:
	var rows := TitleHero.mirror_rows(sprite["half"])
	var palette := {}
	for ch: String in sprite["palette"]:
		var spec := str(sprite["palette"][ch])
		palette[ch] = TitleStyle.ACCENT_DEFAULT if spec == "accent" else Color(spec)
	var back := PackedStringArray()
	for row in rows:
		var r := row
		for ch: String in BACK_COVER:
			r = r.replace(ch, BACK_COVER[ch])
		back.append(r)
	var closed := PackedStringArray()
	for row in rows:
		closed.append(row.replace("e", "o"))
	var hot := PackedStringArray()
	for row in rows:
		hot.append(row.replace("f", "y").replace("c", "w"))
	# Poses differ by shape (closed eyes, hotter flames, position), not by tints, so the sheet stays at
	# the map's own colors plus three greys (faint) and white (upgrade): under the 16-color limit.
	var greys := func(c: Color) -> Color:
		return Color("#3a3640") if c.v < 0.35 else (Color("#6e6a74") if c.v < 0.8 else Color("#a8a4ae"))
	var white := func(_c: Color) -> Color: return Color("#fff4d6")
	var poses: Array[Image] = [
		_frame(rows, palette, 0, 0),             # idle
		_frame(rows, palette, 0, 1),             # idle_b
		_frame(hot, palette, 0, 3),              # attack (lunges down, flames flare)
		_frame(hot, palette, 0, -2),             # special
		_frame(closed, palette, 0, -1),          # hurt
		_frame(closed, palette, 0, 0, greys, 0.5),  # faint (collapsed, grey)
		_frame(closed, palette, 0, -2),          # happy
		_frame(closed, palette, 0, 2),           # asleep
		_frame(back, palette, 0, 0),             # back
		_frame(back, palette, 0, 1),             # back_b
		_frame(back, palette, 0, -3),            # back_attack (lunges up)
		_frame(back, palette, 0, 1),             # back_hurt
		_frame(rows, palette, 0, 0, white),      # upgrade
		_frame(hot, palette, 0, 0),              # overheated
		_frame(closed, palette, 0, 1),           # throttled
		_frame(rows, palette, 0, 0),             # icon
	]
	var sheet := Image.create(FRAME * 4, FRAME * 4, false, Image.FORMAT_RGBA8)
	for i in poses.size():
		sheet.blit_rect(poses[i], Rect2i(0, 0, FRAME, FRAME), Vector2i((i % 4) * FRAME, (i / 4) * FRAME))
	return sheet


## One 64x64 pose: the map at 2x, centered, feet on FLOOR, nudged by (dx, dy), colors through `tint`,
## squashed to `height` of its size (faint) from the feet up.
static func _frame(rows: PackedStringArray, palette: Dictionary, dx: int, dy: int,
		tint: Callable = Callable(), height: float = 1.0) -> Image:
	var img := Image.create(FRAME, FRAME, false, Image.FORMAT_RGBA8)
	var w := rows[0].length() * SCALE
	var h := rows.size() * SCALE
	var left := (FRAME - w) / 2 + dx
	var bottom := FLOOR + dy
	for py in roundi(h * height):
		var src_y := floori(py / height) / SCALE
		var y := bottom - roundi(h * height) + py
		for px in w:
			var ch := rows[src_y][px / SCALE]
			if not palette.has(ch):
				continue
			var c: Color = palette[ch]
			if tint.is_valid():
				c = tint.call(c)
			var x := left + px
			if x >= 0 and x < FRAME and y >= 0 and y < FRAME:
				img.set_pixel(x, y, c)
	return img
