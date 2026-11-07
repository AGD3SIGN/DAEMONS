class_name CursorButton
extends Button
## Flat text button that shows a ">" cursor while focused. Hovering (mouse) or tapping (touch)
## moves focus to it, so keyboard, gamepad, mouse and touch all share one cursor.
## ui_accept / click / tap presses it (standard Button behavior).

var label_text: String = "":
	set(value):
		label_text = value
		_refresh()


func _init(p_text: String = "") -> void:
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	focus_mode = Control.FOCUS_ALL
	label_text = p_text
	mouse_entered.connect(_on_mouse_entered)
	focus_entered.connect(_refresh)
	focus_exited.connect(_refresh)


func set_enabled(enabled: bool) -> void:
	disabled = not enabled
	focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


func _on_mouse_entered() -> void:
	if not disabled:
		grab_focus()


func _refresh() -> void:
	text = ("> " if has_focus() else "  ") + label_text
