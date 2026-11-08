class_name OverworldTiles
extends RefCounted
## Builds the overworld TileSet from the tileset PNG + data/tiles.json. Each tile carries custom
## data ("name", "collision", "behavior") that movement reads; no per-tile scripts.
## Swap assets/tiles/placeholder_overworld.png for real art (same 16x16 grid) and nothing else changes.

const TILE_SIZE := 16
const TEXTURE_PATH := "res://assets/tiles/placeholder_overworld.png"
const SOURCE_ID := 0

static var _tile_set: TileSet
static var _coords_by_name: Dictionary = {}


static func tile_set() -> TileSet:
	if _tile_set != null:
		return _tile_set
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "name")
	ts.set_custom_data_layer_type(0, TYPE_STRING)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(1, "collision")
	ts.set_custom_data_layer_type(1, TYPE_BOOL)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(2, "behavior")
	ts.set_custom_data_layer_type(2, TYPE_STRING)

	var source := TileSetAtlasSource.new()
	source.texture = load(TEXTURE_PATH)
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	ts.add_source(source, SOURCE_ID)
	_coords_by_name = {}
	for tile_name: String in DataRegistry.tiles:
		var t: Dictionary = DataRegistry.tiles[tile_name]
		var coords := Vector2i(int(t["atlas"][0]), int(t["atlas"][1]))
		source.create_tile(coords)
		var data := source.get_tile_data(coords, 0)
		data.set_custom_data("name", tile_name)
		data.set_custom_data("collision", bool(t["collision"]))
		data.set_custom_data("behavior", String(t["behavior"]))
		_coords_by_name[tile_name] = coords
	_tile_set = ts
	return ts


static func coords_of(tile_name: String) -> Vector2i:
	tile_set()
	return _coords_by_name.get(tile_name, Vector2i(-1, -1))
