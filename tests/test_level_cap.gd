extends GutTest
## GDD: each Certification sets a level cap. EXP stops at the cap (overflow thrown away), the battle says so once,
## and Overclock Chips can't push past it. Caps live in data/level_caps.json (placeholder numbers, TBD).


func before_each() -> void:
	GameState.reset()


func after_each() -> void:
	GameState.reset()


func _d(species: String, lvl: int) -> DaemonInstance:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	return DaemonInstance.create(species, lvl, rng, 1)


func test_caps_come_from_data_and_rise_with_certs() -> void:
	assert_eq(DataRegistry.level_caps.size(), 9, "0 through 8 Certifications")
	assert_eq(GameState.level_cap(), DataRegistry.level_caps[0])
	GameState.certifications.append("desktop_support")
	assert_eq(GameState.level_cap(), DataRegistry.level_caps[1])
	for i in range(1, 9):
		assert_gte(DataRegistry.level_caps[i], DataRegistry.level_caps[i - 1], "never goes down")


func test_exp_stops_at_the_cap_and_overflow_is_discarded() -> void:
	var d := _d("chipmunk", 13)
	d.gain_exp(999999, 14)
	assert_eq(d.level, 14, "stops at the cap")
	assert_eq(d.total_exp, GrowthRate.exp_for_level(d.growth_rate(), 14), "overflow thrown away")
	var events := d.gain_exp(500, 14)
	assert_true(events.is_empty(), "nothing more at the cap")
	d.gain_exp(500, 20)
	assert_gt(d.level, 14, "the next Cert lets it grow again (from 0 EXP into the level, not the overflow)")


func test_battle_says_once_that_it_needs_a_certification() -> void:
	var me := _d("chipmunk", 14)
	var team: Array[DaemonInstance] = [me]
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var state := BattleState.new(BattleSide.new("You", team),
		BattleSide.new("Wild", [_d("dustbunny", 3)] as Array[DaemonInstance]), rng, true)
	state.level_cap = 14
	var before := me.total_exp
	var all: Array[Dictionary] = []
	while not state.is_over():
		all.append_array(BattleSim.run_turn(state, BattleAction.fight(0), BattleAction.fight(0)))
	assert_eq(me.total_exp, before, "no EXP at the cap")
	var capped := all.filter(func(e: Dictionary) -> bool: return e["type"] == "level_capped")
	assert_eq(capped.size(), 1)
	assert_eq(BattleText.describe(capped[0], true, ""), "CHIPMUNK needs a new certification to grow further.")


func test_overclock_chip_cant_pass_the_cap() -> void:
	var d := _d("chipmunk", GameState.level_cap())
	GameState.add_daemon(d)
	GameState.bag["overclock_chip"] = 1
	var r := ItemUse.use_on("overclock_chip", d)
	assert_false(r["ok"])
	assert_string_contains(r["messages"][0], "needs a new certification")
	assert_eq(int(GameState.bag["overclock_chip"]), 1, "not used up")
	GameState.certifications.append("desktop_support")
	assert_true(ItemUse.use_on("overclock_chip", d)["ok"], "works again after the next Cert")
