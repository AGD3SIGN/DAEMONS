class_name PlayerController
extends Node2D
## The player on the overworld grid. One tile per step, tweened: walk 4 tiles/sec, run 8 (hold run).
## A quick tap turns in place; holding walks. Walls bump (with a sound), ledges hop down only.
## Movement asks the MapView, which reads TileSet custom data. The camera follows and stays inside
## the map. Input goes through the move_* / run actions, so keyboard, gamepad and touch all work.

signal stepped(cell: Vector2i, behavior: String)
signal bumped(cell: Vector2i)

const TILE := OverworldTiles.TILE_SIZE
const WALK_TIME := 0.25
const RUN_TIME := 0.125
const HOP_TIME := 0.34
const HOP_HEIGHT := 7.0
const TURN_DELAY := 0.09
const BUMP_REPEAT := 0.35
const DIRECTIONS := {"move_up": Vector2i.UP, "move_down": Vector2i.DOWN, "move_left": Vector2i.LEFT, "move_right": Vector2i.RIGHT}

var map: MapView
var cell := Vector2i.ZERO
var facing := Vector2i.DOWN
var moving := false
var input_enabled := true
var time_scale: float = 1.0  # 0 = instant (tests)
var camera: Camera2D

var _sprite: Sprite2D
var _shadow: Sprite2D
var _foot := 0
var _turn_timer := 0.0
var _bump_cooldown := 0.0
var _was_walking := false


func _ready() -> void:
	z_index = 1
	_shadow = Sprite2D.new()
	_shadow.texture = _shadow_texture()
	_shadow.centered = false
	_shadow.position = Vector2(2, 12)
	_shadow.visible = false
	add_child(_shadow)
	_sprite = Sprite2D.new()
	_sprite.texture = CharacterSprites.sheet("player", Color("d04848"), Color("583820"))
	_sprite.centered = false
	_sprite.hframes = 3
	_sprite.vframes = 4
	add_child(_sprite)
	camera = Camera2D.new()
	camera.position = Vector2(TILE / 2.0, TILE / 2.0)  # center on the tile (offset would ignore the map limits)
	add_child(camera)
	camera.make_current()
	_set_frame(0)


func setup(p_map: MapView, start_cell: Vector2i, start_facing: Vector2i) -> void:
	map = p_map
	cell = start_cell
	facing = start_facing
	position = Vector2(cell * TILE)
	moving = false
	var px := map.pixel_size()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = px.x
	camera.limit_bottom = px.y
	camera.reset_smoothing()
	_set_frame(0)


func _process(delta: float) -> void:
	_bump_cooldown = maxf(0.0, _bump_cooldown - delta)
	if moving or not input_enabled or map == null:
		return
	var dir := _held_direction()
	if dir == Vector2i.ZERO:
		_turn_timer = 0.0
		_was_walking = false
		_set_frame(0)
		return
	if dir != facing and not _was_walking:
		facing = dir  # tap = turn in place
		_set_frame(0)
		_turn_timer = TURN_DELAY
		return
	if _turn_timer > 0.0:
		_turn_timer -= delta
		return
	try_step(dir, Input.is_action_pressed("run"))


## Tries one step. Returns "moved", "hopped" or "bumped" once the move finishes.
func try_step(dir: Vector2i, running: bool = false) -> String:
	facing = dir
	var target := cell + dir
	if dir == Vector2i.DOWN and map.tile_info(target)["behavior"] == "ledge_down":
		var landing := target + Vector2i.DOWN
		if map.is_walkable(landing):
			await _hop(landing)
			return "hopped"
		_bump(target)
		return "bumped"
	if not map.is_walkable(target):
		_bump(target)
		return "bumped"
	await _walk(target, RUN_TIME if running else WALK_TIME)
	return "moved"


func _walk(target: Vector2i, duration: float) -> void:
	moving = true
	_foot = 1 - _foot
	_set_frame(1 + _foot)
	var tween := create_tween()
	tween.tween_property(self, "position", Vector2(target * TILE), duration * time_scale)
	tween.parallel().tween_callback(_set_frame.bind(0)).set_delay(duration * time_scale * 0.5)
	await tween.finished
	_arrive(target)


func _hop(landing: Vector2i) -> void:
	moving = true
	_shadow.visible = true
	_set_frame(1 + _foot)
	var tween := create_tween()
	tween.tween_property(self, "position", Vector2(landing * TILE), HOP_TIME * time_scale)
	tween.parallel().tween_method(_hop_arc, 0.0, 1.0, HOP_TIME * time_scale)
	await tween.finished
	_sprite.position.y = 0
	_shadow.visible = false
	_arrive(landing)


func _hop_arc(t: float) -> void:
	_sprite.position.y = -roundf(sin(t * PI) * HOP_HEIGHT)


func _arrive(target: Vector2i) -> void:
	cell = target
	position = Vector2(cell * TILE)
	moving = false
	_was_walking = true
	_set_frame(0)
	stepped.emit(cell, map.tile_info(cell)["behavior"])


func _bump(target: Vector2i) -> void:
	_was_walking = false
	if _bump_cooldown > 0.0:
		return
	_bump_cooldown = BUMP_REPEAT
	_foot = 1 - _foot
	_set_frame(1 + _foot)  # walk in place
	AudioManager.play_sfx("bump")
	bumped.emit(target)


func _held_direction() -> Vector2i:
	var held: Array[Vector2i] = []
	for action: String in DIRECTIONS:
		if Input.is_action_pressed(action):
			held.append(DIRECTIONS[action])
	if held.is_empty():
		return Vector2i.ZERO
	return facing if facing in held else held[0]


func _set_frame(frame: int) -> void:
	if _sprite != null:
		_sprite.frame = CharacterSprites.frame_index(facing, frame)


static func _shadow_texture() -> Texture2D:
	var img := Image.create(12, 5, false, Image.FORMAT_RGBA8)
	for y in 5:
		for x in 12:
			if Vector2((x - 5.5) / 6.0, (y - 2.0) / 2.5).length() <= 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0.3))
	return ImageTexture.create_from_image(img)
