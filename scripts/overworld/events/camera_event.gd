class_name CameraEvent
extends MapEvent
## A security camera (SecOps Department). Mounted on a wall tile, it watches a straight line of floor in front of
## it, drawn as a red beam that stops at the first thing you can't walk through. With "turns" it rotates to the next
## facing every "turn_every" steps you take. If its beam covers you after it turns, the Overworld walks you back
## to "send_to" (a spawn point on this map). "off_flag" switches it off for good.
##
##   {"type": "camera", "x": 3, "y": 9, "facing": "down", "range": 5, "turns": ["down", "right"],
##    "turn_every": 2, "send_to": "entrance", "dialogue": "caught_by_camera", "off_flag": "cams_disabled"}

const BEAM := Color(1.0, 0.2, 0.25, 0.28)
const BEAM_EDGE := Color(1.0, 0.35, 0.35, 0.55)

var facing := Vector2i.DOWN
var sight_range := 4
var turns: Array[Vector2i] = []
var turn_every := 1
var send_to := "default"
var dialogue_id := ""
var off_flag := ""

var _turn_index := 0
var _steps := 0
var _flash := 0.0


func configure(data: Dictionary) -> void:
	super.configure(data)
	facing = MapView.FACING_VECTORS.get(data.get("facing", "down"), Vector2i.DOWN)
	sight_range = int(data.get("range", 4))
	for f: Variant in data.get("turns", []):
		turns.append(MapView.FACING_VECTORS.get(f, Vector2i.DOWN))
	turn_every = maxi(1, int(data.get("turn_every", 1)))
	send_to = String(data.get("send_to", "default"))
	dialogue_id = String(data.get("dialogue", ""))
	off_flag = String(data.get("off_flag", ""))
	z_index = 2
	reset()


func is_on() -> bool:
	return off_flag.is_empty() or not GameState.flags.get(off_flag, false)


## Back to its first facing (when you're caught, every camera restarts its sweep).
func reset() -> void:
	_steps = 0
	_turn_index = 0
	if not turns.is_empty():
		facing = turns[0]
	queue_redraw()


func refresh() -> void:
	queue_redraw()


## Called once per player step: maybe turn.
func on_player_step() -> void:
	if turns.size() < 2:
		return
	_steps += 1
	if _steps % turn_every == 0:
		_turn_index = (_turn_index + 1) % turns.size()
		facing = turns[_turn_index]
		queue_redraw()


## The floor cells this camera can see right now.
func watched_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not is_on() or world == null or world.map == null:
		return out
	for distance in range(1, sight_range + 1):
		var c := cell + facing * distance
		if world.map.tile_info(c)["collision"]:
			break
		out.append(c)
	return out


func sees(target: Vector2i) -> bool:
	return target in watched_cells()


func flash() -> void:
	_flash = 0.35 if Settings.calm_effects() else 1.0  # SHAKE & FLASH off: a dim glow, no flicker
	var tween := create_tween()
	tween.tween_property(self, "_flash", 0.0, 0.5 * (world.time_scale if world != null else 1.0))
	tween.tween_callback(queue_redraw)
	for i in (1 if Settings.calm_effects() else 6):
		await get_tree().create_timer(0.08 * (world.time_scale if world != null else 1.0)).timeout
		queue_redraw()


func _draw() -> void:
	var t := OverworldTiles.TILE_SIZE
	var on := is_on()
	if on:
		var color := BEAM.lerp(Color(1, 0.1, 0.1, 0.6), _flash)
		for c in watched_cells():
			var r := Rect2(Vector2(c - cell) * t, Vector2(t, t))
			draw_rect(r, color)
			draw_rect(r, BEAM_EDGE, false, 1.0)
	# The camera: a gray box with a lens pointing the way it faces (dark when switched off).
	var center := Vector2(t, t) / 2.0
	draw_rect(Rect2(center - Vector2(5, 4), Vector2(10, 8)), Color("2a2e38"))
	draw_rect(Rect2(center - Vector2(5, 4), Vector2(10, 8)), Color("9aa0ac"), false, 1.0)
	draw_circle(center + Vector2(facing) * 4.0, 2.5, Color("ff4048") if on else Color("505460"))
