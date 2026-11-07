extends Control
## Title screen. Blinks "press Start" and waits for ui_accept or menu.

signal start_pressed

const BLINK_SEC := 0.5

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
		print("Start pressed")
