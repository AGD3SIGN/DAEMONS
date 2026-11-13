class_name BattleScene
extends Control
## The battle screen: the "Server Floor" arena from Brandon's Battle Scene spec (2026-11-13), in a 960x640
## frame scaled by whole numbers (see _layout),
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
##   trainer_id, prize, defeat_text, cert — trainer battles (see BattleScene.trainer_config())
## Winning a trainer battle marks them beaten (flag "trainer_<id>"), pays the prize and may award a
## certification. Losing any battle is a black-out: half your credits, team healed, back to the
## last Help Desk.

signal finished(result: Dictionary)

const SCENE := "res://scenes/battle/battle_scene.tscn"
const FRAME := BattleStyle.FRAME
const FIELD_SCALE := 3.0
const PLAYER_SPRITE_SCALE := 4.0
## Where things sit in the 960x640 frame (Battle Scene spec): sprite frames are 64x64 with the feet near
## row 60, so the foe's feet land on the wild pad (~y 347) and the player's on the host pad (~y 466).
const FOE_SPRITE_AT := Vector2(639, 167)
const PLAYER_SPRITE_AT := Vector2(112, 226)
const FOE_TRAINER_AT := Vector2(24, -33)       # relative to the foe slot, in frame pixels
const PLAYER_TRAINER_AT := Vector2(32, -44)    # relative to the player slot
const FOE_CARD_AT := Vector2(28, 28)
const CONSOLE_RECT := Rect2(16, 476, 928, 148)
const FOE_BOB := 6.0                           # wild Daemon bobs 6 px over 2.4 s
const FOE_BOB_TIME := 2.4
## Trainer figures in the battle intro (and one frame of <id>_battle.png).
const TRAINER_SIZE := Vector2(48, 72)
const UPGRADE_BG := Color("181c30")

var config: Dictionary = {}
var state: BattleState
var trainer_name: String = ""
var foe_tier: String = "random"
var time_scale: float = 1.0
var auto: bool = false
var auto_policy: String = "smart"
var result: Dictionary = {}

var stage: Control      # the 960x640 frame
var arena: BattleArena
var field: Control      # x3 layer for sprites, effects and the key
var scanlines: Control
var foe_slot: Control
var player_slot: Control
var foe_sprite: TextureRect
var player_sprite: TextureRect
var fx: BattleFx
## Trainers shown at the start of the battle (overworld art at 3x); they slide away as the Daemons come out.
var player_trainer: TextureRect
var foe_trainer: TextureRect
var foe_panel: BattleInfoPanel
var player_panel: BattleInfoPanel
var text_box: TextBox
var menu: BattleMenu
var key_sprite: TextureRect
var capture_meter: CaptureMeter  # SCAN / ISOLATE / ENCRYPT bar while a Quarantine Key works
var stat_popup: Panel
var stat_popup_label: Label

var _player: BattlePlayer
var _upgrade_overlay: ColorRect
var _upgrade_sprite: TextureRect
var _upgrading := false
var _upgrade_cancel := false
var _started := false
var _foe_rest := Vector2.ZERO
var _bob := 0.0


func _ready() -> void:
	theme = UiTheme.get_theme()
	TouchControls.suppress("battle")  # everything in battle is tappable; buttons would cover the HP panel
	tree_exiting.connect(func() -> void: TouchControls.release("battle"))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	if state == null and SceneRouter.params.has("battle"):
		setup(SceneRouter.params["battle"])
	elif state == null:
		_setup_demo()  # opened directly (F6 in the editor)
	if state != null and not _started:
		_start()


## Battle config for a trainer from data/trainers/*.json.
static func trainer_config(trainer_id: String) -> Dictionary:
	var t: Dictionary = DataRegistry.trainers[trainer_id]
	var music := "battle_boss" if t.has("cert") else ("battle_rival" if t.get("story", false) else "battle_trainer")
	return {"foe": t["team"], "wild": false, "trainer_name": t["name"], "ai": t["ai"], "trainer_id": trainer_id,
		"prize": int(t["prize"]), "defeat_text": t["defeat"], "cert": t.get("cert", ""),
		"story": t.get("story", false), "music": t.get("music", music), "trainer_sprite": t.get("sprite", "")}


static func trainer_flag(trainer_id: String) -> String:
	return "trainer_" + trainer_id



func _process(delta: float) -> void:
	if _player != null:
		_player.tick(delta)
	# The wild Daemon bobs 6 px up and back (2.4 s ease-in-out loop).
	if foe_sprite != null and foe_sprite.visible and time_scale > 0.0 and not Settings.wants_reduced_motion():
		_bob += delta
		var p := 0.5 - 0.5 * cos(TAU * _bob / FOE_BOB_TIME)
		foe_slot.position = _foe_rest - Vector2(0, roundf(FOE_BOB * p) / FIELD_SCALE)
	elif foe_slot != null:
		foe_slot.position = _foe_rest
	# "UNKNOWN HOST" sits under the wild pad until the player's card takes that space.
	if arena != null and player_panel != null:
		arena.show_unknown_host = not player_panel.visible

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
	foe_panel.wild = state.is_wild
	arena.zone_id = String(config.get("zone", BattleStyle.DEFAULT_ZONE))
	AudioManager.play_music(config.get("music", "battle_wild" if state.is_wild else "battle_trainer"))
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
				break  # safety net: never loop forever on an invalid action
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
		text_box.set_reserved_right(int(BattleMenu.COMMAND_RECT.size.x))  # console shrinks to the left part
		text_box.show_now("What will you run?")
		match await menu.choose_command():
			"fight":
				if not BattleSim.has_pp(d):
					return BattleAction.fight(BattleSim.FALLBACK_SLOT)  # "X has no Cycles left!" -> Force Quit
				var slot := await menu.choose_move(d, true)
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
	match state.outcome:
		"player_won":
			AudioManager.play_music("victory")
			await _trainer_rewards()
		"player_lost":
			if config.get("story", false):
				await _story_loss()
			else:
				await _black_out()
	if state.outcome == "caught" and state.captured != null:
		var caught := state.captured
		caught.original_trainer_id = GameState.trainer_id
		GameState.cmdb_caught[caught.species_id] = true
		if config.get("add_captured", true):
			var where := GameState.add_daemon(caught)
			match where:
				"stack":
					await text_box.show_text("%s was added to your Active Stack." % caught.display_name())
				"rack":
					await text_box.show_text("Your stack is full. %s was sent to the Server Rack." % caught.display_name())
				_:
					await text_box.show_text("Every rack is full! %s had to be released." % caught.display_name())
	result = {"outcome": state.outcome, "turns": state.turn, "captured": state.captured}
	await get_tree().create_timer(0.2 * time_scale).timeout


# --- results -----------------------------------------------------------------

func _trainer_rewards() -> void:
	var trainer_id: String = config.get("trainer_id", "")
	if trainer_id.is_empty():
		return
	GameState.flags[trainer_flag(trainer_id)] = true
	var defeat: String = config.get("defeat_text", "")
	if not defeat.is_empty():
		await text_box.show_text("%s: %s" % [trainer_name, defeat])
	var prize := int(config.get("prize", 0))
	if prize > 0:
		GameState.credits += prize
		AudioManager.play_sfx("confirm")
		await text_box.show_text("You got %d CR for winning!" % prize)
	var cert: String = config.get("cert", "")
	if not cert.is_empty() and not cert in GameState.certifications:
		GameState.certifications.append(cert)
		AudioManager.play_sfx("confirm")
		await text_box.show_text("You earned the %s!" % DataRegistry.certifications[cert]["name"])


## Story battles (rival fights) don't black out: the story goes on either way.
func _story_loss() -> void:
	var trainer_id: String = config.get("trainer_id", "")
	if not trainer_id.is_empty():
		GameState.flags[trainer_flag(trainer_id)] = true
	GameState.heal_stack()
	var defeat: String = config.get("defeat_text", "")
	if not defeat.is_empty():
		await text_box.show_text("%s: Ha! Read receipt: you LOST. ...But fine. %s" % [trainer_name, defeat])
	await text_box.show_text("Your Daemons got patched up.")


## Lose half your credits, heal up, wake at the last Help Desk.
func _black_out() -> void:
	var lost := GameState.credits / 2
	GameState.credits -= lost
	GameState.heal_stack()
	GameState.location = GameState.last_help_desk.duplicate()
	GameState.repel_steps = 0
	var dropped := " You dropped %d CR in the panic" % lost if lost > 0 else ""
	await text_box.show_text("Everything went dark...%s and rushed back to the Help Desk." % dropped)


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

## A trainer figure in a Daemon slot: 48x72 (the front/back pose from <id>_battle.png), feet on the platform.
func _trainer_in(slot: Control, at: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.position = at
	t.size = TRAINER_SIZE
	t.visible = false
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.set_meta("rest", at)
	slot.add_child(t)
	return t


## The trainer figure for the battle intro: the back for the player, the front for a trainer. Uses the
## battle-size art (<id>_battle.png, 48x72 front + back, made by import_character.gd from the source
## sheet); falls back to the overworld walking frame (blocky when scaled up) if there's none.
static func trainer_frame(sprite_id: String, from_behind: bool) -> Texture2D:
	if sprite_id.is_empty():
		return null
	var atlas := AtlasTexture.new()
	var battle_path := CharacterSprites.ART_DIR + sprite_id + "_battle.png"
	if ResourceLoader.exists(battle_path):
		atlas.atlas = load(battle_path)
		atlas.region = Rect2((TRAINER_SIZE.x if from_behind else 0), 0, TRAINER_SIZE.x, TRAINER_SIZE.y)
		return atlas
	if not ResourceLoader.exists(CharacterSprites.ART_DIR + sprite_id + ".png"):
		return null
	var sheet := CharacterSprites.sheet(sprite_id, Color.WHITE, Color.WHITE)
	var h := CharacterSprites.frame_height(sheet)
	atlas.atlas = sheet
	atlas.region = Rect2(0, (1 if from_behind else 0) * h, CharacterSprites.frame_width(sheet), h)
	return atlas


func _build() -> void:
	# The battle draws in a 960x640 design frame (Battle Scene spec), scaled by whole numbers of physical
	# pixels and centered; the arena keeps going past the frame on wider or taller screens.
	stage = Control.new()
	stage.name = "Stage"
	stage.size = FRAME
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	arena = BattleArena.new()
	arena.size = FRAME
	stage.add_child(arena)

	# Sprites, trainers, move effects and the key live on a x3 layer (64 px Daemon frames = 192 px).
	field = Control.new()
	field.name = "Field"
	field.scale = Vector2(FIELD_SCALE, FIELD_SCALE)
	field.size = FRAME / FIELD_SCALE
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(field)
	foe_slot = _slot(FOE_SPRITE_AT / FIELD_SCALE)
	player_slot = _slot(PLAYER_SPRITE_AT / FIELD_SCALE)
	foe_sprite = _sprite_in(foe_slot)
	player_sprite = _sprite_in(player_slot)
	player_sprite.scale = Vector2.ONE * PLAYER_SPRITE_SCALE / FIELD_SCALE  # x4 in the frame: closer to the camera
	player_trainer = _trainer_in(player_slot, PLAYER_TRAINER_AT / FIELD_SCALE)
	player_trainer.scale = Vector2.ONE * PLAYER_SPRITE_SCALE / FIELD_SCALE
	foe_trainer = _trainer_in(foe_slot, FOE_TRAINER_AT / FIELD_SCALE)
	_foe_rest = foe_slot.position
	fx = BattleFx.new()  # move effects draw over the Daemons but under the cards
	field.add_child(fx)
	key_sprite = TextureRect.new()
	key_sprite.texture = DaemonSprites.quarantine_key()
	key_sprite.size = Vector2(12, 18)
	key_sprite.visible = false
	field.add_child(key_sprite)

	foe_panel = BattleInfoPanel.new()
	foe_panel.setup(false)
	foe_panel.position = FOE_CARD_AT
	foe_panel.visible = false
	stage.add_child(foe_panel)
	player_panel = BattleInfoPanel.new()
	player_panel.setup(true)
	player_panel.position = Vector2(FRAME.x - 28 - BattleInfoPanel.PLAYER_SIZE.x, 384)
	player_panel.visible = false
	stage.add_child(player_panel)
	capture_meter = CaptureMeter.new()  # SCAN / ISOLATE / ENCRYPT, x2, under the wild card
	capture_meter.position = Vector2(28, 162)
	capture_meter.scale = Vector2(2, 2)
	capture_meter.visible = false
	stage.add_child(capture_meter)

	stat_popup = Panel.new()
	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = BattleStyle.PANEL
	popup_style.border_color = BattleStyle.HOST
	popup_style.set_border_width_all(3)
	popup_style.shadow_color = Color.BLACK
	popup_style.shadow_offset = Vector2(6, 6)
	stat_popup.add_theme_stylebox_override("panel", popup_style)
	stat_popup.position = Vector2(FRAME.x - 28 - 300, 150)
	stat_popup.size = Vector2(300, 224)
	stat_popup_label = Label.new()
	stat_popup_label.position = Vector2(18, 12)
	stat_popup_label.add_theme_font_override("font", BattleStyle.vt323())
	stat_popup_label.add_theme_font_size_override("font_size", 30)
	stat_popup_label.add_theme_color_override("font_color", BattleStyle.TEXT_PRIMARY)
	stat_popup_label.add_theme_constant_override("line_spacing", 0)
	stat_popup.add_child(stat_popup_label)
	stat_popup.visible = false
	stage.add_child(stat_popup)

	text_box = BattleConsole.new()
	text_box.position = CONSOLE_RECT.position
	text_box.size = CONSOLE_RECT.size
	stage.add_child(text_box)
	menu = BattleMenu.new()
	stage.add_child(menu)
	menu.hovered.connect(_on_menu_hovered)
	scanlines = Scanlines.new()
	scanlines.size = FRAME
	stage.add_child(scanlines)

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
	resized.connect(_layout)
	_layout()


## Fits the 960x640 frame: the largest whole-number scale of physical pixels that fits (or a smaller
## fractional one on screens under 960x640), centered. Tells the arena and scanlines how much of the
## frame's surroundings are visible so they can fill them.
func _layout() -> void:
	if stage == null:
		return
	var view := size if size.x > 0.0 and size.y > 0.0 else get_viewport_rect().size
	var px := pixels_per_unit()
	var k := frame_scale(view * px)
	stage.scale = Vector2.ONE * k / px
	var origin_px := ((view * px - FRAME * k) / 2.0).floor()
	stage.position = origin_px / px
	var visible := Rect2(-stage.position / stage.scale, view / stage.scale)
	arena.view_rect = visible
	scanlines.view_rect = visible
	# Move effects (dim, flash, cover) fill the whole view, not just the frame.
	fx.set_anchors_preset(Control.PRESET_TOP_LEFT)
	fx.position = visible.position / FIELD_SCALE
	fx.size = visible.size / FIELD_SCALE


## Physical screen pixels per viewport unit (canvas_items stretch: 4 on a 1280x720 window).
func pixels_per_unit() -> float:
	if not is_inside_tree():
		return 1.0
	var s := get_viewport().get_final_transform().get_scale().x
	return s if s > 0.0 else 1.0


## Scale for the frame on a screen of `physical` pixels: whole numbers when it fits at least once.
static func frame_scale(physical: Vector2) -> float:
	var fit := minf(physical.x / FRAME.x, physical.y / FRAME.y)
	return floorf(fit) if fit >= 1.0 else fit


func _on_menu_hovered(kind: String, index: int) -> void:
	var console := text_box as BattleConsole
	if console == null:
		return
	if kind == "command":
		var cmd: Array = BattleMenu.COMMANDS[index]
		console.set_man(String(cmd[0]).to_lower(), cmd[2])
	else:
		var d := state.sides[BattleState.PLAYER].active() if state != null else null
		if d != null and index < d.moves.size():
			console.set_man(String(d.moves[index]["id"]), menu.move_man(index))


func _slot(at: Vector2) -> Control:
	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.position = at
	slot.size = Vector2(64, 64)
	field.add_child(slot)
	return slot


func _sprite_in(slot: Control) -> TextureRect:
	var sprite := TextureRect.new()
	sprite.size = Vector2(64, 64)
	sprite.visible = false
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(sprite)
	return sprite


## 1 px black lines at 16% every 3 px over the whole view (off with Options > CRT effects).
class Scanlines extends Control:
	var view_rect := Rect2(Vector2.ZERO, BattleStyle.FRAME):
		set(value):
			view_rect = value
			queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		visible = Settings.crt_effects

	func _draw() -> void:
		var y := floorf(view_rect.position.y / 3.0) * 3.0
		while y < view_rect.end.y:
			draw_rect(Rect2(view_rect.position.x, y, view_rect.size.x, 1), Color(0, 0, 0, 0.16))
			y += 3.0
