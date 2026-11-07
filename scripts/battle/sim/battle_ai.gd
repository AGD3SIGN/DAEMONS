class_name BattleAI
extends RefCounted
## Picks actions for computer-controlled sides. Pure like the sim, and it draws randomness from
## state.rng, so AI battles replay exactly with the same seed.
##
## Tiers:
##   "random" — any move with PP left. Wild Daemons use this.
##   "basic"  — best expected damage: power x type x STAB x accuracy. Skips moves the target is
##              immune to; falls back to status moves only when nothing can hurt it.
##   "smart"  — basic, plus: inflicts a status while the target is healthy, boosts itself early,
##              heals when low, and switches out when the opponent's type hits it super-effectively
##              and a benched Daemon handles it better.

const TIERS: PackedStringArray = ["random", "basic", "smart"]
## Smart AI stops switching after this many voluntary switches, so two smart sides can't ping-pong.
const MAX_SMART_SWITCHES := 2


static func choose_action(state: BattleState, side: int, tier: String) -> BattleAction:
	var user := state.sides[side].active()
	if tier == "smart":
		var switch_index := _better_switch(state, side)
		if switch_index >= 0:
			return BattleAction.switch_to(switch_index)
	var usable: Array[int] = []
	for i in user.moves.size():
		if int(user.moves[i]["pp"]) > 0:
			usable.append(i)
	if usable.is_empty():
		# No PP anywhere (see Bug #2). Switch if possible, otherwise this action is invalid.
		var bench := _first_usable_bench(state, side)
		return BattleAction.switch_to(bench) if bench >= 0 else BattleAction.fight(0)
	if tier == "random":
		return BattleAction.fight(usable[state.rng.randi_range(0, usable.size() - 1)])

	var best_score := -INF
	var best: Array[int] = []
	for i in usable:
		var score := score_move(state, side, i, tier)
		if score > best_score:
			best_score = score
			best = [i]
		elif score == best_score:
			best.append(i)
	if best_score <= 0.0:
		best = usable  # nothing useful; just do something
	return BattleAction.fight(best[state.rng.randi_range(0, best.size() - 1)])


## Which Daemon to send in after a crash.
static func choose_replacement(state: BattleState, side: int, tier: String) -> int:
	if tier != "smart":
		return _first_usable_bench(state, side)
	var s := state.sides[side]
	var best := -1
	var best_threat := INF
	for i in s.stack.size():
		if i == s.active_index or s.stack[i].is_fainted():
			continue
		var threat := threat_to(state, side, s.stack[i])
		if threat < best_threat:
			best_threat = threat
			best = i
	return best


## How good a move looks right now. 0 = pointless.
static func score_move(state: BattleState, side: int, slot: int, tier: String) -> float:
	var user := state.sides[side].active()
	var opp_side := BattleState.opponent(side)
	var target := state.sides[opp_side].active()
	var move := DataRegistry.get_move(user.moves[slot]["id"])
	var effect: String = move["effect"]["id"]
	var params: Dictionary = move["effect"]["params"]

	if move["category"] != "status":
		var effectiveness := DataRegistry.type_multiplier(move["type"], target.types())
		var power := float(move["power"])
		if effect == "multi_hit":
			power *= (float(params["min"]) + float(params["max"])) / 2.0
		var stab := BattleSim.STAB_MULTIPLIER if move["type"] in user.types() else 1.0
		var accuracy := 1.0 if int(move["accuracy"]) == 0 else int(move["accuracy"]) / 100.0
		return power * effectiveness * stab * accuracy

	if tier != "smart":
		return 1.0  # basic only uses status moves as a fallback

	var user_health := float(user.current_uptime) / user.max_uptime()
	var target_health := float(target.current_uptime) / target.max_uptime()
	match effect:
		"status_chance":
			var status: String = params["status"]
			if status == "looping":
				return 0.0 if int(state.sides[opp_side].volatile.get("looping_turns", 0)) > 0 else 150.0
			if not target.status.is_empty() or BattleSim.is_immune(target, status):
				return 0.0
			return 200.0 if target_health > 0.5 else 60.0
		"stat_change":
			var stages: Dictionary = state.sides[side if params["target"] == "self" else opp_side].stages
			for stat: String in params["changes"]:
				if absi(int(stages[stat])) >= 2:
					return 5.0
			if params["target"] == "self":
				return 110.0 if user_health > 0.7 else 5.0
			return 40.0
		"heal":
			return 250.0 if user_health < 0.4 else 0.0
	return 1.0


## Worst multiplier the opponent's own types deal to `d` (a rough "how scary is this matchup").
static func threat_to(state: BattleState, side: int, d: DaemonInstance) -> float:
	var opponent := state.sides[BattleState.opponent(side)].active()
	if opponent == null:
		return 1.0
	var worst := 0.0
	for attack_type: String in opponent.types():
		worst = maxf(worst, DataRegistry.type_multiplier(attack_type, d.types()))
	return worst


## Smart AI: a bench index to switch to, or -1 to stay in.
static func _better_switch(state: BattleState, side: int) -> int:
	var s := state.sides[side]
	if s.voluntary_switches >= MAX_SMART_SWITCHES:
		return -1
	var current := threat_to(state, side, s.active())
	if current < 2.0:
		return -1
	var best := choose_replacement(state, side, "smart")
	if best < 0 or threat_to(state, side, s.stack[best]) >= current:
		return -1
	return best


static func _first_usable_bench(state: BattleState, side: int) -> int:
	var s := state.sides[side]
	for i in s.stack.size():
		if i != s.active_index and not s.stack[i].is_fainted():
			return i
	return -1
