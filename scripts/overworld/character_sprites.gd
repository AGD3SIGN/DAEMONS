class_name CharacterSprites
extends RefCounted
## Placeholder overworld character sheets: 3 frames (idle, step A, step B) x 4 rows
## (down, up, left, right), 16x16 each. Real art: assets/sprites/characters/<id>.png, same layout.

const SIZE := 16
const ROWS := {Vector2i.DOWN: 0, Vector2i.UP: 1, Vector2i.LEFT: 2, Vector2i.RIGHT: 3}
const ART_DIR := "res://assets/sprites/characters/"

static var _cache: Dictionary = {}


static func sheet(id: String, shirt: Color, hair: Color) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var path := ART_DIR + id + ".png"
	var tex: Texture2D
	if ResourceLoader.exists(path):
		tex = load(path)
	else:
		tex = ImageTexture.create_from_image(_draw_sheet(shirt, hair))
	_cache[id] = tex
	return tex


static func frame_index(facing: Vector2i, frame: int) -> int:
	return int(ROWS.get(facing, 0)) * 3 + frame


static func _draw_sheet(shirt: Color, hair: Color) -> Image:
	var img := Image.create(SIZE * 3, SIZE * 4, false, Image.FORMAT_RGBA8)
	var skin := Color("f0c8a0")
	var outline := Color("282830")
	var pants := Color("384868")
	for row in 4:
		for frame in 3:
			var o := Vector2i(frame * SIZE, row * SIZE)
			# legs: idle together, steps alternate
			var left_leg := 0 if frame == 0 else (-1 if frame == 1 else 1)
			_rect(img, o, Rect2i(5, 12 + mini(0, left_leg), 3, 3 + absi(left_leg)), pants)
			_rect(img, o, Rect2i(8, 12 + mini(0, -left_leg), 3, 3 + absi(left_leg)), pants)
			_rect(img, o, Rect2i(4, 7, 8, 6), shirt)          # body
			_rect(img, o, Rect2i(4, 1, 8, 7), skin)           # head
			_rect(img, o, Rect2i(4, 1, 8, 2), hair)           # hair top
			match row:
				0:  # facing down: eyes
					_rect(img, o, Rect2i(5, 4, 1, 2), outline)
					_rect(img, o, Rect2i(10, 4, 1, 2), outline)
				1:  # facing up: back of head
					_rect(img, o, Rect2i(4, 1, 8, 6), hair)
				2:  # left
					_rect(img, o, Rect2i(8, 1, 4, 5), hair)
					_rect(img, o, Rect2i(5, 4, 1, 2), outline)
				3:  # right
					_rect(img, o, Rect2i(4, 1, 4, 5), hair)
					_rect(img, o, Rect2i(10, 4, 1, 2), outline)
			_outline(img, o, outline)
	return img


static func _rect(img: Image, o: Vector2i, r: Rect2i, c: Color) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if x >= 0 and y >= 0 and x < SIZE and y < SIZE:
				img.set_pixel(o.x + x, o.y + y, c)


static func _outline(img: Image, o: Vector2i, c: Color) -> void:
	var edge: Array[Vector2i] = []
	for y in SIZE:
		for x in SIZE:
			if img.get_pixel(o.x + x, o.y + y).a > 0.0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < SIZE and n.y < SIZE and img.get_pixel(o.x + n.x, o.y + n.y).a > 0.0 \
						and img.get_pixel(o.x + n.x, o.y + n.y) != c:
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		img.set_pixel(o.x + p.x, o.y + p.y, c)
