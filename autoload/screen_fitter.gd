extends Node
## Keeps pixels crisp AND fills the window. Godot's built-in integer stretch expands the view to the
## window's aspect first, then floors the scale, which leaves thick black borders at most window
## sizes. Instead we pick the integer scale ourselves and size the view to window / scale, so the
## leftover border is under one scaled pixel and the extra space shows more of the world.

const BASE_SIZE := Vector2i(320, 180)


func _ready() -> void:
	var window := get_window()
	window.min_size = BASE_SIZE
	window.size_changed.connect(_refit)
	_refit()


func _refit() -> void:
	var window := get_window()
	window.content_scale_size = fit(window.size)["view"]


## Pure math so it can be unit-tested. Returns {"scale": int, "view": Vector2i}.
static func fit(window_size: Vector2i) -> Dictionary:
	var scale: int = maxi(1, mini(window_size.x / BASE_SIZE.x, window_size.y / BASE_SIZE.y))
	var view := Vector2i(maxi(BASE_SIZE.x, window_size.x / scale), maxi(BASE_SIZE.y, window_size.y / scale))
	return {"scale": scale, "view": view}
