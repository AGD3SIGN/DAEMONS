extends GutTest
## Phase 2c: run chance, Quarantine capture, trainer AI tiers, battle text, console battle.

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


func _battle(player: Array[DaemonInstance], foe: Array[DaemonInstance], wild: bool = true,
		items: Dictionary = {}, seed_value: int = 7) -> BattleState:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return BattleState.new(BattleSide.new("You", player, items), BattleSide.new("Foe", foe), rng, wild)


func _of(events: Array[Dictionary], type: String) -> Array[Dictionary]:
	return events.filter(func(e: Dictionary) -> bool: return e["type"] == type)


func _move_id(state: BattleState, side: int, action: BattleAction) -> String:
	return state.sides[side].active().moves[action.slot]["id"]


# --- capture -----------------------------------------------------------------

func test_capture_value_formula() -> void:
	var bunny := _daemon("dustbunny", 5)  # catch rate 255
	assert_eq(BattleSim.capture_value(bunny, 1.0), 85, "full Uptime: 255 / 3")
	bunny.status = "standby"
	assert_eq(BattleSim.capture_value(bunny, 1.0), 170)
	bunny.status = "corrupted"
	assert_eq(BattleSim.capture_value(bunny, 1.0), 127)
	bunny.status = ""
	bunny.current_uptime = 1
	assert_gt(BattleSim.capture_value(bunny, 1.0), 240, "almost guaranteed at 1 Uptime")
	assert_gt(BattleSim.capture_value(_daemon("chipmunk", 5), 255.0), 255, "Root Key")


func test_shake_threshold() -> void:
	assert_eq(BattleSim.shake_threshold(0), 0)
	assert_eq(BattleSim.shake_threshold(255), 65536)
	assert_between(BattleSim.shake_threshold(85), 49700, 49900)
	assert_gt(BattleSim.shake_threshold(170), BattleSim.shake_threshold(85))


func _capture_rate(status: String, key: String, trials: int) -> int:
	var caught := 0
	for seed_value in range(1, trials + 1):
		var bunny := _daemon("dustbunny", 5)
		bunny.status = status
		var state := _battle([_daemon("pingo", 20)], [bunny], true, {key: 1}, seed_value)
		var events := BattleSim.run_turn(state, BattleAction.item(key, 0), BattleAction.fight(0))
		if state.outcome == "caught":
			caught += 1
			assert_eq(state.captured, bunny)
			assert_eq(_of(events, "capture_shake").size(), 3)
			assert_eq(events[-1], {"type": "battle_end", "outcome": "caught"})
			assert_eq(_of(events, "move_used").size(), 0, "the foe never gets to act")
		else:
			var failed: Dictionary = _of(events, "capture_failed")[0]
			assert_eq(_of(events, "capture_shake").size(), failed["shakes"])
		assert_false(state.sides[0].items.has(key), "the key is used up either way")
	return caught


func test_capture_odds() -> void:
	var full := _capture_rate("", "thumb_drive", 300)    # about 1 in 3
	var asleep := _capture_rate("standby", "thumb_drive", 300)  # about 2 in 3
	assert_between(full, 70, 130)
	assert_gt(asleep, full + 40)
	assert_eq(_capture_rate("", "root_key", 20), 20, "Root Key never fails")


func test_capture_only_in_wild_battles_for_the_player() -> void:
	var state := _battle([_daemon("pingo", 20)], [_daemon("dustbunny", 5)], false, {"thumb_drive": 1})
	assert_string_contains(BattleSim.validate_action(state, 0, BattleAction.item("thumb_drive", 0)), "another trainer")
	state = _battle([_daemon("pingo", 20)], [_daemon("dustbunny", 5)])
	state.sides[1].items = {"thumb_drive": 1}
	assert_string_contains(BattleSim.validate_action(state, 1, BattleAction.item("thumb_drive", 0)), "only the player")


# --- running -----------------------------------------------------------------

func test_faster_side_always_escapes() -> void:
	for seed_value in range(1, 21):
		var state := _battle([_daemon("pingo", 20)], [_daemon("dustbunny", 5)], true, {}, seed_value)
		BattleSim.run_turn(state, BattleAction.run(), BattleAction.fight(0))
		assert_eq(state.outcome, "fled")


func test_slower_side_can_fail_but_odds_improve() -> void:
	var failed_once := false
	for seed_value in range(1, 21):
		var chipmunk := _daemon("chipmunk", 5)
		var state := _battle([chipmunk], [_daemon("dustbunny", 40)], true, {}, seed_value)
		chipmunk.current_uptime = 9999  # don't crash while trying
		var tries := 0
		while state.outcome != "fled" and tries < 10:
			var events := BattleSim.run_turn(state, BattleAction.run(), BattleAction.fight(1))
			tries += 1
			if not _of(events, "run_failed").is_empty():
				failed_once = true
				assert_eq(_of(events, "move_used").size(), 1, "the foe acts after a failed escape")
		assert_eq(state.outcome, "fled", "30 more out of 256 per attempt guarantees it by the 9th try")
	assert_true(failed_once)


# --- AI ----------------------------------------------------------------------

func test_random_ai_uses_varied_moves() -> void:
	var picks := {}
	for seed_value in range(1, 41):
		var state := _battle([_daemon("chipmunk", 20)], [_daemon("pingo", 20)], true, {}, seed_value)
		picks[BattleAI.choose_action(state, 1, "random").slot] = true
	assert_gt(picks.size(), 2)


func test_basic_ai_prefers_super_effective() -> void:
	for seed_value in range(1, 21):
		var state := _battle([_daemon("chipmunk", 20)], [_daemon("pingo", 20)], true, {}, seed_value)
		var move := _move_id(state, 1, BattleAI.choose_action(state, 1, "basic"))
		assert_true(move in ["ping", "fast_ethernet"], "Network hits Hardware 2x, picked " + move)


func test_basic_ai_avoids_immune_targets() -> void:
	_saved_chart_value = DataRegistry.type_chart["network"].get("hardware", 1.0)
	DataRegistry.type_chart["network"]["hardware"] = 0.0
	for seed_value in range(1, 21):
		var state := _battle([_daemon("chipmunk", 20)], [_daemon("pingo", 20)], true, {}, seed_value)
		var move := _move_id(state, 1, BattleAI.choose_action(state, 1, "basic"))
		assert_false(move in ["ping", "fast_ethernet"], "picked an immune move: " + move)


func test_smart_ai_statuses_a_healthy_target_first() -> void:
	var chipmunk := _daemon("chipmunk", 20)
	var state := _battle([chipmunk], [_daemon("routeroo", 20)])
	assert_eq(_move_id(state, 1, BattleAI.choose_action(state, 1, "smart")), "latency_spike")
	chipmunk.status = "throttled"
	assert_true(_move_id(state, 1, BattleAI.choose_action(state, 1, "smart")) in ["ping", "fast_ethernet"])


func test_smart_ai_heals_when_low() -> void:
	var bitling := _daemon("bitling", 20)
	bitling.current_uptime = 5
	var state := _battle([_daemon("dustbunny", 20)], [bitling])
	assert_eq(_move_id(state, 1, BattleAI.choose_action(state, 1, "smart")), "patch_up")


func test_smart_ai_switches_out_of_a_bad_matchup() -> void:
	var state := _battle([_daemon("pingo", 20)], [_daemon("chipmunk", 20), _daemon("bitling", 20)])
	var action := BattleAI.choose_action(state, 1, "smart")
	assert_eq(action.kind, BattleAction.Kind.SWITCH)
	assert_eq(action.index, 1, "Software resists Network")
	assert_eq(BattleAI.choose_action(state, 1, "basic").kind, BattleAction.Kind.FIGHT, "basic never switches")
	state.sides[1].voluntary_switches = BattleAI.MAX_SMART_SWITCHES
	assert_eq(BattleAI.choose_action(state, 1, "smart").kind, BattleAction.Kind.FIGHT, "switch cap")


func test_smart_replacement_picks_the_best_matchup() -> void:
	var crashed := _daemon("dustbunny", 20)
	crashed.current_uptime = 0
	var state := _battle([_daemon("pingo", 20)], [crashed, _daemon("chipmunk", 20), _daemon("bitling", 20)])
	state.sides[1].active_index = 0  # the crashed one was in battle
	assert_eq(BattleAI.choose_replacement(state, 1, "smart"), 2)
	assert_eq(BattleAI.choose_replacement(state, 1, "basic"), 1)


# --- text --------------------------------------------------------------------

func test_battle_text() -> void:
	assert_eq(BattleText.describe({"type": "switch_in", "side": 1, "daemon": "Dustbunny"}, true), "A wild Dustbunny spawned!")
	assert_eq(BattleText.describe({"type": "move_used", "side": 1, "user": "Pingo", "move_name": "Ping"}, false), "Foe Pingo ran Ping!")
	assert_eq(BattleText.describe({"type": "stat_changed", "side": 0, "daemon": "Chipmunk", "stat": "throughput", "delta": 2}, true), "Chipmunk's Throughput rose sharply!")
	assert_eq(BattleText.describe({"type": "upgrade_ready", "daemon": "Pingo"}, true), "Your Pingo is upgrading!")
	assert_eq(BattleText.describe({"type": "turn_start", "turn": 1}, true), "")


# --- console battle ----------------------------------------------------------

func test_console_battles_finish_and_replay_exactly() -> void:
	for trainer in [false, true]:
		for seed_value in [1, 2, 3]:
			var result := ConsoleBattle.simulate(seed_value, trainer)
			assert_ne(result["outcome"], "", "battle should end (trainer=%s seed=%d)" % [trainer, seed_value])
			assert_eq(ConsoleBattle.simulate(seed_value, trainer)["lines"], result["lines"], "same seed, same battle")
	assert_ne(ConsoleBattle.simulate(1, true)["lines"], ConsoleBattle.simulate(2, true)["lines"])
