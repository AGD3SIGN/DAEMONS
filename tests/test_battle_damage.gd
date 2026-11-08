extends GutTest
## Phase 2b: damage, accuracy, crits, type matchups, stat stages, statuses, move effects,
## fainting, forced switches, EXP and upgrades.
##
## Daemons here have Build Quality 15 and a neutral profile, so stats are fixed. At Lv 20:
## Pingo Compute 28 / Uptime 52, Chipmunk Encryption 27 / Uptime 50.

var _saved_chart_value: Variant = null


func after_each() -> void:
	if _saved_chart_value != null:
		DataRegistry.type_chart["network"]["hardware"] = _saved_chart_value
		_saved_chart_value = null


func _daemon(species: String, lvl: int) -> DaemonInstance:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var d := DaemonInstance.create(species, lvl, rng)
	for stat in DaemonInstance.STATS:
		d.build_quality[stat] = 15
	d.config_profile = "balanced"
	d.heal_full()
	return d


func _battle(player: Array[DaemonInstance], foe: Array[DaemonInstance], wild: bool = true, seed_value: int = 7) -> BattleState:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return BattleState.new(BattleSide.new("Player", player), BattleSide.new("Foe", foe), rng, wild)


func _slot(d: DaemonInstance, move_id: String) -> int:
	for i in d.moves.size():
		if d.moves[i]["id"] == move_id:
			return i
	fail_test("%s doesn't know %s" % [d.species_id, move_id])
	return 0


func _fight(d: DaemonInstance, move_id: String) -> BattleAction:
	return BattleAction.fight(_slot(d, move_id))


func _of(events: Array[Dictionary], type: String) -> Array[Dictionary]:
	return events.filter(func(e: Dictionary) -> bool: return e["type"] == type)


func _types(events: Array[Dictionary]) -> Array:
	return events.map(func(e: Dictionary) -> String: return e["type"])


# --- damage formula ----------------------------------------------------------

func test_damage_formula_exact() -> void:
	# floor(floor(10 * 40 * 28 / 27) / 50) + 2 = 10 -> roll -> STAB 1.5 -> Network vs Hardware 2x
	var state := _battle([_daemon("pingo", 20)], [_daemon("chipmunk", 20)])
	var ping := DataRegistry.get_move("ping")
	assert_eq(BattleSim.calc_damage(state, 0, ping, false, 100), 30)
	assert_eq(BattleSim.calc_damage(state, 0, ping, false, 85), 24)
	assert_eq(BattleSim.calc_damage(state, 0, ping, true, 100), 44, "crit: 10 -> 15 -> 22 -> 44")


func test_stat_stages_change_damage_and_crits_ignore_bad_ones() -> void:
	var state := _battle([_daemon("pingo", 20)], [_daemon("chipmunk", 20)])
	var ping := DataRegistry.get_move("ping")
	state.sides[0].stages["compute"] = 2  # 28 -> 56
	assert_eq(BattleSim.calc_damage(state, 0, ping, false, 100), 54)
	state.sides[0].stages["compute"] = -2
	assert_eq(BattleSim.calc_damage(state, 0, ping, true, 100), 44, "crit ignores the attacker's drop")
	state.sides[0].stages["compute"] = 0
	state.sides[1].stages["encryption"] = 2
	assert_eq(BattleSim.calc_damage(state, 0, ping, true, 100), 44, "crit ignores the defender's boost")


func test_overheated_halves_physical_only() -> void:
	var chipmunk := _daemon("chipmunk", 20)
	var state := _battle([chipmunk], [_daemon("pingo", 20)])
	var slam := DataRegistry.get_move("heatsink_slam")
	var runaway := DataRegistry.get_move("thermal_runaway")
	var slam_normal := BattleSim.calc_damage(state, 0, slam, false, 100)
	var runaway_normal := BattleSim.calc_damage(state, 0, runaway, false, 100)
	chipmunk.status = "overheated"
	assert_lt(BattleSim.calc_damage(state, 0, slam, false, 100), slam_normal)
	assert_eq(BattleSim.calc_damage(state, 0, runaway, false, 100), runaway_normal)


func test_damage_lands_in_range() -> void:
	for seed_value in range(1, 31):
		var pingo := _daemon("pingo", 20)
		var chipmunk := _daemon("chipmunk", 20)
		var state := _battle([pingo], [chipmunk], true, seed_value)
		var events := BattleSim.run_turn(state, _fight(pingo, "ping"), _fight(chipmunk, "chassis_guard"))
		var hit: Dictionary = _of(events, "damage")[0]
		assert_between(int(hit["amount"]), 24, 44)
		assert_eq(chipmunk.current_uptime, chipmunk.max_uptime() - int(hit["amount"]))


func test_effectiveness_events() -> void:
	var pingo := _daemon("pingo", 20)
	var chipmunk := _daemon("chipmunk", 20)
	var events := BattleSim.run_turn(_battle([pingo], [chipmunk]), _fight(pingo, "ping"), _fight(chipmunk, "chassis_guard"))
	assert_eq(_of(events, "effectiveness")[0]["multiplier"], 2.0)
	var other := _daemon("pingo", 20)
	events = BattleSim.run_turn(_battle([pingo], [other]), _fight(pingo, "ping"), _fight(other, "bandwidth_hog"))
	assert_eq(_of(events, "effectiveness")[0]["multiplier"], 0.5)


func test_type_immunity_means_no_damage() -> void:
	_saved_chart_value = DataRegistry.type_chart["network"].get("hardware", 1.0)
	DataRegistry.type_chart["network"]["hardware"] = 0.0
	var pingo := _daemon("pingo", 20)
	var chipmunk := _daemon("chipmunk", 20)
	var events := BattleSim.run_turn(_battle([pingo], [chipmunk]), _fight(pingo, "ping"), _fight(chipmunk, "chassis_guard"))
	assert_eq(_of(events, "no_effect").size(), 1)
	assert_eq(_of(events, "damage").size(), 0)
	assert_eq(chipmunk.current_uptime, chipmunk.max_uptime())


func test_multi_hit() -> void:
	var bunny := _daemon("dustbunny", 20)
	var tank := _daemon("mainmunk", 50)
	var events := BattleSim.run_turn(_battle([bunny], [tank]), _fight(bunny, "double_click"), _fight(tank, "defrag"))
	assert_eq(_of(events, "hit_count")[0]["count"], 2)
	assert_eq(_of(events, "damage").size(), 2)
	var counts := {}
	for seed_value in range(1, 41):
		bunny = _daemon("dustbunny", 20)
		tank = _daemon("mainmunk", 50)
		events = BattleSim.run_turn(_battle([bunny], [tank], true, seed_value), _fight(bunny, "keyboard_smash"), _fight(tank, "defrag"))
		if _of(events, "move_missed").is_empty():
			var count: int = _of(events, "hit_count")[0]["count"]
			assert_between(count, 2, 5)
			counts[count] = true
	assert_gt(counts.size(), 1, "keyboard smash should vary its hit count")


# --- accuracy ----------------------------------------------------------------

func test_accuracy_stages() -> void:
	var misses := 0
	for seed_value in range(1, 61):
		var pingo := _daemon("pingo", 20)
		var chipmunk := _daemon("chipmunk", 20)
		var state := _battle([pingo], [chipmunk], true, seed_value)
		state.sides[0].stages["accuracy"] = -6  # 100% -> 33%
		var events := BattleSim.run_turn(state, _fight(pingo, "ping"), _fight(chipmunk, "chassis_guard"))
		misses += _of(events, "move_missed").size()
		# Never-miss moves ignore accuracy entirely.
		state = _battle([pingo], [chipmunk], true, seed_value)
		state.sides[0].stages["accuracy"] = -6
		events = BattleSim.run_turn(state, _fight(pingo, "bandwidth_hog"), _fight(chipmunk, "chassis_guard"))
		assert_eq(_of(events, "move_missed").size(), 0)
	assert_between(misses, 25, 55, "about 2 in 3 should miss")
	assert_eq(BattleSim.accuracy_multiplier(-6), 1.0 / 3.0)
	assert_eq(BattleSim.accuracy_multiplier(3), 2.0)


# --- stat changes ------------------------------------------------------------

func test_stat_change_self_caps_at_six() -> void:
	var chipmunk := _daemon("chipmunk", 20)
	var pingo := _daemon("pingo", 20)
	var state := _battle([chipmunk], [pingo])
	for i in 6:
		BattleSim.run_turn(state, _fight(chipmunk, "chassis_guard"), _fight(pingo, "bandwidth_hog"))
	assert_eq(state.sides[0].stages["hardening"], 6)
	var events := BattleSim.run_turn(state, _fight(chipmunk, "chassis_guard"), _fight(pingo, "bandwidth_hog"))
	var failed: Array[Dictionary] = _of(events, "stat_change_failed").filter(func(e: Dictionary) -> bool: return e["side"] == 0)
	assert_eq(failed.size(), 1)
	assert_eq(failed[0]["direction"], 1)


func test_stat_change_on_foe() -> void:
	var chipmunk := _daemon("chipmunk", 20)
	var pingo := _daemon("pingo", 20)
	var state := _battle([chipmunk], [pingo])
	var events := BattleSim.run_turn(state, _fight(chipmunk, "screen_glare"), _fight(pingo, "bandwidth_hog"))
	assert_eq(state.sides[1].stages["accuracy"], -1)
	assert_eq(_of(events, "stat_changed")[0]["side"], 1)


# --- statuses ----------------------------------------------------------------

func _try_status(species: String, status: String) -> bool:
	var state := _battle([_daemon("pingo", 20)], [_daemon(species, 20)])
	var events: Array[Dictionary] = []
	return BattleSim.try_apply_status(state, 1, status, events)


func test_status_immunities() -> void:
	assert_false(_try_status("fanbat", "throttled"), "Power can't be Throttled")
	assert_false(_try_status("chipmunk", "overheated"), "Hardware can't Overheat")
	assert_false(_try_status("wormby", "corrupted"), "Malware can't be Corrupted")
	assert_true(_try_status("dustbunny", "corrupted"))


func test_status_move_sticks_once() -> void:
	var pengwan := _daemon("pengwan", 20)
	var chipmunk := _daemon("chipmunk", 20)
	var state := _battle([pengwan], [chipmunk])
	var applied := false
	for i in 10:
		var events := BattleSim.run_turn(state, _fight(pengwan, "latency_spike"), _fight(chipmunk, "chassis_guard"))
		if not _of(events, "status_applied").is_empty():
			applied = true
			break
	assert_true(applied, "90% accuracy should land within 10 tries")
	assert_eq(chipmunk.status, "throttled")
	var again := BattleSim.run_turn(state, _fight(pengwan, "latency_spike"), _fight(chipmunk, "chassis_guard"))
	assert_true(not _of(again, "status_failed").is_empty() or not _of(again, "move_missed").is_empty())


func test_corrupted_and_overheated_residual_damage() -> void:
	var chipmunk := _daemon("chipmunk", 20)  # Uptime 50 -> 6 per turn
	var pingo := _daemon("pingo", 20)        # Uptime 52 -> 3 per turn
	chipmunk.status = "corrupted"
	pingo.status = "overheated"
	var events := BattleSim.run_turn(_battle([chipmunk], [pingo]), _fight(chipmunk, "chassis_guard"), _fight(pingo, "bandwidth_hog"))
	var hurt := _of(events, "status_damage")
	assert_eq(hurt.size(), 2)
	assert_eq(hurt[0]["amount"], 6)
	assert_eq(hurt[1]["amount"], 3)
	assert_eq(chipmunk.current_uptime, 44)


func test_standby_blocks_then_wakes() -> void:
	var chipmunk := _daemon("chipmunk", 20)
	var pingo := _daemon("pingo", 20)
	chipmunk.status = "standby"
	chipmunk.status_turns = 2
	var state := _battle([chipmunk], [pingo])
	var pp_before := int(chipmunk.moves[_slot(chipmunk, "chassis_guard")]["pp"])
	for i in 2:
		var events := BattleSim.run_turn(state, _fight(chipmunk, "chassis_guard"), _fight(pingo, "bandwidth_hog"))
		assert_eq(_of(events, "status_blocked")[0]["status"], "standby")
	assert_eq(int(chipmunk.moves[_slot(chipmunk, "chassis_guard")]["pp"]), pp_before, "no PP used while asleep")
	var woke := BattleSim.run_turn(state, _fight(chipmunk, "chassis_guard"), _fight(pingo, "bandwidth_hog"))
	assert_eq(_of(woke, "status_cured")[0]["status"], "standby")
	assert_eq(_of(woke, "move_used").filter(func(e: Dictionary) -> bool: return e["side"] == 0).size(), 1)


func test_hung_recovers_eventually() -> void:
	var chipmunk := _daemon("chipmunk", 20)
	var pingo := _daemon("pingo", 20)
	chipmunk.status = "hung"
	var state := _battle([chipmunk], [pingo])
	for i in 60:
		BattleSim.run_turn(state, _fight(chipmunk, "chassis_guard"), _fight(pingo, "bandwidth_hog"))
		if chipmunk.status.is_empty():
			break
	assert_eq(chipmunk.status, "")


func test_throttled_skips_about_a_quarter() -> void:
	var skipped := 0
	for seed_value in range(1, 201):
		var chipmunk := _daemon("chipmunk", 20)
		var pingo := _daemon("pingo", 20)
		chipmunk.status = "throttled"
		var events := BattleSim.run_turn(_battle([chipmunk], [pingo], true, seed_value), _fight(chipmunk, "chassis_guard"), _fight(pingo, "bandwidth_hog"))
		skipped += _of(events, "status_blocked").size()
	assert_between(skipped, 24, 76, "about 50 of 200")


func test_looping_ends_and_sometimes_self_hits() -> void:
	var self_hits := 0
	for seed_value in range(1, 31):
		var chipmunk := _daemon("chipmunk", 20)
		var pingo := _daemon("pingo", 20)
		var state := _battle([chipmunk], [pingo], true, seed_value)
		var ignored: Array[Dictionary] = []
		assert_true(BattleSim.try_apply_status(state, 0, "looping", ignored))
		var ended := false
		for i in 5:
			var events := BattleSim.run_turn(state, _fight(chipmunk, "chassis_guard"), _fight(pingo, "bandwidth_hog"))
			self_hits += _of(events, "hurt_itself").size()
			if not _of(events, "looping_ended").is_empty():
				ended = true
				break
		assert_true(ended, "Looping lasts 2 to 5 turns")
	assert_gt(self_hits, 0)


# --- drain, recoil, heal -----------------------------------------------------

func test_drain_heals_half_the_damage() -> void:
	var glowbit := _daemon("glowbit", 20)
	var bunny := _daemon("dustbunny", 20)
	glowbit.current_uptime = 1
	var events := BattleSim.run_turn(_battle([glowbit], [bunny]), _fight(glowbit, "code_injection"), _fight(bunny, "screen_glare"))
	var dealt: int = _of(events, "damage")[0]["amount"]
	assert_eq(_of(events, "drain")[0]["amount"], maxi(1, dealt / 2))


func test_recoil_hurts_the_user() -> void:
	var mainmunk := _daemon("mainmunk", 50)
	var boar := _daemon("munkboard", 50)
	var events := BattleSim.run_turn(_battle([mainmunk], [boar]), _fight(mainmunk, "hard_reset"), _fight(boar, "overclock"))
	var dealt: int = _of(events, "damage")[0]["amount"]
	var recoil: Dictionary = _of(events, "recoil")[0]
	assert_eq(recoil["amount"], maxi(1, floori(dealt * 0.33)))
	assert_eq(mainmunk.current_uptime, mainmunk.max_uptime() - int(recoil["amount"]))


func test_heal_move() -> void:
	var glowbit := _daemon("glowbit", 20)  # max 51, heals up to 25
	var bunny := _daemon("dustbunny", 20)
	glowbit.current_uptime -= 20
	var state := _battle([glowbit], [bunny])
	var events := BattleSim.run_turn(state, _fight(glowbit, "patch_up"), _fight(bunny, "screen_glare"))
	assert_eq(_of(events, "heal")[0]["amount"], 20)
	events = BattleSim.run_turn(state, _fight(glowbit, "patch_up"), _fight(bunny, "screen_glare"))
	assert_eq(_of(events, "move_failed")[0]["reason"], "full_uptime")


# --- crashing, EXP, switching ------------------------------------------------

func test_wild_win_gives_exp_and_logs() -> void:
	var pingo := _daemon("pingo", 20)
	var bunny := _daemon("dustbunny", 5)
	bunny.current_uptime = 1
	var state := _battle([pingo], [bunny])
	var events := BattleSim.run_turn(state, _fight(pingo, "fast_ethernet"), BattleAction.fight(0))
	assert_eq(_types(events).slice(-4), ["damage", "fainted", "exp_gained", "battle_end"])
	assert_eq(_of(events, "exp_gained")[0]["amount"], 35, "floor(50 * 5 / 7)")
	assert_eq(state.outcome, "player_won")
	assert_eq(pingo.experience_logs["bandwidth"], 1)
	assert_eq(_of(events, "move_used").size(), 1, "the crashed foe doesn't act")


func test_trainer_battle_forced_switch_and_bonus_exp() -> void:
	var pingo := _daemon("pingo", 20)
	var bunny := _daemon("dustbunny", 5)
	bunny.current_uptime = 1
	var state := _battle([pingo], [bunny, _daemon("wormby", 5)], false)
	var events := BattleSim.run_turn(state, _fight(pingo, "fast_ethernet"), BattleAction.fight(0))
	assert_eq(_of(events, "exp_gained")[0]["amount"], 52, "trainer bonus x1.5")
	assert_eq(_of(events, "switch_needed")[0]["side"], 1)
	assert_eq(state.outcome, "")
	var blocked := BattleSim.run_turn(state, BattleAction.fight(0), BattleAction.fight(0))
	assert_eq(blocked[0]["reason"], "choose a replacement first")
	assert_eq(BattleSim.forced_switch(state, 1, 0)[0]["type"], "invalid_action", "can't send in the crashed one")
	var sent := BattleSim.forced_switch(state, 1, 1)
	assert_eq(sent[0]["daemon"], "Wormby")
	assert_eq(BattleSim.run_turn(state, BattleAction.fight(0), BattleAction.fight(0))[0]["type"], "turn_start")


func test_exp_is_split_between_participants() -> void:
	for pingo_crashed in [false, true]:
		var pingo := _daemon("pingo", 20)
		var glowbit := _daemon("glowbit", 20)
		var bunny := _daemon("dustbunny", 5)
		var state := _battle([pingo, glowbit], [bunny])
		BattleSim.run_turn(state, BattleAction.switch_to(1), _fight(bunny, "bump"))
		bunny.current_uptime = 1
		if pingo_crashed:
			pingo.current_uptime = 0
		var events := BattleSim.run_turn(state, _fight(glowbit, "code_injection"), _fight(bunny, "bump"))
		assert_eq(state.outcome, "player_won")
		var gains := _of(events, "exp_gained").map(func(e: Dictionary) -> int: return e["amount"])
		assert_eq(gains, [35] if pingo_crashed else [17, 17])


func test_level_up_mid_battle_then_upgrade_after() -> void:
	var chipmunk := _daemon("chipmunk", 15)
	chipmunk.total_exp = GrowthRate.exp_for_level("medium_slow", 16) - 1
	var bunny := _daemon("dustbunny", 5)
	bunny.current_uptime = 1
	var events := BattleSim.run_turn(_battle([chipmunk], [bunny]), _fight(chipmunk, "heatsink_slam"), BattleAction.fight(0))
	var types := _types(events)
	assert_eq(chipmunk.level, 16)
	assert_gt(types.find("battle_end"), types.find("level_up"))
	var upgrade: Dictionary = _of(events, "upgrade_ready")[0]
	assert_eq(upgrade["to"], "munkboard")
	assert_gt(types.find("upgrade_ready"), types.find("battle_end"), "upgrades happen after the battle")
	assert_eq(chipmunk.species_id, "chipmunk", "the sim only flags it; the caller evolves")


func test_player_loses_when_everyone_crashes() -> void:
	var pingo := _daemon("pingo", 20)
	pingo.current_uptime = 1
	var mainmunk := _daemon("mainmunk", 50)
	var state := _battle([pingo], [mainmunk])
	var events := BattleSim.run_turn(state, _fight(pingo, "ping"), _fight(mainmunk, "hard_reset"))
	assert_eq(state.outcome, "player_lost")
	assert_eq(_of(events, "move_used").size(), 1, "Pingo never got to act")
	assert_eq(_of(events, "fainted")[0]["side"], 0)
	assert_eq(_of(events, "switch_needed").size(), 0)


# --- Bug #2: out of PP everywhere -> Force Quit --------------------------------

func _drain_pp(d: DaemonInstance) -> void:
	for slot: Dictionary in d.moves:
		slot["pp"] = 0


func test_out_of_pp_uses_force_quit_with_recoil() -> void:
	var pingo := _daemon("pingo", 20)
	var bunny := _daemon("dustbunny", 20)
	var state := _battle([pingo], [bunny], false)
	_drain_pp(bunny)
	assert_false(BattleSim.has_pp(bunny))
	var foe_action := BattleAI.choose_action(state, BattleState.FOE, "basic")
	assert_eq(foe_action.kind, BattleAction.Kind.FIGHT)
	assert_eq(foe_action.slot, BattleSim.FALLBACK_SLOT, "no bench and no PP: Force Quit")
	var events := BattleSim.run_turn(state, _fight(pingo, "ping"), foe_action)
	var types := events.map(func(e: Dictionary) -> String: return e["type"])
	assert_false("invalid_action" in types, "the turn goes through (used to soft-lock)")
	assert_true("out_of_pp" in types)
	var used := events.filter(func(e: Dictionary) -> bool: return e["type"] == "move_used" and e["side"] == BattleState.FOE)
	assert_eq(used[0]["move"], "force_quit")
	assert_true(events.any(func(e: Dictionary) -> bool: return e["type"] == "recoil" and e["side"] == BattleState.FOE), "recoil hurts the user")
	assert_string_ends_with(BattleText.describe(events[types.find("out_of_pp")], false, "Kevin"), "Dustbunny has no PP left!")


func test_force_quit_only_when_every_move_is_empty() -> void:
	var pingo := _daemon("pingo", 20)
	var state := _battle([pingo], [_daemon("dustbunny", 20)])
	assert_ne(BattleSim.validate_action(state, BattleState.PLAYER, BattleAction.fight(BattleSim.FALLBACK_SLOT)), "",
		"not allowed while a move has PP")
	pingo.moves[0]["pp"] = 0
	assert_ne(BattleSim.validate_action(state, BattleState.PLAYER, BattleAction.fight(0)), "", "a 0-PP move is still refused")
	_drain_pp(pingo)
	assert_eq(BattleSim.validate_action(state, BattleState.PLAYER, BattleAction.fight(BattleSim.FALLBACK_SLOT)), "")


func test_out_of_pp_switches_first_if_the_bench_can_fight() -> void:
	var bunny := _daemon("dustbunny", 20)
	var state := _battle([_daemon("pingo", 20)], [bunny, _daemon("wormby", 20)], false)
	_drain_pp(bunny)
	var action := BattleAI.choose_action(state, BattleState.FOE, "random")
	assert_eq(action.kind, BattleAction.Kind.SWITCH)


func test_trainer_battle_with_no_pp_finishes() -> void:
	# The soft-lock scenario end to end: an auto battle where the foe starts with no PP at all.
	var scene: BattleScene = load(BattleScene.SCENE).instantiate()
	var team: Array[DaemonInstance] = [_daemon("pingo", 12)]
	scene.setup({"foe": [["dustbunny", 30]], "trainer_name": "Kevin", "ai": "basic", "player_stack": team,
		"items": {}, "auto": true, "time_scale": 0.0})
	add_child(scene)
	_drain_pp(scene.state.sides[BattleState.FOE].stack[0])
	await wait_for_signal(scene.finished, 30.0)
	assert_true(scene.state.is_over(), "the battle ends instead of looping")
	scene.free()
