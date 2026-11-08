class_name MapView
extends Node2D
## One loaded map: a TileMapLayer built from data/maps/<id>.json, plus questions movement asks
## ("can I walk here?", "what's this tile's behavior?"). All answers come from TileSet custom data.

const TILE := OverworldTiles.TILE_SIZE
const FACING_VECTORS := {"up": Vector2i.UP, "down": Vector2i.DOWN, "left": Vector2i.LEFT, "right": Vector2i.RIGHT}

var map_id: String = ""
var map_data: Dictionary = {}
var size_cells := Vector2i.ZERO
var layer: TileMapLayer
## Cells taken by NPCs and other solid events (Phase 4b fills this in).
var occupied: Dictionary = {}


## Builds the map. Returns false if the map couldn't be loaded.
func load_map(id: String) -> bool:
	map_id = id
	map_data = DataRegistry.get_map(id)
	if map_data.is_empty():
		return false
	if layer != null:
		layer.queue_free()
	layer = TileMapLayer.new()
	layer.name = "Ground"
	layer.tile_set = OverworldTiles.tile_set()
	add_child(layer)
	var legend: Dictionary = map_data["legend"]
	var rows: Array = map_data["rows"]
	size_cells = Vector2i(String(rows[0]).length(), rows.size())
	for y in rows.size():
		var row := String(rows[y])
		for x in row.length():
			layer.set_cell(Vector2i(x, y), OverworldTiles.SOURCE_ID, OverworldTiles.coords_of(legend[row[x]]))
	return true


func pixel_size() -> Vector2i:
	return size_cells * TILE


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size_cells.x and cell.y < size_cells.y


## {"name", "collision", "behavior"} for a cell. Outside the map counts as a wall.
func tile_info(cell: Vector2i) -> Dictionary:
	if not is_inside(cell):
		return {"name": "", "collision": true, "behavior": "none"}
	var data := layer.get_cell_tile_data(cell)
	if data == null:
		return {"name": "", "collision": true, "behavior": "none"}
	return {"name": data.get_custom_data("name"), "collision": data.get_custom_data("collision"),
		"behavior": data.get_custom_data("behavior")}


## Can something step onto this cell normally? Ledges only work downward (handled by the mover).
func is_walkable(cell: Vector2i) -> bool:
	var info := tile_info(cell)
	if info["collision"] or occupied.has(cell):
		return false
	return not info["behavior"] in ["water", "counter", "ledge_down"]


func spawn(spawn_name: String = "default") -> Dictionary:
	var spawns: Dictionary = map_data.get("spawns", {})
	var sp: Dictionary = spawns.get(spawn_name, spawns.get("default", {"x": 0, "y": 0, "facing": "down"}))
	return {"cell": Vector2i(int(sp["x"]), int(sp["y"])), "facing": FACING_VECTORS.get(sp.get("facing", "down"), Vector2i.DOWN)}
