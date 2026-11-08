class_name Overworld
extends Node2D
## The overworld scene: loads a map and its events, places the player, and handles what happens
## around them: warps (with a fade), trigger zones, talking to NPCs and signs (A while facing),
## hidden items, and dialogue (text box + yes/no) — including starting trainer battles.
##
## Open it with SceneRouter.goto(Overworld.SCENE, {"map": "onboarding_town", "spawn": "default"}).
## With no "map" param it returns to GameState.location (e.g. after a battle), else Onboarding Town.

signal battle_requested(config: Dictionary)
signal map_loaded(map_id: String)

const SCENE := "res://scenes/overworld/overworld.tscn"
const DEFAULT_MAP := "onboarding_town"
const DEBUG_MENU := "res://scenes/debug/debug_menu.tscn"
const FADE_TIME := 0.2

var map: MapView
var player: PlayerController
var events: Array[MapEvent] = []

## Tests / automation knobs.
var time_scale: float = 1.0
var auto_advance_text := false
var auto_choice: Variant = null      # true / false answers every yes/no question automatically
var allow_scene_change := true       # false: start_battle only emits battle_requested
var dialogue_log: Array[String] = []  # every line shown, in order

var text_box: TextBox
var menu: BattleMenu
var _speaker_tab: Panel
var _speaker_label: Label
var _fade: ColorRect
var _banner: Panel
var _banner_label: Label
var _busy := false   # dialogue or warp in progress


func _ready() -> void:
	_build_ui()
	var params := SceneRouter.params
	if params.has("map"):
		load_map(params["map"], params.get("spawn", "default"))
	elif GameState.location.has("map"):
		var loc := GameState.location
		load_map(loc["map"])
		player.setup(map, Vector2i(int(loc["x"]), int(loc["y"])), MapView.FACING_VECTORS.get(loc.get("facing", "down"), Vector2i.DOWN))
	else:
		load_map(DEFAULT_MAP)


func set_time_scale(value: float) -> void:
	time_scale = value
	player.time_scale = value
	text_box.time_scale = value


# --- maps and events ---------------------------------------------------------

func load_map(map_id: String, spawn_name: String = "default") -> bool:
	if map != null:
		remove_child(map)
		map.queue_free()
	events.clear()
	map = MapView.new()
	map.name = "Map"
	add_child(map)
	move_child(map, 0)
	if not map.load_map(map_id):
		push_error("Overworld: couldn't load map '%s'" % map_id)
		return false
	if player == null:
		player = PlayerController.new()
		player.name = "Player"
		player.time_scale = time_scale
		add_child(player)
		player.stepped.connect(_on_stepped)
	var sp := map.spawn(spawn_name)
	player.setup(map, sp["cell"], sp["facing"])
	_spawn_events()
	_remember_location()
	_show_banner(String(map.map_data.get("name", map_id)))
	map_loaded.emit(map_id)
	return true


func _spawn_events() -> void:
	for data: Dictionary in map.map_data.get("events", []):
		var event := _new_event(data["type"])
		event.world = self
		event.configure(data)
		events.append(event)
		map.add_child(event)


static func _new_event(type: String) -> MapEvent:
	match type:
		"warp":
			return WarpEvent.new()
		"sign":
			return SignEvent.new()
		"npc":
			return NpcEvent.new()
		"trigger":
			return TriggerEvent.new()
	return HiddenItemEvent.new()


func find_npc(npc_id: String) -> NpcEvent:
	for event in events:
		if event is NpcEvent and event.npc_id == npc_id:
			return event
	return null


func is_idle() -> bool:
	return not _busy and not player.moving


func _event_at(cell: Vector2i) -> MapEvent:
	for event in events:
		if event.cell == cell and not event is WarpEvent and not event is TriggerEvent:
			return event
	return null


# --- stepping, warping, triggers ---------------------------------------------

func _on_stepped(cell: Vector2i, _behavior: String) -> void:
	_remember_location()
	for event in events:
		if event is WarpEvent and event.cell == cell:
			warp_to(event.to_map, event.to_spawn)
			return
	for event in events:
		if event is TriggerEvent and event.contains(cell) and event.is_active():
			_busy = true
			player.input_enabled = false
			await event.run()
			return
	# Phase 5: wild encounters on hot_zone tiles.


func warp_to(map_id: String, spawn_name: String = "default") -> void:
	_busy = true
	player.input_enabled = false
	await _fade_to(1.0)
	load_map(map_id, spawn_name)
	await _fade_to(0.0)
	_busy = false
	player.input_enabled = true


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, FADE_TIME * time_scale)
	await tween.finished


func _remember_location() -> void:
	var facing_name := "down"
	for facing_key: String in MapView.FACING_VECTORS:
		if MapView.FACING_VECTORS[facing_key] == player.facing:
			facing_name = facing_key
	GameState.location = {"map": map.map_id, "x": player.cell.x, "y": player.cell.y, "facing": facing_name}


# --- talking -----------------------------------------------------------------

## Press A: talk to / read / pick up whatever the player is facing. Counters reach one tile further.
func interact() -> void:
	if not is_idle():
		return
	var target := player.cell + player.facing
	if map.tile_info(target)["behavior"] == "counter":
		target += player.facing
	var event := _event_at(target)
	if event == null or not event.can_interact():
		return
	_busy = true
	player.input_enabled = false
	await event.interact()
	_busy = false
	player.input_enabled = true


## Runs a dialogue by id. The text box shows while it runs; movement is paused.
func run_dialogue(dialogue_id: String, npc: NpcEvent = null) -> void:
	_busy = true
	player.input_enabled = false
	text_box.visible = true
	await DialogueRunner.new(self, npc).run(DataRegistry.get_dialogue(dialogue_id))
	text_box.visible = false
	_speaker_tab.visible = false
	_busy = false
	player.input_enabled = true


## One line of dialogue (types out, waits for A).
func say(text: String, speaker: String = "") -> void:
	dialogue_log.append(text)
	_set_speaker(speaker)
	text_box.visible = true
	text_box.auto_advance = auto_advance_text
	await text_box.show_text(text)


## A message outside a dialogue script (e.g. "You found a Coffee!").
func show_message(text: String) -> void:
	var was_visible := text_box.visible
	await say(text)
	text_box.visible = was_visible


## Yes/No question. Returns true for yes.
func ask(question: String, speaker: String = "") -> bool:
	dialogue_log.append(question)
	_set_speaker(speaker)
	text_box.visible = true
	text_box.show_now(question)
	if auto_choice != null:
		await get_tree().process_frame
		return bool(auto_choice)
	return await menu.confirm()


func start_battle(config: Dictionary) -> void:
	_remember_location()
	config["return_scene"] = SCENE
	battle_requested.emit(config)
	if allow_scene_change:
		SceneRouter.goto(BattleScene.SCENE, {"battle": config})


func _set_speaker(speaker: String) -> void:
	_speaker_tab.visible = not speaker.is_empty()
	_speaker_label.text = speaker
	_speaker_tab.size.x = speaker.length() * 8 + 14


# --- input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and is_idle():
		get_viewport().set_input_as_handled()
		interact()
	elif OS.is_debug_build() and event.is_action_pressed("menu") and is_idle():
		# Temporary until the pause menu (Phase 6): debug builds go back to the debug menu.
		get_viewport().set_input_as_handled()
		SceneRouter.goto(DEBUG_MENU)


# --- UI ----------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var root := Control.new()
	root.theme = UiTheme.get_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	_banner = Panel.new()
	_banner.position = Vector2(4, -24)
	_banner.size = Vector2(130, 20)
	root.add_child(_banner)
	_banner_label = Label.new()
	_banner_label.position = Vector2(8, 5)
	_banner.add_child(_banner_label)

	text_box = TextBox.new()
	text_box.anchor_left = 0
	text_box.anchor_right = 1
	text_box.anchor_top = 1
	text_box.anchor_bottom = 1
	text_box.offset_left = 2
	text_box.offset_right = -2
	text_box.offset_top = -48
	text_box.offset_bottom = -2
	text_box.visible = false
	root.add_child(text_box)

	_speaker_tab = Panel.new()
	_speaker_tab.anchor_top = 1
	_speaker_tab.anchor_bottom = 1
	_speaker_tab.offset_left = 6
	_speaker_tab.offset_top = -64
	_speaker_tab.offset_bottom = -46
	_speaker_tab.visible = false
	root.add_child(_speaker_tab)
	_speaker_label = Label.new()
	_speaker_label.position = Vector2(7, 5)
	_speaker_tab.add_child(_speaker_label)

	menu = BattleMenu.new()
	root.add_child(menu)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)


func _show_banner(text: String) -> void:
	_banner_label.text = text
	_banner.size.x = maxf(80.0, text.length() * 8 + 16)
	_banner.position.y = -24
	var tween := create_tween()
	tween.tween_property(_banner, "position:y", 4.0, 0.25 * time_scale)
	tween.tween_interval(1.8 * time_scale)
	tween.tween_property(_banner, "position:y", -24.0, 0.25 * time_scale)
