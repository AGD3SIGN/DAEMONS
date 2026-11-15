extends GutTest
## Player feedback (2026-11-14): early fights forced ~10 minutes of grinding. 2026-11-15: "don't make it easier,
## just don't lose to one hit". Every trainer before Dana must be winnable on all three starter paths at the
## level a player reaches without grinding (no items, a basic-AI player that always uses its strongest attack,
## plus the partners you'd have caught by then), but the later ones must not be pushovers either.

const RIVAL := {"chipmunk": "pingo", "pingo": "glowbit", "glowbit": "chipmunk"}
## [trainer, starter level, partners [[species, level]...], min wins out of 40 on every path,
##  max average wins out of 40 across the three paths (40 = no ceiling)]
const FIGHTS := [
	["kevin_rival_1_%s", 5, [], 20, 40],  # the tutorial fight
	["intern_ian", 6, [], 20, 40],
	["sysadmin_sam", 6, [["dustbunny", 4]], 10, 34],
	["jogger_jo", 7, [["cablesnake", 5], ["dustbunny", 5]], 12, 40],
	["signal_hunter_hal", 8, [["cablesnake", 6], ["dustbunny", 5]], 10, 34],
	["phisher_pete", 9, [["cablesnake", 7], ["dustbunny", 6]], 20, 40],
	["tech_theo", 10, [["cablesnake", 7], ["ramster", 6]], 10, 32],
	["tech_tina", 10, [["cablesnake", 7], ["ramster", 6]], 10, 32],
	["dana", 12, [["cablesnake", 10], ["ramster", 9]], 10, 30],
]


func _d(species: String, lvl: int, seed_value: int) -> DaemonInstance:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return DaemonInstance.create(species, lvl, rng, 1)


func _sim(player: Array[DaemonInstance], foe: Array[DaemonInstance], seed_value: int, tier: String) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var state := BattleState.new(BattleSide.new("You", player), BattleSide.new("Foe", foe), rng, false)
	while not state.is_over() and state.turn < 200:
		for side in 2:
			if state.needs_switch[side]:
				BattleSim.forced_switch(state, side, BattleAI.choose_replacement(state, side, "basic" if side == 0 else tier))
		var events := BattleSim.run_turn(state, BattleAI.choose_action(state, 0, "basic"), BattleAI.choose_action(state, 1, tier))
		if events.size() == 1 and events[0]["type"] == "invalid_action":
			break
	return state.outcome


func _wins(trainer: String, starter: String, lvl: int, partners: Array) -> int:
	var wins := 0
	for i in 40:
		var team: Array[DaemonInstance] = [_d(starter, lvl, i)]
		for j in partners.size():
			team.append(_d(partners[j][0], int(partners[j][1]), i + 100 * (j + 1)))
		var foe: Array[DaemonInstance] = []
		for entry: Array in DataRegistry.trainers[trainer]["team"]:
			foe.append(_d(entry[0], int(entry[1]), i + 300))
		if _sim(team, foe, i, DataRegistry.trainers[trainer]["ai"]) == "player_won":
			wins += 1
	return wins


func test_every_early_trainer_is_winnable_on_every_starter_path() -> void:
	var report := PackedStringArray()
	for fight: Array in FIGHTS:
		var line := "%-18s Lv%-3d" % [String(fight[0]).replace("_%s", ""), fight[1]]
		var total := 0
		for starter: String in ["chipmunk", "pingo", "glowbit"]:
			var trainer: String = fight[0] % RIVAL[starter] if "%s" in fight[0] else fight[0]
			var wins := _wins(trainer, starter, int(fight[1]), fight[2])
			line += "  %-8s %2d/40" % [starter, wins]
			total += wins
			assert_gte(wins, int(fight[3]), "%s vs %s at Lv%d" % [starter, trainer, fight[1]])
		assert_lte(total / 3.0, float(fight[4]), "%s is a pushover (average %.1f/40)" % [fight[0], total / 3.0])
		report.append(line)
	gut.p("Early-game win rates (no items):\n" + "\n".join(report))


## "You shouldn't lose to one hit early on" (2026-11-15). The worst normal hit (no crit, top damage roll) from
## any wild Daemon or trainer before Dana must leave a full-Uptime starter standing at the level you meet it.
## Crits can still do it now and then; that's the risk that keeps fights tense.
const ONE_HIT_AREAS := [["onboarding_town", 5], ["route_1", 5], ["wifi_dead_zone", 8]]


func _worst_hit(attacker: DaemonInstance, target: DaemonInstance) -> int:
	var a: Array[DaemonInstance] = [target]
	var b: Array[DaemonInstance] = [attacker]
	var state := BattleState.new(BattleSide.new("You", a), BattleSide.new("Foe", b), RandomNumberGenerator.new(), false)
	var worst := 0
	for slot: Dictionary in attacker.moves:
		var move := DataRegistry.get_move(slot["id"])
		if int(move.get("power", 0)) > 0:
			worst = maxi(worst, BattleSim.calc_damage(state, 1, move, false, BattleSim.ROLL_MAX))
	return worst


func test_nothing_early_one_shots_a_starter_without_a_crit() -> void:
	var foes := []  # [label, species, level, player level]
	for area: Array in ONE_HIT_AREAS:
		for zone: Array in DataRegistry.encounters[area[0]]["zones"].values():
			for e: Dictionary in zone:
				foes.append(["wild in " + area[0], e["species"], int(e["max"]), int(area[1])])
	for fight: Array in FIGHTS:
		for starter: String in RIVAL:
			var trainer: String = fight[0] % RIVAL[starter] if "%s" in fight[0] else fight[0]
			for entry: Array in DataRegistry.trainers[trainer]["team"]:
				foes.append([trainer, entry[0], int(entry[1]), int(fight[1])])
	for f: Array in foes:
		for starter: String in RIVAL:
			var me := _d(starter, int(f[3]), 1)
			var hit := _worst_hit(_d(f[1], int(f[2]), 2), me)
			assert_lt(hit, me.max_uptime(), "%s's Lv%d %s one-shots a Lv%d %s (%d >= %d)" % [f[0], f[2], f[1], f[3], starter, hit, me.max_uptime()])
