extends GutTest
## Act 2 part 1 (story outline, approved 2026-11-13): the "-R" email leaving Patch Town, Route 2, Port City
## (encrypted Help Desk, Kevin's second battle, Pyrewall going dark at Port 443) and the Networking Department.

var world: Overworld


func before_each() -> void:
	GameState.reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	GameState.add_daemon(DaemonInstance.create("chipmunk", 16, rng, 1))
	GameState.flags["got_starter"] = true


func after_each() -> void:
	SceneRouter.params = {}
	GameState.reset()


func _open(map_id: String, spawn: String = "default") -> void:
	SceneRouter.params = {"map": map_id, "spawn": spawn}
	world = load(Overworld.SCENE).instantiate()
	world.allow_scene_change = false
	world.auto_advance_text = true
	world.auto_choice = true
	watch_signals(world)
	add_child_autofree(world)
	world.set_time_scale(0.0)
	await wait_process_frames(2)


func _logged(part: String) -> bool:
	for line in world.dialogue_log:
		if part in line:
			return true
	return false


func _step(dir: Vector2i) -> void:
	await world.player.try_step(dir)
	await wait_until(func() -> bool: return world.is_idle(), 5.0)


func test_leaving_patch_town_brings_the_ransom_email_then_route_2() -> void:
	GameState.certifications.append("desktop_support")
	GameState.flags["patch_gate_open"] = true
	await _open("patch_town")
	world.player.setup(world.map, Vector2i(14, 2), Vector2i.UP)
	await _step(Vector2i.UP)
	assert_true(_logged("YOUR FILES HAVE BEEN QUARANTINED"), "every phone buzzes")
	assert_true(_logged("yogurt"), "and Kevin replies-all")
	assert_true(GameState.flags.get("ransom_email_seen", false))
	await _step(Vector2i.UP)
	await wait_until(func() -> bool: return world.map.map_id == "route_2" and world.is_idle(), 5.0)
	assert_eq(world.map.map_id, "route_2", "the road north is open")


func test_arriving_in_port_city() -> void:
	await _open("port_city", "south")
	await wait_until(func() -> bool: return world.is_idle(), 5.0)
	assert_true(GameState.flags.get("port_city_arrived", false))
	assert_true(_logged("Port 443"))


func test_the_port_city_help_desk_is_encrypted_but_the_container_heals() -> void:
	GameState.flags["port_city_arrived"] = true
	await _open("port_city")
	world.player.setup(world.map, Vector2i(6, 13), Vector2i.UP)
	await _step(Vector2i.UP)
	assert_true(_logged("QUARANTINED"), "the real Help Desk is locked")
	assert_eq(world.player.cell, Vector2i(6, 13), "and you step back out")
	GameState.active_stack[0].current_uptime = 1
	world.player.setup(world.map, Vector2i(10, 14), Vector2i.UP)
	await world.interact()
	assert_eq(GameState.active_stack[0].current_uptime, GameState.active_stack[0].max_uptime(), "the pop-up heals")
	assert_eq(String(GameState.last_help_desk.get("map", "")), "port_city", "and becomes your last Help Desk")


func test_kevin_meets_you_on_the_docks_with_the_starter_that_beats_yours() -> void:
	GameState.flags["port_city_arrived"] = true
	GameState.flags["starter_chipmunk"] = true
	await _open("port_city")
	world.player.setup(world.map, Vector2i(17, 8), Vector2i.UP)
	await _step(Vector2i.UP)
	await wait_until(func() -> bool: return not get_signal_parameters(world, "battle_requested").is_empty(), 5.0)
	var config: Dictionary = get_signal_parameters(world, "battle_requested")[0]
	assert_eq(config["trainer_id"], "kevin_rival_2_pingo", "Pengwan line beats Chipmunk")
	assert_true(config["story"], "a rival fight: losing doesn't black out")
	assert_eq(config["zone"], "coolant_loop", "Port City battles use the Coolant Loop arena")
	assert_true(world.find_npc("kevin_docks").visible)


func test_zed_takes_pyrewall_offline_at_port_443() -> void:
	GameState.flags["port_city_arrived"] = true
	GameState.flags["kevin_docks_met"] = true
	await _open("port_city")
	world.player.setup(world.map, Vector2i(27, 4), Vector2i.UP)
	await _step(Vector2i.UP)
	assert_true(GameState.flags.get("pyrewall_offline", false))
	assert_true(_logged("goes dark"))
	assert_false(world.find_npc("zed").visible, "Zed is gone")
	world.player.setup(world.map, Vector2i(28, 6), Vector2i.UP)
	await world.interact()
	assert_true(_logged("spray-painted"), "the Port 443 sign changes")


func test_networking_department_vlan_door() -> void:
	await _open("department_2")
	await wait_until(func() -> bool: return world.is_idle(), 5.0)
	assert_true(_logged("VLAN"), "the receptionist explains the puzzle")
	assert_false(world.map.is_walkable(Vector2i(7, 9)), "laser door closed")
	for x in [6, 10]:  # trunks B and C
		world.player.setup(world.map, Vector2i(x, 12), Vector2i.UP)
		await world.interact()
	assert_true(world.map.is_walkable(Vector2i(7, 9)), "B + C on -> open")
	world.player.setup(world.map, Vector2i(2, 12), Vector2i.UP)
	await world.interact()  # bridge the guest network
	assert_false(world.map.is_walkable(Vector2i(7, 9)), "guest Wi-Fi on -> closed again")


func test_ping_awards_the_networking_cert() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var team: Array[DaemonInstance] = [DaemonInstance.create("mainmunk", 45, rng, 1)]
	var config := BattleScene.trainer_config("ping_okoro")
	assert_eq(config["music"], "battle_boss")
	config.merge({"player_stack": team, "items": {}, "auto": true, "time_scale": 0.0, "seed": 2}, true)
	var scene: BattleScene = load(BattleScene.SCENE).instantiate()
	scene.setup(config)
	add_child_autofree(scene)
	await wait_for_signal(scene.finished, 30.0)
	assert_eq(scene.result["outcome"], "player_won")
	assert_true("networking" in GameState.certifications)


func test_act2_levels_climb_from_dana_to_ping() -> void:
	var ace := func(id: String) -> int:
		var best := 0
		for entry: Array in DataRegistry.trainers[id]["team"]:
			best = maxi(best, int(entry[1]))
		return best
	assert_gt(ace.call("ping_okoro"), ace.call("dana"))
	assert_gt(ace.call("ping_okoro"), ace.call("kevin_rival_2_pingo"))
	assert_gt(ace.call("kevin_rival_2_pingo"), ace.call("kevin_rival_1_pingo"))


# --- Act 2 part 2: The Basement, DevOps Heights, the Abandoned Data Center --------

func test_the_basement_gate_needs_the_networking_cert() -> void:
	GameState.flags["port_city_arrived"] = true
	await _open("port_city")
	world.player.setup(world.map, Vector2i(32, 14), Vector2i.RIGHT)
	await world.interact()
	assert_true(_logged("Networking Cert"))
	assert_false(GameState.flags.get("basement_open", false))
	GameState.certifications.append("networking")
	await world.interact()
	assert_true(GameState.flags.get("basement_open", false))
	assert_eq(await world.player.try_step(Vector2i.RIGHT), "moved", "the guard stepped aside")


func test_restorephant_and_the_legacy_driver_after_brute() -> void:
	GameState.flags["basement_arrived"] = true
	await _open("the_basement", "east")
	world.player.setup(world.map, Vector2i(28, 4), Vector2i.DOWN)
	await world.interact()
	assert_true(_logged("still at the door"), "the archivist hides while Brute is here")
	assert_false(GameState.bag.has("legacy_driver"))
	GameState.flags["trainer_brute_basement"] = true
	world.player.setup(world.map, Vector2i(27, 4), Vector2i.UP)
	await _step(Vector2i.UP)
	assert_true(GameState.flags.get("restorephant_seen", false))
	assert_true(_logged("RESTOREPHANT"))
	world.player.setup(world.map, Vector2i(28, 4), Vector2i.DOWN)
	await world.interact()
	assert_true(GameState.bag.has("legacy_driver"), "Ziphare is reachable in normal play now")


func test_kevin_admits_he_got_phished_in_devops_heights() -> void:
	GameState.flags["starter_pingo"] = true
	await _open("devops_heights")
	world.player.setup(world.map, Vector2i(20, 13), Vector2i.RIGHT)
	await _step(Vector2i.RIGHT)
	await wait_until(func() -> bool: return not get_signal_parameters(world, "battle_requested").is_empty(), 5.0)
	var config: Dictionary = get_signal_parameters(world, "battle_requested")[0]
	assert_eq(config["trainer_id"], "kevin_rival_3_glowbit", "Scriptfly line beats Pengwan")
	var kevin := world.find_npc("kevin_devops")
	world.player.setup(world.map, kevin.cell + Vector2i.DOWN, Vector2i.UP)
	await world.interact()
	assert_true(_logged("MFA"), "he turned on MFA for everything")


func test_devops_pipeline_door() -> void:
	await _open("department_3")
	await wait_until(func() -> bool: return world.is_idle(), 5.0)
	assert_false(world.map.is_walkable(Vector2i(7, 9)))
	for x in [2, 6]:  # BUILD and TESTS
		world.player.setup(world.map, Vector2i(x, 12), Vector2i.UP)
		await world.interact()
	assert_true(world.map.is_walkable(Vector2i(7, 9)), "green pipeline -> open")
	world.player.setup(world.map, Vector2i(10, 12), Vector2i.UP)
	await world.interact()
	assert_false(world.map.is_walkable(Vector2i(7, 9)), "never deploy on a Friday")


func test_devi_awards_the_software_cert() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var team: Array[DaemonInstance] = [DaemonInstance.create("mainmunk", 50, rng, 1)]
	var config := BattleScene.trainer_config("devi_shah")
	config.merge({"player_stack": team, "items": {}, "auto": true, "time_scale": 0.0, "seed": 2}, true)
	var scene: BattleScene = load(BattleScene.SCENE).instantiate()
	scene.setup(config)
	add_child_autofree(scene)
	await wait_for_signal(scene.finished, 30.0)
	assert_eq(scene.result["outcome"], "player_won")
	assert_true("software" in GameState.certifications)


func test_cooling_units_open_the_data_center_door() -> void:
	GameState.flags["data_center_arrived"] = true
	await _open("abandoned_data_center")
	assert_false(world.map.is_walkable(Vector2i(26, 10)), "overheat lock")
	for x in [8, 20]:
		world.player.setup(world.map, Vector2i(x, 14), Vector2i.DOWN)
		await world.interact()
	assert_true(world.map.is_walkable(Vector2i(26, 10)), "both cooling units on -> open")


func test_cron_takes_sudofox_and_marge_calls() -> void:
	GameState.flags["data_center_arrived"] = true
	await _open("abandoned_data_center")
	world.player.setup(world.map, Vector2i(2, 6), Vector2i.UP)
	assert_false(world.map.is_walkable(Vector2i(2, 5)), "Zed blocks the last aisle")
	GameState.flags["trainer_zed_dc"] = true
	world.player.setup(world.map, Vector2i(2, 4), Vector2i.UP)
	await world.player.try_step(Vector2i.RIGHT)
	await world.player.try_step(Vector2i.LEFT)
	await wait_until(func() -> bool: return world.is_idle(), 5.0)
	assert_true(GameState.flags.get("sudofox_taken", false))
	assert_true(_logged("SUDOFOX"))
	assert_true(_logged("it needs Friday"), "Marge calls")
	assert_false(world.find_npc("cron").visible, "Cron is gone")
