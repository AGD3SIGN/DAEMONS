extends GutTest
## Phase 4a: tiles from TileSet custom data, map loading/validation, grid movement on
## Onboarding Town (instant moves at time_scale 0).

var _map: MapView
var _player: PlayerController


func before_each() -> void:
	_map = MapView.new()
	add_child_autofree(_map)
	assert_true(_map.load_map("onboarding_town"))
	_player = PlayerController.new()
	add_child_autofree(_player)
	_player.time_scale = 0.0
	_player.input_enabled = false


func _place(cell: Vector2i, facing: Vector2i = Vector2i.DOWN) -> void:
	_player.setup(_map, cell, facing)


# --- tiles -------------------------------------------------------------------

func test_tileset_custom_data() -> void:
	var ts := OverworldTiles.tile_set()
	assert_eq(ts.tile_size, Vector2i(16, 16))
	assert_eq(OverworldTiles.coords_of("tree"), Vector2i(4, 0))
	var source: TileSetAtlasSource = ts.get_source(OverworldTiles.SOURCE_ID)
	assert_eq(source.get_tiles_count(), 16)
	var tangle := source.get_tile_data(OverworldTiles.coords_of("cable_tangle"), 0)
	assert_eq(tangle.get_custom_data("behavior"), "hot_zone")
	assert_true(source.get_tile_data(OverworldTiles.coords_of("tree"), 0).get_custom_data("collision"))


# --- maps --------------------------------------------------------------------

func test_every_map_loads() -> void:
	var ids := DataRegistry.map_ids()
	assert_true("onboarding_town" in ids)
	for id in ids:
		assert_false(DataRegistry.get_map(id).is_empty(), id + " should load cleanly")


func test_map_validator_catches_problems() -> void:
	var good: Dictionary = DataRegistry.get_map("onboarding_town").duplicate(true)
	var bad := good.duplicate(true)
	bad["rows"][3] = String(bad["rows"][3]).left(10)
	assert_string_contains(" ".join(DataRegistry.check_map(bad, "onboarding_town")), "row 3 is 10 wide")
	bad = good.duplicate(true)
	bad["rows"][4] = "?" + String(bad["rows"][4]).substr(1)
	assert_string_contains(" ".join(DataRegistry.check_map(bad, "onboarding_town")), "unknown character '?'")
	bad = good.duplicate(true)
	bad["spawns"]["default"] = {"x": 0, "y": 0, "facing": "down"}
	assert_string_contains(" ".join(DataRegistry.check_map(bad, "onboarding_town")), "can't stand on")
	bad = good.duplicate(true)
	bad["legend"]["T"] = "palm_tree"
	assert_string_contains(" ".join(DataRegistry.check_map(bad, "onboarding_town")), "unknown tile 'palm_tree'")
	assert_eq(DataRegistry.check_map(good, "onboarding_town").size(), 0)


func test_onboarding_town_layout() -> void:
	assert_eq(_map.size_cells, Vector2i(30, 25))
	assert_eq(_map.pixel_size(), Vector2i(480, 400))
	assert_eq(_map.tile_info(Vector2i(7, 7))["behavior"], "door", "player's front door")
	assert_eq(_map.tile_info(Vector2i(20, 18))["behavior"], "door", "Help Desk door")
	assert_eq(_map.tile_info(Vector2i(14, 0))["name"], "path", "exit north to Route 1")
	assert_true(_map.tile_info(Vector2i(-1, 5))["collision"], "outside the map is a wall")
	var spawn := _map.spawn()
	assert_eq(spawn["cell"], Vector2i(7, 8))
	assert_true(_map.is_walkable(spawn["cell"]))


# --- movement ----------------------------------------------------------------

func test_walk_one_tile_per_step() -> void:
	_place(Vector2i(7, 8))
	assert_eq(await _player.try_step(Vector2i.DOWN), "moved")
	assert_eq(_player.cell, Vector2i(7, 9))
	assert_eq(_player.position, Vector2(7 * 16, 9 * 16))
	assert_eq(_player.facing, Vector2i.DOWN)


func test_trees_and_water_block() -> void:
	_place(Vector2i(2, 11), Vector2i.DOWN)
	watch_signals(_player)
	assert_eq(await _player.try_step(Vector2i.LEFT), "bumped")
	assert_eq(_player.cell, Vector2i(2, 11))
	assert_eq(_player.facing, Vector2i.LEFT, "turns to face the wall")
	assert_signal_emitted(_player, "bumped")
	_place(Vector2i(9, 16))
	assert_eq(await _player.try_step(Vector2i.LEFT), "bumped", "can't walk into the pond")


func test_ledges_hop_down_but_not_up() -> void:
	_place(Vector2i(6, 9))
	assert_eq(await _player.try_step(Vector2i.DOWN), "hopped")
	assert_eq(_player.cell, Vector2i(6, 11), "jumps over the ledge")
	assert_eq(await _player.try_step(Vector2i.UP), "bumped", "can't climb back up")
	assert_eq(_player.cell, Vector2i(6, 11))


func test_stepping_into_a_cable_tangle_reports_hot_zone() -> void:
	_place(Vector2i(3, 5))
	watch_signals(_player)
	await _player.try_step(Vector2i.UP)
	assert_signal_emitted_with_parameters(_player, "stepped", [Vector2i(3, 4), "hot_zone"])


func test_camera_stays_inside_the_map() -> void:
	_place(Vector2i(7, 8))
	assert_eq(_player.camera.limit_right, 480)
	assert_eq(_player.camera.limit_bottom, 400)
	assert_eq(_player.camera.limit_left, 0)


# --- scene, sprites, sound ---------------------------------------------------

func test_overworld_scene_loads_town() -> void:
	SceneRouter.params = {"map": "onboarding_town"}
	var world: Overworld = load(Overworld.SCENE).instantiate()
	add_child_autofree(world)
	assert_eq(world.map.map_id, "onboarding_town")
	assert_eq(world.player.cell, Vector2i(7, 8))
	assert_eq(GameState.location, {"map": "onboarding_town", "x": 7, "y": 8})
	SceneRouter.params = {}
	GameState.location.clear()


func test_character_sheet() -> void:
	var sheet := CharacterSprites.sheet("player", Color.RED, Color.BROWN)
	assert_eq(sheet.get_size(), Vector2(48, 64))
	assert_eq(CharacterSprites.frame_index(Vector2i.RIGHT, 2), 11)


func test_placeholder_sfx() -> void:
	AudioManager.play_sfx("bump")
	AudioManager.play_sfx("no_such_sound")
	var bump: AudioStreamWAV = AudioManager._sfx_stream("bump")
	assert_not_null(bump)
	assert_gt(bump.data.size(), 1000)
