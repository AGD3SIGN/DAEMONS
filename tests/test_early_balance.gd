extends GutTest
## Player feedback (2026-11-14): early fights forced ~10 minutes of grinding. Every trainer before Dana
## must be winnable on all three starter paths at the level a player reaches without grinding (no items,
## a basic-AI player that always uses its strongest attack, plus the partners you'd have caught by then).

const RIVAL := {"chipmunk": "pingo", "pingo": "glowbit", "glowbit": "chipmunk"}
## [trainer, starter level, partners [[species, level]...], min wins out of 40]
const FIGHTS := [
	["kevin_rival_1_%s", 5, [], 20],
	["intern_ian", 6, [], 20],
	["sysadmin_sam", 6, [["dustbunny", 4]], 20],
	["jogger_jo", 7, [["dustbunny", 5]], 20],
	["signal_hunter_hal", 8, [["cablesnake", 6], ["dustbunny", 5]], 12],
	["phisher_pete", 9, [["cablesnake", 7], ["dustbunny", 6]], 20],
	["tech_theo", 10, [["cablesnake", 7], ["ramster", 6]], 16],
	["tech_tina", 10, [["cablesnake", 7], ["ramster", 6]], 12],
	["dana", 12, [["cablesnake", 10], ["ramster", 9]], 12],
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
		for starter: String in ["chipmunk", "pingo", "glowbit"]:
			var trainer: String = fight[0] % RIVAL[starter] if "%s" in fight[0] else fight[0]
			var wins := _wins(trainer, starter, int(fight[1]), fight[2])
			line += "  %-8s %2d/40" % [starter, wins]
			assert_gte(wins, int(fight[3]), "%s vs %s at Lv%d" % [starter, trainer, fight[1]])
		report.append(line)
	gut.p("Early-game win rates (no items):\n" + "\n".join(report))
