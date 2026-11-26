extends GutTest
## Help desk tickets v1 and the onboarding training (GDD §6 and §11): data/tickets.json, Progress, the TICKETS app,
## Marge's "Do the onboarding training?" with "SKIP IT" for veterans.

var world: Overworld


func before_each() -> void:
	GameState.reset()


func after_each() -> void:
	SceneRouter.params = {}
	GameState.reset()


func _daemon(species: String, lvl: int) -> DaemonInstance:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return DaemonInstance.create(species, lvl, rng, 1)


func _open(map_id: String, spawn: String = "default") -> void:
	SceneRouter.params = {"map": map_id, "spawn": spawn}
	world = load(Overworld.SCENE).instantiate()
	world.allow_scene_change = false
	world.auto_advance_text = true
	world.auto_choice = true
	add_child_autofree(world)
	world.set_time_scale(0.0)


func _logged(text_part: String) -> bool:
	for line in world.dialogue_log:
		if text_part in line:
			return true
	return false


# --- data --------------------------------------------------------------------

func test_onboarding_tickets_teach_battling_catching_and_items() -> void:
	var goals := {}
	for id: String in DataRegistry.tickets:
		if DataRegistry.tickets[id]["category"] == "onboarding":
			goals[DataRegistry.tickets[id]["goal"].get("stat", "")] = id
	assert_has(goals, "wild_wins", "a battle ticket")
	assert_has(goals, "caught", "a catching ticket")
	assert_has(goals, "items_used", "an items ticket")


func test_validator_catches_bad_tickets() -> void:
	var raw := DataRegistry.read_raw().duplicate(true)
	raw["tickets"] = raw["tickets"] + [
		{"id": "zz_bad", "number": 1, "title": "Bad", "from": "HR", "priority": "whenever", "category": "x",
			"text": "t", "goal": {"stat": "naps", "at_least": 1}, "goal_text": "g",
			"reward": {"items": {"golden_stapler": 1}}},
	]
	raw["dialogue"]["zz.json"] = {"zz": [{"cmd": "open_ticket", "ticket": "nope"}]}
	var v := DataValidator.new()
	var errors := " ".join(v.validate(raw))
	assert_string_contains(errors, "'priority'")
	assert_string_contains(errors, "ticket number 1 is already used")
	assert_string_contains(errors, "'stat'")
	assert_string_contains(errors, "unknown item 'golden_stapler'")
	assert_string_contains(errors, "unknown ticket 'nope'")


# --- Progress ----------------------------------------------------------------

func test_conditions() -> void:
	assert_false(Progress.met({"flag": "x"}))
	GameState.flags["x"] = true
	assert_true(Progress.met({"flag": "x"}))
	assert_true(Progress.met({"any_flags": ["nope", "x"]}))
	assert_false(Progress.met({"stat": "caught", "at_least": 2}))
	Progress.count("caught", 2)
	assert_true(Progress.met({"stat": "caught", "at_least": 2}))
	assert_false(Progress.met({"certs": 1}))
	assert_false(Progress.met({"flag": "x", "stack_size": 1}), "every key must hold")
	GameState.add_daemon(_daemon("pingo", 5))
	assert_true(Progress.met({"flag": "x", "stack_size": 1}))


func test_an_open_ticket_resolves_once_its_goal_is_met_and_pays() -> void:
	assert_true(Progress.collect().filter(func(n: Dictionary) -> bool: return n["kind"] == "resolved").is_empty())
	Progress.count("wild_wins")
	assert_true(Progress.collect().filter(func(n: Dictionary) -> bool: return n["kind"] == "resolved").is_empty(),
		"not in the queue yet, so it doesn't count")
	Progress.open_ticket("onb_battle")
	var notes := Progress.collect().filter(func(n: Dictionary) -> bool: return n["kind"] == "resolved")
	assert_eq(notes.size(), 1)
	assert_eq(notes[0]["id"], "onb_battle")
	assert_string_contains(notes[0]["lines"][0], "Ticket #0001 resolved")
	assert_eq(GameState.tickets["onb_battle"], "resolved")
	assert_eq(GameState.credits, 100)
	assert_eq(Progress.stat("tickets_resolved"), 1)
	assert_true(Progress.collect().is_empty(), "only once")
	assert_false(Progress.open_ticket("onb_battle"), "a closed ticket doesn't reopen")


func test_skipping_training_closes_the_tickets_and_still_pays() -> void:
	Progress.open_ticket("onb_battle")
	var lines := Progress.skip_tickets("onboarding")
	assert_gt(lines.size(), 0)
	for id in ["onb_battle", "onb_catch", "onb_items"]:
		assert_eq(GameState.tickets[id], "skipped")
	assert_eq(GameState.credits, 100)
	assert_eq(GameState.bag.get("thumb_drive", 0), 3)
	assert_eq(GameState.bag.get("coffee", 0), 2)
	Progress.count("wild_wins")
	assert_true(Progress.collect().filter(func(n: Dictionary) -> bool: return n["kind"] == "resolved").is_empty(),
		"skipped tickets never pay twice")


func test_the_queue_lists_open_tickets_by_priority_then_closed_ones() -> void:
	for id in ["onb_items", "onb_catch", "onb_battle"]:
		Progress.open_ticket(id)
	GameState.tickets["onb_battle"] = "resolved"
	assert_eq(Progress.ticket_queue(), ["onb_catch", "onb_items", "onb_battle"] as Array[String])


func test_tickets_and_kudos_survive_a_save() -> void:
	Progress.open_ticket("onb_catch")
	GameState.tickets["onb_battle"] = "resolved"
	GameState.kudos["first_day"] = true
	var data := JSON.parse_string(JSON.stringify(GameState.to_dict())) as Dictionary
	GameState.reset()
	GameState.from_dict(data)
	assert_eq(GameState.tickets, {"onb_catch": "open", "onb_battle": "resolved"})
	assert_true(GameState.kudos.has("first_day"))


# --- in the game -------------------------------------------------------------

func test_winning_a_wild_battle_counts_for_the_training_ticket() -> void:
	var team: Array[DaemonInstance] = [_daemon("munkboard", 30)]
	var scene: BattleScene = load(BattleScene.SCENE).instantiate()
	scene.setup({"auto": true, "time_scale": 0.0, "seed": 4, "foe": [["dustbunny", 2]], "wild": true,
		"player_stack": team, "items": {}})
	add_child_autofree(scene)
	await wait_for_signal(scene.finished, 30.0)
	assert_eq(scene.result["outcome"], "player_won")
	assert_eq(Progress.stat("wild_wins"), 1)
	assert_eq(Progress.stat("battles_won"), 1)
	assert_eq(Progress.stat("trainer_wins"), 0)


func test_back_on_the_map_a_finished_ticket_is_announced() -> void:
	GameState.add_daemon(_daemon("pingo", 5))
	GameState.flags["got_starter"] = true
	GameState.flags["kevin_left_help_desk"] = true
	Progress.open_ticket("onb_battle")
	Progress.count("wild_wins")
	_open("route_1")
	await wait_until(func() -> bool: return GameState.tickets["onb_battle"] == "resolved" and world.is_idle(), 5.0)
	assert_true(_logged("Ticket #0001 resolved"))
	assert_true(_logged("You got 100 CR."))


func test_a_veteran_can_skip_training() -> void:
	GameState.add_daemon(_daemon("chipmunk", 5))
	GameState.flags["got_starter"] = true
	GameState.flags["starter_chipmunk"] = true
	GameState.flags["kevin_rival_1_done"] = true
	GameState.location = {"map": "help_desk", "x": 8, "y": 6, "facing": "up"}
	SceneRouter.params = {}
	world = load(Overworld.SCENE).instantiate()
	world.allow_scene_change = false
	world.auto_advance_text = true
	world.auto_choice = true
	world.auto_picks = [1]  # SKIP IT
	add_child_autofree(world)
	world.set_time_scale(0.0)
	await wait_until(func() -> bool: return GameState.flags.get("kevin_left_help_desk", false) and world.is_idle(), 10.0)
	assert_true(_logged("I've done this before"))
	for id in ["onb_battle", "onb_catch", "onb_items"]:
		assert_eq(GameState.tickets.get(id), "skipped")
	assert_eq(GameState.bag.get("thumb_drive", 0), 8, "Marge's 5 plus the training reward")


func test_phone_has_tickets_and_kudos_apps() -> void:
	var phone := Phone.new()
	var ids := phone.app_ids()
	phone.free()
	assert_has(ids, "TICKETS")
	assert_has(ids, "KUDOS")
	for id in ids:
		assert_lte(Phone.short_label(id, id).length(), 6, "%s fits under its icon" % id)


func test_reading_a_ticket() -> void:
	Progress.open_ticket("onb_catch")
	var lines := FieldMenus.ticket_lines("onb_catch")
	assert_string_contains(lines[0], "#0002 ASSET INTAKE")
	assert_string_contains(lines[0], "P2")
	assert_true(lines.any(func(l: String) -> bool: return l.begins_with("TO DO: Quarantine")))
	assert_true(lines.any(func(l: String) -> bool: return l.begins_with("TIP: ")))
	GameState.tickets["onb_catch"] = "resolved"
	assert_eq(FieldMenus.ticket_lines("onb_catch")[-1], "STATUS: Resolved.")


func test_ticket_rows_show_the_whole_title_and_closed_ones_say_ok() -> void:
	Progress.open_ticket("onb_battle")
	Progress.open_ticket("onb_catch")
	GameState.tickets["onb_catch"] = "resolved"
	var menus := FieldMenus.new()
	var rows := menus.ticket_rows(["onb_battle", "onb_catch"] as Array[String])
	menus.free()
	assert_eq(rows[0], "P2 #0001 Forgeling Safety Training")
	assert_eq(rows[1], "OK #0002 Asset Intake")


# --- Act 1 side tickets ------------------------------------------------------

func _place(cell: Vector2i, facing: Vector2i) -> void:
	world.player.setup(world.map, cell, facing)


func test_the_321_ticket_opens_after_kevin_leaves_and_the_sticky_note_closes_it() -> void:
	GameState.add_daemon(_daemon("pingo", 5))
	GameState.flags["got_starter"] = true
	GameState.flags["kevin_left_help_desk"] = true
	_open("help_desk")
	await wait_until(func() -> bool: return GameState.tickets.get("tkt_321") == "open" and world.is_idle(), 5.0)
	assert_true(_logged("New ticket #3021 from Accounting"))
	_place(Vector2i(11, 3), Vector2i.UP)
	await world.interact()
	await wait_until(func() -> bool: return world.is_idle(), 5.0)
	assert_true(_logged("3-2-1!!! DON'T FORGET."))
	assert_eq(GameState.tickets["tkt_321"], "resolved")
	assert_eq(GameState.credits, 150)


func test_the_first_tape_label_is_on_the_help_desk_bookshelf() -> void:
	GameState.add_daemon(_daemon("pingo", 5))
	GameState.flags["got_starter"] = true
	GameState.flags["kevin_left_help_desk"] = true
	_open("help_desk")
	await wait_until(func() -> bool: return world.is_idle(), 5.0)
	_place(Vector2i(1, 5), Vector2i.DOWN)
	await world.interact()
	assert_true(_logged("TESTED FRIDAYS"))
	assert_true(GameState.flags.get("found_tape_label_1", false))


func test_moms_printer_ticket_comes_after_your_first_wild_win_and_a_reboot_fixes_it() -> void:
	GameState.add_daemon(_daemon("pingo", 5))
	GameState.flags["got_starter"] = true
	GameState.flags["kevin_left_help_desk"] = true
	GameState.flags["got_mom_coffee"] = true
	Progress.collect()
	assert_false(GameState.tickets.has("tkt_printer"), "not before you've been out working")
	Progress.count("wild_wins")
	Progress.collect()
	assert_eq(GameState.tickets.get("tkt_printer"), "open")
	_open("player_house")
	await wait_until(func() -> bool: return world.is_idle(), 5.0)
	_place(Vector2i(4, 4), Vector2i.UP)
	await world.interact()
	await wait_until(func() -> bool: return world.is_idle(), 5.0)
	assert_true(_logged("6:00:00"))
	assert_eq(GameState.tickets["tkt_printer"], "resolved")
	assert_eq(GameState.bag.get("coffee", 0), 3)


# --- Kudos -------------------------------------------------------------------

func test_kudos_unlock_once_and_are_all_reachable_in_the_demo() -> void:
	GameState.flags["got_starter"] = true
	var notes := Progress.collect().filter(func(n: Dictionary) -> bool: return n["kind"] == "kudos")
	assert_eq(notes.map(func(n: Dictionary) -> String: return n["id"]), ["first_day"])
	assert_eq(notes[0]["lines"][0], "Kudos unlocked: First Day!")
	assert_true(Progress.collect().is_empty(), "only once")
	for id: String in DataRegistry.kudos:
		var goal: Dictionary = DataRegistry.kudos[id]["goal"]
		assert_lte(int(goal.get("certs", 0)), 2, "%s: the demo ends at Cert 2" % id)


func test_resolving_tickets_can_unlock_a_kudos_in_the_same_check() -> void:
	for id in ["onb_battle", "onb_catch", "onb_items"]:
		Progress.open_ticket(id)
	Progress.count("wild_wins")
	Progress.count("caught")
	Progress.count("items_used")
	var kinds := Progress.collect().map(func(n: Dictionary) -> String: return "%s:%s" % [n["kind"], n["id"]])
	assert_has(kinds, "resolved:onb_items")
	assert_has(kinds, "kudos:ticket_closer")
	assert_has(kinds, "kudos:asset_tag")
	assert_lt(kinds.find("resolved:onb_items"), kinds.find("kudos:ticket_closer"), "the ticket first, then its Kudos")


func test_no_kudos_popup_on_the_way_into_a_battle() -> void:
	GameState.add_daemon(_daemon("pingo", 5))
	_open("route_1")
	await wait_until(func() -> bool: return world.is_idle(), 5.0)
	world.allow_scene_change = true
	world._leaving = true
	GameState.flags["got_starter"] = true
	await world.check_progress()
	assert_false(GameState.kudos.has("first_day"), "waits until you're back on the map")
	world._leaving = false
	world.allow_scene_change = false
