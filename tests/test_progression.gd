extends GutTest
## Phase 6: trainers (line of sight, rewards), certifications, black-out, saving/loading,
## options, title new game, and "beat a trainer, save, quit, relaunch, continue".

const TEST_SLOTS: PackedStringArray = ["user://test_save_a.json", "user://test_save_b.json"]

var world: Overworld


func before_each() -> void:
	GameState.reset()
	SaveManager.slot_paths = TEST_SLOTS
	SaveManager.delete_saves()


func after_each() -> void:
	SaveManager.delete_saves()
	SaveManager.slot_paths = SaveManager.SLOT_PATHS
	SceneRouter.params = {}
	GameState.reset()


func _daemon(species: String, lvl: int) -> DaemonInstance:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	return DaemonInstance.create(species, lvl, rng, 1)


func _open(map_id: String, spawn: String = "default") -> void:
	SceneRouter.params = {"map": map_id, "spawn": spawn}
	world = load(Overworld.SCENE).instantiate()
	add_child_autofree(world)
	world.allow_scene_change = false
	world.auto_advance_text = true
	world.auto_choice = true
	world.set_time_scale(0.0)


func _battle(config: Dictionary) -> BattleScene:
	var base := {"auto": true, "time_scale": 0.0, "seed": 4}
	base.merge(config, true)
	var scene: BattleScene = load(BattleScene.SCENE).instantiate()
	scene.setup(base)
	add_child_autofree(scene)
	await wait_for_signal(scene.finished, 30.0)
	return scene


# --- data --------------------------------------------------------------------

func test_trainer_and_cert_data() -> void:
	assert_eq(DataRegistry.certifications.size(), 8)
	assert_true(DataRegistry.trainers.has("intern_ian"))
	var config := BattleScene.trainer_config("sysadmin_sam")
	assert_eq(config["trainer_name"], "Sysadmin Sam")
	assert_false(config["wild"])
	assert_eq(config["prize"], 240)
	var raw := DataRegistry.read_raw().duplicate(true)
	raw["trainers"]["zz"] = {"bad": {"name": "X", "team": [["dustbunny", 3]], "ai": "genius", "prize": 1,
		"intro": "a", "defeat": "b", "after": "c", "cert": "plumbing"}}
	raw["dialogue"]["zz.json"] = {"zz": [{"cmd": "start_battle"}, {"cmd": "give_cert", "cert": "plumbing"}]}
	var errors := " | ".join(DataValidator.new().validate(raw))
	assert_string_contains(errors, "'ai' is \"genius\"")
	assert_string_contains(errors, "unknown certification 'plumbing'")
	assert_string_contains(errors, "needs 'trainer' or 'foe'")


# --- trainers on the overworld -----------------------------------------------

func test_trainer_spots_you_walks_up_and_battles() -> void:
	GameState.add_daemon(_daemon("chipmunk", 10))
	_open("route_1", "south")
	watch_signals(world)
	world.player.setup(world.map, Vector2i(9, 19), Vector2i.UP)
	await world.player.try_step(Vector2i.UP)  # into Intern Ian's line of sight
	await wait_until(func() -> bool: return world.is_idle(), 5.0)
	assert_signal_emitted(world, "battle_requested")
	var config: Dictionary = get_signal_parameters(world, "battle_requested")[0]
	assert_eq(config["trainer_id"], "intern_ian")
	assert_eq(world.find_npc("intern_ian").cell, Vector2i(10, 18), "walked up next to you")
	assert_eq(world.player.facing, Vector2i.RIGHT, "you turn to face them")
	assert_true("Hey! You look like you know how to restart things. Battle me!" in world.dialogue_log)


func test_line_of_sight_is_blocked_by_obstacles() -> void:
	GameState.add_daemon(_daemon("chipmunk", 10))
	_open("route_1", "south")
	var ian := world.find_npc("intern_ian")
	world.player.setup(world.map, Vector2i(9, 18), Vector2i.UP)
	assert_true(world.trainer_sees_player(ian))
	world.map.occupied[Vector2i(10, 18)] = ian  # something in between
	assert_false(world.trainer_sees_player(ian))
	world.map.occupied.erase(Vector2i(10, 18))
	world.player.setup(world.map, Vector2i(9, 17), Vector2i.UP)
	assert_false(world.trainer_sees_player(ian), "not in their row")


func test_beaten_trainers_stay_beaten() -> void:
	GameState.add_daemon(_daemon("chipmunk", 10))
	GameState.flags[BattleScene.trainer_flag("intern_ian")] = true
	_open("route_1", "south")
	watch_signals(world)
	world.player.setup(world.map, Vector2i(9, 19), Vector2i.UP)
	await world.player.try_step(Vector2i.UP)
	await wait_until(func() -> bool: return world.is_idle(), 5.0)
	assert_signal_not_emitted(world, "battle_requested")
	world.player.setup(world.map, Vector2i(10, 18), Vector2i.RIGHT)
	await world.interact()
	assert_true("Intern Ian: I'm still on probation. Please don't tell my manager." in world.dialogue_log)


func test_talking_to_an_unbeaten_trainer_starts_the_battle() -> void:
	GameState.add_daemon(_daemon("chipmunk", 10))
	_open("route_1", "south")
	watch_signals(world)
	world.player.setup(world.map, Vector2i(10, 18), Vector2i.RIGHT)
	await world.interact()
	assert_signal_emitted(world, "battle_requested")
	assert_eq(world.find_npc("intern_ian").cell, Vector2i(11, 18), "didn't need to walk")


func test_losing_the_rival_battle_is_not_a_black_out() -> void:
	var weak := _daemon("dustbunny", 2)
	weak.current_uptime = 1
	var team: Array[DaemonInstance] = [weak]
	GameState.active_stack.assign(team)
	GameState.credits = 3000
	GameState.location = {"map": "help_desk", "x": 6, "y": 7, "facing": "up"}
	var config := BattleScene.trainer_config("kevin_rival_1_pingo")
	config["items"] = {}
	var scene := await _battle(config)
	assert_eq(scene.result["outcome"], "player_lost")
	assert_eq(GameState.credits, 3000, "no credits lost")
	assert_eq(GameState.location["map"], "help_desk", "you stay where you were")
	assert_eq(weak.current_uptime, weak.max_uptime(), "patched up")
	assert_true(GameState.flags.get("trainer_kevin_rival_1_pingo", false), "the story moves on")


# --- battle results ----------------------------------------------------------

func test_winning_pays_the_prize_and_marks_the_trainer() -> void:
	var team: Array[DaemonInstance] = [_daemon("motherboar", 30)]
	GameState.credits = 100
	var config := BattleScene.trainer_config("intern_ian")
	config["player_stack"] = team
	config["items"] = {}
	var scene := await _battle(config)
	assert_eq(scene.result["outcome"], "player_won")
	assert_eq(GameState.credits, 260)
	assert_true(GameState.flags.get("trainer_intern_ian", false))


func test_bosses_can_award_a_certification() -> void:
	var team: Array[DaemonInstance] = [_daemon("motherboar", 30)]
	var config := BattleScene.trainer_config("intern_ian")
	config["cert"] = "desktop_support"
	config["player_stack"] = team
	config["items"] = {}
	await _battle(config)
	assert_true("desktop_support" in GameState.certifications)


func test_black_out() -> void:
	var weak := _daemon("dustbunny", 2)
	weak.current_uptime = 1
	var team: Array[DaemonInstance] = [weak]
	GameState.active_stack.assign(team)
	GameState.credits = 1001
	GameState.location = {"map": "route_1", "x": 9, "y": 10, "facing": "up"}
	GameState.repel_steps = 40
	var config := BattleScene.trainer_config("sysadmin_sam")
	config["items"] = {}
	var scene := await _battle(config)
	assert_eq(scene.result["outcome"], "player_lost")
	assert_eq(GameState.credits, 501, "lost half (rounded down)")
	assert_eq(weak.current_uptime, weak.max_uptime(), "healed")
	assert_eq(GameState.location, GameState.last_help_desk, "back at the Help Desk")
	assert_eq(GameState.repel_steps, 0)
	assert_false(GameState.flags.get("trainer_sysadmin_sam", false))


func test_healing_sets_the_black_out_point() -> void:
	GameState.add_daemon(_daemon("chipmunk", 10))
	_open("help_desk")
	world.player.setup(world.map, Vector2i(6, 4), Vector2i.UP)
	world._remember_location()
	await world.interact()
	assert_eq(GameState.last_help_desk["map"], "help_desk")
	assert_eq(Vector2i(GameState.last_help_desk["x"], GameState.last_help_desk["y"]), Vector2i(6, 4))


# --- certifications in dialogue ----------------------------------------------

func test_cert_checks_and_awards_in_dialogue() -> void:
	_open("onboarding_town")
	var gate := [{"if_cert": "networking", "then": [{"text": "Access granted."}], "else": [{"text": "Access denied."}]}]
	await DialogueRunner.new(world).run(gate)
	assert_true("Access denied." in world.dialogue_log)
	await DialogueRunner.new(world).run([{"cmd": "give_cert", "cert": "networking"}])
	assert_true("networking" in GameState.certifications)
	await DialogueRunner.new(world).run(gate)
	assert_true("Access granted." in world.dialogue_log)


# --- saving ------------------------------------------------------------------

func _fill_state() -> void:
	GameState.trainer_id = 48213
	GameState.credits = 1234
	GameState.play_time_sec = 3725.5
	GameState.add_daemon(_daemon("pingo", 14))
	GameState.active_stack[0].nickname = "Packets"
	GameState.active_stack[0].current_uptime = 7
	GameState.racks[2].append(_daemon("wormby", 5))
	GameState.bag = {"coffee": 4, "thumb_drive": 2}
	GameState.flags = {"got_mom_coffee": true, "trainer_intern_ian": true}
	GameState.certifications.append("desktop_support")
	GameState.cmdb_seen = {"pingo": true, "wormby": true, "dustbunny": true}
	GameState.cmdb_caught = {"pingo": true, "wormby": true}
	GameState.cmdb_found_at = {"wormby": "Route 1: Cable Run"}
	GameState.location = {"map": "route_1", "x": 9, "y": 12, "facing": "left"}
	GameState.repel_steps = 33


func test_save_and_load_round_trip() -> void:
	_fill_state()
	var before := JSON.stringify(JSON.parse_string(JSON.stringify(GameState.to_dict())), "", true)
	assert_eq(SaveManager.save_game(), "")
	GameState.reset()
	assert_eq(GameState.credits, 0)
	assert_eq(SaveManager.load_game(), "")
	var after := JSON.stringify(JSON.parse_string(JSON.stringify(GameState.to_dict())), "", true)
	assert_eq(after, before, "everything came back")
	assert_eq(GameState.active_stack[0].display_name(), "Packets")
	assert_eq(GameState.racks[2][0].species_id, "wormby")
	assert_eq(GameState.location, {"map": "route_1", "x": 9, "y": 12, "facing": "left"})


func test_slots_alternate_and_newest_wins() -> void:
	GameState.credits = 1
	SaveManager.save_game()
	GameState.credits = 2
	SaveManager.save_game()
	assert_true(FileAccess.file_exists(TEST_SLOTS[0]) and FileAccess.file_exists(TEST_SLOTS[1]), "both slots used")
	GameState.credits = 3
	SaveManager.save_game()  # overwrites the older slot
	SaveManager.load_game()
	assert_eq(GameState.credits, 3)
	var counts := [int(SaveManager.read_slot(TEST_SLOTS[0])["save_count"]), int(SaveManager.read_slot(TEST_SLOTS[1])["save_count"])]
	counts.sort()
	assert_eq(counts, [2, 3])


func test_damaged_newest_save_falls_back_to_the_other_slot() -> void:
	GameState.credits = 10
	SaveManager.save_game()
	GameState.credits = 20
	SaveManager.save_game()
	# Truncate the newest file, like a crash halfway through writing it.
	var newest := TEST_SLOTS[0] if int(SaveManager.read_slot(TEST_SLOTS[0])["save_count"]) == 2 else TEST_SLOTS[1]
	var text := FileAccess.get_file_as_string(newest)
	var file := FileAccess.open(newest, FileAccess.WRITE)
	file.store_string(text.left(text.length() / 2))
	file.close()
	assert_eq(SaveManager.load_game(), "")
	assert_eq(GameState.credits, 10, "loaded the older, intact save")


func test_edited_or_future_saves_are_rejected() -> void:
	GameState.credits = 50
	SaveManager.save_game()
	var body: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_SLOTS[0]))
	body["data"]["credits"] = 999999  # edited by hand; checksum no longer matches
	var file := FileAccess.open(TEST_SLOTS[0], FileAccess.WRITE)
	file.store_string(JSON.stringify(body))
	file.close()
	assert_false(SaveManager.has_save())
	body["data"]["credits"] = 50
	body["version"] = SaveManager.SAVE_VERSION + 1
	file = FileAccess.open(TEST_SLOTS[0], FileAccess.WRITE)
	file.store_string(JSON.stringify(body))
	file.close()
	assert_true(SaveManager.read_slot(TEST_SLOTS[0]).is_empty(), "saves from a newer version aren't loaded")


func test_older_versions_go_through_migrate() -> void:
	GameState.credits = 70
	SaveManager.save_game()
	var body: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_SLOTS[0]))
	body["version"] = 0
	var file := FileAccess.open(TEST_SLOTS[0], FileAccess.WRITE)
	file.store_string(JSON.stringify(body))
	file.close()
	assert_eq(SaveManager.load_game(), "")
	assert_eq(GameState.credits, 70)


# --- the done-when -----------------------------------------------------------

func test_beat_a_trainer_save_quit_relaunch_continue() -> void:
	GameState.trainer_id = 11111
	GameState.add_daemon(_daemon("motherboar", 30))
	GameState.location = {"map": "route_1", "x": 10, "y": 18, "facing": "right"}
	var config := BattleScene.trainer_config("intern_ian")
	config["items"] = {}
	await _battle(config)
	assert_true(GameState.flags.get("trainer_intern_ian", false))
	assert_eq(SaveManager.save_game(), "")
	var credits := GameState.credits
	GameState.reset()  # "quit"
	assert_eq(SaveManager.load_game(), "")  # "relaunch → Continue"
	SceneRouter.params = {}
	world = load(Overworld.SCENE).instantiate()
	add_child_autofree(world)
	assert_eq(world.map.map_id, "route_1")
	assert_eq(world.player.cell, Vector2i(10, 18))
	assert_eq(world.player.facing, Vector2i.RIGHT)
	assert_eq(GameState.credits, credits)
	assert_false(world.find_npc("intern_ian").is_undefeated_trainer(), "Ian remembers losing")


# --- misc --------------------------------------------------------------------

func test_new_game_starts_with_nothing() -> void:
	var title_script: GDScript = load("res://scripts/ui/title_screen.gd")
	title_script.new_game()
	assert_eq(GameState.active_stack.size(), 0, "the starter comes from the manager")
	assert_between(GameState.trainer_id, 10000, 99999)
	assert_eq(GameState.credits, 3000)


func test_options_persist() -> void:
	var saved_path := Settings.path
	var old := [Settings.text_speed, Settings.sfx_volume, Settings.battle_animations]
	Settings.path = "user://test_settings.cfg"
	Settings.text_speed = "fast"
	Settings.sfx_volume = 0.3
	Settings.battle_animations = false
	Settings.save_settings()
	Settings.text_speed = "slow"
	Settings.battle_animations = true
	Settings.load_settings()
	assert_eq(Settings.text_speed, "fast")
	assert_almost_eq(Settings.sfx_volume, 0.3, 0.001)
	assert_false(Settings.battle_animations)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	Settings.path = saved_path
	Settings.text_speed = old[0]
	Settings.sfx_volume = old[1]
	Settings.battle_animations = old[2]
	Settings.apply()


func test_play_time_counts_only_in_game() -> void:
	GameState.clock_running = false
	GameState._process(5.0)
	assert_eq(GameState.play_time_sec, 0.0)
	GameState.clock_running = true
	GameState._process(5.0)
	assert_eq(GameState.play_time_sec, 5.0)
	GameState.clock_running = false
