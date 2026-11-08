class_name BattleScene
extends Control
## The battle screen. Builds the GBA-style layout (320x180, anchored so bigger views still fit),
## runs the turn loop on top of BattleSim, and plays events back through BattlePlayer.
##
## Start a battle from anywhere:
##   SceneRouter.goto(BattleScene.SCENE, {"battle": config})
## Or in code/tests: instance the scene, call setup(config), then add it to the tree.
##
## config keys (all optional):
##   foe: [[species_id, level], ...]    or foe_stack: Array[DaemonInstance]     default: Dustbunny Lv5
##   wild: bool (default: true unless trainer_name)   trainer_name: String   ai: random | basic | smart
##   player_stack: Array[DaemonInstance]  (default GameState.active_stack)
##   items: Dictionary                     (default GameState.bag; used up in place)
##   seed: int   return_scene: String   add_captured: bool (default true)
##   auto: bool — the AI plays your side and text advances by itself
##   auto_policy: "smart" | "capture" (auto only: throw Quarantine Keys first)
##   time_scale: float — animation speed multiplier, 0 = instant

signal finished(result: Dictionary)

const SCENE := "res://scenes/battle/battle_scene.tscn"
const SKY := Color("d4e4ec")
const GROUND := Color("bcdcac")
const PLATFORM := Color("98c088")
const UPGRADE_BG := Color("181c30")

var config: Dictionary = {}
var state: BattleState
var trainer_name: String = ""
var foe_tier: String = "random"
var time_scale: float = 1.0
var auto: bool = false
var auto_policy: String = "smart"
var result: Dictionary = {}

var foe_slot: Control
var player_slot: Control
var foe_sprite: TextureRect
var player_sprite: TextureRect
var foe_panel: BattleInfoPanel
var player_panel: BattleInfoPanel
var text_box: TextBox
var menu: BattleMenu
var key_sprite: TextureRect
var stat_popup: Panel
var stat_popup_label: Label

var _player: BattlePlayer
var _upgrade_overlay: ColorRect
var _upgrade_sprite: TextureRect
var _upgrading := false
var _upgrade_cancel := false
var _started := false


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	if state == null and SceneRouter.params.has("battle"):
		setup(SceneRouter.params["battle"])
	elif state == null:
		_setup_demo()  # opened directly (F6 in the editor)
	if state != null and not _started:
		_start()


func setup(cfg: Dictionary) -> void:
	config = cfg
	auto = cfg.get("auto", false)
	auto_policy = cfg.get("auto_policy", "smart")
	time_scale = float(cfg.get("time_scale", 1.0))
	trainer_name = cfg.get("trainer_name", "")
	var wild: bool = cfg.get("wild", trainer_name.is_empty())
	foe_tier = cfg.get("ai", "random" if wild else "basic")
	var rng := RandomNumberGenerator.new()
	if cfg.has("seed"):
		rng.seed = int(cfg["seed"])
	else:
		rng.randomize()
	var player_stack: Array[DaemonInstance] = []
	player_stack.assign(cfg.get("player_stack", GameState.active_stack))
	var items: Dictionary = cfg.get("items", GameState.bag)
	var foe_stack: Array[DaemonInstance] = []
	if cfg.has("foe_stack"):
		foe_stack.assign(cfg["foe_stack"])
	else:
		for entry: Array in cfg.get("foe", [["dustbunny", 5]]):
			foe_stack.append(DaemonInstance.create(entry[0], int(entry[1]), rng, 0 if wild else 2))
	state = BattleState.new(BattleSide.new("You", player_stack, items),
		BattleSide.new(trainer_name if not trainer_name.is_empty() else "Wild", foe_stack), rng, wild)
	if is_inside_tree() and not _started:
		_start()


## Demo battle when the scene is run on its own: your team (or a default one) vs a wild Dustbunny.
## Pass "-- --auto" on the command line to watch the AI play it.
func _setup_demo() -> void:
	var team: Array[DaemonInstance] = []
	team.assign(GameState.active_stack)
	if team.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 2026
		team = [DaemonInstance.create("chipmunk", 12, rng, 1), DaemonInstance.create("pingo", 10, rng, 1)]
	setup({"foe": [["dustbunny", 5]], "player_stack": team, "items": {"coffee": 3, "thumb_drive": 5},
		"auto": "--auto" in OS.get_cmdline_user_args(), "seed": 5})


# --- battle flow -------------------------------------------------------------

func _start() -> void:
	_started = true
	_player = BattlePlayer.new(self)
	text_box.time_scale = time_scale
	text_box.auto_advance = auto
	foe_panel.time_scale = time_scale
	player_panel.time_scale = time_scale
	_run()


func _run() -> void:
	for d in state.sides[BattleState.FOE].stack:
		GameState.cmdb_seen[d.species_id] = true
	await _player.play(BattleSim.start(state))
	while not state.is_over():
		await _send_replacements()
		var action := await _choose_player_action()
		var foe_action := BattleAI.choose_action(state, BattleState.FOE, foe_tier)
		var events := BattleSim.run_turn(state, action, foe_action)
		if events.size() == 1 and events[0]["type"] == "invalid_action":
			await text_box.show_text(_sentence(events[0]["reason"]))
			if auto:
				break  # nothing valid left (Bug #2); don't loop forever
			continue
		await _player.play(events)
	await _after_battle()
	finished.emit(result)
	var return_scene: String = config.get("return_scene", "")
	if not return_scene.is_empty():
		SceneRouter.goto(return_scene, {"battle_result": result})


func _send_replacements() -> void:
	if state.needs_switch[BattleState.FOE]:
		var foe_index := BattleAI.choose_replacement(state, BattleState.FOE, foe_tier)
		await _player.play(BattleSim.forced_switch(state, BattleState.FOE, foe_index))
	while state.needs_switch[BattleState.PLAYER]:
		var index := BattleAI.choose_replacement(state, BattleState.PLAYER, "smart")
		if not auto:
			text_box.show_now("Choose a Daemon to deploy.")
			index = await menu.choose_from_list("Deploy which Daemon?", _stack_rows(), _stack_enabled(), false)
		var events := BattleSim.forced_switch(state, BattleState.PLAYER, index)
		if events[0]["type"] == "invalid_action":
			await text_box.show_text(_sentence(events[0]["reason"]))
			continue
		await _player.play(events)


func _choose_player_action() -> BattleAction:
	if auto:
		return _auto_action()
	var d := state.sides[BattleState.PLAYER].active()
	while true:
		text_box.show_now("What will %s do?" % d.display_name())
		text_box.set_reserved_right(134)
		match await menu.choose_command():
			"fight":
				var slot := await menu.choose_move(d)
				if slot >= 0:
					return BattleAction.fight(slot)
			"stack":
				var index := await menu.choose_from_list("Switch to which Daemon?", _stack_rows(), _stack_enabled(), true)
				if index >= 0:
					return BattleAction.switch_to(index)
			"bag":
				var item_action := await _choose_item()
				if item_action != null:
					return item_action
			"run":
				return BattleAction.run()
	return null


func _auto_action() -> BattleAction:
	if auto_policy == "capture" and state.is_wild:
		var items: Dictionary = state.sides[BattleState.PLAYER].items
		for item_id: String in items:
			if DataRegistry.get_item(item_id)["effect"]["id"] == "capture" and int(items[item_id]) > 0:
				return BattleAction.item(item_id, 0)
	return BattleAI.choose_action(state, BattleState.PLAYER, "smart")


func _choose_item() -> BattleAction:
	var items: Dictionary = state.sides[BattleState.PLAYER].items
	var ids: Array[String] = []
	var rows := PackedStringArray()
	var enabled: Array = []
	for item_id: String in items:
		var item := DataRegistry.get_item(item_id)
		var effect: String = item["effect"]["id"]
		if int(items[item_id]) <= 0 or not (effect in BattleSim.BATTLE_ITEM_EFFECTS or effect == "capture"):
			continue
		ids.append(item_id)
		rows.append("%-15s x%d" % [item["name"], int(items[item_id])])
		enabled.append(effect != "capture" or state.is_wild)
	if ids.is_empty():
		await text_box.show_text("Nothing in your bag works in battle.")
		return null
	var pick := await menu.choose_from_list("Use which item?", rows, enabled, true)
	if pick < 0:
		return null
	if DataRegistry.get_item(ids[pick])["effect"]["id"] == "capture":
		return BattleAction.item(ids[pick], 0)
	var target := await menu.choose_from_list("Use it on which Daemon?", _stack_rows(), [], true)
	return BattleAction.item(ids[pick], target) if target >= 0 else null


## Called by BattlePlayer when a Daemon wants a 5th move.
func prompt_move_replace(e: Dictionary) -> void:
	var d := state.sides[BattleState.PLAYER].stack[int(e["index"])]
	var new_name: String = DataRegistry.get_move(e["move"])["name"]
	if not auto:
		text_box.show_now("Uninstall a move to make room for %s?" % new_name)
		if await menu.confirm():
			var slot := await menu.choose_move(d)
			if slot >= 0:
				var old_name: String = DataRegistry.get_move(d.moves[slot]["id"])["name"]
				d.learn_move(e["move"], slot)
				await text_box.show_text("%s uninstalled %s and installed %s!" % [d.display_name(), old_name, new_name])
				return
	await text_box.show_text("%s did not install %s." % [d.display_name(), new_name])


func _after_battle() -> void:
	for e in _player.upgrades:
		var d := state.sides[BattleState.PLAYER].stack[int(e["index"])]
		if not d.is_fainted():
			await _play_upgrade(d, int(e["index"]), e["to"])
	if state.outcome == "caught" and state.captured != null:
		var caught := state.captured
		GameState.cmdb_caught[caught.species_id] = true
		if config.get("add_captured", true):
			var where := GameState.add_daemon(caught)
			if where == "stack":
				await text_box.show_text("%s was added to your Active Stack." % caught.display_name())
			else:
				await text_box.show_text("Your stack is full. %s was sent to the Server Rack." % caught.display_name())
	result = {"outcome": state.outcome, "turns": state.turn, "captured": state.captured}
	await get_tree().create_timer(0.2 * time_scale).timeout


# --- upgrading ---------------------------------------------------------------

func _play_upgrade(d: DaemonInstance, index: int, target: String) -> void:
	_upgrading = true
	_upgrade_cancel = false
	var old_texture := DaemonSprites.front(d.species_id)
	var new_texture := DaemonSprites.front(target)
	_upgrade_overlay.color = UPGRADE_BG
	_upgrade_overlay.visible = true
	_upgrade_sprite.texture = old_texture
	await text_box.show_text("Your %s is upgrading!" % d.display_name())
	var interval := 0.45
	var cancelled := false
	for i in 16:
		_upgrade_sprite.texture = new_texture if i % 2 == 1 else old_texture
		_upgrade_sprite.self_modulate = Color(6, 6, 6)
		await get_tree().create_timer(interval * time_scale).timeout
		interval = maxf(0.06, interval * 0.82)
		if _upgrade_cancel:
			cancelled = true
			break
	_upgrade_sprite.self_modulate = Color.WHITE
	_upgrading = false
	if cancelled:
		_upgrade_sprite.texture = old_texture
		await text_box.show_text("Huh? %s stopped upgrading." % d.display_name())
		_upgrade_overlay.visible = false
		return
	var flash := create_tween()
	flash.tween_property(_upgrade_overlay, "color", Color.WHITE, 0.15 * time_scale)
	flash.tween_property(_upgrade_overlay, "color", UPGRADE_BG, 0.35 * time_scale)
	_upgrade_sprite.texture = new_texture
	await flash.finished
	var old_name := d.display_name()
	d.evolve(target)
	GameState.cmdb_seen[target] = true
	GameState.cmdb_caught[target] = true
	await text_box.show_text("%s upgraded into %s!" % [old_name, DataRegistry.get_species(target)["name"]])
	for move_id in d.moves_learned_at(d.level):
		if d.knows_move(move_id):
			continue
		if d.learn_move(move_id):
			await text_box.show_text("%s installed %s!" % [d.display_name(), DataRegistry.get_move(move_id)["name"]])
		else:
			await text_box.show_text("%s wants to install %s, but all 4 slots are full." % [d.display_name(), DataRegistry.get_move(move_id)["name"]])
			await prompt_move_replace({"index": index, "move": move_id})
	_upgrade_overlay.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _upgrading and not auto and event.is_action_pressed("ui_cancel"):
		_upgrade_cancel = true
		get_viewport().set_input_as_handled()


# --- list helpers ------------------------------------------------------------

func _stack_rows() -> PackedStringArray:
	var me := state.sides[BattleState.PLAYER]
	var rows := PackedStringArray()
	for i in me.stack.size():
		var d := me.stack[i]
		var tag := "IN BATTLE" if i == me.active_index else ("CRASHED" if d.is_fainted() else d.status.to_upper().left(3))
		rows.append("%-10s Lv%-3d %3d/%-3d %s" % [d.display_name(), d.level, d.current_uptime, d.max_uptime(), tag])
	return rows


func _stack_enabled() -> Array:
	var me := state.sides[BattleState.PLAYER]
	var enabled: Array = []
	for i in me.stack.size():
		enabled.append(i != me.active_index and not me.stack[i].is_fainted())
	return enabled


static func _sentence(reason: String) -> String:
	return reason.left(1).to_upper() + reason.substr(1) + "."


# --- layout ------------------------------------------------------------------

func _build() -> void:
	var sky := ColorRect.new()
	sky.color = SKY
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sky)
	var ground := ColorRect.new()
	ground.color = GROUND
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.anchor_top = 0.42
	add_child(ground)

	foe_slot = _slot(Vector4(1, 0, 1, 0), Rect2(-104, 16, 64, 64))
	player_slot = _slot(Vector4(0, 1, 0, 1), Rect2(30, -118, 64, 64))
	_platform(foe_slot, Rect2(-14, 46, 92, 16))
	_platform(player_slot, Rect2(-22, 48, 108, 18))
	foe_sprite = _sprite_in(foe_slot)
	player_sprite = _sprite_in(player_slot)

	foe_panel = BattleInfoPanel.new()
	foe_panel.setup(false)
	_place(foe_panel, Vector4(0, 0, 0, 0), Rect2(6, 8, 124, 30))
	player_panel = BattleInfoPanel.new()
	player_panel.setup(true)
	_place(player_panel, Vector4(1, 1, 1, 1), Rect2(-144, -96, 140, 42))
	foe_panel.visible = false
	player_panel.visible = false

	key_sprite = TextureRect.new()
	key_sprite.texture = DaemonSprites.quarantine_key()
	key_sprite.size = Vector2(12, 18)
	key_sprite.visible = false
	add_child(key_sprite)

	stat_popup = Panel.new()
	_place(stat_popup, Vector4(1, 0, 1, 0), Rect2(-122, 30, 118, 70))
	stat_popup_label = Label.new()
	stat_popup_label.position = Vector2(8, 7)
	stat_popup_label.add_theme_constant_override("line_spacing", 2)
	stat_popup.add_child(stat_popup_label)
	stat_popup.visible = false

	_upgrade_overlay = ColorRect.new()
	_upgrade_overlay.color = UPGRADE_BG
	_upgrade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_upgrade_overlay.visible = false
	add_child(_upgrade_overlay)
	_upgrade_sprite = TextureRect.new()
	_upgrade_sprite.anchor_left = 0.5
	_upgrade_sprite.anchor_right = 0.5
	_upgrade_sprite.anchor_top = 0.4
	_upgrade_sprite.anchor_bottom = 0.4
	_upgrade_sprite.offset_left = -32
	_upgrade_sprite.offset_right = 32
	_upgrade_sprite.offset_top = -32
	_upgrade_sprite.offset_bottom = 32
	_upgrade_overlay.add_child(_upgrade_sprite)

	text_box = TextBox.new()
	_place(text_box, Vector4(0, 1, 1, 1), Rect2(2, -48, -4, 46))
	menu = BattleMenu.new()
	add_child(menu)


## Positions a control by anchors (left, top, right, bottom) and an offset rect. For anchors that
## stretch (left != right), rect.size.x is the right offset instead of a width.
func _place(control: Control, anchors: Vector4, rect: Rect2) -> void:
	control.anchor_left = anchors.x
	control.anchor_top = anchors.y
	control.anchor_right = anchors.z
	control.anchor_bottom = anchors.w
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.size.x if anchors.x != anchors.z else rect.position.x + rect.size.x
	control.offset_bottom = rect.position.y + rect.size.y
	add_child(control)


func _slot(anchors: Vector4, rect: Rect2) -> Control:
	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(slot, anchors, rect)
	return slot


func _sprite_in(slot: Control) -> TextureRect:
	var sprite := TextureRect.new()
	sprite.size = Vector2(64, 64)
	sprite.visible = false
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(sprite)
	return sprite


func _platform(slot: Control, rect: Rect2) -> void:
	var platform := Platform.new()
	platform.color = PLATFORM
	platform.position = rect.position
	platform.size = rect.size
	slot.add_child(platform)


class Platform extends Control:
	var color := Color.WHITE

	func _draw() -> void:
		var points := PackedVector2Array()
		var center := size / 2.0
		for i in 32:
			var angle := TAU * i / 32.0
			points.append(center + Vector2(cos(angle) * center.x, sin(angle) * center.y))
		draw_colored_polygon(points, color)
		draw_polyline(points + PackedVector2Array([points[0]]), color.darkened(0.25), 1.0)
