extends GutTest
## Help desk tickets v1 and the onboarding training (GDD §6 and §11): data/tickets.json, Progress, the TICKETS app,
## Marge's "Do the onboarding training?" with "I KNOW THIS" for veterans.

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
	world.auto_picks = [1]  # I KNOW THIS
	add_child_autofree(world)
	world.set_time_scale(0.0)
	await wait_until(func() -> bool: return GameState.flags.get("kevin_left_help_desk", false) and world.is_idle(), 10.0)
	assert_true(_logged("I've done this before"))
	for id in ["onb_battle", "onb_catch", "onb_items"]:
		assert_eq(GameState.tickets.get(id), "skipped")
	assert_eq(GameState.bag.get("thumb_drive", 0), 8, "Marge's 5 plus the training reward")


func test_phone_has_tickets_and_kudos_apps() -> void:
	var ids := Phone.new().app_ids()
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
