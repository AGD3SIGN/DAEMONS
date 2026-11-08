extends GutTest
## The Daemon Lab debug screen loads and its actions work.

var _lab: Control


func before_each() -> void:
	_lab = load("res://scenes/debug/daemon_lab.tscn").instantiate()
	add_child_autofree(_lab)


func test_starts_on_first_species_and_saves_ok() -> void:
	assert_eq(_lab.daemon.species_id, "chipmunk")
	assert_true(_lab.save_ok)


func test_browse_level_and_upgrade() -> void:
	for i in 11:
		_lab.change_level(1)  # level 16
	_lab.upgrade()
	assert_eq(_lab.daemon.species_id, "motherboar")
	_lab.overclock()
	assert_eq(_lab.daemon.level, 17)
	assert_true(_lab.save_ok)


func test_species_wraps_around() -> void:
	_lab.change_species(-1)
	assert_eq(_lab.daemon.species_id, "servurtle")
