extends GutTest
## Move effects: every move has one, the data checker catches mistakes, and each effect plays to the
## end and cleans up after itself.


func test_every_move_has_an_effect() -> void:
	for move_id: String in DataRegistry.moves:
		var fx: Array = DataRegistry.get_move(move_id).get("fx", [])
		assert_false(fx.is_empty(), move_id + " has an fx list")


func test_effects_are_varied() -> void:
	# The point of fx: moves shouldn't all look alike. No two moves share the exact same steps.
	var seen := {}
	for move_id: String in DataRegistry.moves:
		var key := JSON.stringify(DataRegistry.get_move(move_id)["fx"])
		assert_false(seen.has(key), "%s looks the same as %s" % [move_id, seen.get(key, "")])
		seen[key] = move_id
	var kinds := {}
	for move_id: String in DataRegistry.moves:
		for step: Dictionary in DataRegistry.get_move(move_id)["fx"]:
			kinds[step["kind"]] = true
	assert_eq(kinds.size(), BattleFx.KINDS.size(), "every effect piece is used by some move")


func test_validator_catches_bad_fx() -> void:
	var v := DataValidator.new()
	var base := DataRegistry.get_move("bump").duplicate(true)
	for bad: Variant in [
		"burst",
		[{"kind": "explode"}],
		[{"kind": "rise", "glyph": "smiley"}],
		[{"kind": "burst", "on": "everyone"}],
		[{"kind": "burst", "color": "blurple"}],
	]:
		var m := base.duplicate(true)
		m["fx"] = bad
		v.errors.clear()
		v._validate_fx(m, "moves › test")
		assert_false(v.errors.is_empty(), "rejects %s" % JSON.stringify(bad))
	var good := base.duplicate(true)
	good["fx"] = [{"kind": "rise", "glyph": "plus", "on": "user", "color": "#5ce07a", "parallel": true}]
	v.errors.clear()
	v._validate_fx(good, "moves › test")
	assert_true(v.errors.is_empty(), "accepts a valid step: %s" % [v.errors])


func test_every_move_effect_plays_and_cleans_up() -> void:
	var fx := BattleFx.new()
	add_child_autofree(fx)
	fx.time_scale = 0.05  # fast, but still runs every tween and timer
	for move_id: String in DataRegistry.moves:
		var move := DataRegistry.get_move(move_id)
		await fx.play(move["fx"], Vector2(70, 120), Vector2(250, 50), Color("3c8ee0"))
		await wait_process_frames(2)  # parallel steps may finish a moment later
		await wait_seconds(0.05)
		await wait_process_frames(2)
		assert_eq(fx.get_child_count(), 0, move_id + " left nothing behind")


func test_instant_battles_skip_effects() -> void:
	var fx := BattleFx.new()
	add_child_autofree(fx)
	fx.time_scale = 0.0
	var start := Time.get_ticks_msec()
	await fx.play(DataRegistry.get_move("packet_flood")["fx"], Vector2.ZERO, Vector2(100, 0), Color.WHITE)
	assert_lt(Time.get_ticks_msec() - start, 50, "time_scale 0 (tests, animations off) plays nothing")
	assert_eq(fx.get_child_count(), 0)
