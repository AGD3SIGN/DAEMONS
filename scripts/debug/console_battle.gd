class_name ConsoleBattle
extends Node
## Debug: a text-only battle in the terminal, running on the real battle sim.
##
## You play (type commands):
##   godot --headless --path . res://scenes/debug/console_battle.tscn
## Options go after "--":
##   ... -- --trainer          fight Kevin's 3 Daemons instead of a wild one
##   ... -- --seed 42          pick the random seed (same seed = same battle)
##   ... -- --ai basic         foe AI tier: random | basic | smart
##   ... -- --auto             let the smart AI play your side too

const MAX_TURNS := 200
const WILD_POOL := [["dustbunny", 4, 7], ["wormby", 4, 7], ["cablesnake", 5, 8], ["floppit", 5, 8], ["spigeon", 4, 7]]
const PLAYER_TEAM := [["chipmunk", 12], ["pingo", 10], ["glowbit", 10]]
const KEVIN_TEAM := [["spigeon", 9], ["cablesnake", 10], ["wormby", 11]]
const PLAYER_ITEMS := {"coffee": 3, "energy_drink": 1, "hard_reboot": 1, "thumb_drive": 5, "encrypted_key": 2}


func _ready() -> void:
	var opts := parse_args(OS.get_cmdline_user_args())
	run(opts)
	get_tree().quit()


static func parse_args(args: PackedStringArray) -> Dictionary:
	var opts := {"auto": false, "trainer": false, "seed": int(Time.get_unix_time_from_system()), "ai": "", "echo": true}
	var i := 0
	while i < args.size():
		match args[i]:
			"--auto":
				opts["auto"] = true
			"--trainer":
				opts["trainer"] = true
			"--seed":
				i += 1
				opts["seed"] = int(args[i]) if i < args.size() else 1
			"--ai":
				i += 1
				opts["ai"] = args[i] if i < args.size() else ""
		i += 1
	return opts


## Plays a whole AI-vs-AI battle quietly. Used by tests.
static func simulate(seed_value: int, trainer: bool, ai: String = "") -> Dictionary:
	return run({"auto": true, "trainer": trainer, "seed": seed_value, "ai": ai, "echo": false})


static func run(opts: Dictionary) -> Dictionary:
	var out: Array[String] = []
	var echo: bool = opts.get("echo", true)
	var interactive: bool = not opts.get("auto", false)
	var trainer: bool = opts.get("trainer", false)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(opts.get("seed", 1))
	var foe_tier: String = opts.get("ai", "")
	if foe_tier.is_empty() or not foe_tier in BattleAI.TIERS:
		foe_tier = "smart" if trainer else "random"
	var foe_name := "Kevin" if trainer else ""

	var player_stack: Array[DaemonInstance] = []
	for entry: Array in PLAYER_TEAM:
		player_stack.append(DaemonInstance.create(entry[0], entry[1], rng, 1))
	var foe_stack: Array[DaemonInstance] = []
	if trainer:
		for entry: Array in KEVIN_TEAM:
			foe_stack.append(DaemonInstance.create(entry[0], entry[1], rng, 2))
	else:
		var pick: Array = WILD_POOL[rng.randi_range(0, WILD_POOL.size() - 1)]
		foe_stack.append(DaemonInstance.create(pick[0], rng.randi_range(pick[1], pick[2]), rng))

	var state := BattleState.new(BattleSide.new("You", player_stack, PLAYER_ITEMS.duplicate()),
		BattleSide.new(foe_name if trainer else "Wild", foe_stack), rng, not trainer)
	var all_events: Array[Dictionary] = []
	_say(out, echo, "=== DAEMONS console battle (seed %d, foe AI: %s) ===" % [int(opts.get("seed", 1)), foe_tier])
	_show(out, echo, state, BattleSim.start(state), foe_name, all_events)

	while not state.is_over() and state.turn < MAX_TURNS:
		for side in 2:
			if state.needs_switch[side]:
				var index := -1
				if side == BattleState.PLAYER and interactive:
					index = _ask_replacement(out, echo, state)
				else:
					index = BattleAI.choose_replacement(state, side, foe_tier if side == BattleState.FOE else "smart")
				if index < 0:
					_say(out, echo, "You closed the console.")
					return _result(out, state, all_events)
				_show(out, echo, state, BattleSim.forced_switch(state, side, index), foe_name, all_events)
		var player_action: BattleAction
		if interactive:
			player_action = _ask_action(out, echo, state, foe_name)
			if player_action == null:
				_say(out, echo, "You closed the console.")
				return _result(out, state, all_events)
		else:
			player_action = BattleAI.choose_action(state, BattleState.PLAYER, "smart")
		var foe_action := BattleAI.choose_action(state, BattleState.FOE, foe_tier)
		var events := BattleSim.run_turn(state, player_action, foe_action)
		if events.size() == 1 and events[0]["type"] == "invalid_action":
			_say(out, echo, "  (can't do that: %s)" % events[0]["reason"])
			if not interactive:
				_say(out, echo, "Stuck: no valid action left.")
				break
			continue
		_say(out, echo, "")
		_show(out, echo, state, events, foe_name, all_events)

	if not state.is_over():
		_say(out, echo, "Turn limit reached.")
	for e in all_events:
		if e["type"] == "upgrade_ready":
			var d: DaemonInstance = state.sides[BattleState.PLAYER].stack[int(e["index"])]
			var old_name := d.display_name()
			d.evolve(e["to"])
			_say(out, echo, "%s upgraded into %s!" % [old_name, d.display_name()])
	if state.outcome == "caught":
		_say(out, echo, "%s was added to your Active Stack." % state.captured.display_name())
	_say(out, echo, "=== Outcome: %s after %d turns ===" % [state.outcome if state.outcome else "none", state.turn])
	return _result(out, state, all_events)


static func _result(out: Array[String], state: BattleState, all_events: Array[Dictionary]) -> Dictionary:
	return {"lines": out, "outcome": state.outcome, "turns": state.turn, "events": all_events}


# --- printing ----------------------------------------------------------------

static func _say(out: Array[String], echo: bool, text: String) -> void:
	out.append(text)
	if echo:
		print(text)


static func _show(out: Array[String], echo: bool, state: BattleState, events: Array[Dictionary], foe_name: String, all_events: Array[Dictionary]) -> void:
	for e in events:
		all_events.append(e)
		var text := BattleText.describe(e, state.is_wild, foe_name)
		if not text.is_empty():
			_say(out, echo, text)
		if e.has("uptime") and e.has("max_uptime") and e["type"] != "switch_in":
			var d_name: String = e.get("daemon", "")
			_say(out, echo, "    %s %s" % [d_name, _bar(int(e["uptime"]), int(e["max_uptime"]))])


static func _bar(current: int, maximum: int) -> String:
	var filled := roundi(10.0 * current / maxi(1, maximum))
	return "[%s%s] %d/%d" % ["#".repeat(filled), "-".repeat(10 - filled), current, maximum]


static func _status_line(label: String, d: DaemonInstance) -> String:
	var status := "" if d.status.is_empty() else "  " + d.status.to_upper().left(3)
	return "%s %s Lv%d  %s%s" % [label, d.display_name(), d.level, _bar(d.current_uptime, d.max_uptime()), status]


# --- input (interactive mode) ------------------------------------------------

## Reads one line. Returns null on end of input (Ctrl+D) so the caller can stop.
static func _read_line() -> Variant:
	printraw("> ")
	var raw := OS.read_string_from_stdin(1024)
	if raw.is_empty():
		return null
	return raw.strip_edges()


static func _ask_action(out: Array[String], echo: bool, state: BattleState, foe_name: String) -> BattleAction:
	var me := state.sides[BattleState.PLAYER]
	var foe := state.sides[BattleState.FOE]
	while true:
		_say(out, echo, "")
		_say(out, echo, "--- Turn %d ---" % (state.turn + 1))
		_say(out, echo, _status_line("FOE: Wild" if state.is_wild else "FOE:", foe.active()) + ("" if state.is_wild else "  (%s)" % foe_name))
		_say(out, echo, _status_line("YOU:", me.active()))
		var d := me.active()
		for i in d.moves.size():
			var move := DataRegistry.get_move(d.moves[i]["id"])
			_say(out, echo, "  %d) %-16s PP %2d  %s" % [i + 1, move["name"], int(d.moves[i]["pp"]), DataRegistry.types[move["type"]]["name"]])
		_say(out, echo, "  s) switch   i) item   r) run   q) quit")
		var line: Variant = _read_line()
		if line == null or line == "q":
			return null
		match line:
			"s":
				var index := _pick_from_stack(out, echo, state, false)
				if index >= 0:
					return BattleAction.switch_to(index)
			"i":
				var action := _ask_item(out, echo, state)
				if action != null:
					return action
			"r":
				return BattleAction.run()
			_:
				if (line as String).is_valid_int() and int(line) >= 1 and int(line) <= d.moves.size():
					return BattleAction.fight(int(line) - 1)
				_say(out, echo, "  Type 1-%d, s, i, r or q." % d.moves.size())
	return null


static func _ask_item(out: Array[String], echo: bool, state: BattleState) -> BattleAction:
	var items: Dictionary = state.sides[BattleState.PLAYER].items
	var ids: Array = items.keys()
	if ids.is_empty():
		_say(out, echo, "  Your bag is empty.")
		return null
	for i in ids.size():
		_say(out, echo, "  %d) %s x%d" % [i + 1, DataRegistry.get_item(ids[i])["name"], int(items[ids[i]])])
	_say(out, echo, "  Which item? (blank = back)")
	var line: Variant = _read_line()
	if line == null or not (line as String).is_valid_int() or int(line) < 1 or int(line) > ids.size():
		return null
	var item_id: String = ids[int(line) - 1]
	if DataRegistry.get_item(item_id)["effect"]["id"] == "capture":
		return BattleAction.item(item_id, 0)
	var target := _pick_from_stack(out, echo, state, true)
	return BattleAction.item(item_id, target) if target >= 0 else null


static func _ask_replacement(out: Array[String], echo: bool, state: BattleState) -> int:
	_say(out, echo, "Choose a Daemon to deploy:")
	while true:
		var index := _pick_from_stack(out, echo, state, false)
		if index == -2:
			return -1
		if index >= 0:
			return index
	return -1


## Lists the stack and reads a choice. Returns the index, -1 for back, -2 for end of input.
static func _pick_from_stack(out: Array[String], echo: bool, state: BattleState, include_active: bool) -> int:
	var me := state.sides[BattleState.PLAYER]
	for i in me.stack.size():
		var d := me.stack[i]
		var tag := " (in battle)" if i == me.active_index else (" (crashed)" if d.is_fainted() else "")
		if include_active or i != me.active_index:
			_say(out, echo, "  %d) %s Lv%d %s%s" % [i + 1, d.display_name(), d.level, _bar(d.current_uptime, d.max_uptime()), tag])
	var line: Variant = _read_line()
	if line == null:
		return -2
	if not (line as String).is_valid_int():
		return -1
	return int(line) - 1
