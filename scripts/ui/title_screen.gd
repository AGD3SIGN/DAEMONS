extends Control
## Title screen. Blinks "press Start", then offers CONTINUE (if there's a save), NEW GAME and,
## in debug builds, the debug menu.

signal start_pressed

const BLINK_SEC := 0.5
const DEBUG_MENU_SCENE := "res://scenes/debug/debug_menu.tscn"
const NEW_GAME_MAP := "player_house"

@onready var _prompt: Label = %Prompt

var _blink_time: float = 0.0
var _menu: MenuList
var _choosing := false


func _ready() -> void:
	GameState.clock_running = false
	_update_prompt(InputPrompts.scheme)
	InputPrompts.scheme_changed.connect(_update_prompt)
	_menu = MenuList.new()
	_menu.theme = UiTheme.get_theme()
	_menu.setup(Vector4(0.5, 1, 0.5, 1), Vector4(-70, -70, 70, -8), 4)
	_menu.cancellable = true
	add_child(_menu)


## "- press Z -", "- press A -", "- tap the check button -" to match what you're holding.
func _update_prompt(_scheme: String) -> void:
	_prompt.text = "- %s -" % ("tap to start" if InputPrompts.scheme == "touch" else InputPrompts.press("ui_accept"))


func _process(delta: float) -> void:
	_blink_time += delta
	_prompt.visible = not _choosing and fmod(_blink_time, BLINK_SEC * 2.0) < BLINK_SEC


func _unhandled_input(event: InputEvent) -> void:
	if _choosing:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("menu") \
			or (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		get_viewport().set_input_as_handled()
		start_pressed.emit()
		show_menu()


func show_menu() -> void:
	_choosing = true
	var options := PackedStringArray()
	if SaveManager.has_save():
		options.append("CONTINUE")
	options.append("NEW GAME")
	if OS.is_debug_build():
		options.append("DEBUG MENU")
	var preview := SaveManager.preview()
	var header := "" if preview.is_empty() else "TIME %s  CERTS %d" % [TrainerCardPanel.format_time(preview["play_time_sec"]), preview["certs"]]
	var r := await _menu.choose(header, options)
	_menu.close()
	_choosing = false
	if r["action"] != "pick":
		return
	match options[r["index"]]:
		"CONTINUE":
			if SaveManager.load_game().is_empty():
				SceneRouter.goto(Overworld.SCENE)
		"NEW GAME":
			new_game()
			SceneRouter.goto(Overworld.SCENE, {"map": NEW_GAME_MAP, "spawn": "new_game"})
		"DEBUG MENU":
			SceneRouter.goto(DEBUG_MENU_SCENE)


## Fresh run: no Daemons yet. You wake up at home (intro trigger), name yourself, and get a
## starter from the manager at the Help Desk.
static func new_game() -> void:
	GameState.reset()
	GameState.trainer_id = randi_range(10000, 99999)
	GameState.credits = 3000
