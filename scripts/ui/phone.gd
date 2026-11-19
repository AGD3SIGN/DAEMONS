class_name Phone
extends Control
## Your work phone (Brandon, 2026-11-15): the menu button opens it, the map button opens it straight to Maps.
## Home screen = a grid of apps (the old pause menu's entries); FieldMenus opens whatever app you pick.
## Maps turns the phone sideways and draws Root Valley from data/region_map.json as a circuit board:
## towns are chips, routes are vias, roads are copper traces, and the place you're standing on blinks.
##
##   await phone.home(start_app)  -> app id ("MAP", "CMDB", ...) or "" when you put the phone away
##   await phone.maps()           -> returns when you close Maps

signal _picked(app: String)
signal _maps_closed

const SMALL_FONT := "res://assets/fonts/Silkscreen-Regular.ttf"
const COLS := 3

## [id, label, tile color, 8x8 glyph]. DEBUG is added in debug builds.
const APPS := [
	["MAP", "MAPS", "2fa86a", ["..####..", ".#....#.", ".#.##.#.", ".#.##.#.", ".#....#.", "..#..#..", "...##...", "........"]],
	["CMDB", "CMDB", "3c8ee0", [".######.", "#......#", ".######.", "#......#", ".######.", "#......#", ".######.", "........"]],
	["STACK", "STACK", "e0703c", ["..#..#..", ".######.", "#.#..#.#", "#......#", "#.####.#", ".#....#.", "..####..", "........"]],
	["BAG", "BAG", "b07a3c", ["...##...", "..#..#..", ".######.", "#......#", "#.####.#", "#......#", ".######.", "........"]],
	["CARD", "ID CARD", "8b6fd6", ["........", "########", "#.##...#", "#.##.###", "#......#", "#.##.###", "########", "........"]],
	["SAVE", "SAVE", "4c5a78", ["#######.", "#.###.##", "#.###..#", "#......#", "#.####.#", "#.####.#", "########", "........"]],
	["CONTROLS", "CONTROLS", "d0a020", ["........", ".######.", "#.#...##", "###..#.#", "#.#.#..#", "#......#", ".##..##.", "........"]],
	["OPTIONS", "SETTINGS", "7a8494", ["...##...", ".#.##.#.", "..####..", "###..###", "###..###", "..####..", ".#.##.#.", "...##..."]],
	["FEEDBACK", "FEEDBACK", "d85a8a", [".######.", "#......#", "#.#.#.##", "#......#", ".######.", "..#.....", ".#......", "........"]],
]
const DEBUG_APP := ["DEBUG", "DEBUG", "b23a3a", [".#....#.", "..####..", ".#.##.#.", "#.####.#", ".######.", "#.####.#", "..#..#..", "........"]]

# Portrait phone (home screen), in the 320x180 game view.
const BODY := Rect2(104, 2, 112, 176)
const SCREEN := Rect2(110, 16, 100, 148)
const ICON := 24
const GRID_ORIGIN := Vector2(114, 40)
const CELL := Vector2(32, 28)
# Landscape phone (Maps).
const L_BODY := Rect2(2, 2, 316, 176)
const L_SCREEN := Rect2(16, 6, 288, 170)
const MAP_ORIGIN := Vector2(16, 18)

const BODY_COLOR := Color("1c2030")
const BODY_EDGE := Color("3a4258")
const SCREEN_BG := Color("0c1626")
const SCREEN_TEXT := Color("e8f1ff")
const ACCENT := Color("3ee6ff")
const TRACE := Color("c8843c")
const TRACE_DIM := Color("5a4630")
const GRID_DOT := Color("16263c")

var apps: Array = []
var selected := 0
var mode := ""          # "", "home", "maps"
var map_cursor := ""    # region place id under the Maps cursor
var _font: Font
var _blink := 0.0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	apps = APPS.duplicate()
	if OS.is_debug_build():
		apps.append(DEBUG_APP)


func _ready() -> void:
	_font = load(SMALL_FONT)


# --- home ------------------------------------------------------------------------

func home(start_app: String = "") -> String:
	for i in apps.size():
		if apps[i][0] == start_app:
			selected = i
	mode = "home"
	visible = true
	queue_redraw()
	var app: String = await _picked
	mode = ""
	visible = false
	return app


func app_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for a: Array in apps:
		out.append(a[0])
	return out


func move_selection(dx: int, dy: int) -> void:
	var rows := ceili(apps.size() / float(COLS))
	var col := selected % COLS
	var row := selected / COLS
	col = wrapi(col + dx, 0, COLS)
	row = wrapi(row + dy, 0, rows)
	selected = mini(row * COLS + col, apps.size() - 1)
	queue_redraw()


func icon_rect(i: int) -> Rect2:
	var cell := GRID_ORIGIN + Vector2(i % COLS, i / COLS) * CELL
	return Rect2(cell + Vector2((CELL.x - ICON) / 2.0, 0), Vector2(ICON, ICON))


# --- maps ------------------------------------------------------------------------

func maps() -> void:
	map_cursor = here()
	mode = "maps"
	visible = true
	queue_redraw()
	await _maps_closed
	mode = ""
	visible = false


## The region-map place you're standing in ("" if the map isn't on it).
static func here() -> String:
	return DataRegistry.region_of(String(GameState.location.get("map", "")))


## "known" (visited, or where you are), "rumored" (next to a known place: shown as ???), "hidden".
static func place_state(place: Dictionary) -> String:
	var id := String(place["id"])
	if place.has("show_if_flag"):
		return "known" if GameState.flags.get(place["show_if_flag"], false) else "hidden"
	if GameState.visited.has(id) or id == here():
		return "known"
	for link: Array in DataRegistry.region_map.get("links", []):
		for side in 2:
			if link[side] == id and (GameState.visited.has(link[1 - side]) or link[1 - side] == here()):
				return "rumored"
	return "hidden"


static func places() -> Array:
	return DataRegistry.region_map.get("locations", [])


static func place(id: String) -> Dictionary:
	for p: Dictionary in places():
		if p["id"] == id:
			return p
	return {}


func place_pos(p: Dictionary) -> Vector2:
	return MAP_ORIGIN + Vector2(int(p["x"]), int(p["y"]))


## Moves the Maps cursor to the nearest shown place in a direction (within 60 degrees of it).
func move_map_cursor(dir: Vector2) -> void:
	var from := place(map_cursor)
	if from.is_empty():
		return
	var origin := Vector2(int(from["x"]), int(from["y"]))
	var best := ""
	var best_score := INF
	for p: Dictionary in places():
		if p["id"] == map_cursor or place_state(p) == "hidden":
			continue
		var delta := Vector2(int(p["x"]), int(p["y"])) - origin
		var angle := absf(delta.angle_to(dir))
		if angle > PI / 3.0:
			continue
		var score := delta.length() * (1.0 + angle)
		if score < best_score:
			best_score = score
			best = p["id"]
	if not best.is_empty():
		map_cursor = best
		queue_redraw()


## Name and description lines for the place under the cursor.
func cursor_info() -> PackedStringArray:
	var p := place(map_cursor)
	if p.is_empty():
		return PackedStringArray(["NO SIGNAL", "This place isn't on the valley map."])
	if place_state(p) == "rumored":
		return PackedStringArray(["???", "You haven't been here yet."])
	var title := String(p["name"])
	if p["id"] == here():
		title += "  (YOU ARE HERE)"
	return PackedStringArray([title, String(p["blurb"])])


# --- input -----------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if mode.is_empty():
		return
	var handled := true
	if mode == "home":
		if event.is_action_pressed("ui_left"):
			move_selection(-1, 0)
		elif event.is_action_pressed("ui_right"):
			move_selection(1, 0)
		elif event.is_action_pressed("ui_up"):
			move_selection(0, -1)
		elif event.is_action_pressed("ui_down"):
			move_selection(0, 1)
		elif event.is_action_pressed("ui_accept"):
			_pick(apps[selected][0])
		elif event.is_action_pressed("map"):
			_pick("MAP")
		elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
			_pick("")
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_tap_home((get_local_mouse_position() - home_origin()) / home_scale())
		else:
			handled = false
	else:
		if event.is_action_pressed("ui_left"):
			move_map_cursor(Vector2.LEFT)
		elif event.is_action_pressed("ui_right"):
			move_map_cursor(Vector2.RIGHT)
		elif event.is_action_pressed("ui_up"):
			move_map_cursor(Vector2.UP)
		elif event.is_action_pressed("ui_down"):
			move_map_cursor(Vector2.DOWN)
		elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu") or event.is_action_pressed("map"):
			_close_maps()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_tap_map(get_local_mouse_position() - view_offset())
		else:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _tap_home(at: Vector2) -> void:
	for i in apps.size():
		if icon_rect(i).grow(3).has_point(at):
			selected = i
			_pick(apps[i][0])
			return
	if not BODY.has_point(at):
		_pick("")


func _tap_map(at: Vector2) -> void:
	for p: Dictionary in places():
		if place_state(p) != "hidden" and place_pos(p).distance_to(at) <= 9.0:
			map_cursor = p["id"]
			queue_redraw()
			return
	if not L_SCREEN.has_point(at):
		_close_maps()


func _pick(app: String) -> void:
	AudioManager.play_sfx("select" if app.is_empty() else "confirm")
	mode = ""
	_picked.emit.call_deferred(app)


func _close_maps() -> void:
	AudioManager.play_sfx("select")
	mode = ""
	_maps_closed.emit.call_deferred()


func _process(delta: float) -> void:
	if mode == "maps":
		_blink += delta
		queue_redraw()


# --- drawing -----------------------------------------------------------------------

## The phone is laid out for the 320x180 base view. Wider or taller windows show more world around it, so the
## whole phone is shifted to stay centered (drawing and taps both use this).
const BASE_VIEW := Vector2(320, 180)


func view_offset() -> Vector2:
	return ((size - BASE_VIEW) / 2.0).floor().max(Vector2.ZERO)


## The home screen grows to fill tall views (2026-11-18, Brandon: the phone is small on a phone held upright):
## the biggest quarter step that fits the body with a little margin, never smaller than 1.
func home_scale() -> float:
	var fit := minf((size.x - 8.0) / BODY.size.x, (size.y - 8.0) / BODY.size.y)
	return clampf(floorf(fit * 4.0) / 4.0, 1.0, 4.0)


## Where the home screen's (0, 0) lands, so the phone body is centered at home_scale().
func home_origin() -> Vector2:
	return (size / 2.0 - (BODY.position + BODY.size / 2.0) * home_scale()).floor()


func _draw() -> void:
	if mode.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))  # dim the whole world, however wide
	if mode == "home":
		draw_set_transform(home_origin(), 0.0, Vector2.ONE * home_scale())
		_draw_home()
		return
	draw_set_transform(view_offset())
	if mode == "maps":
		_draw_maps()


func _text(pos: Vector2, s: String, color: Color = SCREEN_TEXT, width: float = -1,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(_font, pos, s, align, width, 8, color)


func _draw_frame(body: Rect2, screen: Rect2) -> void:
	draw_rect(body, BODY_COLOR)
	draw_rect(body, BODY_EDGE, false, 2.0)
	draw_rect(screen, SCREEN_BG)


func _draw_status_bar(screen: Rect2) -> void:
	var t := Time.get_time_dict_from_system()
	_text(screen.position + Vector2(3, 8), "%d:%02d" % [t["hour"], t["minute"]])
	var right := screen.end.x - 4
	for i in 4:  # signal bars: full outside the Dead Zone
		var h := 2 + i * 2
		var lit := i == 0 or here() != "wifi_dead_zone"
		draw_rect(Rect2(right - 30 + i * 4, screen.position.y + 8 - h, 3, h), SCREEN_TEXT if lit else BODY_EDGE)
	draw_rect(Rect2(right - 12, screen.position.y + 2, 11, 6), SCREEN_TEXT, false, 1.0)
	draw_rect(Rect2(right - 11, screen.position.y + 3, 7, 4), Color("5ce07a"))


func _draw_home() -> void:
	_draw_frame(BODY, SCREEN)
	draw_rect(Rect2(BODY.position.x + 44, BODY.position.y + 6, 24, 3), BODY_EDGE)  # speaker
	draw_circle(Vector2(BODY.get_center().x, BODY.end.y - 7), 4.0, BODY_EDGE)      # home button
	_draw_status_bar(SCREEN)
	var where := place(here())
	var line := String(where.get("name", "R-VALLEY OS")) if not where.is_empty() else "R-VALLEY OS"
	_text(Vector2(SCREEN.position.x, SCREEN.position.y + 20), line.to_upper(), ACCENT, SCREEN.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	for i in apps.size():
		var r := icon_rect(i)
		var app: Array = apps[i]
		if i == selected:
			draw_rect(r.grow(2), ACCENT, false, 1.0)
		draw_rect(r, Color(app[2]))
		draw_rect(r, Color(app[2]).darkened(0.4), false, 1.0)
		_draw_glyph(app[3], r.position + Vector2(4, 4), 2, Color.WHITE)
	var label := String(apps[selected][1])
	_text(Vector2(SCREEN.position.x, SCREEN.end.y - 6), label, SCREEN_TEXT, SCREEN.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_glyph(rows: Array, at: Vector2, scale: int, color: Color) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] == "#":
				draw_rect(Rect2(at + Vector2(x, y) * scale, Vector2(scale, scale)), color)


func _draw_maps() -> void:
	_draw_frame(L_BODY, L_SCREEN)
	draw_rect(Rect2(L_BODY.position.x + 5, L_BODY.get_center().y - 12, 3, 24), BODY_EDGE)  # speaker
	draw_circle(Vector2(L_BODY.end.x - 7, L_BODY.get_center().y), 4.0, BODY_EDGE)          # home button
	for x in range(int(L_SCREEN.position.x) + 4, int(L_SCREEN.end.x), 8):
		for y in range(int(MAP_ORIGIN.y) + 2, int(MAP_ORIGIN.y) + 138, 8):
			draw_rect(Rect2(x, y, 1, 1), GRID_DOT)
	_text(L_SCREEN.position + Vector2(4, 9), "MAPS  ·  " + String(DataRegistry.region_map.get("name", "")).to_upper(), ACCENT)
	_text(Vector2(L_SCREEN.end.x - 4 - 120, L_SCREEN.position.y + 9), "%d PLACES FOUND" % _known_count(), SCREEN_TEXT, 120,
		HORIZONTAL_ALIGNMENT_RIGHT)
	# Roads: solid copper between known places, dim when one end is still ???.
	for link: Array in DataRegistry.region_map.get("links", []):
		var a := place(link[0])
		var b := place(link[1])
		var sa := place_state(a)
		var sb := place_state(b)
		if sa == "hidden" or sb == "hidden":
			continue
		var color := TRACE if sa == "known" and sb == "known" else TRACE_DIM
		_trace(place_pos(a), place_pos(b), color)
	for exit: Dictionary in DataRegistry.region_map.get("exits", []):
		var from := place(exit["from"])
		if place_state(from) != "known":
			continue
		var start := place_pos(from)
		var end := Vector2(L_SCREEN.end.x - 3, start.y)
		_trace(start, end, TRACE_DIM)
		draw_colored_polygon(PackedVector2Array([end + Vector2(-5, -4), end, end + Vector2(-5, 4)]), Color("8090a8"))  # road out
	for p: Dictionary in places():
		var st := place_state(p)
		if st != "hidden":
			_node(p, st)
	var cur := place(here())
	if not cur.is_empty():
		var pulse := 7.0 + 2.0 * sin(_blink * 6.0)
		draw_arc(place_pos(cur), pulse, 0, TAU, 20, ACCENT, 1.0)
	var sel := place(map_cursor)
	if not sel.is_empty():
		var c := place_pos(sel)
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var tip := c + corner * 9
			draw_line(tip, tip - Vector2(corner.x * 3, 0), Color.WHITE)
			draw_line(tip, tip - Vector2(0, corner.y * 3), Color.WHITE)
	var info := cursor_info()
	draw_rect(Rect2(L_SCREEN.position.x, L_SCREEN.end.y - 24, L_SCREEN.size.x, 24), Color("101c30"))
	_text(Vector2(L_SCREEN.position.x + 4, L_SCREEN.end.y - 14), info[0].to_upper(), ACCENT)
	_text(Vector2(L_SCREEN.position.x + 4, L_SCREEN.end.y - 4), info[1], SCREEN_TEXT)


func _known_count() -> int:
	var n := 0
	for p: Dictionary in places():
		if place_state(p) == "known":
			n += 1
	return n


## Copper traces bend at right angles like a circuit board: across first, then down.
func _trace(a: Vector2, b: Vector2, color: Color) -> void:
	var corner := Vector2(b.x, a.y)
	draw_line(a, corner, color, 2.0)
	draw_line(corner, b, color, 2.0)


func _node(p: Dictionary, st: String) -> void:
	var c := place_pos(p)
	var kind := String(p["kind"])
	if st == "rumored":
		var box := Rect2(c - Vector2(5, 5), Vector2(10, 10))
		draw_rect(box, Color("2a3448"))
		draw_rect(box, Color("8090a8"), false, 1.0)
		# Center the "?" on the box from the font's real glyph size, not a guessed offset.
		var glyph := _font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
		var baseline := c.y + (_font.get_ascent(8) - _font.get_descent(8)) / 2.0
		_text(Vector2(roundf(c.x - glyph.x / 2.0), roundf(baseline)), "?", Color("c8d4e8"))
		return
	match kind:
		"town":  # a chip with pins
			for i in 3:
				draw_rect(Rect2(c.x - 5 + i * 4, c.y - 8, 2, 2), Color("b8bcc4"))
				draw_rect(Rect2(c.x - 5 + i * 4, c.y + 6, 2, 2), Color("b8bcc4"))
			draw_rect(Rect2(c - Vector2(6, 6), Vector2(12, 12)), Color("20242c"))
			draw_rect(Rect2(c - Vector2(6, 6), Vector2(12, 12)), Color("b8bcc4"), false, 1.0)
		"route":
			draw_circle(c, 3.0, TRACE)
			draw_circle(c, 1.0, SCREEN_BG)
		"wild":
			draw_circle(c, 4.0, Color("2fa86a"))
			draw_circle(c, 4.0, Color("8ff0b8"), false, 1.0)
		"dungeon":
			draw_rect(Rect2(c - Vector2(5, 5), Vector2(10, 10)), Color("6a2030"))
			draw_rect(Rect2(c - Vector2(5, 5), Vector2(10, 10)), Color("e05a6a"), false, 1.0)
		"locked":
			draw_rect(Rect2(c - Vector2(6, 6), Vector2(12, 12)), Color("3a3a48"))
			draw_rect(Rect2(c - Vector2(6, 6), Vector2(12, 12)), Color("e0c040"), false, 1.0)
			draw_rect(Rect2(c - Vector2(2, 1), Vector2(4, 4)), Color("e0c040"))
	if kind == "town" or kind == "locked":
		var label := String(p.get("short", p["name"])).to_upper()
		var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var at: Vector2
		match String(p.get("label_at", "below")):
			"above":
				at = c + Vector2(-w / 2.0, -11)
			"left":
				at = c + Vector2(-w - 13, 3)
			"right":
				at = c + Vector2(13, 3)
			_:
				at = c + Vector2(-w / 2.0, 17)
		at.x = clampf(at.x, L_SCREEN.position.x + 2, L_SCREEN.end.x - w - 2)
		_text(at, label, Color("c8d4e8"))
