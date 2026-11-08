extends Node
## Phone/tablet app lifecycle. When the app goes to the background (home button, a call, switching
## apps), the game pauses, and if you're walking around the overworld with nothing else happening
## it autosaves (Options > Autosave), because mobile OSes may kill backgrounded apps without warning.
## Battles and cutscenes aren't saved mid-way; they just pause. Desktop keeps running in the background.

signal suspended
signal resumed

var is_suspended := false
var last_autosave_ok := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _notification(what: int) -> void:
	if not OS.has_feature("mobile"):
		return
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			suspend()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			resume()


## pause_tree = false lets tests check the autosave without freezing the test runner.
func suspend(pause_tree: bool = true) -> void:
	if is_suspended:
		return
	is_suspended = true
	last_autosave_ok = autosave_if_safe()
	if pause_tree:
		get_tree().paused = true
	suspended.emit()


func resume() -> void:
	if not is_suspended:
		return
	is_suspended = false
	get_tree().paused = false
	resumed.emit()


## Saves only from the overworld while nothing is going on (no dialogue, menu, warp or battle).
func autosave_if_safe(scene: Node = null) -> bool:
	if not Settings.autosave_on_suspend:
		return false
	var current := scene if scene != null else get_tree().current_scene
	if not current is Overworld or not current.is_idle():
		return false
	return SaveManager.save_game().is_empty()
