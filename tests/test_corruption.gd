extends GutTest
## Corrupted Hexforged (HEXFORGED story, 2026-11-15): ERR:: versions of wild species, caught into the Quarantined
## pocket, cleaned at a Help Desk. Malware lines (Ransom's own builds) can never be corrupted.

var world: Overworld


func before_each() -> void:
	GameState.reset()
	GameState.flags["corruption_revealed"] = true  # most tests here are about after the Power Plant reveal


func after_each() -> void:
	SceneRouter.params = {}
	GameState.reset()


func _d(species: String, lvl: int, corrupted := false) -> DaemonInstance:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var d := DaemonInstance.create(species, lvl, rng, 1)
	d.is_corrupted = corrupted
	return d


func test_corruption_adds_malware_and_cleaning_removes_it() -> void:
	var snake := _d("cablesnake", 12, true)
	assert_eq(snake.types(), ["network", "malware"], "Malware becomes its second type")
	assert_eq(snake.display_name(), "ERR::CABLESNAKE")
	assert_eq(DataRegistry.type_multiplier("security", snake.types()), 2.0, "Security hits it super-effectively")
	snake.is_corrupted = false
	assert_eq(snake.types(), ["network"])
	assert_eq(snake.display_name(), "Cablesnake")
	var bat := _d("fanbat", 20, true)
	assert_eq(bat.types(), ["hardware", "malware"], "a dual type keeps its first type, Malware replaces the second")


func test_stat_mods_only_while_corrupted() -> void:
	var d := _d("ramster", 30)
	var clean := d.stats()
	d.is_corrupted = true
	var bad := d.stats()
	assert_eq(bad["throughput"], floori(clean["throughput"] * 1.10))
	assert_eq(bad["encryption"], floori(clean["encryption"] * 0.90))
	assert_eq(bad["uptime"], clean["uptime"], "Uptime is never modified")
	assert_eq(bad["compute"], clean["compute"])
	d.is_corrupted = false
	assert_eq(d.stats(), clean, "back to normal once cleaned")


func test_a_corrupted_hexforged_cant_enter_the_stack() -> void:
	var where := GameState.add_daemon(_d("cablesnake", 10, true))
	assert_eq(where, "quarantined")
	assert_eq(GameState.active_stack.size(), 0, "not in the stack")
	assert_eq(GameState.quarantined.size(), 1, "in the Quarantined pocket")
	assert_true(GameState.cmdb_seen.has("cablesnake"), "seeing one counts as seen")
	assert_true(GameState.cmdb_compromised.has("cablesnake"))
	assert_false(GameState.has_usable_daemon(), "it can't battle for you")


func test_cleaning_flips_the_flag_and_goes_to_stack_or_rack() -> void:
	GameState.add_daemon(_d("cablesnake", 10, true))
	assert_eq(GameState.clean_quarantined(0), "stack")
	assert_false(GameState.active_stack[0].is_corrupted)
	assert_true(GameState.quarantined.is_empty())
	assert_true(GameState.cmdb_recovered.has("cablesnake"))
	assert_eq(CmdbPanel.status_line("cablesnake"), "Status: Recovered")
	for i in 5:
		GameState.add_daemon(_d("dustbunny", 5))
	GameState.add_daemon(_d("fanbat", 10, true))
	assert_eq(GameState.clean_quarantined(0), "rack", "full stack: it goes to the Server Rack")
	assert_false(GameState.racks[0][0].is_corrupted)
	assert_eq(GameState.clean_quarantined(0), "", "nothing left to clean")


func test_cmdb_says_compromised_until_one_is_cleaned() -> void:
	assert_eq(CmdbPanel.status_line("fanbat"), "")
	GameState.cmdb_compromised["fanbat"] = true
	assert_string_starts_with(CmdbPanel.status_line("fanbat"), "Status: COMPROMISED")


func test_malware_lines_can_never_roll_corrupted() -> void:
	for id in ["wormby", "wormhole", "spigeon", "botgeon"]:
		assert_false(DaemonInstance.can_be_corrupted(id), "%s is Ransom's own build" % id)
	assert_true(DaemonInstance.can_be_corrupted("cablesnake"))
	var saved: Variant = DataRegistry.encounters.get("zz_test")
	DataRegistry.encounters["zz_test"] = {"rate": 1.0, "zones": {"cable_tangle": [
		{"species": "wormby", "min": 5, "max": 5, "weight": 1, "corrupted_chance": 1.0}]}}
	var rng := RandomNumberGenerator.new()
	for i in 50:
		var hit := Encounters.roll("zz_test", "cable_tangle", rng, 1, false)
		assert_false(hit["corrupted"], "Wormby never comes corrupted")
	DataRegistry.encounters["zz_test"] = {"rate": 1.0, "zones": {"cable_tangle": [
		{"species": "cablesnake", "min": 5, "max": 5, "weight": 1, "corrupted_chance": 1.0}]}}
	assert_true(Encounters.roll("zz_test", "cable_tangle", rng, 1, false)["corrupted"], "chance 1.0 always does")
	DataRegistry.encounters.erase("zz_test")
	# A save that claims a Wormby is corrupted is ignored.
	var w := _d("wormby", 5)
	var dict := w.to_dict()
	dict["corrupted"] = true
	assert_false(DaemonInstance.from_dict(dict).is_corrupted)


func test_validator_rejects_corrupted_malware_and_bad_chances() -> void:
	var raw := DataRegistry.read_raw(PackedStringArray())
	for s: Dictionary in raw["species"]:
		if s["id"] == "wormby":
			s["corrupted"] = {"name_prefix": "ERR::", "add_type": "Malware", "stat_mods": {}}
	for slot: Dictionary in raw["encounters"]["power_plant"]["zones"]["cable_tangle"]:  # after the reveal
		if slot["species"] == "transistant":
			slot["corrupted_chance"] = 0.5
		if slot["species"] == "fanbat":
			slot["corrupted_chance"] = 1.5
	var errors := "\n".join(DataValidator.new().validate(raw))
	assert_string_contains(errors, "Malware lines can't be corrupted")
	assert_string_contains(errors, "'transistant' has no corrupted block")
	assert_string_contains(errors, "'corrupted_chance' must be 0.0 to 1.0")


func test_saves_round_trip_corruption() -> void:
	GameState.add_daemon(_d("dustbunny", 6))
	GameState.add_daemon(_d("cablesnake", 10, true))
	GameState.cmdb_recovered["fanbat"] = true
	var saved: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	GameState.reset()
	GameState.from_dict(saved)
	assert_eq(GameState.quarantined.size(), 1)
	assert_true(GameState.quarantined[0].is_corrupted, "is_corrupted survives a save")
	assert_false(GameState.active_stack[0].is_corrupted)
	assert_true(GameState.cmdb_compromised.has("cablesnake"))
	assert_true(GameState.cmdb_recovered.has("fanbat"))


func test_wild_battle_spawns_err_version() -> void:
	var rng := RandomNumberGenerator.new()
	var team: Array[DaemonInstance] = [_d("pingo", 14)]
	var scene: BattleScene = load(BattleScene.SCENE).instantiate()
	scene.setup({"foe": [["cablesnake", 12, true]], "player_stack": team, "wild": true, "auto": true, "time_scale": 0.0, "seed": 1})
	var foe := scene.state.sides[BattleState.FOE].active()
	assert_true(foe.is_corrupted)
	assert_eq(scene.host_label(), "ERR::CABLESNAKE")
	scene.free()
	assert_not_null(DaemonSprites.corrupted_pose("cablesnake", "idle"), "placeholder corrupted sprite")


func test_help_desk_cleans_it_end_to_end() -> void:
	GameState.flags["got_starter"] = true
	GameState.add_daemon(_d("pingo", 10))
	GameState.add_daemon(_d("cablesnake", 9, true))
	SceneRouter.params = {"map": "help_desk", "spawn": "default"}
	world = load(Overworld.SCENE).instantiate()
	world.allow_scene_change = false
	world.auto_advance_text = true
	world.auto_choice = true
	add_child_autofree(world)
	world.set_time_scale(0.0)
	await wait_process_frames(3)
	await wait_until(func() -> bool: return world.is_idle(), 5.0)
	var tech := world.find_npc("tech")
	world.player.setup(world.map, tech.cell + Vector2i.DOWN * 2, Vector2i.UP)
	await world.run_dialogue("help_desk_tech", tech)
	var joined := " ".join(world.dialogue_log)
	assert_string_contains(joined, "ERR::CABLESNAKE was restored to CABLESNAKE!")
	assert_true(GameState.quarantined.is_empty())
	assert_eq(GameState.active_stack.size(), 2)
	assert_false(GameState.active_stack[1].is_corrupted)


func test_clean_effect_ends_on_the_clean_sprite() -> void:
	var bad := DaemonSprites.corrupted_pose("fanbat", "idle")
	var good := DaemonSprites.pose("fanbat", "idle")
	var final := CleanEffect.swap_step(bad.get_image(), good.get_image(), CleanEffect.SWAP_STEPS)
	var g := good.get_image()
	g.convert(Image.FORMAT_RGBA8)
	assert_eq(final.get_data(), g.get_data(), "the last swap step is exactly the clean sprite")
	var half := CleanEffect.swap_step(bad.get_image(), good.get_image(), 2)
	assert_ne(half.get_data(), g.get_data(), "halfway is a mix (stepped, not a crossfade)")
	var fx := CleanEffect.new()
	fx.time_scale = 0.0
	add_child_autofree(fx)
	await fx.play(bad, good)
	assert_eq(fx._tex, good, "finishes on the clean sprite")


func test_old_daemons_user_data_is_copied_once() -> void:
	var base := ProjectSettings.globalize_path("user://").path_join("zz_old_user_dir")
	DirAccess.make_dir_recursive_absolute(base)
	var f := FileAccess.open(base.path_join("settings.cfg"), FileAccess.WRITE)
	f.store_string("[test]\nold=true\n")
	f.close()
	var target := ProjectSettings.globalize_path("user://settings.cfg")
	var had := FileAccess.file_exists(target)
	var copied := SaveManager.carry_over_old_user_data(base)
	if had:
		assert_false("settings.cfg" in copied, "never overwrites what's already there")
	else:
		assert_true("settings.cfg" in copied)
		DirAccess.remove_absolute(target)
	DirAccess.remove_absolute(base.path_join("settings.cfg"))
	DirAccess.remove_absolute(base)



# --- the GDD's slow reveal (2026-11-15) ------------------------------------------------------------------------------

func test_nothing_corrupted_before_the_power_plant_reveal() -> void:
	GameState.flags.erase("corruption_revealed")
	DataRegistry.encounters["zz_test"] = {"rate": 1.0, "zones": {"cable_tangle": [
		{"species": "cablesnake", "min": 5, "max": 5, "weight": 1, "corrupted_chance": 1.0}]}}
	var rng := RandomNumberGenerator.new()
	assert_false(Encounters.roll("zz_test", "cable_tangle", rng, 1, false)["corrupted"], "no ERR:: before the reveal")
	DataRegistry.encounters.erase("zz_test")
	GameState.cmdb_compromised["cablesnake"] = true
	assert_eq(CmdbPanel.status_line("cablesnake"), "", "CMDB status hidden")
	var menus := FieldMenus.new()
	assert_eq(menus._bag_pages(), FieldMenus.POCKETS.size(), "no QUARANTINED page")
	GameState.flags["corruption_revealed"] = true
	assert_eq(menus._bag_pages(), FieldMenus.POCKETS.size() + 1, "the page appears after the reveal")
	menus.free()


func test_the_power_plant_reveals_corruption() -> void:
	var steps: Array = DataRegistry.get_dialogue("power_plant_arrival")
	assert_true(steps.any(func(st: Dictionary) -> bool: return st.get("flag", "") == "corruption_revealed"))


func test_validation_rejects_corruption_before_the_power_plant() -> void:
	for map_id in DataValidator.PRE_POWER_PLANT_AREAS:
		for zone: Array in DataRegistry.encounters.get(map_id, {}).get("zones", {}).values():
			for slot: Dictionary in zone:
				assert_eq(float(slot.get("corrupted_chance", 0.0)), 0.0, "%s %s" % [map_id, slot["species"]])
	var raw := DataRegistry.read_raw(PackedStringArray())
	raw["encounters"]["route_2"]["zones"]["cable_tangle"][1]["corrupted_chance"] = 0.3
	assert_string_contains("\n".join(DataValidator.new().validate(raw)), "no corrupted Hexforged before the Power Plant")
