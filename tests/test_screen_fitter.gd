extends GutTest
## ScreenFitter picks an integer scale and fills the window with view pixels.

const Fitter := preload("res://autoload/screen_fitter.gd")


func _leftover(window: Vector2i) -> Vector2i:
	var r: Dictionary = Fitter.fit(window)
	return window - r["view"] * r["scale"]


func test_exact_multiple_has_no_border() -> void:
	var r: Dictionary = Fitter.fit(Vector2i(1280, 720))
	assert_eq(r["scale"], 4)
	assert_eq(r["view"], Vector2i(320, 180))
	assert_eq(_leftover(Vector2i(1280, 720)), Vector2i.ZERO)


func test_odd_sizes_leave_less_than_one_scaled_pixel() -> void:
	for size in [Vector2i(1170, 1000), Vector2i(1100, 700), Vector2i(1971, 1093), Vector2i(2560, 1600)]:
		var r: Dictionary = Fitter.fit(size)
		var left := _leftover(size)
		assert_lt(left.x, r["scale"], "x border too big at %s" % size)
		assert_lt(left.y, r["scale"], "y border too big at %s" % size)


func test_extra_space_shows_more_world() -> void:
	# 4:3 window at 3x: wider than base height, so we see extra rows.
	var r: Dictionary = Fitter.fit(Vector2i(1170, 1000))
	assert_eq(r["scale"], 3)
	assert_eq(r["view"], Vector2i(390, 333))


func test_never_smaller_than_base() -> void:
	var r: Dictionary = Fitter.fit(Vector2i(200, 100))
	assert_eq(r["scale"], 1)
	assert_eq(r["view"], Vector2i(320, 180))
