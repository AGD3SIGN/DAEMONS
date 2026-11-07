class_name BattleSim
extends RefCounted
## The battle rules engine. Pure: it takes a BattleState and one BattleAction per side,
## changes the state, and returns an ordered list of BattleEvents (Dictionaries with a "type").
## It never touches nodes, UI or audio. The battle UI plays the events back.
##
## Turn flow: validate both actions -> turn_start -> each side acts in turn order -> end-of-turn
## status damage -> turn_end. After any crash: fainted, EXP for the player, switch_needed or
## battle_end. If a side needs a replacement, call forced_switch() before the next run_turn().
##
## Events (side: 0 = player, 1 = foe). Every event has "type".
##   battle_start      {is_wild, player, foe}
##   turn_start        {turn}                                  turn_end {turn}
##   switch_out        {side, daemon}
##   switch_in         {side, daemon, index, uptime, max_uptime}
##   item_used         {side, item, item_name, target, target_index}
##   heal              {side, daemon, target_index, amount, uptime, max_uptime}
##   revived           {side, daemon, target_index, uptime, max_uptime}
##   move_used         {side, user, move, move_name, target_side, target}
##   move_missed       {side, user}
##   move_failed       {side, reason}                          reason: "no_target" | "full_uptime"
##   damage            {side, daemon, amount, uptime, max_uptime, critical, effectiveness, source}
##                     source: "move" | "looping"; side = who took the damage
##   hit_count         {count}                                 after a multi-hit move
##   effectiveness     {multiplier}                            only when not 1x
##   no_effect         {side, target}                          the target's type is immune
##   drain             {side, daemon, amount, uptime, max_uptime}   user healed by a draining move
##   recoil            {side, daemon, amount, uptime, max_uptime}   user hurt by its own move
##   stat_changed      {side, daemon, stat, delta, stage}
##   stat_change_failed {side, daemon, stat, direction}        already at +6 / -6
##   status_applied    {side, daemon, status}
##   status_failed     {side, daemon, status}                  a status move didn't stick
##   status_blocked    {side, daemon, status}                  couldn't act this turn
##   status_cured      {side, daemon, target_index, status}    woke up / recovered / item
##   looping           {side, daemon}                          still Looping (may hit itself)
##   hurt_itself       {side, daemon}                          followed by a damage event
##   looping_ended     {side, daemon}
##   status_damage     {side, daemon, status, amount, uptime, max_uptime}
##   fainted           {side, daemon}
##   exp_gained        {side, index, daemon, amount}
##   level_up / move_learned / move_learn_pending  (from DaemonInstance, plus side, index, daemon)
##   switch_needed     {side}
##   fled              {side}                                  run_failed {side}
##   capture_shake     {n}                                     1..3, one per passed check
##   captured          {side, daemon, species}                 outcome becomes "caught"
##   capture_failed    {shakes}                                0..3 shakes before it broke free
##   battle_end        {outcome}
##   upgrade_ready     {side, index, daemon, to}               after battle_end; caller calls evolve()
##   invalid_action    {side, reason}                          turn not played; ask again

const ACTION_RANK := {
	BattleAction.Kind.RUN: 0,
	BattleAction.Kind.SWITCH: 1,
	BattleAction.Kind.ITEM: 2,
	BattleAction.Kind.FIGHT: 3,
}
const BATTLE_ITEM_EFFECTS: PackedStringArray = ["heal_uptime", "full_restore", "revive"]

const CRIT_CHANCE := 1.0 / 16.0
const CRIT_MULTIPLIER := 1.5
const STAB_MULTIPLIER := 1.5
const ROLL_MIN := 85
const ROLL_MAX := 100
const THROTTLED_SKIP_CHANCE := 0.25
const HUNG_RECOVER_CHANCE := 0.2
const LOOPING_SELF_HIT_CHANCE := 1.0 / 3.0
const LOOPING_SELF_HIT_POWER := 40
const STANDBY_TURNS := Vector2i(1, 3)
const LOOPING_TURNS := Vector2i(2, 5)
const CORRUPTED_FRACTION := 8     # loses 1/8 max Uptime per turn
const OVERHEATED_FRACTION := 16   # loses 1/16 max Uptime per turn
const TRAINER_EXP_BONUS := 1.5
const CAPTURE_CHECKS := 4

static var _effect_handlers: Dictionary = {}


# --- public API --------------------------------------------------------------

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
		_handle_faints(state, events)
		_check_end(state, events)
	if not state.is_over():
		_end_of_turn(state, events)
		_handle_faints(state, events)
		_check_end(state, events)
	if not state.is_over():
		events.append(_ev("turn_end", {"turn": state.turn}))
	return events


## Sends in a replacement after a crash (switch_needed). Doesn't use up a turn.
static func forced_switch(state: BattleState, side: int, index: int) -> Array[Dictionary]:
	if state.is_over() or not state.needs_switch[side]:
		return [_ev("invalid_action", {"side": side, "reason": "no replacement is needed"})]
	var reason := _validate_switch_target(state.sides[side], index)
	if not reason.is_empty():
		return [_ev("invalid_action", {"side": side, "reason": reason})]
	state.needs_switch[side] = false
	_bring_in(state, side, index)
	return [_switch_in_event(state, side)]


## "" if the action is allowed, else a reason a player could read.
static func validate_action(state: BattleState, side: int, action: BattleAction) -> String:
	if action == null:
		return "no action chosen"
	if state.needs_switch[side]:
		return "choose a replacement first"
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
			return _validate_switch_target(s, action.index)
		BattleAction.Kind.ITEM:
			return _validate_item(state, side, action)
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


## Stat stages: +1 = 1.5x, +2 = 2x ... +6 = 4x; -1 = 2/3 ... -6 = 1/4.
static func stage_multiplier(stage: int) -> float:
	var s := clampi(stage, -6, 6)
	return maxf(2.0, 2.0 + s) / maxf(2.0, 2.0 - s)


## Accuracy/evasion stages: +1 = 4/3 ... +6 = 3x; -1 = 3/4 ... -6 = 1/3.
static func accuracy_multiplier(stage: int) -> float:
	var s := clampi(stage, -6, 6)
	return maxf(3.0, 3.0 + s) / maxf(3.0, 3.0 - s)


## Damage for one hit, with the crit and random roll (85..100) passed in so it's testable.
## floor(floor(floor(2L/5+2) * Power * Atk / Def) / 50) + 2, then x crit, x roll/100, x STAB, x type.
@warning_ignore("integer_division")
static func calc_damage(state: BattleState, side: int, move: Dictionary, critical: bool, roll: int) -> int:
	var atk_side := state.sides[side]
	var def_side := state.sides[BattleState.opponent(side)]
	var attacker := atk_side.active()
	var defender := def_side.active()
	var physical: bool = move["category"] == "physical"
	var atk_stat := "throughput" if physical else "compute"
	var def_stat := "hardening" if physical else "encryption"
	var atk_stage := int(atk_side.stages[atk_stat])
	var def_stage := int(def_side.stages[def_stat])
	if critical:  # crits ignore the attacker's drops and the defender's boosts
		atk_stage = maxi(atk_stage, 0)
		def_stage = mini(def_stage, 0)
	var atk := floori(attacker.get_stat(atk_stat) * stage_multiplier(atk_stage))
	var def := maxi(1, floori(defender.get_stat(def_stat) * stage_multiplier(def_stage)))
	if physical and attacker.status == "overheated":
		atk = atk / 2
	var damage := (2 * attacker.level / 5 + 2) * int(move["power"]) * atk / def / 50 + 2
	if critical:
		damage = floori(damage * CRIT_MULTIPLIER)
	damage = damage * roll / 100
	if move["type"] in attacker.types():
		damage = floori(damage * STAB_MULTIPLIER)
	var effectiveness := DataRegistry.type_multiplier(move["type"], defender.types())
	if effectiveness == 0.0:
		return 0
	return maxi(1, floori(damage * effectiveness))


## Tries to give the active Daemon on `side` a status. Returns false if it can't
## (already has one, immune, already Looping, crashed).
static func try_apply_status(state: BattleState, side: int, status: String, events: Array[Dictionary]) -> bool:
	var s := state.sides[side]
	var d := s.active()
	if d == null or d.is_fainted():
		return false
	if status == "looping":
		if int(s.volatile.get("looping_turns", 0)) > 0:
			return false
		s.volatile["looping_turns"] = state.rng.randi_range(LOOPING_TURNS.x, LOOPING_TURNS.y)
	else:
		if not d.status.is_empty() or is_immune(d, status):
			return false
		d.status = status
		d.status_turns = state.rng.randi_range(STANDBY_TURNS.x, STANDBY_TURNS.y) if status == "standby" else 0
	events.append(_ev("status_applied", {"side": side, "daemon": d.display_name(), "status": status}))
	return true


static func is_immune(d: DaemonInstance, status: String) -> bool:
	for type_id: String in d.types():
		if status in DataRegistry.types.get(type_id, {}).get("status_immunities", []):
			return true
	return false


# --- actions -----------------------------------------------------------------

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


## Faster (or equal) always escapes. Otherwise odds = floor(mine * 128 / theirs) + 30 * attempts,
## out of 256. Each failed attempt makes the next one likelier.
static func _do_run(state: BattleState, side: int, events: Array[Dictionary]) -> void:
	state.escape_attempts += 1
	var mine := effective_bandwidth(state, side)
	var theirs := effective_bandwidth(state, BattleState.opponent(side))
	var escaped := mine >= theirs
	if not escaped:
		var odds := floori(mine * 128.0 / maxf(1.0, theirs)) + 30 * state.escape_attempts
		escaped = odds >= 256 or state.rng.randi_range(0, 255) < odds
	if escaped:
		state.outcome = "fled"
		events.append(_ev("fled", {"side": side}))
	else:
		events.append(_ev("run_failed", {"side": side}))


static func _do_switch(state: BattleState, side: int, index: int, events: Array[Dictionary]) -> void:
	state.sides[side].voluntary_switches += 1
	events.append(_ev("switch_out", {"side": side, "daemon": state.sides[side].active().display_name()}))
	_bring_in(state, side, index)
	events.append(_switch_in_event(state, side))


static func _bring_in(state: BattleState, side: int, index: int) -> void:
	var s := state.sides[side]
	s.active_index = index
	s.reset_volatile()
	if side == BattleState.FOE:
		state.participants = [state.sides[BattleState.PLAYER].active_index]
	elif not index in state.participants:
		state.participants.append(index)


static func _do_item(state: BattleState, side: int, action: BattleAction, events: Array[Dictionary]) -> void:
	var s := state.sides[side]
	var item := DataRegistry.get_item(action.item_id)
	s.items[action.item_id] = int(s.items[action.item_id]) - 1
	if int(s.items[action.item_id]) <= 0:
		s.items.erase(action.item_id)
	if item["effect"]["id"] == "capture":
		var foe := state.sides[BattleState.opponent(side)].active()
		events.append(_ev("item_used", {"side": side, "item": action.item_id, "item_name": item["name"],
			"target": foe.display_name(), "target_index": -1}))
		_attempt_capture(state, float(item["effect"]["params"]["bonus"]), events)
		return
	var target := s.stack[action.index]
	events.append(_ev("item_used", {"side": side, "item": action.item_id, "item_name": item["name"],
		"target": target.display_name(), "target_index": action.index}))
	var params: Dictionary = item["effect"]["params"]
	match item["effect"]["id"]:
		"heal_uptime":
			_heal(side, action.index, target, int(params["amount"]), events)
		"full_restore":
			_heal(side, action.index, target, target.max_uptime(), events)
			if not target.status.is_empty():
				events.append(_ev("status_cured", {"side": side, "daemon": target.display_name(), "target_index": action.index, "status": target.status}))
				target.status = ""
				target.status_turns = 0
		"revive":
			target.current_uptime = maxi(1, floori(target.max_uptime() * float(params["fraction"])))
			target.status = ""
			target.status_turns = 0
			events.append(_ev("revived", {"side": side, "daemon": target.display_name(), "target_index": action.index,
				"uptime": target.current_uptime, "max_uptime": target.max_uptime()}))


static func _heal(side: int, index: int, target: DaemonInstance, amount: int, events: Array[Dictionary]) -> void:
	var healed := mini(amount, target.max_uptime() - target.current_uptime)
	if healed <= 0:
		return
	target.current_uptime += healed
	events.append(_ev("heal", {"side": side, "daemon": target.display_name(), "target_index": index, "amount": healed,
		"uptime": target.current_uptime, "max_uptime": target.max_uptime()}))


static func _do_fight(state: BattleState, side: int, slot: int, events: Array[Dictionary]) -> void:
	var user := state.sides[side].active()
	if user == null or user.is_fainted():
		return  # crashed before it could act
	if not _can_act(state, side, events):
		return
	var move_slot: Dictionary = user.moves[slot]
	move_slot["pp"] = int(move_slot["pp"]) - 1
	var move := DataRegistry.get_move(move_slot["id"])
	var target_side := BattleState.opponent(side)
	var target := state.sides[target_side].active()
	events.append(_ev("move_used", {"side": side, "user": user.display_name(), "move": move_slot["id"],
		"move_name": move["name"], "target_side": target_side,
		"target": target.display_name() if target != null else ""}))
	_resolve_move(state, side, move, events)


## Status checks before acting: Standby, Hung, Looping, Throttled (in that order).
static func _can_act(state: BattleState, side: int, events: Array[Dictionary]) -> bool:
	var s := state.sides[side]
	var d := s.active()
	var info := {"side": side, "daemon": d.display_name(), "status": d.status}
	match d.status:
		"standby":
			if d.status_turns > 0:
				d.status_turns -= 1
				events.append(_ev("status_blocked", info.duplicate()))
				return false
			_cure(state, side, events)
		"hung":
			if state.rng.randf() < HUNG_RECOVER_CHANCE:
				_cure(state, side, events)
			else:
				events.append(_ev("status_blocked", info.duplicate()))
				return false

	var looping := int(s.volatile.get("looping_turns", 0))
	if looping > 0:
		looping -= 1
		s.volatile["looping_turns"] = looping
		if looping == 0:
			events.append(_ev("looping_ended", {"side": side, "daemon": d.display_name()}))
		else:
			events.append(_ev("looping", {"side": side, "daemon": d.display_name()}))
			if state.rng.randf() < LOOPING_SELF_HIT_CHANCE:
				events.append(_ev("hurt_itself", {"side": side, "daemon": d.display_name()}))
				_apply_damage(state, side, _self_hit_damage(state, side), events, {"critical": false, "effectiveness": 1.0, "source": "looping"})
				return false

	if d.status == "throttled" and state.rng.randf() < THROTTLED_SKIP_CHANCE:
		events.append(_ev("status_blocked", {"side": side, "daemon": d.display_name(), "status": "throttled"}))
		return false
	return true


static func _cure(state: BattleState, side: int, events: Array[Dictionary]) -> void:
	var d := state.sides[side].active()
	events.append(_ev("status_cured", {"side": side, "daemon": d.display_name(), "target_index": state.sides[side].active_index, "status": d.status}))
	d.status = ""
	d.status_turns = 0


## Typeless physical hit on itself: own Throughput vs own Hardening, no crit/STAB/type.
@warning_ignore("integer_division")
static func _self_hit_damage(state: BattleState, side: int) -> int:
	var s := state.sides[side]
	var d := s.active()
	var atk := floori(d.get_stat("throughput") * stage_multiplier(int(s.stages["throughput"])))
	var def := maxi(1, floori(d.get_stat("hardening") * stage_multiplier(int(s.stages["hardening"]))))
	var damage := (2 * d.level / 5 + 2) * LOOPING_SELF_HIT_POWER * atk / def / 50 + 2
	return maxi(1, damage * state.rng.randi_range(ROLL_MIN, ROLL_MAX) / 100)


# --- resolving a move --------------------------------------------------------

static func _resolve_move(state: BattleState, side: int, move: Dictionary, events: Array[Dictionary]) -> void:
	var target_side := BattleState.opponent(side)
	var target := state.sides[target_side].active()
	var effect_id: String = move["effect"]["id"]
	var params: Dictionary = move["effect"]["params"]
	var is_status_move: bool = move["category"] == "status"
	var self_targeted: bool = is_status_move and (effect_id == "heal" or (effect_id == "stat_change" and params.get("target") == "self"))

	if not self_targeted:
		if target == null or target.is_fainted():
			events.append(_ev("move_failed", {"side": side, "reason": "no_target"}))
			return
		if not _accuracy_hits(state, side, move):
			events.append(_ev("move_missed", {"side": side, "user": state.sides[side].active().display_name()}))
			return

	var ctx := {"state": state, "side": side, "target_side": target_side, "move": move,
		"params": params, "events": events, "damage": 0}

	if not is_status_move:
		var effectiveness := DataRegistry.type_multiplier(move["type"], target.types())
		if effectiveness == 0.0:
			events.append(_ev("no_effect", {"side": target_side, "target": target.display_name()}))
			return
		var hits := _roll_hits(state, params) if effect_id == "multi_hit" else 1
		var landed := 0
		for i in hits:
			if target.is_fainted():
				break
			var critical := state.rng.randf() < CRIT_CHANCE
			var roll := state.rng.randi_range(ROLL_MIN, ROLL_MAX)
			var damage := calc_damage(state, side, move, critical, roll)
			ctx["damage"] = int(ctx["damage"]) + _apply_damage(state, target_side, damage, events,
				{"critical": critical, "effectiveness": effectiveness, "source": "move"})
			landed += 1
		if hits > 1:
			events.append(_ev("hit_count", {"count": landed}))
		if effectiveness != 1.0:
			events.append(_ev("effectiveness", {"multiplier": effectiveness}))

	var handler: Callable = _handlers().get(effect_id, Callable())
	if handler.is_valid():
		handler.call(ctx)


static func _accuracy_hits(state: BattleState, side: int, move: Dictionary) -> bool:
	var accuracy := int(move["accuracy"])
	if accuracy == 0:
		return true  # never misses
	var stage := int(state.sides[side].stages["accuracy"]) - int(state.sides[BattleState.opponent(side)].stages["evasion"])
	return state.rng.randf() * 100.0 < accuracy * accuracy_multiplier(stage)


## 2-5 hits: 3/8 two, 3/8 three, 1/8 four, 1/8 five. Other ranges are uniform.
static func _roll_hits(state: BattleState, params: Dictionary) -> int:
	var lo := int(params["min"])
	var hi := int(params["max"])
	if lo == hi:
		return lo
	if lo == 2 and hi == 5:
		var r := state.rng.randi_range(0, 7)
		return 2 if r < 3 else (3 if r < 6 else (4 if r == 6 else 5))
	return state.rng.randi_range(lo, hi)


## Takes Uptime off the active Daemon on `side`. Returns the amount actually lost.
static func _apply_damage(state: BattleState, side: int, amount: int, events: Array[Dictionary], extra: Dictionary) -> int:
	var d := state.sides[side].active()
	var lost := mini(amount, d.current_uptime)
	d.current_uptime -= lost
	var data := {"side": side, "daemon": d.display_name(), "amount": lost,
		"uptime": d.current_uptime, "max_uptime": d.max_uptime()}
	data.merge(extra)
	events.append(_ev("damage", data))
	return lost


# --- move effect handlers (keyed by effect id in moves.json) -----------------

static func _handlers() -> Dictionary:
	if _effect_handlers.is_empty():
		_effect_handlers = {
			"none": func(_ctx: Dictionary) -> void: pass,
			"multi_hit": func(_ctx: Dictionary) -> void: pass,  # hits are rolled in the damage step
			"status_chance": func(ctx: Dictionary) -> void: _fx_status_chance(ctx),
			"stat_change": func(ctx: Dictionary) -> void: _fx_stat_change(ctx),
			"drain": func(ctx: Dictionary) -> void: _fx_drain(ctx),
			"recoil": func(ctx: Dictionary) -> void: _fx_recoil(ctx),
			"heal": func(ctx: Dictionary) -> void: _fx_heal(ctx),
		}
	return _effect_handlers


## True if a chance effect (1..100) goes off. 100 never rolls.
static func _chance(state: BattleState, chance: int) -> bool:
	return chance >= 100 or state.rng.randi_range(1, 100) <= chance


static func _fx_status_chance(ctx: Dictionary) -> void:
	var state: BattleState = ctx["state"]
	var target_side: int = ctx["target_side"]
	var target := state.sides[target_side].active()
	if target == null or target.is_fainted():
		return
	if not _chance(state, int(ctx["params"]["chance"])):
		return
	var status: String = ctx["params"]["status"]
	var events: Array[Dictionary] = ctx["events"]
	if not try_apply_status(state, target_side, status, events) and ctx["move"]["category"] == "status":
		events.append(_ev("status_failed", {"side": target_side, "daemon": target.display_name(), "status": status}))


static func _fx_stat_change(ctx: Dictionary) -> void:
	var state: BattleState = ctx["state"]
	var params: Dictionary = ctx["params"]
	var side: int = ctx["side"] if params["target"] == "self" else ctx["target_side"]
	var s := state.sides[side]
	var d := s.active()
	if d == null or d.is_fainted() or not _chance(state, int(params["chance"])):
		return
	var events: Array[Dictionary] = ctx["events"]
	for stat: String in params["changes"]:
		var delta := int(params["changes"][stat])
		var old := int(s.stages[stat])
		var new_stage := clampi(old + delta, -6, 6)
		if new_stage == old:
			events.append(_ev("stat_change_failed", {"side": side, "daemon": d.display_name(), "stat": stat, "direction": signi(delta)}))
		else:
			s.stages[stat] = new_stage
			events.append(_ev("stat_changed", {"side": side, "daemon": d.display_name(), "stat": stat, "delta": new_stage - old, "stage": new_stage}))


static func _fx_drain(ctx: Dictionary) -> void:
	var dealt: int = ctx["damage"]
	var user: DaemonInstance = ctx["state"].sides[ctx["side"]].active()
	if dealt <= 0 or user.is_fainted():
		return
	var amount := mini(maxi(1, floori(dealt * float(ctx["params"]["fraction"]))), user.max_uptime() - user.current_uptime)
	if amount <= 0:
		return
	user.current_uptime += amount
	ctx["events"].append(_ev("drain", {"side": ctx["side"], "daemon": user.display_name(), "amount": amount, "uptime": user.current_uptime, "max_uptime": user.max_uptime()}))


static func _fx_recoil(ctx: Dictionary) -> void:
	var dealt: int = ctx["damage"]
	var user: DaemonInstance = ctx["state"].sides[ctx["side"]].active()
	if dealt <= 0 or user.is_fainted():
		return
	var amount := mini(maxi(1, floori(dealt * float(ctx["params"]["fraction"]))), user.current_uptime)
	user.current_uptime -= amount
	ctx["events"].append(_ev("recoil", {"side": ctx["side"], "daemon": user.display_name(), "amount": amount, "uptime": user.current_uptime, "max_uptime": user.max_uptime()}))


static func _fx_heal(ctx: Dictionary) -> void:
	var side: int = ctx["side"]
	var s: BattleSide = ctx["state"].sides[side]
	var user := s.active()
	if user.current_uptime >= user.max_uptime():
		ctx["events"].append(_ev("move_failed", {"side": side, "reason": "full_uptime"}))
		return
	_heal(side, s.active_index, user, floori(user.max_uptime() * float(ctx["params"]["fraction"])), ctx["events"])


# --- Quarantine (capture) ----------------------------------------------------

## a = floor((3*Max - 2*Current) * catch_rate * key_bonus / (3*Max)) x status bonus
## Status bonus: 2 for Standby/Hung, 1.5 for Throttled/Corrupted/Overheated. a >= 255 always catches.
static func capture_value(foe: DaemonInstance, key_bonus: float) -> int:
	var max_up := foe.max_uptime()
	var catch_rate := int(foe.species_data()["catch_rate"])
	var a := floorf((3 * max_up - 2 * foe.current_uptime) * catch_rate * key_bonus / (3.0 * max_up))
	match foe.status:
		"standby", "hung":
			a *= 2.0
		"throttled", "corrupted", "overheated":
			a *= 1.5
	return floori(a)


## Each of the 4 checks passes if a random 0..65535 is below this.
static func shake_threshold(a: int) -> int:
	if a <= 0:
		return 0
	if a >= 255:
		return 65536
	return floori(1048560.0 / sqrt(sqrt(16711680.0 / a)))


static func _attempt_capture(state: BattleState, key_bonus: float, events: Array[Dictionary]) -> void:
	var foe := state.sides[BattleState.FOE].active()
	var threshold := shake_threshold(capture_value(foe, key_bonus))
	var passed := 0
	while passed < CAPTURE_CHECKS and (threshold >= 65536 or state.rng.randi_range(0, 65535) < threshold):
		passed += 1
	for n in mini(passed, 3):
		events.append(_ev("capture_shake", {"n": n + 1}))
	if passed == CAPTURE_CHECKS:
		state.outcome = "caught"
		state.captured = foe
		events.append(_ev("captured", {"side": BattleState.FOE, "daemon": foe.display_name(), "species": foe.species_id}))
	else:
		events.append(_ev("capture_failed", {"shakes": mini(passed, 3)}))


# --- end of turn, crashes, EXP -----------------------------------------------

static func _end_of_turn(state: BattleState, events: Array[Dictionary]) -> void:
	for side in [BattleState.PLAYER, BattleState.FOE]:
		var d := state.sides[side].active()
		if d == null or d.is_fainted():
			continue
		var fraction := 0
		match d.status:
			"corrupted":
				fraction = CORRUPTED_FRACTION
			"overheated":
				fraction = OVERHEATED_FRACTION
		if fraction == 0:
			continue
		var lost := mini(maxi(1, d.max_uptime() / fraction), d.current_uptime)
		d.current_uptime -= lost
		events.append(_ev("status_damage", {"side": side, "daemon": d.display_name(), "status": d.status,
			"amount": lost, "uptime": d.current_uptime, "max_uptime": d.max_uptime()}))


## Reports each newly crashed active Daemon once, awards EXP for foe crashes, and flags
## the side for a replacement if it has one.
static func _handle_faints(state: BattleState, events: Array[Dictionary]) -> void:
	for side in [BattleState.FOE, BattleState.PLAYER]:
		var s := state.sides[side]
		var d := s.active()
		if d == null or not d.is_fainted() or s.volatile.get("faint_reported", false):
			continue
		s.volatile["faint_reported"] = true
		d.status = ""
		d.status_turns = 0
		events.append(_ev("fainted", {"side": side, "daemon": d.display_name()}))
		if side == BattleState.FOE:
			_award_exp(state, events)
		if s.has_usable():
			state.needs_switch[side] = true
			events.append(_ev("switch_needed", {"side": side}))


## EXP = floor(base_exp * foe level / 7), x1.5 in trainer battles, split between the
## participants still standing. Each of them also gets the foe's full Experience Logs.
@warning_ignore("integer_division")
static func _award_exp(state: BattleState, events: Array[Dictionary]) -> void:
	var foe := state.sides[BattleState.FOE].active()
	var total := int(foe.species_data()["base_exp"]) * foe.level / 7
	if not state.is_wild:
		total = floori(total * TRAINER_EXP_BONUS)
	var player := state.sides[BattleState.PLAYER]
	var receivers: Array[int] = []
	for i in state.participants:
		if i >= 0 and i < player.stack.size() and not player.stack[i].is_fainted():
			receivers.append(i)
	if receivers.is_empty():
		return
	var share := maxi(1, total / receivers.size())
	var log_yield: Dictionary = foe.species_data()["log_yield"]
	for i in receivers:
		var d := player.stack[i]
		d.add_experience_logs(log_yield)
		if d.level >= DaemonInstance.MAX_LEVEL:
			continue
		events.append(_ev("exp_gained", {"side": BattleState.PLAYER, "index": i, "daemon": d.display_name(), "amount": share}))
		for e in d.gain_exp(share):
			e["side"] = BattleState.PLAYER
			e["index"] = i
			e["daemon"] = d.display_name()
			events.append(e)
			if e["type"] == "level_up":
				state.leveled_up[i] = true


static func _check_end(state: BattleState, events: Array[Dictionary]) -> void:
	if not state.is_over():
		if not state.sides[BattleState.FOE].has_usable():
			state.outcome = "player_won"
		elif not state.sides[BattleState.PLAYER].has_usable():
			state.outcome = "player_lost"
	if not state.is_over() or state.end_reported:
		return
	state.end_reported = true
	state.needs_switch = [false, false]
	events.append(_ev("battle_end", {"outcome": state.outcome}))
	var player := state.sides[BattleState.PLAYER]
	for i: int in state.leveled_up:
		var d := player.stack[i]
		var target := "" if d.is_fainted() else d.check_evolution("level")
		if not target.is_empty():
			events.append(_ev("upgrade_ready", {"side": BattleState.PLAYER, "index": i, "daemon": d.display_name(), "to": target}))


# --- helpers -----------------------------------------------------------------

static func _validate_switch_target(s: BattleSide, index: int) -> String:
	if index < 0 or index >= s.stack.size():
		return "there's no Daemon in that slot"
	if index == s.active_index:
		return "that Daemon is already in battle"
	if s.stack[index].is_fainted():
		return "that Daemon has crashed"
	return ""


static func _validate_item(state: BattleState, side: int, action: BattleAction) -> String:
	var s := state.sides[side]
	if int(s.items.get(action.item_id, 0)) <= 0:
		return "you don't have any of that item"
	var item := DataRegistry.get_item(action.item_id)
	if item.is_empty():
		return "unknown item"
	var effect: String = item["effect"]["id"]
	if effect == "capture":
		if not state.is_wild:
			return "you can't Quarantine another trainer's Daemon"
		if side != BattleState.PLAYER:
			return "only the player can use Quarantine Keys"
		var foe := state.sides[BattleState.opponent(side)].active()
		if foe == null or foe.is_fainted():
			return "there's nothing to Quarantine"
		return ""
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
