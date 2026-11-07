class_name BattleSim
extends RefCounted
## The battle rules engine. Pure: it takes a BattleState and one BattleAction per side,
## changes the state, and returns an ordered list of BattleEvents (Dictionaries with a "type").
## It never touches nodes, UI or audio. The battle UI plays the events back.
##
## Events (side: 0 = player, 1 = foe):
##   battle_start   {is_wild, player, foe}
##   turn_start     {turn}                       turn_end {turn}
##   switch_out     {side, daemon}               switch_in {side, daemon, index, uptime, max_uptime}
##   item_used      {side, item, item_name, target, target_index}
##   heal           {side, target_index, amount, uptime, max_uptime}
##   status_cured   {side, target_index, status}
##   revived        {side, target_index, uptime, max_uptime}
##   move_used      {side, user, move, move_name, target_side, target}
##   fled           {side}
##   battle_end     {outcome}
##   invalid_action {side, reason}               (turn not played; ask again)

## Run beats switch beats item beats fight. Inside a bracket: priority, then bandwidth, then a coin flip.
const ACTION_RANK := {
	BattleAction.Kind.RUN: 0,
	BattleAction.Kind.SWITCH: 1,
	BattleAction.Kind.ITEM: 2,
	BattleAction.Kind.FIGHT: 3,
}
const BATTLE_ITEM_EFFECTS: PackedStringArray = ["heal_uptime", "full_restore", "revive"]


## Opening events: who's here. Call once before the first turn.
static func start(state: BattleState) -> Array[Dictionary]:
	var player := state.sides[BattleState.PLAYER]
	var foe := state.sides[BattleState.FOE]
	return [
		_ev("battle_start", {"is_wild": state.is_wild, "player": player.name, "foe": foe.name}),
		_switch_in_event(state, BattleState.FOE),
		_switch_in_event(state, BattleState.PLAYER),
	]


## Plays one turn. If either action is invalid, nothing happens and a single
## invalid_action event comes back so the caller can ask again.
static func run_turn(state: BattleState, player_action: BattleAction, foe_action: BattleAction) -> Array[Dictionary]:
	if state.is_over():
		return [_ev("invalid_action", {"side": -1, "reason": "the battle is over"})]
	var actions: Array[BattleAction] = [player_action, foe_action]
	for side in 2:
		var reason := validate_action(state, side, actions[side])
		if not reason.is_empty():
			return [_ev("invalid_action", {"side": side, "reason": reason})]

	var events: Array[Dictionary] = []
	state.turn += 1
	events.append(_ev("turn_start", {"turn": state.turn}))
	for side in turn_order(state, actions):
		if state.is_over():
			break
		_execute(state, side, actions[side], events)
	if not state.is_over():
		events.append(_ev("turn_end", {"turn": state.turn}))
	_check_end(state, events)
	return events


## "" if the action is allowed, else a reason a player could read.
static func validate_action(state: BattleState, side: int, action: BattleAction) -> String:
	if action == null:
		return "no action chosen"
	var s := state.sides[side]
	match action.kind:
		BattleAction.Kind.FIGHT:
			var user := s.active()
			if user == null or user.is_fainted():
				return "the active Daemon has crashed"
			if action.slot < 0 or action.slot >= user.moves.size():
				return "there's no move in that slot"
			if int(user.moves[action.slot]["pp"]) <= 0:
				return "no PP left for that move"
		BattleAction.Kind.SWITCH:
			if action.index < 0 or action.index >= s.stack.size():
				return "there's no Daemon in that slot"
			if action.index == s.active_index:
				return "that Daemon is already in battle"
			if s.stack[action.index].is_fainted():
				return "that Daemon has crashed"
		BattleAction.Kind.ITEM:
			return _validate_item(s, action)
		BattleAction.Kind.RUN:
			if not state.is_wild:
				return "you can't run from a trainer battle"
	return ""


## Order the two sides act in this turn. Always rolls the tie-breaker so the RNG
## advances the same way whatever the actions are.
static func turn_order(state: BattleState, actions: Array[BattleAction]) -> Array[int]:
	var keys: Array = []
	for side in 2:
		var action := actions[side]
		var priority := 0
		if action.kind == BattleAction.Kind.FIGHT:
			var move_id: String = state.sides[side].active().moves[action.slot]["id"]
			priority = int(DataRegistry.get_move(move_id)["priority"])
		keys.append({
			"side": side,
			"rank": ACTION_RANK[action.kind],
			"priority": priority,
			"speed": effective_bandwidth(state, side),
			"tie": state.rng.randf(),
		})
	keys.sort_custom(_goes_first)
	return [keys[0]["side"], keys[1]["side"]]


## Bandwidth after stat stages and Throttled (halved).
static func effective_bandwidth(state: BattleState, side: int) -> float:
	var s := state.sides[side]
	var d := s.active()
	if d == null:
		return 0.0
	var speed := d.get_stat("bandwidth") * stage_multiplier(int(s.stages.get("bandwidth", 0)))
	if d.status == "throttled":
		speed *= 0.5
	return speed


## Standard stage multiplier: +1 = 1.5x, +2 = 2x ... +6 = 4x; -1 = 2/3 ... -6 = 1/4.
static func stage_multiplier(stage: int) -> float:
	var s := clampi(stage, -6, 6)
	return maxf(2.0, 2.0 + s) / maxf(2.0, 2.0 - s)


# --- execution ---------------------------------------------------------------

static func _execute(state: BattleState, side: int, action: BattleAction, events: Array[Dictionary]) -> void:
	match action.kind:
		BattleAction.Kind.RUN:
			_do_run(state, side, events)
		BattleAction.Kind.SWITCH:
			_do_switch(state, side, action.index, events)
		BattleAction.Kind.ITEM:
			_do_item(state, side, action, events)
		BattleAction.Kind.FIGHT:
			_do_fight(state, side, action.slot, events)


static func _do_run(state: BattleState, side: int, events: Array[Dictionary]) -> void:
	# Phase 2c replaces this with the bandwidth-based escape chance.
	state.escape_attempts += 1
	state.outcome = "fled"
	events.append(_ev("fled", {"side": side}))


static func _do_switch(state: BattleState, side: int, index: int, events: Array[Dictionary]) -> void:
	var s := state.sides[side]
	events.append(_ev("switch_out", {"side": side, "daemon": s.active().display_name()}))
	s.active_index = index
	s.reset_volatile()
	events.append(_switch_in_event(state, side))


static func _do_item(state: BattleState, side: int, action: BattleAction, events: Array[Dictionary]) -> void:
	var s := state.sides[side]
	var item := DataRegistry.get_item(action.item_id)
	var target := s.stack[action.index]
	s.items[action.item_id] = int(s.items[action.item_id]) - 1
	if int(s.items[action.item_id]) <= 0:
		s.items.erase(action.item_id)
	events.append(_ev("item_used", {"side": side, "item": action.item_id, "item_name": item["name"],
		"target": target.display_name(), "target_index": action.index}))
	var params: Dictionary = item["effect"]["params"]
	match item["effect"]["id"]:
		"heal_uptime":
			_heal(side, action.index, target, int(params["amount"]), events)
		"full_restore":
			_heal(side, action.index, target, target.max_uptime(), events)
			if not target.status.is_empty():
				events.append(_ev("status_cured", {"side": side, "target_index": action.index, "status": target.status}))
				target.status = ""
		"revive":
			target.current_uptime = maxi(1, floori(target.max_uptime() * float(params["fraction"])))
			target.status = ""
			events.append(_ev("revived", {"side": side, "target_index": action.index,
				"uptime": target.current_uptime, "max_uptime": target.max_uptime()}))


static func _heal(side: int, index: int, target: DaemonInstance, amount: int, events: Array[Dictionary]) -> void:
	var healed := mini(amount, target.max_uptime() - target.current_uptime)
	if healed <= 0:
		return
	target.current_uptime += healed
	events.append(_ev("heal", {"side": side, "target_index": index, "amount": healed,
		"uptime": target.current_uptime, "max_uptime": target.max_uptime()}))


static func _do_fight(state: BattleState, side: int, slot: int, events: Array[Dictionary]) -> void:
	var user := state.sides[side].active()
	if user == null or user.is_fainted():
		return  # crashed before it could act
	var move_slot: Dictionary = user.moves[slot]
	move_slot["pp"] = int(move_slot["pp"]) - 1
	var move := DataRegistry.get_move(move_slot["id"])
	var target_side := BattleState.opponent(side)
	var target := state.sides[target_side].active()
	events.append(_ev("move_used", {"side": side, "user": user.display_name(), "move": move_slot["id"],
		"move_name": move["name"], "target_side": target_side,
		"target": target.display_name() if target != null else ""}))
	_resolve_move(state, side, move, events)


## Phase 2b: accuracy, damage, crits, type effectiveness, status and move effects.
static func _resolve_move(_state: BattleState, _side: int, _move: Dictionary, _events: Array[Dictionary]) -> void:
	pass


static func _check_end(state: BattleState, events: Array[Dictionary]) -> void:
	if not state.is_over():
		if not state.sides[BattleState.FOE].has_usable():
			state.outcome = "player_won"
		elif not state.sides[BattleState.PLAYER].has_usable():
			state.outcome = "player_lost"
	if state.is_over() and not state.end_reported:
		state.end_reported = true
		events.append(_ev("battle_end", {"outcome": state.outcome}))


# --- helpers -----------------------------------------------------------------

static func _validate_item(s: BattleSide, action: BattleAction) -> String:
	if int(s.items.get(action.item_id, 0)) <= 0:
		return "you don't have any of that item"
	var item := DataRegistry.get_item(action.item_id)
	if item.is_empty():
		return "unknown item"
	var effect: String = item["effect"]["id"]
	if effect == "capture":
		return "Quarantine Keys aren't wired up yet (Phase 2c)"
	if not effect in BATTLE_ITEM_EFFECTS:
		return "that can't be used in battle"
	if action.index < 0 or action.index >= s.stack.size():
		return "there's no Daemon in that slot"
	var target := s.stack[action.index]
	if effect == "revive":
		return "" if target.is_fainted() else "that Daemon hasn't crashed"
	if target.is_fainted():
		return "that Daemon needs a Hard Reboot first"
	var full := target.current_uptime >= target.max_uptime()
	if effect == "heal_uptime" and full:
		return "it won't have any effect"
	if effect == "full_restore" and full and target.status.is_empty():
		return "it won't have any effect"
	return ""


static func _goes_first(a: Dictionary, b: Dictionary) -> bool:
	if a["rank"] != b["rank"]:
		return a["rank"] < b["rank"]
	if a["priority"] != b["priority"]:
		return a["priority"] > b["priority"]
	if a["speed"] != b["speed"]:
		return a["speed"] > b["speed"]
	return a["tie"] > b["tie"]


static func _switch_in_event(state: BattleState, side: int) -> Dictionary:
	var s := state.sides[side]
	var d := s.active()
	return _ev("switch_in", {"side": side, "daemon": d.display_name(), "index": s.active_index,
		"uptime": d.current_uptime, "max_uptime": d.max_uptime()})


static func _ev(type: String, data: Dictionary) -> Dictionary:
	data["type"] = type
	return data
