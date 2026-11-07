extends GutTest
## Phase 2a: battle structure. Turn order, actions, validation, events, determinism.


## A Daemon with fixed Build Quality (15) and a neutral profile, so stats are predictable.
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
		items: Dictionary = {}, seed_value: int = 99) -> BattleState:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return BattleState.new(BattleSide.new("Player", player, items), BattleSide.new("Foe", foe), rng, wild)


func _slot(d: DaemonInstance, move_id: String) -> int:
	for i in d.moves.size():
		if d.moves[i]["id"] == move_id:
			return i
	fail_test("%s doesn't know %s" % [d.species_id, move_id])
	return -1


func _types(events: Array[Dictionary]) -> Array:
	return events.map(func(e: Dictionary) -> String: return e["type"])


## Which sides used a move, in order.
func _move_order(events: Array[Dictionary]) -> Array:
	return events.filter(func(e: Dictionary) -> bool: return e["type"] == "move_used") \
		.map(func(e: Dictionary) -> int: return e["side"])


# --- start -------------------------------------------------------------------

func test_start_events() -> void:
	var state := _battle([_daemon("pingo", 10)], [_daemon("dustbunny", 5)])
	var events := BattleSim.start(state)
	assert_eq(_types(events), ["battle_start", "switch_in", "switch_in"])
	assert_eq(events[1]["side"], BattleState.FOE, "foe appears first")
	assert_eq(events[1]["daemon"], "Dustbunny")
	assert_eq(events[2]["uptime"], events[2]["max_uptime"])


func test_skips_crashed_daemons_at_start() -> void:
	var first := _daemon("chipmunk", 10)
	first.current_uptime = 0
	var state := _battle([first, _daemon("pingo", 10)], [_daemon("dustbunny", 5)])
	assert_eq(state.sides[0].active_index, 1)


# --- turn order --------------------------------------------------------------

func test_faster_daemon_moves_first() -> void:
	# Lv 20, BQ 15: Dustbunny bandwidth 36, Pingo 26.
	var pingo := _daemon("pingo", 20)
	var bunny := _daemon("dustbunny", 20)
	var state := _battle([pingo], [bunny])
	var events := BattleSim.run_turn(state, BattleAction.fight(_slot(pingo, "ping")), BattleAction.fight(0))
	assert_eq(_move_order(events), [BattleState.FOE, BattleState.PLAYER])


func test_priority_beats_bandwidth() -> void:
	var pingo := _daemon("pingo", 20)
	var bunny := _daemon("dustbunny", 20)
	var state := _battle([pingo], [bunny])
	var events := BattleSim.run_turn(state, BattleAction.fight(_slot(pingo, "fast_ethernet")), BattleAction.fight(0))
	assert_eq(_move_order(events), [BattleState.PLAYER, BattleState.FOE])


func test_throttled_halves_bandwidth() -> void:
	var pingo := _daemon("pingo", 20)
	var bunny := _daemon("dustbunny", 20)
	bunny.status = "throttled"  # 36 -> 18, now slower than Pingo's 26
	var state := _battle([pingo], [bunny])
	assert_eq(BattleSim.effective_bandwidth(state, BattleState.FOE), 18.0)
	var events := BattleSim.run_turn(state, BattleAction.fight(_slot(pingo, "ping")), BattleAction.fight(0))
	assert_eq(_move_order(events)[0], BattleState.PLAYER, "Throttled may also skip the foe's turn")


func test_bandwidth_stages_count() -> void:
	var pingo := _daemon("pingo", 20)
	var state := _battle([pingo], [_daemon("dustbunny", 20)])
	state.sides[0].stages["bandwidth"] = 2  # 26 x 2 = 52 > 36
	var events := BattleSim.run_turn(state, BattleAction.fight(_slot(pingo, "ping")), BattleAction.fight(0))
	assert_eq(_move_order(events), [BattleState.PLAYER, BattleState.FOE])


func test_stage_multipliers() -> void:
	assert_eq(BattleSim.stage_multiplier(0), 1.0)
	assert_eq(BattleSim.stage_multiplier(1), 1.5)
	assert_eq(BattleSim.stage_multiplier(6), 4.0)
	assert_almost_eq(BattleSim.stage_multiplier(-1), 2.0 / 3.0, 0.0001)
	assert_eq(BattleSim.stage_multiplier(-6), 0.25)


func test_speed_ties_are_random_but_seeded() -> void:
	var firsts := {}
	for seed_value in range(1, 41):
		var state := _battle([_daemon("pingo", 20)], [_daemon("pingo", 20)], true, {}, seed_value)
		var order := _move_order(BattleSim.run_turn(state, BattleAction.fight(0), BattleAction.fight(0)))
		firsts[order[0]] = true
		var again := _battle([_daemon("pingo", 20)], [_daemon("pingo", 20)], true, {}, seed_value)
		assert_eq(_move_order(BattleSim.run_turn(again, BattleAction.fight(0), BattleAction.fight(0))), order)
	assert_eq(firsts.size(), 2, "both sides should win a tie sometimes")


func test_switch_happens_before_moves() -> void:
	var pingo := _daemon("pingo", 20)
	var state := _battle([pingo], [_daemon("dustbunny", 20), _daemon("wormby", 20)])
	var events := BattleSim.run_turn(state, BattleAction.fight(_slot(pingo, "fast_ethernet")), BattleAction.switch_to(1))
	assert_eq(_types(events), ["turn_start", "switch_out", "switch_in", "move_used", "damage", "turn_end"])
	assert_eq(events[3]["target"], "Wormby", "the move hits whoever is in now")


func test_switch_resets_stages() -> void:
	var state := _battle([_daemon("pingo", 20), _daemon("chipmunk", 20)], [_daemon("dustbunny", 20)])
	state.sides[0].stages["throughput"] = 3
	BattleSim.run_turn(state, BattleAction.switch_to(1), BattleAction.fight(0))
	assert_eq(state.sides[0].stages["throughput"], 0)
	assert_eq(state.sides[0].active().species_id, "chipmunk")


func test_item_goes_after_switch_and_before_moves() -> void:
	var pingo := _daemon("pingo", 20)
	pingo.current_uptime -= 30
	var state := _battle([pingo], [_daemon("dustbunny", 20), _daemon("wormby", 20)], true, {"coffee": 2})
	var events := BattleSim.run_turn(state, BattleAction.item("coffee", 0), BattleAction.switch_to(1))
	assert_eq(_types(events), ["turn_start", "switch_out", "switch_in", "item_used", "heal", "turn_end"])


func test_run_goes_first_and_ends_wild_battle() -> void:
	var state := _battle([_daemon("pingo", 20)], [_daemon("dustbunny", 20)])
	var events := BattleSim.run_turn(state, BattleAction.run(), BattleAction.fight(0))
	assert_eq(_types(events), ["turn_start", "fled", "battle_end"])
	assert_eq(state.outcome, "fled")
	assert_eq(BattleSim.run_turn(state, BattleAction.fight(0), BattleAction.fight(0))[0]["type"], "invalid_action")


# --- actions -----------------------------------------------------------------

func test_fight_uses_pp_and_counts_turns() -> void:
	var pingo := _daemon("pingo", 20)
	var state := _battle([pingo], [_daemon("dustbunny", 20)])
	var pp_before := int(pingo.moves[0]["pp"])
	var events := BattleSim.run_turn(state, BattleAction.fight(0), BattleAction.fight(0))
	assert_eq(int(pingo.moves[0]["pp"]), pp_before - 1)
	assert_eq(state.turn, 1)
	assert_eq(events[0], {"type": "turn_start", "turn": 1})
	BattleSim.run_turn(state, BattleAction.fight(0), BattleAction.fight(0))
	assert_eq(state.turn, 2)


func test_coffee_heals_and_is_used_up() -> void:
	var pingo := _daemon("pingo", 20)
	pingo.current_uptime -= 12
	var state := _battle([pingo], [_daemon("dustbunny", 20)], true, {"coffee": 1})
	var events := BattleSim.run_turn(state, BattleAction.item("coffee", 0), BattleAction.fight(0))
	var heal: Dictionary = events.filter(func(e: Dictionary) -> bool: return e["type"] == "heal")[0]
	assert_eq(heal["amount"], 12, "capped at what's missing")
	assert_eq(heal["uptime"], pingo.max_uptime(), "full before the foe's attack lands")
	assert_false(state.sides[0].items.has("coffee"))


func test_pizza_friday_clears_status() -> void:
	var pingo := _daemon("pingo", 20)
	pingo.current_uptime = 1
	pingo.status = "corrupted"
	var state := _battle([pingo], [_daemon("dustbunny", 20)], true, {"pizza_friday": 3})
	var events := BattleSim.run_turn(state, BattleAction.item("pizza_friday", 0), BattleAction.fight(0))
	assert_true("status_cured" in _types(events))
	assert_eq(pingo.status, "")
	assert_eq(events.filter(func(e: Dictionary) -> bool: return e["type"] == "heal")[0]["uptime"], pingo.max_uptime())
	assert_eq(state.sides[0].items["pizza_friday"], 2)


func test_hard_reboot_revives_benched_daemon() -> void:
	var crashed := _daemon("chipmunk", 20)
	crashed.current_uptime = 0
	var state := _battle([_daemon("pingo", 20), crashed], [_daemon("dustbunny", 20)], true, {"hard_reboot": 1})
	BattleSim.run_turn(state, BattleAction.item("hard_reboot", 1), BattleAction.fight(0))
	assert_eq(crashed.current_uptime, crashed.max_uptime() / 2)


# --- validation --------------------------------------------------------------

func _assert_invalid(state: BattleState, action: BattleAction, reason_part: String) -> void:
	var events := BattleSim.run_turn(state, action, BattleAction.fight(0))
	assert_eq(events.size(), 1)
	assert_eq(events[0]["type"], "invalid_action")
	assert_string_contains(events[0]["reason"], reason_part)


func test_invalid_actions_are_rejected_without_playing_the_turn() -> void:
	var pingo := _daemon("pingo", 20)
	var crashed := _daemon("chipmunk", 20)
	crashed.current_uptime = 0
	var state := _battle([pingo, crashed], [_daemon("dustbunny", 20)], true, {"coffee": 1, "firewall_rule": 1, "thumb_drive": 5, "hard_reboot": 1})
	_assert_invalid(state, BattleAction.switch_to(0), "already in battle")
	_assert_invalid(state, BattleAction.switch_to(1), "crashed")
	_assert_invalid(state, BattleAction.switch_to(5), "no Daemon")
	_assert_invalid(state, BattleAction.fight(7), "no move")
	_assert_invalid(state, BattleAction.item("energy_drink", 0), "don't have")
	_assert_invalid(state, BattleAction.item("coffee", 0), "won't have any effect")
	_assert_invalid(state, BattleAction.item("coffee", 1), "Hard Reboot first")
	_assert_invalid(state, BattleAction.item("hard_reboot", 0), "hasn't crashed")
	_assert_invalid(state, BattleAction.item("firewall_rule", 0), "can't be used in battle")
	_assert_invalid(state, BattleAction.item("thumb_drive", 0), "Phase 2c")
	pingo.moves[0]["pp"] = 0
	_assert_invalid(state, BattleAction.fight(0), "no PP")
	assert_eq(state.turn, 0, "no turn was played")
	assert_eq(state.sides[0].items["coffee"], 1, "nothing was used up")


func test_cant_run_from_trainers() -> void:
	var state := _battle([_daemon("pingo", 20)], [_daemon("dustbunny", 20)], false)
	_assert_invalid(state, BattleAction.run(), "trainer")


# --- determinism -------------------------------------------------------------

func test_same_seed_same_battle() -> void:
	var logs := []
	for attempt in 2:
		var state := _battle([_daemon("pingo", 20), _daemon("bitling", 20)], [_daemon("pingo", 20), _daemon("wormby", 20)], true, {}, 1234)
		var events := BattleSim.start(state)
		events.append_array(BattleSim.run_turn(state, BattleAction.fight(0), BattleAction.fight(1)))
		events.append_array(BattleSim.run_turn(state, BattleAction.switch_to(1), BattleAction.fight(0)))
		events.append_array(BattleSim.run_turn(state, BattleAction.fight(2), BattleAction.switch_to(1)))
		logs.append(JSON.stringify(events))
	assert_eq(logs[0], logs[1])
