class_name BarrierEvent
extends MapEvent
## A laser door that blocks its tile until the right flags are set. Open when every flag in
## open_flags is set and none in closed_flags is. Used for the Department puzzle (patch panels
## set flags; the door re-checks after every dialogue).

@export var open_flags: PackedStringArray = []
@export var closed_flags: PackedStringArray = []

var _sprite: Sprite2D
var _is_open := false


func configure(data: Dictionary) -> void:
	super.configure(data)
	open_flags = PackedStringArray(data.get("open_flags", []))
	closed_flags = PackedStringArray(data.get("closed_flags", []))


func _ready() -> void:
	z_index = 1
	_sprite = Sprite2D.new()
	_sprite.texture = _laser_texture()
	_sprite.centered = false
	add_child(_sprite)
	refresh(false)


func should_be_open() -> bool:
	for flag in open_flags:
		if not GameState.flags.get(flag, false):
			return false
	for flag in closed_flags:
		if GameState.flags.get(flag, false):
			return false
	return true


func is_open() -> bool:
	return _is_open


## Re-checks the flags. Returns true if the door just opened.
func refresh(announce: bool = true) -> bool:
	var was_open := _is_open
	_is_open = should_be_open()
	_sprite.visible = not _is_open
	if _is_open:
		world.map.occupied.erase(cell)
	else:
		world.map.occupied[cell] = self
	if announce and _is_open and not was_open:
		AudioManager.play_sfx("confirm")
	return _is_open and not was_open


static func _laser_texture() -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			if x == 0 or x == 15:
				img.set_pixel(x, y, Color("505868"))
			elif y % 4 == 1:
				img.set_pixel(x, y, Color(1.0, 0.25, 0.25, 0.95))
			elif y % 4 == 2:
				img.set_pixel(x, y, Color(1.0, 0.6, 0.6, 0.6))
	return ImageTexture.create_from_image(img)
