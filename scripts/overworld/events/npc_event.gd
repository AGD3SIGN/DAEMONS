class_name NpcEvent
extends MapEvent
## A person on the map. Solid (you can't walk through them). Press A facing them to talk: they
## turn to face you and run their dialogue. Optional wandering within 2 tiles of where they start.
## move_path() walks them along a list of directions (used by the move_npc dialogue command).
## Trainers ("trainer": id from data/trainers) spot you along the way they face (up to "sight"
## tiles), walk over and battle. Once beaten they say their "after" line. "hide_if_flag" removes
## the NPC when that flag is set (e.g. a gatekeeper who steps aside for good). "hidden": true keeps
## them off the map (not drawn, not solid) until a show_npc cutscene step brings them in (e.g. Kevin
## bursting through the Help Desk door).

const WALK_TIME := 0.28
const RUN_TIME := 0.14
const WANDER_RADIUS := 2
const FACINGS := {"up": Vector2i.UP, "down": Vector2i.DOWN, "left": Vector2i.LEFT, "right": Vector2i.RIGHT}

@export var npc_id: String = ""
@export var dialogue_id: String = ""
@export var facing: Vector2i = Vector2i.DOWN
@export var wander: bool = false
@export var trainer_id: String = ""
@export var hide_if_flag: String = ""
@export var off_map: bool = false  # map data: "hidden": true
@export var shirt: Color = Color("4878c8")
@export var hair: Color = Color("402818")
## Character art id (assets/sprites/characters/<id>.png); empty = placeholder from shirt and hair.
@export var sprite_id: String = ""

var home := Vector2i.ZERO
var moving := false

var _sprite: Sprite2D
var _wander_timer := 0.0


func configure(data: Dictionary) -> void:
	super.configure(data)
	npc_id = data["id"]
	dialogue_id = data.get("dialogue", "")
	trainer_id = data.get("trainer", "")
	hide_if_flag = data.get("hide_if_flag", "")
	off_map = data.get("hidden", false)
	facing = FACINGS.get(data.get("facing", "down"), Vector2i.DOWN)
	wander = data.get("wander", false)
	var look: Dictionary = data.get("look", {})
	shirt = Color(look.get("shirt", "#4878c8"))
	hair = Color(look.get("hair", "#402818"))
	sprite_id = look.get("sprite", "")
	home = cell


func _ready() -> void:
	z_index = CharacterSprites.depth(cell.y)
	_sprite = Sprite2D.new()
	var sheet_id := sprite_id if not sprite_id.is_empty() else "npc_" + shirt.to_html(false) + hair.to_html(false)
	CharacterSprites.place(_sprite, CharacterSprites.sheet(sheet_id, shirt, hair))
	add_child(_sprite)
	_set_frame(0)
	_reset_wander_timer()
	visible = not off_map
	if world != null and not off_map:
		world.map.occupied[cell] = self


func can_interact() -> bool:
	return not moving and not off_map


## Brings a hidden NPC onto the map (drawn and solid). Used by the show_npc cutscene step.
func appear() -> void:
	off_map = false
	visible = true
	if world != null:
		world.map.occupied[cell] = self


## Takes the NPC off the map again (hide_npc).
func disappear() -> void:
	off_map = true
	visible = false
	if world != null and world.map.occupied.get(cell) == self:
		world.map.occupied.erase(cell)


## Directions to a free tile next to the player (shortest walk), or [] if there's no way.
func path_to_player() -> Array:
	var goal := world.player.cell
	var dirs := {Vector2i.UP: "up", Vector2i.DOWN: "down", Vector2i.LEFT: "left", Vector2i.RIGHT: "right"}
	var came_from := {cell: null}
	var queue: Array[Vector2i] = [cell]
	while not queue.is_empty():
		var at: Vector2i = queue.pop_front()
		if (at - goal).length_squared() == 1:
			var path: Array = []
			while came_from[at] != null:
				var prev: Vector2i = came_from[at]
				path.push_front(dirs[at - prev])
				at = prev
			return path
		for d: Vector2i in dirs:
			var next := at + d
			if came_from.has(next) or next == goal:
				continue
			var blocker: Variant = world.map.occupied.get(next)
			if not world.map.is_walkable(next) or (blocker != null and blocker != self):
				continue
			came_from[next] = at
			queue.append(next)
	return []


func interact() -> void:
	face(world.player.cell - cell)
	if is_undefeated_trainer():
		await world.engage_trainer(self, false)
	elif not trainer_id.is_empty() and dialogue_id.is_empty():
		await world.show_message("%s: %s" % [trainer_data()["name"], trainer_data()["after"]])
	else:
		await world.run_dialogue(dialogue_id, self)


func trainer_data() -> Dictionary:
	return DataRegistry.trainers.get(trainer_id, {})


func is_undefeated_trainer() -> bool:
	return not trainer_id.is_empty() and not GameState.flags.get(BattleScene.trainer_flag(trainer_id), false)


func sight() -> int:
	return int(trainer_data().get("sight", 0))


## The "!" when a trainer spots you.
func show_alert(duration: float) -> void:
	var bubble := Label.new()
	bubble.text = "!"
	bubble.theme = UiTheme.get_theme()
	bubble.add_theme_color_override("font_color", Color("e04040"))
	bubble.position = Vector2(4, -12)
	add_child(bubble)
	AudioManager.play_sfx("confirm")
	await get_tree().create_timer(duration).timeout
	bubble.queue_free()


func face(direction: Vector2i) -> void:
	if direction != Vector2i.ZERO:
		facing = direction.clampi(-1, 1)
	_set_frame(0)


## Walks along ["up", "left", ...] (or runs, twice as fast). Stops early if something blocks the way.
func move_path(path: Array, run: bool = false) -> void:
	for dir_name: Variant in path:
		if not await step(FACINGS.get(dir_name, Vector2i.ZERO), run):
			face(FACINGS.get(dir_name, facing))
			return


## One step. Returns false (and just turns) if the cell is blocked.
func step(dir: Vector2i, run: bool = false) -> bool:
	if dir == Vector2i.ZERO:
		return false
	facing = dir
	var target := cell + dir
	if not world.map.is_walkable(target) or target == world.player.cell:
		_set_frame(0)
		return false
	moving = true
	world.map.occupied.erase(cell)
	world.map.occupied[target] = self
	cell = target
	z_index = CharacterSprites.depth(cell.y)
	_set_frame(1)
	var tween := create_tween()
	tween.tween_property(self, "position", Vector2(target * OverworldTiles.TILE_SIZE), (RUN_TIME if run else WALK_TIME) * world.time_scale)
	await tween.finished
	_set_frame(0)
	moving = false
	return true


func _process(delta: float) -> void:
	if off_map or not wander or is_undefeated_trainer() or moving or world == null or not world.is_idle():
		return
	_wander_timer -= delta
	if _wander_timer > 0.0:
		return
	_reset_wander_timer()
	var dir: Vector2i = FACINGS.values().pick_random()
	if (cell + dir - home).length() > WANDER_RADIUS:
		face(dir)
		return
	step(dir)


func _reset_wander_timer() -> void:
	_wander_timer = randf_range(1.5, 4.0)


func _set_frame(frame: int) -> void:
	if _sprite != null:
		_sprite.frame = CharacterSprites.frame_index(facing, frame)
