extends SceneTree
## Draws the placeholder overworld tileset (16 tiles, 16x16 each, 8 per row) to
## res://assets/tiles/placeholder_overworld.png. Run from the repo root:
##   godot --headless -s res://tools/build_placeholder_tiles.gd
## Tile names/collision/behavior live in data/tiles.json; the order here must match its atlas coords.
## Replace the PNG with real art any time; keep the same grid.

const T := 16
const OUT := "res://assets/tiles/placeholder_overworld.png"

const GRASS := Color("78c850")
const GRASS_DARK := Color("58a838")
const PATH := Color("d8c088")
const PATH_DARK := Color("b8a068")
const WATER := Color("5890e0")
const WATER_LIGHT := Color("90c0f8")
const TREE := Color("287838")
const TREE_DARK := Color("185028")
const TRUNK := Color("806040")
const WOOD := Color("a87848")
const WOOD_DARK := Color("704828")
const WALL := Color("ece4cc")
const WALL_DARK := Color("b8b098")
const GLASS := Color("88c8f0")
const ROOF_RED := Color("d05040")
const ROOF_BLUE := Color("4878c8")
const FLOOR := Color("d8b880")
const CABLES: Array[Color] = [Color("404858"), Color("3870c0"), Color("e08030")]

var img: Image


func _init() -> void:
	img = Image.create(T * 8, T * 2, false, Image.FORMAT_RGBA8)
	var painters: Array[Callable] = [_grass, _path, _cable_tangle, _water, _tree, _fence, _flowers, _roof_red,
		_roof_blue, _wall, _window, _door, _ledge, _sign, _floor, _counter]
	for i in painters.size():
		painters[i].call(Vector2i(i % 8, i / 8) * T)
	var err := img.save_png(ProjectSettings.globalize_path(OUT))
	print("Saved %s: %s" % [OUT, error_string(err)])
	quit()


func _px(o: Vector2i, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < T and y < T:
		img.set_pixel(o.x + x, o.y + y, c)


func _fill(o: Vector2i, c: Color) -> void:
	for y in T:
		for x in T:
			_px(o, x, y, c)


func _rect(o: Vector2i, r: Rect2i, c: Color) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_px(o, x, y, c)


func _grass(o: Vector2i) -> void:
	_fill(o, GRASS)
	for p: Vector2i in [Vector2i(2, 3), Vector2i(3, 2), Vector2i(10, 5), Vector2i(11, 4), Vector2i(6, 11), Vector2i(7, 10), Vector2i(13, 13), Vector2i(12, 12)]:
		_px(o, p.x, p.y, GRASS_DARK)


func _path(o: Vector2i) -> void:
	_fill(o, PATH)
	for p: Vector2i in [Vector2i(3, 4), Vector2i(11, 2), Vector2i(7, 9), Vector2i(13, 12), Vector2i(2, 13)]:
		_px(o, p.x, p.y, PATH_DARK)
		_px(o, p.x + 1, p.y, PATH_DARK)


func _cable_tangle(o: Vector2i) -> void:
	_grass(o)
	for i in CABLES.size():
		var phase := i * 5
		for x in T:
			var y := 3 + i * 4 + int(round(2.0 * sin((x + phase) * 0.8)))
			_px(o, x, y, CABLES[i])
			_px(o, x, y + 1, CABLES[i].darkened(0.3))


func _water(o: Vector2i) -> void:
	_fill(o, WATER)
	for x in range(2, 7):
		_px(o, x, 4, WATER_LIGHT)
	for x in range(9, 14):
		_px(o, x, 11, WATER_LIGHT)


func _tree(o: Vector2i) -> void:
	_grass(o)
	_rect(o, Rect2i(6, 11, 4, 5), TRUNK)
	for y in T:
		for x in T:
			var d := Vector2(x - 7.5, y - 6.5).length()
			if d <= 7.0:
				_px(o, x, y, TREE_DARK if d > 6.0 or (x + y) % 5 == 0 else TREE)


func _fence(o: Vector2i) -> void:
	_grass(o)
	_rect(o, Rect2i(0, 5, 16, 2), WOOD)
	_rect(o, Rect2i(0, 10, 16, 2), WOOD)
	for x in [2, 13]:
		_rect(o, Rect2i(x, 3, 2, 12), WOOD_DARK)


func _flowers(o: Vector2i) -> void:
	_grass(o)
	for p: Array in [[Vector2i(3, 3), Color("f05050")], [Vector2i(11, 4), Color("f8d040")], [Vector2i(6, 10), Color("f8f8f8")], [Vector2i(12, 12), Color("f05050")]]:
		var c: Vector2i = p[0]
		_px(o, c.x, c.y, p[1])
		_px(o, c.x - 1, c.y, p[1])
		_px(o, c.x + 1, c.y, p[1])
		_px(o, c.x, c.y - 1, p[1])
		_px(o, c.x, c.y + 1, Color("f8e080"))


func _roof(o: Vector2i, c: Color) -> void:
	_fill(o, c)
	for y in [3, 7, 11, 15]:
		for x in T:
			_px(o, x, y, c.darkened(0.3))
	for y in range(0, 16, 4):
		var shift := 0 if (y / 4) % 2 == 0 else 4
		for x in range(shift, 16, 8):
			_px(o, x, y + 1, c.darkened(0.2))
			_px(o, x, y + 2, c.darkened(0.2))


func _roof_red(o: Vector2i) -> void:
	_roof(o, ROOF_RED)


func _roof_blue(o: Vector2i) -> void:
	_roof(o, ROOF_BLUE)


func _wall(o: Vector2i) -> void:
	_fill(o, WALL)
	_rect(o, Rect2i(0, 14, 16, 2), WALL_DARK)
	_rect(o, Rect2i(0, 0, 16, 1), WALL_DARK)


func _window(o: Vector2i) -> void:
	_wall(o)
	_rect(o, Rect2i(3, 3, 10, 8), WALL_DARK)
	_rect(o, Rect2i(4, 4, 8, 6), GLASS)
	_rect(o, Rect2i(4, 4, 3, 2), Color.WHITE)


func _door(o: Vector2i) -> void:
	_wall(o)
	_rect(o, Rect2i(3, 2, 10, 14), WOOD_DARK)
	_rect(o, Rect2i(4, 3, 8, 13), WOOD)
	_px(o, 10, 9, Color("f8d040"))


func _ledge(o: Vector2i) -> void:
	_grass(o)
	_rect(o, Rect2i(0, 10, 16, 3), GRASS_DARK)
	_rect(o, Rect2i(0, 13, 16, 3), Color("487830"))
	for x in range(0, 16, 3):
		_px(o, x, 10, GRASS)


func _sign(o: Vector2i) -> void:
	_grass(o)
	_rect(o, Rect2i(7, 9, 2, 6), WOOD_DARK)
	_rect(o, Rect2i(2, 3, 12, 7), WOOD_DARK)
	_rect(o, Rect2i(3, 4, 10, 5), WOOD)
	for x in range(4, 12, 2):
		_px(o, x, 6, WOOD_DARK)


func _floor(o: Vector2i) -> void:
	_fill(o, FLOOR)
	for y in [3, 7, 11, 15]:
		for x in T:
			_px(o, x, y, FLOOR.darkened(0.15))


func _counter(o: Vector2i) -> void:
	_floor(o)
	_rect(o, Rect2i(0, 2, 16, 10), WOOD_DARK)
	_rect(o, Rect2i(0, 2, 16, 3), Color("e0d8c8"))
