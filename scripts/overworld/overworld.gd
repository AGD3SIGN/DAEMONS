class_name Overworld
extends Node2D
## The overworld scene: loads a map, places the player at a spawn point, shows the area name.
## Open it with SceneRouter.goto(Overworld.SCENE, {"map": "onboarding_town", "spawn": "default"}).
## Opened directly (F6), it loads Onboarding Town.

const SCENE := "res://scenes/overworld/overworld.tscn"
const DEFAULT_MAP := "onboarding_town"
const DEBUG_MENU := "res://scenes/debug/debug_menu.tscn"

var map: MapView
var player: PlayerController

var _banner: Panel
var _banner_label: Label


func _ready() -> void:
	_build_banner()
	load_map(SceneRouter.params.get("map", DEFAULT_MAP), SceneRouter.params.get("spawn", "default"))


func load_map(map_id: String, spawn_name: String = "default") -> bool:
	if map != null:
		map.queue_free()
	map = MapView.new()
	map.name = "Map"
	add_child(map)
	if not map.load_map(map_id):
		push_error("Overworld: couldn't load map '%s'" % map_id)
		return false
	if player == null:
		player = PlayerController.new()
		player.name = "Player"
		add_child(player)
		player.stepped.connect(_on_stepped)
	var sp := map.spawn(spawn_name)
	player.setup(map, sp["cell"], sp["facing"])
	_remember_location()
	_show_banner(String(map.map_data.get("name", map_id)))
	return true


func _on_stepped(_cell: Vector2i, _behavior: String) -> void:
	_remember_location()
	# Phase 4b: warps, triggers. Phase 5: wild encounters on hot_zone tiles.


func _remember_location() -> void:
	GameState.location = {"map": map.map_id, "x": player.cell.x, "y": player.cell.y}


func _unhandled_input(event: InputEvent) -> void:
	# Temporary until the pause menu (Phase 6): debug builds go back to the debug menu.
	if OS.is_debug_build() and event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		SceneRouter.goto(DEBUG_MENU)


# --- area name banner (GBA-style, slides down for a moment) -------------------

func _build_banner() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_banner = Panel.new()
	_banner.theme = UiTheme.get_theme()
	_banner.position = Vector2(4, -24)
	_banner.size = Vector2(130, 20)
	layer.add_child(_banner)
	_banner_label = Label.new()
	_banner_label.position = Vector2(8, 5)
	_banner.add_child(_banner_label)


func _show_banner(text: String) -> void:
	_banner_label.text = text
	_banner.size.x = maxf(80.0, text.length() * 8 + 16)
	var tween := create_tween()
	tween.tween_property(_banner, "position:y", 4.0, 0.25)
	tween.tween_interval(1.8)
	tween.tween_property(_banner, "position:y", -24.0, 0.25)
