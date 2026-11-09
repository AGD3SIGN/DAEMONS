class_name SliceAudit
extends RefCounted
## "Playtest by reading the scripts": walks every map from the New Game spawn and reports
##   - maps / spawns you can't reach, and places you can enter but never leave (soft-locks)
##   - warps, NPCs, signs and hidden items nobody can reach
##   - flags that are checked but never set (broken gates) and flags set but never used
##   - certifications that are checked but never awarded
##   - trainers and dialogues nothing uses, and the trainer level curve
## Movement rules match the game: solid tiles, water and counters block, ledges only drop down,
## NPCs block unless they can be hidden by a flag, laser doors count as open if solvable.
##
## Run: tests/test_slice_audit.gd (fails on problems) or SliceAudit.run() from anywhere.

const START := {"map": "player_house", "spawn": "new_game"}
const HOME := {"map": "onboarding_town", "spawn": "default"}
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var problems: PackedStringArray = []
var notes: PackedStringArray = []

var _flags_set := {}
var _flags_read := {}
var _certs_given := {}
var _certs_read := {}
var _trainers_used := {}
var _dialogues_used := {}
var _region_cache := {}


static func run() -> SliceAudit:
	var audit := SliceAudit.new()
	audit._audit()
	return audit


func report() -> String:
	var lines := PackedStringArray(["# Slice audit", ""])
	lines.append("## Problems (%d)" % problems.size())
	lines.append_array(Array(problems).map(func(p: String) -> String: return "- " + p) if not problems.is_empty() else ["- None"])
	lines.append("")
	lines.append("## Notes")
	lines.append_array(Array(notes).map(func(n: String) -> String: return "- " + n))
	return "\n".join(lines)


# --- the walk ----------------------------------------------------------------

func _audit() -> void:
	_collect_dialogue_facts()
	var visited := {}   # "map:spawn" -> true
	var exits := {}     # "map:spawn" -> Array of "map:spawn" it can warp to
	var queue: Array = [_node(START["map"], START["spawn"])]
	var maps_seen := {}
	while not queue.is_empty():
		var node: String = queue.pop_front()
		if visited.has(node):
			continue
		visited[node] = true
		var parts := node.split(":")
		var map_id := parts[0]
		var m := DataRegistry.get_map(map_id)
		if m.is_empty():
			problems.append("%s: map doesn't load" % map_id)
			continue
		maps_seen[map_id] = true
		var region := _region(map_id, parts[1])
		exits[node] = []
		for e: Dictionary in m.get("events", []):
			if e["type"] == "warp" and region.has(Vector2i(int(e["x"]), int(e["y"]))):
				var target := _node(e["to_map"], e["to_spawn"])
				exits[node].append(target)
				queue.append(target)
		if exits[node].is_empty():
			problems.append("%s: soft-lock — you can arrive here but no exit is reachable" % node)

	for map_id in DataRegistry.map_ids():
		if not maps_seen.has(map_id):
			problems.append("%s: map is never reachable from New Game" % map_id)
		else:
			_check_events(map_id, visited)

	# Every place you can get to must lead back home.
	for node: String in visited:
		if not _can_reach(node, _node(HOME["map"], HOME["spawn"]), exits):
			problems.append("%s: can't get back to Onboarding Town from here" % node)

	for flag: String in _flags_read:
		if not _flags_set.has(flag):
			problems.append("flag '%s' is checked (%s) but nothing sets it" % [flag, _flags_read[flag]])
	for flag: String in _flags_set:
		if not _flags_read.has(flag):
			notes.append("flag '%s' is set but never checked (fine for bookkeeping)" % flag)
	for cert: String in _certs_read:
		if not _certs_given.has(cert):
			problems.append("certification '%s' is checked but never awarded" % cert)
	for trainer_id: String in DataRegistry.trainers:
		if not _trainers_used.has(trainer_id):
			notes.append("trainer '%s' isn't placed anywhere" % trainer_id)
	for dialogue_id: String in DataRegistry.dialogues:
		if not _dialogues_used.has(dialogue_id):
			notes.append("dialogue '%s' is never used" % dialogue_id)
	notes.append("maps reachable: %d of %d; arrival points: %d" % [maps_seen.size(), DataRegistry.map_ids().size(), visited.size()])
	notes.append_array(_level_curve())
	notes.append(_pp_note())


func _node(map_id: String, spawn: String) -> String:
	var m := DataRegistry.get_map(map_id)
	if not m.get("spawns", {}).has(spawn):
		spawn = "default"
	return "%s:%s" % [map_id, spawn]


func _can_reach(from: String, to: String, exits: Dictionary) -> bool:
	var seen := {from: true}
	var queue: Array = [from]
	while not queue.is_empty():
		var n: String = queue.pop_front()
		if n == to:
			return true
		for nxt: String in exits.get(n, []):
			if not seen.has(nxt):
				seen[nxt] = true
				queue.append(nxt)
	return false


# --- movement ----------------------------------------------------------------

## Cells you can stand on starting from a spawn point.
func _region(map_id: String, spawn: String) -> Dictionary:
	var key := map_id + ":" + spawn
	if _region_cache.has(key):
		return _region_cache[key]
	var m := DataRegistry.get_map(map_id)
	var sp: Dictionary = m["spawns"].get(spawn, m["spawns"]["default"])
	var start := Vector2i(int(sp["x"]), int(sp["y"]))
	var blockers := _static_blockers(m)
	var region := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for dir in DIRS:
			var target := cell + dir
			var info := _tile(m, target)
			if dir == Vector2i.DOWN and info.get("behavior") == "ledge_down":
				target += Vector2i.DOWN  # hop over
				info = _tile(m, target)
			if not _walkable(info) or blockers.has(target) or region.has(target):
				continue
			region[target] = true
			queue.append(target)
	_region_cache[key] = region
	return region


func _tile(m: Dictionary, cell: Vector2i) -> Dictionary:
	var rows: Array = m["rows"]
	if cell.y < 0 or cell.y >= rows.size() or cell.x < 0 or cell.x >= String(rows[0]).length():
		return {}
	return DataRegistry.tiles.get(m["legend"].get(String(rows[cell.y])[cell.x], ""), {})


func _walkable(info: Dictionary) -> bool:
	return not info.is_empty() and not info["collision"] and not info["behavior"] in ["water", "counter", "ledge_down"]


## NPCs that never move out of the way. Hidden NPCs (cutscene actors) aren't there. Gate NPCs with
## hide_if_flag count as passable when their
## flag can be set; laser doors count as passable when their flags can be satisfied.
func _static_blockers(m: Dictionary) -> Dictionary:
	var out := {}
	for e: Dictionary in m.get("events", []):
		var cell := Vector2i(int(e["x"]), int(e["y"]))
		if e["type"] == "npc":
			var hideable: bool = e.get("hidden", false) or (e.has("hide_if_flag") and _flags_set.has(e["hide_if_flag"]))
			if not hideable and not e.get("wander", false):
				out[cell] = true
		elif e["type"] == "barrier":
			var solvable := true
			for flag: String in e.get("open_flags", []):
				solvable = solvable and _flags_set.has(flag)
			if not solvable:
				out[cell] = true
	return out


# --- events ------------------------------------------------------------------

func _check_events(map_id: String, visited: Dictionary) -> void:
	var m := DataRegistry.get_map(map_id)
	var reachable := {}
	for node: String in visited:
		if node.begins_with(map_id + ":"):
			reachable.merge(_region(map_id, node.split(":")[1]))
	for e: Dictionary in m.get("events", []):
		var cell := Vector2i(int(e["x"]), int(e["y"]))
		var label := "%s (%d,%d) %s %s" % [map_id, cell.x, cell.y, e["type"], e.get("id", e.get("dialogue", e.get("item", "")))]
		match e["type"]:
			"warp", "trigger":
				if e["type"] == "warp" and not reachable.has(cell):
					problems.append("%s: can't be reached" % label)
				if e["type"] == "trigger" and not _rect_touches(reachable, cell, int(e.get("w", 1)), int(e.get("h", 1))):
					problems.append("%s: nobody can walk into it" % label)
			"npc", "sign", "hidden_item":
				if not _can_talk_to(m, reachable, cell) and not (e["type"] == "hidden_item" and reachable.has(cell)):
					problems.append("%s: can't be reached to interact with" % label)
			"barrier":
				for flag: String in e.get("open_flags", []):
					if not _flags_set.has(flag):
						problems.append("%s: needs flag '%s' which nothing sets — door never opens" % [label, flag])


func _can_talk_to(m: Dictionary, reachable: Dictionary, cell: Vector2i) -> bool:
	for dir in DIRS:
		if reachable.has(cell + dir):
			return true
		if _tile(m, cell + dir).get("behavior") == "counter" and reachable.has(cell + dir * 2):
			return true
	return false


func _rect_touches(reachable: Dictionary, origin: Vector2i, w: int, h: int) -> bool:
	for y in h:
		for x in w:
			if reachable.has(origin + Vector2i(x, y)):
				return true
	return false


# --- flags, certs, trainers, dialogue ----------------------------------------

func _collect_dialogue_facts() -> void:
	for flag in ["got_starter", "starter_chipmunk", "starter_pingo", "starter_glowbit"]:
		_flags_set[flag] = "choose_starter"
	for map_id in DataRegistry.map_ids():
		for e: Dictionary in DataRegistry.get_map(map_id).get("events", []):
			if e.has("dialogue"):
				_dialogues_used[e["dialogue"]] = true
			if e.has("trainer"):
				_trainers_used[e["trainer"]] = true
				_flags_set[BattleScene.trainer_flag(e["trainer"])] = "beating %s" % e["trainer"]
				var cert: String = DataRegistry.trainers[e["trainer"]].get("cert", "")
				if not cert.is_empty():
					_certs_given[cert] = true
			for key in ["once_flag"]:
				if e.has(key):
					_flags_set[e[key]] = map_id
					_flags_read[e[key]] = map_id
			for key in ["requires_flag", "unless_flag", "hide_if_flag"]:
				if e.has(key):
					_flags_read[e[key]] = "%s %s" % [map_id, key]
			if e["type"] == "hidden_item":
				_flags_set[e["flag"]] = map_id
				_flags_read[e["flag"]] = map_id
			if e["type"] == "barrier":
				for flag: String in e.get("open_flags", []) + e.get("closed_flags", []):
					_flags_read[flag] = "%s laser door" % map_id
	for dialogue_id: String in DataRegistry.dialogues:
		_scan_steps(DataRegistry.dialogues[dialogue_id], dialogue_id)


func _scan_steps(steps: Array, where: String) -> void:
	for step: Dictionary in steps:
		if step.has("if_flag"):
			_flags_read[step["if_flag"]] = where
		if step.has("if_cert"):
			_certs_read[step["if_cert"]] = where
		match step.get("cmd", ""):
			"set_flag":
				_flags_set[step["flag"]] = where
			"give_cert":
				_certs_given[step["cert"]] = true
			"start_battle":
				if step.has("trainer"):
					_trainers_used[step["trainer"]] = true
					_flags_set[BattleScene.trainer_flag(step["trainer"])] = where
		for branch in ["yes", "no", "then", "else"]:
			if step.has(branch):
				_scan_steps(step[branch], where)


func _level_curve() -> PackedStringArray:
	var out := PackedStringArray()
	for trainer_id: String in DataRegistry.trainers:
		var levels: Array = DataRegistry.trainers[trainer_id]["team"].map(func(entry: Array) -> int: return int(entry[1]))
		out.append("trainer %s: levels %s" % [trainer_id, levels])
	return out


## PP check: how much PP do slice Daemons carry, and is the 0-PP fallback (Force Quit) in place?
func _pp_note() -> String:
	var lowest := 9999
	var who := ""
	for species_id: String in DataRegistry.species:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1
		var d := DaemonInstance.create(species_id, 5, rng)
		var total := 0
		for slot: Dictionary in d.moves:
			total += int(slot["pp"])
		if total < lowest:
			lowest = total
			who = species_id
	var fallback := "in place" if not DataRegistry.get_move(BattleSim.FALLBACK_MOVE).is_empty() else "MISSING (battles can soft-lock at 0 PP)"
	return "PP: lowest total at Lv 5 is %d (%s). 0-PP fallback (Force Quit): %s." % [lowest, who, fallback]
