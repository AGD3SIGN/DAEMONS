class_name NpcEvent
extends MapEvent
## A person on the map. Solid (you can't walk through them). Press A facing them to talk: they
## turn to face you and run their dialogue. Optional wandering within 2 tiles of where they start.
## move_path() walks them along a list of directions (used by the move_npc dialogue command).
## Phase 6 adds trainer data (line of sight, battle).

const WALK_TIME := 0.28
const WANDER_RADIUS := 2
const FACINGS := {"up": Vector2i.UP, "down": Vector2i.DOWN, "left": Vector2i.LEFT, "right": Vector2i.RIGHT}

@export var npc_id: String = ""
@export var dialogue_id: String = ""
@export var facing: Vector2i = Vector2i.DOWN
@export var wander: bool = false
@export var shirt: Color = Color("4878c8")
@export var hair: Color = Color("402818")

var home := Vector2i.ZERO
var moving := false

var _sprite: Sprite2D
var _wander_timer := 0.0


func configure(data: Dictionary) -> void:
	super.configure(data)
	npc_id = data["id"]
	dialogue_id = data["dialogue"]
	facing = FACINGS.get(data.get("facing", "down"), Vector2i.DOWN)
	wander = data.get("wander", false)
	var look: Dictionary = data.get("look", {})
	shirt = Color(look.get("shirt", "#4878c8"))
	hair = Color(look.get("hair", "#402818"))
	home = cell


func _ready() -> void:
	z_index = 1
	_sprite = Sprite2D.new()
	_sprite.texture = CharacterSprites.sheet("npc_" + shirt.to_html(false) + hair.to_html(false), shirt, hair)
	_sprite.centered = false
	_sprite.hframes = 3
	_sprite.vframes = 4
	add_child(_sprite)
	_set_frame(0)
	_reset_wander_timer()
	if world != null:
		world.map.occupied[cell] = self


func can_interact() -> bool:
	return not moving


func interact() -> void:
	face(world.player.cell - cell)
	await world.run_dialogue(dialogue_id, self)


func face(direction: Vector2i) -> void:
	if direction != Vector2i.ZERO:
		facing = direction.clampi(-1, 1)
	_set_frame(0)


## Walks along ["up", "left", ...]. Stops early if something blocks the way.
func move_path(path: Array) -> void:
	for dir_name: Variant in path:
		if not await step(FACINGS.get(dir_name, Vector2i.ZERO)):
			face(FACINGS.get(dir_name, facing))
			return


## One step. Returns false (and just turns) if the cell is blocked.
func step(dir: Vector2i) -> bool:
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
	_set_frame(1)
	var tween := create_tween()
	tween.tween_property(self, "position", Vector2(target * OverworldTiles.TILE_SIZE), WALK_TIME * world.time_scale)
	await tween.finished
	_set_frame(0)
	moving = false
	return true


func _process(delta: float) -> void:
	if not wander or moving or world == null or not world.is_idle():
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
