extends GutTest
## Phase 1b: EXP curves, stat formulas, level up, move learning, evolution, save round trip.


func _rng(seed_value: int = 42) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## A Daemon with fixed build quality, no logs, a chosen profile. No randomness.
func _make(species: String, lvl: int, bq: int = 31, profile: String = "balanced") -> DaemonInstance:
	var d := DaemonInstance.new()
	d.species_id = species
	d.level = lvl
	d.total_exp = GrowthRate.exp_for_level(d.growth_rate(), lvl)
	for stat in DaemonInstance.STATS:
		d.build_quality[stat] = bq
		d.experience_logs[stat] = 0
	d.config_profile = profile
	for move_id in d.default_moves():
		d.learn_move(move_id)
	d.current_uptime = d.max_uptime()
	return d


# --- EXP curves --------------------------------------------------------------

func test_exp_at_level_100() -> void:
	var expected := {"fast": 800000, "medium_fast": 1000000, "medium_slow": 1059860,
		"slow": 1250000, "erratic": 600000, "fluctuating": 1640000}
	for rate: String in expected:
		assert_eq(GrowthRate.exp_for_level(rate, 100), expected[rate], rate)


func test_exp_at_level_2() -> void:
	var expected := {"fast": 6, "medium_fast": 8, "medium_slow": 9, "slow": 10, "erratic": 15, "fluctuating": 4}
	for rate: String in expected:
		assert_eq(GrowthRate.exp_for_level(rate, 2), expected[rate], rate)


func test_curve_breakpoints() -> void:
	assert_eq(GrowthRate.exp_for_level("erratic", 68), 257834)
	assert_eq(GrowthRate.exp_for_level("fluctuating", 36), 46656)
	assert_eq(GrowthRate.exp_for_level("medium_fast", 50), 125000)


func test_every_curve_starts_at_zero_and_always_increases() -> void:
	for rate in GrowthRate.RATES:
		assert_eq(GrowthRate.exp_for_level(rate, 1), 0, rate)
		var previous := 0
		var ok := true
		for lvl in range(2, 101):
			var value := GrowthRate.exp_for_level(rate, lvl)
			if value <= previous:
				ok = false
				fail_test("%s doesn't increase at level %d (%d <= %d)" % [rate, lvl, value, previous])
				break
			previous = value
		if ok:
			pass_test(rate + " increases")


func test_level_for_exp() -> void:
	assert_eq(GrowthRate.level_for_exp("medium_fast", 0), 1)
	assert_eq(GrowthRate.level_for_exp("medium_fast", 124999), 49)
	assert_eq(GrowthRate.level_for_exp("medium_fast", 125000), 50)
	assert_eq(GrowthRate.level_for_exp("medium_fast", 99999999), 100)


# --- stat formulas -----------------------------------------------------------

func test_stats_at_level_50() -> void:
	# Chipmunk base 44/58/48/60/48/52, BQ 31, no logs, neutral profile. Worked by hand:
	# Uptime = floor(119 * 50 / 100) + 50 + 10 = 119; Throughput = floor(147 * 50 / 100) + 5 = 78
	var d := _make("chipmunk", 50)
	assert_eq(d.stats(), {"uptime": 119, "throughput": 78, "hardening": 68, "compute": 80, "encryption": 68, "bandwidth": 72})


func test_config_profile_modifiers() -> void:
	# Aggressive: +10% Throughput, -10% Hardening, floored.
	var d := _make("chipmunk", 50, 31, "aggressive")
	assert_eq(d.get_stat("throughput"), 85)  # floor(78 * 1.1)
	assert_eq(d.get_stat("hardening"), 61)   # floor(68 * 0.9)
	assert_eq(d.get_stat("compute"), 80)     # unchanged
	assert_eq(d.get_stat("uptime"), 119)     # profiles never touch Uptime


func test_experience_logs_count_quarter() -> void:
	var d := _make("chipmunk", 100)
	d.experience_logs["uptime"] = 252
	# floor((88 + 31 + 63) * 100 / 100) + 100 + 10
	assert_eq(d.max_uptime(), 292)


func test_level_1_minimum() -> void:
	var d := _make("chipmunk", 1, 0)
	assert_eq(d.max_uptime(), 11)
	assert_eq(d.get_stat("throughput"), 6)  # floor(116 * 1 / 100) + 5


# --- creation ----------------------------------------------------------------

func test_create_is_deterministic_for_a_seed() -> void:
	var a := DaemonInstance.create("pingo", 12, _rng(7))
	var b := DaemonInstance.create("pingo", 12, _rng(7))
	assert_eq(a.to_dict(), b.to_dict())


func test_create_fills_everything_in_range() -> void:
	var d := DaemonInstance.create("chipmunk", 15, _rng())
	assert_eq(d.level, 15)
	assert_eq(d.current_uptime, d.max_uptime())
	assert_true(DataRegistry.config_profiles.has(d.config_profile))
	for stat in DaemonInstance.STATS:
		assert_between(int(d.build_quality[stat]), 0, 31, stat)
	# Learned by 15: bump, screen_glare, heatsink_slam, chassis_guard, double_click -> keeps the last 4.
	var ids := d.moves.map(func(m: Dictionary) -> String: return m["id"])
	assert_eq(ids, ["screen_glare", "heatsink_slam", "chassis_guard", "double_click"])
	assert_eq(d.moves[1]["pp"], 25)


# --- levelling & moves -------------------------------------------------------

func test_gain_exp_levels_up_and_learns_move() -> void:
	var d := _make("chipmunk", 5)
	var hp_before := d.current_uptime
	var events := d.gain_exp(GrowthRate.exp_for_level("medium_slow", 7) - d.total_exp)
	var types := events.map(func(e: Dictionary) -> String: return e["type"])
	assert_eq(types, ["level_up", "level_up", "move_learned"])
	assert_eq(events[1]["level"], 7)
	assert_eq(events[2]["move"], "heatsink_slam")
	assert_eq(d.level, 7)
	assert_true(d.knows_move("heatsink_slam"))
	assert_gt(d.current_uptime, hp_before, "Uptime grows with the level")
	assert_eq(d.current_uptime, d.max_uptime())


func test_full_move_slots_ask_the_player() -> void:
	var d := _make("chipmunk", 12)
	assert_eq(d.moves.size(), 4)
	var events := d.level_up()
	assert_eq(events[-1], {"type": "move_learn_pending", "move": "double_click"})
	assert_false(d.knows_move("double_click"))
	assert_true(d.learn_move("double_click", 0))
	assert_eq(d.moves[0]["id"], "double_click")
	assert_false(d.learn_move("double_click", 1), "can't learn a move twice")


func test_level_cap() -> void:
	var d := _make("dustbunny", 98)
	d.gain_exp(99999999)
	assert_eq(d.level, 100)
	assert_eq(d.total_exp, GrowthRate.exp_for_level("medium_fast", 100))
	assert_eq(d.gain_exp(1000).size(), 0)
	assert_eq(d.level_up().size(), 0)


func test_experience_log_caps() -> void:
	var d := _make("dustbunny", 10)
	d.add_experience_logs({"uptime": 300})
	assert_eq(d.experience_logs["uptime"], 252)
	d.add_experience_logs({"throughput": 252})
	d.add_experience_logs({"compute": 10})
	assert_eq(d.experience_logs["compute"], 6, "total capped at 510")
	d.add_experience_logs({"bandwidth": 3})
	assert_eq(d.experience_logs["bandwidth"], 0)


# --- upgrading ---------------------------------------------------------------

func test_level_evolution() -> void:
	assert_eq(_make("chipmunk", 15).check_evolution("level"), "")
	assert_eq(_make("chipmunk", 16).check_evolution("level"), "munkboard")
	assert_eq(_make("mainmunk", 100).check_evolution("level"), "")


func test_item_and_sync_evolution() -> void:
	var floppit := _make("floppit", 10)
	assert_eq(floppit.check_evolution("item", "coffee"), "")
	assert_eq(floppit.check_evolution("item", "legacy_driver"), "ziphare")
	assert_eq(floppit.check_evolution("level"), "", "item upgrades ignore level")
	assert_eq(_make("ziphare", 30).check_evolution("sync"), "discohare")


func test_evolve_keeps_damage_taken() -> void:
	var d := _make("chipmunk", 16)
	d.current_uptime -= 10
	d.evolve("munkboard")
	assert_eq(d.species_id, "munkboard")
	assert_eq(d.display_name(), "Munkboard")
	assert_eq(d.current_uptime, d.max_uptime() - 10)


# --- saving ------------------------------------------------------------------

func test_save_round_trip_through_json() -> void:
	var d := DaemonInstance.create("pingo", 20, _rng(), 4242)
	d.nickname = "Packets"
	d.status = "corrupted"
	d.current_uptime -= 5
	d.moves[0]["pp"] -= 3
	d.add_experience_logs({"hardening": 12})
	var restored := DaemonInstance.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	assert_not_null(restored)
	assert_eq(restored.to_dict(), d.to_dict())
	assert_eq(restored.display_name(), "Packets")


func test_load_unknown_species_returns_null() -> void:
	assert_null(DaemonInstance.from_dict({"species": "missingno", "level": 5}))


func test_config_profiles_data() -> void:
	assert_eq(DataRegistry.config_profiles.size(), 25)
	var neutral := 0
	for p: Dictionary in DataRegistry.config_profiles.values():
		if p["up"] == null:
			neutral += 1
	assert_eq(neutral, 5)
	assert_eq(DataRegistry.config_profiles["power_saver"]["down"], "bandwidth")
