extends GutTest
## Phase 5: wild encounters, item use, shop, Server Rack, field menus, and the full
## "walk into a cable tangle → catch → store → heal → CMDB" loop.

var world: Overworld


func before_each() -> void:
	GameState.reset()


func after_each() -> void:
	SceneRouter.params = {}
	GameState.reset()


func _daemon(species: String, lvl: int) -> DaemonInstance:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	return DaemonInstance.create(species, lvl, rng, 1)


func _rng(seed_value: int = 5) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _open(map_id: String, spawn: String = "default") -> void:
	SceneRouter.params = {"map": map_id, "spawn": spawn}
	world = load(Overworld.SCENE).instantiate()
	add_child_autofree(world)
	world.allow_scene_change = false
	world.auto_advance_text = true
	world.auto_choice = true
	world.set_time_scale(0.0)


## Presses an action through the real input pipeline, then lets a few frames run.
func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await wait_process_frames(3)


# --- encounters --------------------------------------------------------------

func test_encounter_tables_and_rolls() -> void:
	assert_true(DataRegistry.encounters.has("route_1"))
	var species_seen := {}
	var rng := _rng()
	for i in 2000:
		var hit := Encounters.roll("route_1", "cable_tangle", rng, 1, false, 1.0)
		assert_false(hit.is_empty())
		species_seen[hit["species"]] = int(species_seen.get(hit["species"], 0)) + 1
		if hit["species"] == "cablesnake":
			assert_between(int(hit["level"]), 3, 5)
	var slots: Array = DataRegistry.encounters["route_1"]["zones"]["cable_tangle"]
	assert_eq(species_seen.size(), slots.size(), "every slot shows up")
	var total := 0.0
	var dust_weight := 0.0
	for slot: Dictionary in slots:
		total += float(slot["weight"])
		if slot["species"] == "dustbunny":
			dust_weight = float(slot["weight"])
	var expected := 2000.0 * dust_weight / total
	assert_between(int(species_seen["dustbunny"]), int(expected * 0.8), int(expected * 1.2), "matches its weight")
	assert_lt(int(species_seen["floppit"]), int(species_seen["spigeon"]), "rare slot is rarer")
	assert_true(Encounters.roll("route_1", "cable_tangle", rng, 1, false, 0.0).is_empty(), "rate 0")
	assert_true(Encounters.roll("route_1", "grass", rng, 1, false, 1.0).is_empty(), "plain grass")
	assert_true(Encounters.roll("player_house", "floor", rng, 1, false, 1.0).is_empty(), "no table")


func test_firewall_rule_blocks_weaker_daemons() -> void:
	var rng := _rng()
	for i in 200:
		assert_true(Encounters.roll("route_1", "cable_tangle", rng, 50, true, 1.0).is_empty())
	assert_false(Encounters.roll("route_1", "cable_tangle", rng, 1, true, 1.0).is_empty(), "weaker lead: no block")


func test_stepping_in_a_cable_tangle_starts_a_wild_battle() -> void:
	GameState.add_daemon(_daemon("chipmunk", 8))
	_open("route_1", "south")
	world.encounter_rate_override = 1.0
	watch_signals(world)
	world.player.setup(world.map, Vector2i(7, 9), Vector2i.LEFT)
	await world.player.try_step(Vector2i.UP)  # (7, 8) is a cable tangle
	await wait_until(func() -> bool: return world.is_idle(), 5.0)
	assert_signal_emitted(world, "battle_requested")
	var config: Dictionary = get_signal_parameters(world, "battle_requested")[0]
	assert_true(config["wild"])
	assert_eq(config["return_scene"], Overworld.SCENE)
	var species: String = config["foe"][0][0]
	assert_eq(GameState.cmdb_found_at[species], "Route 1: Cable Run")


func test_no_encounters_without_a_daemon_that_can_fight() -> void:
	_open("route_1", "south")
	world.encounter_rate_override = 1.0
	watch_signals(world)
	world.player.setup(world.map, Vector2i(7, 9), Vector2i.LEFT)
	await world.player.try_step(Vector2i.UP)
	assert_signal_not_emitted(world, "battle_requested")


func test_firewall_rule_counts_down_and_expires() -> void:
	GameState.add_daemon(_daemon("chipmunk", 8))
	GameState.repel_steps = 2
	_open("onboarding_town")
	await world.player.try_step(Vector2i.DOWN)
	assert_eq(GameState.repel_steps, 1)
	await world.player.try_step(Vector2i.DOWN)
	await wait_until(func() -> bool: return world.is_idle(), 5.0)
	assert_eq(GameState.repel_steps, 0)
	assert_true("The Firewall Rule expired." in world.dialogue_log)


# --- items, shop, racks ------------------------------------------------------

func test_item_use_outside_battle() -> void:
	var chipmunk := _daemon("chipmunk", 10)
	GameState.add_daemon(chipmunk)
	GameState.bag = {"coffee": 2, "hard_reboot": 1, "overclock_chip": 1, "firewall_rule": 1, "thumb_drive": 1}
	assert_false(ItemUse.use_on("coffee", chipmunk)["ok"], "already full")
	assert_eq(GameState.bag["coffee"], 2, "not used up")
	chipmunk.current_uptime -= 5
	assert_true(ItemUse.use_on("coffee", chipmunk)["ok"])
	assert_eq(chipmunk.current_uptime, chipmunk.max_uptime())
	assert_eq(GameState.bag["coffee"], 1)
	assert_false(ItemUse.use_on("hard_reboot", chipmunk)["ok"], "not crashed")
	chipmunk.current_uptime = 0
	assert_true(ItemUse.use_on("hard_reboot", chipmunk)["ok"])
	assert_eq(chipmunk.current_uptime, chipmunk.max_uptime() / 2)
	assert_true(ItemUse.use_on("overclock_chip", chipmunk)["ok"])
	assert_eq(chipmunk.level, 11)
	assert_true(ItemUse.use_in_field("firewall_rule")["ok"])
	assert_eq(GameState.repel_steps, 100)
	assert_false(ItemUse.use_in_field("thumb_drive")["ok"], "keys only in wild battles")


func test_legacy_driver_upgrades_floppit() -> void:
	var floppit := _daemon("floppit", 8)
	GameState.add_daemon(floppit)
	GameState.bag = {"legacy_driver": 1}
	var result := ItemUse.use_on("legacy_driver", floppit)
	assert_true(result["ok"])
	assert_eq(floppit.species_id, "ziphare")
	assert_true(GameState.cmdb_caught.has("ziphare"))
	assert_false(GameState.bag.has("legacy_driver"))


func test_shop_buy_and_sell() -> void:
	GameState.credits = 1000
	assert_eq(Shop.buy("coffee", 3), "")
	assert_eq(GameState.credits, 400)
	assert_eq(GameState.bag["coffee"], 3)
	assert_eq(Shop.max_buyable("coffee"), 2)
	assert_eq(Shop.buy("coffee", 3), "You can't afford that.")
	assert_eq(Shop.buy("root_key", 1), "That's not for sale.")
	assert_eq(Shop.sell("coffee", 2), "")
	assert_eq(GameState.credits, 600, "sold at half price")
	assert_eq(GameState.bag["coffee"], 1)
	assert_eq(Shop.sell("coffee", 5), "You don't have that many.")
	GameState.bag["root_key"] = 1
	assert_false(Shop.can_sell("root_key"))


func test_server_rack_rules() -> void:
	for i in 7:
		assert_eq(GameState.add_daemon(_daemon("dustbunny", 3 + i)), "rack" if i == 6 else "stack")
	assert_eq(GameState.racks.size(), 12)
	assert_eq(GameState.rack_total(), 1)
	assert_eq(GameState.withdraw(0, 0), "Your Active Stack is full.")
	assert_eq(GameState.deposit(5, 0), "")
	assert_eq(GameState.active_stack.size(), 5)
	assert_eq(GameState.move_between_racks(0, 0, 3), "")
	assert_eq(GameState.racks[3].size(), 1)
	assert_eq(GameState.withdraw(3, 0), "")
	assert_eq(GameState.active_stack.size(), 6)
	# can't leave yourself without a Daemon that can fight
	for d: DaemonInstance in GameState.active_stack.slice(1):
		d.current_uptime = 0
	assert_eq(GameState.deposit(0, 0), "You need at least one Daemon that can fight.")
	for i in 30:
		GameState.racks[5].append(_daemon("wormby", 2))
	assert_eq(GameState.deposit(1, 5), "That rack is full.")


func test_stack_order_and_lead() -> void:
	GameState.add_daemon(_daemon("chipmunk", 12))
	GameState.add_daemon(_daemon("pingo", 7))
	GameState.active_stack[0].current_uptime = 0
	assert_eq(GameState.lead_level(), 7, "skips crashed Daemons")
	GameState.swap_stack(0, 1)
	assert_eq(GameState.active_stack[0].species_id, "pingo")


# --- menus (driven with real input events) -----------------------------------

func test_deposit_through_the_server_rack_menu() -> void:
	GameState.add_daemon(_daemon("chipmunk", 12))
	GameState.add_daemon(_daemon("dustbunny", 4))
	GameState.flags["got_starter"] = true  # skip the manager's arrival cutscene
	_open("help_desk")
	var done := [false]
	var flow := func() -> void:
		await world.field_menus.rack_screen()
		done[0] = true
	flow.call()
	await wait_process_frames(2)
	await _press("ui_down")    # WITHDRAW -> DEPOSIT
	await _press("ui_accept")
	await _press("ui_down")    # Chipmunk -> Dustbunny
	await _press("ui_accept")
	await _press("ui_accept")  # Rack 1
	await wait_until(func() -> bool: return world.field_menus.side.is_choosing(), 5.0)
	await _press("ui_cancel")
	await wait_until(func() -> bool: return done[0], 5.0)
	assert_eq(GameState.racks[0].size(), 1)
	assert_eq(GameState.racks[0][0].species_id, "dustbunny")
	assert_eq(GameState.active_stack.size(), 1)


func test_buy_through_the_supply_closet() -> void:
	GameState.credits = 500
	GameState.flags["got_starter"] = true
	_open("help_desk")
	var done := [false]
	var flow := func() -> void:
		await world.field_menus.shop(["coffee", "thumb_drive"])
		done[0] = true
	flow.call()
	await wait_process_frames(2)
	await _press("ui_accept")  # BUY
	await _press("ui_accept")  # Coffee (quantity and "OK?" answered by auto_choice)
	await wait_until(func() -> bool: return world.field_menus.list.is_choosing(), 5.0)
	await _press("ui_cancel")  # leave the buy list
	await wait_until(func() -> bool: return world.field_menus.side.is_choosing(), 5.0)
	await _press("ui_cancel")  # leave the shop
	await wait_until(func() -> bool: return done[0], 5.0)
	assert_eq(GameState.credits, 300)
	assert_eq(GameState.bag.get("coffee", 0), 1)


func test_pause_menu_opens_stack_summary_and_cmdb() -> void:
	GameState.add_daemon(_daemon("pingo", 9))
	GameState.cmdb_seen["dustbunny"] = true
	_open("onboarding_town")
	await _press("menu")
	assert_true(world.field_menus.side.is_choosing(), "pause menu is open")
	await _press("ui_down")    # CMDB -> STACK
	await _press("ui_accept")
	await _press("ui_accept")  # Pingo
	await _press("ui_accept")  # SUMMARY
	assert_true(world.field_menus.summary.visible)
	await _press("ui_right")   # STATS page
	await _press("ui_cancel")
	await wait_until(func() -> bool: return world.field_menus.list.is_choosing(), 5.0)
	await _press("ui_cancel")  # back to pause
	await wait_until(func() -> bool: return world.field_menus.side.is_choosing(), 5.0)
	await _press("ui_up")      # STACK -> CMDB
	await _press("ui_accept")
	await wait_until(func() -> bool: return world.field_menus.list.is_choosing(), 5.0)
	await _press("ui_cancel")
	await wait_until(func() -> bool: return world.field_menus.side.is_choosing(), 5.0)
	await _press("ui_cancel")  # close pause
	await wait_until(func() -> bool: return world.is_idle(), 5.0)
	assert_true(world.is_idle())
	assert_false(world.field_menus.side.visible)


# --- the whole loop ----------------------------------------------------------

func test_catch_store_heal_and_cmdb() -> void:
	var chipmunk := _daemon("chipmunk", 12)
	GameState.add_daemon(chipmunk)
	GameState.bag = {"root_key": 1}
	# A cable tangle encounter: battle on the real battle screen, Quarantine it.
	var scene: BattleScene = load(BattleScene.SCENE).instantiate()
	scene.setup({"foe": [["wormby", 3]], "wild": true, "auto": true, "auto_policy": "capture", "time_scale": 0.0, "seed": 3})
	add_child_autofree(scene)
	await wait_for_signal(scene.finished, 30.0)
	assert_eq(scene.result["outcome"], "caught")
	assert_eq(GameState.active_stack.size(), 2)
	# Store it in the Server Rack.
	assert_eq(GameState.deposit(1, 0), "")
	assert_eq(GameState.racks[0][0].species_id, "wormby")
	# Heal at the Help Desk.
	chipmunk.current_uptime = 1
	GameState.heal_stack()
	assert_eq(chipmunk.current_uptime, chipmunk.max_uptime())
	# It's in the CMDB as seen and quarantined.
	assert_true(GameState.cmdb_seen.has("wormby"))
	assert_true(GameState.cmdb_caught.has("wormby"))
