extends Control
## Title screen. Blinks "press Start" and waits for ui_accept or menu.

signal start_pressed

const BLINK_SEC := 0.5
const DEBUG_MENU_SCENE := "res://scenes/debug/debug_menu.tscn"

@onready var _prompt: Label = %Prompt

var _blink_time: float = 0.0


func _process(delta: float) -> void:
	_blink_time += delta
	_prompt.visible = fmod(_blink_time, BLINK_SEC * 2.0) < BLINK_SEC


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		start_pressed.emit()
		# No game to start yet; Phase 7 routes this to the intro / continue menu.
		# Until then, debug builds open the debug menu (test battles, Daemon Lab).
		if OS.is_debug_build():
			SceneRouter.goto(DEBUG_MENU_SCENE)
