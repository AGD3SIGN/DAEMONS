extends Node
## Central place for scene changes. Fade transitions get added in Phase 4b.


func goto(scene_path: String) -> void:
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("SceneRouter: couldn't load %s (%s)" % [scene_path, error_string(err)])
