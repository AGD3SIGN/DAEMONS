extends Control
## Debug hub (debug builds only, opened from the title screen): start test battles, heal the
## team, open the Daemon Lab. Gives you a starter team and a stocked bag on first visit.

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
const LAB_SCENE := "res://scenes/debug/daemon_lab.tscn"
const SELF_SCENE := "res://scenes/debug/debug_menu.tscn"
const STARTER_TEAM := [["chipmunk", 12], ["pingo", 10], ["bitling", 10]]
const BAG := {"coffee": 5, "energy_drink": 2, "pizza_friday": 1, "hard_reboot": 2,
	"thumb_drive": 10, "encrypted_key": 5, "root_key": 1}
const WILD_POOL := [["dustbunny", 4, 7], ["wormby", 4, 7], ["cablesnake", 5, 8], ["floppit", 5, 8],
	["spamlet", 4, 7], ["fanbat", 6, 9]]
const KEVIN := [["spamlet", 9], ["cablesnake", 10], ["wormby", 11]]

var _status: Label


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if GameState.active_stack.is_empty():
		_make_team()
		_restock()
	var bg := ColorRect.new()
	bg.color = Color("10142a")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 6
	panel.offset_top = 6
	panel.offset_right = -6
	panel.offset_bottom = -6
	add_child(panel)
	var title := Label.new()
	title.text = "DEBUG MENU"
	title.position = Vector2(8, 7)
	panel.add_child(title)
	var buttons := VBoxContainer.new()
	buttons.position = Vector2(4, 20)
	buttons.add_theme_constant_override("separation", 0)
	panel.add_child(buttons)
	var first: CursorButton = null
	for entry: Array in [
		["Overworld: Onboarding Town", func() -> void: SceneRouter.goto(Overworld.SCENE, {"map": "onboarding_town"})],
		["Wild battle: Dustbunny Lv5", _wild_dustbunny],
		["Wild battle: random", _wild_random],
		["Trainer battle: Kevin", _kevin],
		["Watch: AI plays you vs Kevin", _kevin_auto],
		["Heal team + restock bag", _heal],
		["Daemon Lab", func() -> void: SceneRouter.goto(LAB_SCENE)],
		["Title screen", func() -> void: SceneRouter.goto(TITLE_SCENE)],
	]:
		var button := CursorButton.new(entry[0])
		button.custom_minimum_size = Vector2(0, 11)
		button.pressed.connect(entry[1])
		buttons.add_child(button)
		if first == null:
			first = button
	_status = Label.new()
	_status.anchor_right = 1.0
	_status.anchor_top = 1.0
	_status.anchor_bottom = 1.0
	_status.offset_left = 8
	_status.offset_right = -8
	_status.offset_top = -62
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color("505068"))
	panel.add_child(_status)
	_refresh_status()
	first.grab_focus()


func _battle(config: Dictionary) -> void:
	config["return_scene"] = SELF_SCENE
	SceneRouter.goto(BattleScene.SCENE, {"battle": config})


func _wild_dustbunny() -> void:
	_battle({"foe": [["dustbunny", 5]], "wild": true})


func _wild_random() -> void:
	var pick: Array = WILD_POOL.pick_random()
	_battle({"foe": [[pick[0], randi_range(pick[1], pick[2])]], "wild": true})


func _kevin() -> void:
	_battle({"foe": KEVIN, "wild": false, "trainer_name": "Kevin", "ai": "smart"})


func _kevin_auto() -> void:
	_battle({"foe": KEVIN, "wild": false, "trainer_name": "Kevin", "ai": "smart", "auto": true})


func _heal() -> void:
	for d: DaemonInstance in GameState.active_stack:
		d.heal_full()
	_restock()
	_refresh_status("Team healed, bag restocked.")


func _make_team() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for entry: Array in STARTER_TEAM:
		GameState.add_daemon(DaemonInstance.create(entry[0], entry[1], rng, 1))


func _restock() -> void:
	for item_id: String in BAG:
		GameState.bag[item_id] = BAG[item_id]


func _refresh_status(note: String = "") -> void:
	var team := PackedStringArray()
	for d: DaemonInstance in GameState.active_stack:
		team.append("%s %d/%d" % [d.display_name(), d.current_uptime, d.max_uptime()])
	var lines := PackedStringArray()
	if not note.is_empty():
		lines.append(note)
	elif SceneRouter.params.has("battle_result"):
		var r: Dictionary = SceneRouter.params["battle_result"]
		lines.append("Last battle: %s in %d turns" % [r.get("outcome", "?"), int(r.get("turns", 0))])
	lines.append("Team: " + ", ".join(team))
	lines.append("CMDB: %d seen, %d caught   Rack: %d" % [GameState.cmdb_seen.size(), GameState.cmdb_caught.size(), GameState.server_rack.size()])
	_status.text = "\n".join(lines)
