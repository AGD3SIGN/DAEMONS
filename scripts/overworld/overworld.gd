class_name Overworld
extends Node2D
## The overworld scene: loads a map and its events, places the player, and handles what happens
## around them: warps (with a fade), trigger zones, talking to NPCs and signs (A while facing),
## hidden items, dialogue (text box + yes/no), wild encounters in hot zones, and the pause menu
## (Space/Tab/Start) with CMDB, Active Stack and Bag.
##
## Open it with SceneRouter.goto(Overworld.SCENE, {"map": "onboarding_town", "spawn": "default"}).
## With no "map" param it returns to GameState.location (e.g. after a battle), else Onboarding Town.

signal battle_requested(config: Dictionary)
signal map_loaded(map_id: String)

const SCENE := "res://scenes/overworld/overworld.tscn"
const DEFAULT_MAP := "onboarding_town"
const FADE_TIME := 0.2

var map: MapView
var player: PlayerController
var events: Array[MapEvent] = []

## Tests / automation knobs.
var time_scale: float = 1.0
var auto_advance_text := false
var auto_choice: Variant = null      # true / false answers every yes/no question automatically
var encounter_rate_override: float = -1.0  # >= 0 replaces the map's encounter rate (tests)
var encounter_rng := RandomNumberGenerator.new()
var allow_scene_change := true       # false: start_battle only emits battle_requested
var dialogue_log: Array[String] = []  # every line shown, in order

var text_box: TextBox
var menu: BattleMenu
var field_menus: FieldMenus
var _speaker_tab: Panel
var _speaker_label: Label
var _fade: ColorRect
var _banner: Panel
var _banner_label: Label
var _busy := false   # dialogue or warp in progress
var _scripted_move := false  # move_player in a cutscene: steps don't warp/trigger/encounter
var _tint: CanvasModulate


func _ready() -> void:
	encounter_rng.randomize()
	GameState.clock_running = true
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
	_check_arrival.call_deferred()


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
	refresh_barriers()
	_remember_location()
	_apply_map_mood()
	_show_banner(String(map.map_data.get("name", map_id)))
	map_loaded.emit(map_id)
	return true


## Map music and the optional darkness tint (e.g. the Wi-Fi Dead Zone).
func _apply_map_mood() -> void:
	AudioManager.play_music(String(map.map_data.get("music", "")))
	if _tint == null:
		_tint = CanvasModulate.new()
		add_child(_tint)
	_tint.color = Color(String(map.map_data.get("tint", "#ffffff")))


## Re-checks every laser door (after dialogue changes flags).
func refresh_barriers() -> void:
	for event in events:
		if event is BarrierEvent:
			event.refresh()


## Trigger zones under the player when they arrive (cutscenes on entering a map).
func _check_arrival() -> void:
	if not is_inside_tree() or _busy:
		return
	for event in events:
		if event is TriggerEvent and event.contains(player.cell) and event.is_active():
			_busy = true
			player.input_enabled = false
			await event.run()
			return


func _spawn_events() -> void:
	for data: Dictionary in map.map_data.get("events", []):
		if data.has("hide_if_flag") and GameState.flags.get(data["hide_if_flag"], false):
			continue
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
		"barrier":
			return BarrierEvent.new()
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
		if event.cell == cell and not event is WarpEvent and not event is TriggerEvent and not event is BarrierEvent:
			return event
	return null


# --- stepping, warping, triggers ---------------------------------------------

func _on_stepped(cell: Vector2i, _behavior: String) -> void:
	_remember_location()
	if _scripted_move:
		return
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
	for event in events:
		if event is NpcEvent and trainer_sees_player(event):
			await engage_trainer(event, true)
			return
	if GameState.repel_steps > 0:
		GameState.repel_steps -= 1
		if GameState.repel_steps == 0:
			_busy = true
			player.input_enabled = false
			await show_message("The Firewall Rule expired.")
			_busy = false
			player.input_enabled = true
	_check_encounter(cell)


func _check_encounter(cell: Vector2i) -> void:
	var info := map.tile_info(cell)
	if not info["behavior"] in ["hot_zone", "water"] or not GameState.has_usable_daemon():
		return
	var table: Dictionary = DataRegistry.encounters.get(map.map_id, {})
	if table.is_empty():
		return
	var rate := encounter_rate_override if encounter_rate_override >= 0.0 else float(table["rate"])
	var hit := Encounters.roll(map.map_id, info["name"], encounter_rng, GameState.lead_level(), GameState.repel_steps > 0, rate)
	if not hit.is_empty():
		start_wild_battle(hit["species"], hit["level"])


## True if an unbeaten trainer is looking straight at the player within its sight range,
## with nothing solid in between.
func trainer_sees_player(npc: NpcEvent) -> bool:
	if not npc.is_undefeated_trainer() or npc.sight() <= 0 or npc.moving:
		return false
	for distance in range(1, npc.sight() + 1):
		var cell := npc.cell + npc.facing * distance
		if cell == player.cell:
			return true
		if not map.is_walkable(cell):
			return false
	return false


## "!" → walk up (if they spotted you) → intro line → battle.
func engage_trainer(npc: NpcEvent, walk_up: bool) -> void:
	_busy = true
	player.input_enabled = false
	await npc.show_alert(0.6 * time_scale)
	if walk_up:
		var gap := absi(player.cell.x - npc.cell.x) + absi(player.cell.y - npc.cell.y) - 1
		for i in gap:
			if not await npc.step(npc.facing):
				break
	player.face(-npc.facing)
	var t := npc.trainer_data()
	await say(String(t["intro"]), String(t["name"]))
	text_box.visible = false
	_speaker_tab.visible = false
	start_battle(BattleScene.trainer_config(npc.trainer_id))
	if not allow_scene_change:
		_busy = false
		player.input_enabled = true


func start_wild_battle(species_id: String, level: int) -> void:
	_busy = true
	player.input_enabled = false
	if not GameState.cmdb_found_at.has(species_id):
		GameState.cmdb_found_at[species_id] = String(map.map_data.get("name", map.map_id))
	await _encounter_flash()
	start_battle({"foe": [[species_id, level]], "wild": true})
	if not allow_scene_change:
		_busy = false
		player.input_enabled = true


## White flashes, then black, like stumbling into something in tall grass.
func _encounter_flash() -> void:
	var tween := create_tween()
	for i in 3:
		tween.tween_property(_fade, "color", Color(1, 1, 1, 0.8), 0.08 * time_scale)
		tween.tween_property(_fade, "color", Color(1, 1, 1, 0.0), 0.08 * time_scale)
	tween.tween_property(_fade, "color", Color(0, 0, 0, 1), 0.25 * time_scale)
	await tween.finished
	if not allow_scene_change:
		_fade.color = Color(0, 0, 0, 0)


func warp_to(map_id: String, spawn_name: String = "default") -> void:
	_busy = true
	player.input_enabled = false
	await _fade_to(1.0)
	load_map(map_id, spawn_name)
	await _fade_to(0.0)
	_busy = false
	player.input_enabled = true
	_check_arrival()


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
	refresh_barriers()
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


## Walks the player along a path during a cutscene (no warps, triggers or encounters).
func move_player(path: Array) -> void:
	_scripted_move = true
	for dir_name: Variant in path:
		var dir: Vector2i = MapView.FACING_VECTORS.get(dir_name, Vector2i.ZERO)
		if dir != Vector2i.ZERO:
			await player.try_step(dir)
	_scripted_move = false
	_remember_location()


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
	elif event.is_action_pressed("menu") and is_idle():
		get_viewport().set_input_as_handled()
		open_pause()


func open_pause() -> void:
	_busy = true
	player.input_enabled = false
	AudioManager.play_sfx("select")
	await field_menus.open_pause()
	_busy = false
	player.input_enabled = true


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

	field_menus = FieldMenus.new()
	field_menus.world = self
	root.add_child(field_menus)

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
