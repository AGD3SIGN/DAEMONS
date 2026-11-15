extends GutTest
## Player feedback (2026-11-14): a new move silently replaced the first one. Now nothing is replaced
## without picking a move and confirming with the cursor starting on NO; STACK > MOVES reorders moves
## and re-installs ones learned before; the Overclock Chip asks instead of dropping the move.

var world: Overworld


func before_each() -> void:
	GameState.reset()
	GameState.flags["got_starter"] = true
	GameState.location = {"map": "port_city", "x": 17, "y": 12, "facing": "up"}


func after_each() -> void:
	SceneRouter.params = {}
	GameState.reset()


func _make(species: String, lvl: int) -> DaemonInstance:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	return DaemonInstance.create(species, lvl, rng, 1)


func _ids(d: DaemonInstance) -> Array:
	return d.moves.map(func(m: Dictionary) -> String: return m["id"])


func _open(auto_choice: Variant) -> FieldMenus:
	SceneRouter.params = {"map": "port_city", "spawn": "default"}
	world = load(Overworld.SCENE).instantiate()
	world.allow_scene_change = false
	world.auto_advance_text = true
	world.auto_choice = auto_choice
	add_child_autofree(world)
	world.set_time_scale(0.0)
	await wait_process_frames(2)
	return world.field_menus


func _tap(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await wait_process_frames(2)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await wait_process_frames(2)


# --- DaemonInstance ----------------------------------------------------------

func test_swap_moves_keeps_cycles_with_their_move() -> void:
	var d := _make("chipmunk", 15)
	d.moves[0]["pp"] = 3
	var first: String = d.moves[0]["id"]
	assert_true(d.swap_moves(0, 2))
	assert_eq(d.moves[2]["id"], first)
	assert_eq(d.moves[2]["pp"], 3, "Cycles travel with the move")
	assert_false(d.swap_moves(1, 1))
	assert_false(d.swap_moves(0, 9))


func test_replaced_moves_can_be_reinstalled() -> void:
	var d := _make("chipmunk", 15)  # knows the last 4 of: bump, heatsink_slam, screen_glare, chassis_guard, double_click
	assert_eq(d.relearnable_moves(), PackedStringArray(["bump"]))
	d.learn_move("bump", 0)
	assert_eq(d.relearnable_moves(), PackedStringArray(["heatsink_slam"]), "the replaced move is still available")


# --- prompts start on NO -----------------------------------------------------

func test_battle_confirm_can_default_to_no() -> void:
	var holder := Control.new()
	holder.size = BattleStyle.FRAME
	add_child_autofree(holder)
	var menu := BattleMenu.new()
	holder.add_child(menu)
	await wait_process_frames(1)
	var run := func() -> bool: return await menu.confirm(false)
	var result := [null]
	var go := func() -> void: result[0] = await run.call()
	go.call()
	await wait_process_frames(1)
	assert_true(menu._confirm_buttons[1].has_focus(), "cursor on NO")
	menu._confirm_buttons[1].pressed.emit()
	await wait_process_frames(2)
	assert_eq(result[0], false)


func test_mashing_accept_never_replaces_a_move() -> void:
	var menus := await _open(null)
	var d := _make("chipmunk", 15)
	GameState.active_stack.assign([d] as Array[DaemonInstance])
	var before := _ids(d)
	var done := [false]
	var run := func() -> void:
		await menus.offer_move(d, "bump")
		done[0] = true
	run.call()
	for i in 20:
		await _tap("ui_accept")
	assert_eq(_ids(d), before, "20 presses of A and nothing was overwritten")
	assert_false(done[0], "still asking")
	# Back out: cancel the list, then say YES to skipping.
	await _tap("ui_cancel")
	await wait_process_frames(2)
	await _tap("ui_up")  # NO -> YES (skip learning it)
	for i in 6:
		await _tap("ui_accept")
		if done[0]:
			break
	assert_true(done[0], "finished after choosing to skip")
	assert_eq(_ids(d), before)


func test_offer_move_replaces_the_chosen_slot_after_confirming() -> void:
	var menus := await _open(true)
	var d := _make("chipmunk", 15)
	var run := func() -> void: await menus.offer_move(d, "bump")
	run.call()
	await wait_process_frames(2)
	await _tap("ui_down")
	await _tap("ui_accept")  # pick slot 2; auto_choice answers YES to "Forget ...?"
	await wait_process_frames(4)
	assert_eq(d.moves[1]["id"], "bump")
	assert_eq(d.moves.size(), 4)


func test_moves_screen_and_overclock_chip_offer() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/field_menus.gd")
	assert_string_contains(source, "[\"SUMMARY\", \"MOVES\", \"SWAP\", \"ITEM\", \"CANCEL\"]")
	var d := _make("chipmunk", 12)  # full slots; Lv13 brings double_click
	GameState.bag["overclock_chip"] = 1
	var result := ItemUse.use_on("overclock_chip", d)
	assert_eq(result["pending_moves"], ["double_click"], "the field menu gets to ask")
