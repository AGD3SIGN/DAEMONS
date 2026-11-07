extends Node
## Central place for scene changes. Fade transitions get added in Phase 4b.
## `params` carries data to the next scene (e.g. {"battle": config}); the new scene reads it in _ready().

var params: Dictionary = {}


func goto(scene_path: String, scene_params: Dictionary = {}) -> void:
	params = scene_params
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("SceneRouter: couldn't load %s (%s)" % [scene_path, error_string(err)])
