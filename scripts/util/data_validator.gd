class_name DataValidator
extends RefCounted
## Checks parsed game data for missing fields, bad values and broken cross-references.
## Every problem becomes one readable line, e.g.
##   species › chipmunk › learnset[2]: unknown move 'heatsnk_slam'
## After validate(), the id-indexed records are available in types / moves / species / items.

const STATS: PackedStringArray = ["uptime", "throughput", "hardening", "compute", "encryption", "bandwidth"]
## Stats that can be raised/lowered in battle (Uptime can't; accuracy/evasion can).
const STAGE_STATS: PackedStringArray = ["throughput", "hardening", "compute", "encryption", "bandwidth", "accuracy", "evasion"]
const STATUSES: PackedStringArray = ["throttled", "corrupted", "overheated", "standby", "hung", "looping"]
const CATEGORIES: PackedStringArray = ["physical", "special", "status"]
const GROWTH_RATES: PackedStringArray = ["fast", "medium_fast", "medium_slow", "slow", "erratic", "fluctuating"]
const POCKETS: PackedStringArray = ["items", "keys", "scripts", "key_items"]
const MULTIPLIERS: Array[float] = [0.0, 0.5, 2.0]

## effect id -> required param names
const MOVE_EFFECTS := {
	"none": [],
	"status_chance": ["status", "chance"],
	"stat_change": ["target", "changes", "chance"],
	"drain": ["fraction"],
	"recoil": ["fraction"],
	"heal": ["fraction"],
	"multi_hit": ["min", "max"],
}
const ITEM_EFFECTS := {
	"heal_uptime": ["amount"],
	"full_restore": [],
	"revive": ["fraction"],
	"repel": ["steps"],
	"escape": [],
	"capture": ["bonus"],
	"level_up": [],
	"evolve": [],
}
const EVOLUTION_TRIGGERS := {
	"level": ["level"],
	"item": ["item"],
	"sync": [],
}

var errors: PackedStringArray = []
var types: Dictionary = {}       # id -> {id, name, color}
var type_chart: Dictionary = {}  # attacker id -> {defender id -> multiplier}
var moves: Dictionary = {}
var species: Dictionary = {}
var items: Dictionary = {}
var config_profiles: Dictionary = {}


## raw = {"types": ..., "moves": ..., "species": ..., "items": ..., "config_profiles": ...}
## (each value is the parsed JSON of that file)
func validate(raw: Dictionary) -> PackedStringArray:
	errors = PackedStringArray()
	_validate_types(raw.get("types"))
	_validate_profiles(raw.get("config_profiles"))
	moves = _index(raw.get("moves"), "moves")
	items = _index(raw.get("items"), "items")
	species = _index(raw.get("species"), "species")
	for id: String in moves:
		_validate_move(moves[id], "moves › " + id)
	for id: String in items:
		_validate_item(items[id], "items › " + id)
	for id: String in species:
		_validate_species(species[id], "species › " + id)
	return errors


# --- types -------------------------------------------------------------------

func _validate_types(raw: Variant) -> void:
	types = {}
	type_chart = {}
	if typeof(raw) != TYPE_DICTIONARY:
		_err("types", "types.json must be an object with 'types' and 'chart'")
		return
	types = _index(raw.get("types"), "types")
	for id: String in types:
		var where := "types › " + id
		_string(types[id], "name", where)
		var color: Variant = types[id].get("color")
		if typeof(color) != TYPE_STRING or not Color.html_is_valid(color):
			_err(where, "'color' must be a hex color like \"#e0703c\"")
	var chart: Variant = raw.get("chart")
	if typeof(chart) != TYPE_DICTIONARY:
		_err("types", "'chart' must be an object")
		return
	for atk: String in chart:
		var row: Variant = chart[atk]
		if not types.has(atk):
			_err("types › chart", "unknown attacking type '%s'" % atk)
			continue
		if typeof(row) != TYPE_DICTIONARY:
			_err("types › chart › " + atk, "row must be an object")
			continue
		type_chart[atk] = {}
		for def: String in row:
			if not types.has(def):
				_err("types › chart › " + atk, "unknown defending type '%s'" % def)
			elif not _is_number(row[def]) or not float(row[def]) in MULTIPLIERS:
				_err("types › chart › %s › %s" % [atk, def], "multiplier must be 0, 0.5 or 2 (blank = 1)")
			else:
				type_chart[atk][def] = float(row[def])


# --- config profiles ---------------------------------------------------------

## 25 profiles: each non-Uptime stat pair (up, down) once, plus 5 neutral ones (up/down null).
func _validate_profiles(raw: Variant) -> void:
	config_profiles = _index(raw, "config_profiles")
	var battle_stats := Array(STATS).slice(1)  # everything except uptime
	var seen_pairs := {}
	for id: String in config_profiles:
		var p: Dictionary = config_profiles[id]
		var where := "config_profiles › " + id
		_string(p, "name", where)
		var up: Variant = p.get("up")
		var down: Variant = p.get("down")
		if up == null and down == null:
			continue
		if not up in battle_stats or not down in battle_stats:
			_err(where, "'up' and 'down' must both be null (neutral) or one of: %s" % ", ".join(PackedStringArray(battle_stats)))
		elif up == down:
			_err(where, "'up' and 'down' are the same stat; use null for a neutral profile")
		elif seen_pairs.has([up, down]):
			_err(where, "same up/down pair as '%s'" % seen_pairs[[up, down]])
		else:
			seen_pairs[[up, down]] = id
	if typeof(raw) == TYPE_ARRAY and config_profiles.size() != 25:
		_err("config_profiles", "expected 25 profiles, found %d" % config_profiles.size())


# --- moves -------------------------------------------------------------------

func _validate_move(m: Dictionary, where: String) -> void:
	_string(m, "name", where)
	_string(m, "description", where)
	_one_of(m, "type", where, types.keys())
	var category_ok := _one_of(m, "category", where, CATEGORIES)
	if _int(m, "power", where, 0, 250) and category_ok:
		var is_status: bool = m["category"] == "status"
		if is_status and m["power"] != 0:
			_err(where, "status moves must have power 0")
		elif not is_status and m["power"] == 0:
			_err(where, "damaging moves need power above 0")
	_int(m, "accuracy", where, 0, 100)  # 0 = never misses
	_int(m, "max_pp", where, 1, 64)
	_int(m, "priority", where, -7, 7)
	var params := _effect(m, where, MOVE_EFFECTS)
	if params.is_empty():
		return
	var ew := where + " › effect"
	match m["effect"]["id"]:
		"status_chance":
			_one_of(params, "status", ew, STATUSES)
			_int(params, "chance", ew, 1, 100)
		"stat_change":
			_one_of(params, "target", ew, ["self", "foe"])
			_int(params, "chance", ew, 1, 100)
			var changes: Variant = params.get("changes")
			if typeof(changes) != TYPE_DICTIONARY or changes.is_empty():
				_err(ew, "'changes' must be an object like {\"throughput\": 1}")
			else:
				for stat: String in changes:
					if not stat in STAGE_STATS:
						_err(ew, "can't change stat '%s' (allowed: %s)" % [stat, ", ".join(STAGE_STATS)])
					elif not _is_int(changes[stat]) or int(changes[stat]) == 0 or absi(int(changes[stat])) > 6:
						_err(ew, "'%s' change must be a whole number from -6 to 6, not 0" % stat)
		"drain", "recoil", "heal":
			_fraction(params, "fraction", ew)
		"multi_hit":
			if _int(params, "min", ew, 1, 10) and _int(params, "max", ew, 1, 10) and params["min"] > params["max"]:
				_err(ew, "'min' can't be greater than 'max'")


# --- items -------------------------------------------------------------------

func _validate_item(it: Dictionary, where: String) -> void:
	_string(it, "name", where)
	_string(it, "description", where)
	_one_of(it, "pocket", where, POCKETS)
	_int(it, "price", where, 0, 999999)
	var params := _effect(it, where, ITEM_EFFECTS)
	if params.is_empty():
		return
	var ew := where + " › effect"
	match it["effect"]["id"]:
		"heal_uptime":
			_int(params, "amount", ew, 1, 999)
		"revive":
			_fraction(params, "fraction", ew)
		"repel":
			_int(params, "steps", ew, 1, 9999)
		"capture":
			if not _is_number(params.get("bonus")) or float(params["bonus"]) <= 0.0:
				_err(ew, "'bonus' must be a number above 0")


# --- species -----------------------------------------------------------------

func _validate_species(s: Dictionary, where: String) -> void:
	_string(s, "name", where)
	_one_of(s, "growth_rate", where, GROWTH_RATES)
	_int(s, "catch_rate", where, 1, 255)
	_int(s, "base_exp", where, 1, 400)

	var t: Variant = s.get("types")
	if typeof(t) != TYPE_ARRAY or t.size() < 1 or t.size() > 2:
		_err(where, "'types' must be a list of 1 or 2 types")
	else:
		for type_id: Variant in t:
			if not types.has(type_id):
				_err(where, "unknown type '%s'" % str(type_id))
		if t.size() == 2 and t[0] == t[1]:
			_err(where, "'types' lists the same type twice")

	var stats: Variant = s.get("base_stats")
	if typeof(stats) != TYPE_DICTIONARY:
		_err(where, "'base_stats' must be an object with %s" % ", ".join(STATS))
	else:
		for stat in STATS:
			_int(stats, stat, where + " › base_stats", 1, 255)
		for stat: String in stats:
			if not stat in STATS:
				_err(where + " › base_stats", "unknown stat '%s'" % stat)

	var logs: Variant = s.get("log_yield")
	if typeof(logs) != TYPE_DICTIONARY or logs.is_empty():
		_err(where, "'log_yield' must be an object like {\"compute\": 1}")
	else:
		var total := 0
		for stat: String in logs:
			if not stat in STATS:
				_err(where + " › log_yield", "unknown stat '%s'" % stat)
			elif _int(logs, stat, where + " › log_yield", 1, 3):
				total += int(logs[stat])
		if total > 3:
			_err(where + " › log_yield", "total is %d, max is 3" % total)

	var learnset: Variant = s.get("learnset")
	if typeof(learnset) != TYPE_ARRAY or learnset.is_empty():
		_err(where, "'learnset' must be a non-empty list")
	else:
		for i in learnset.size():
			var lw := "%s › learnset[%d]" % [where, i]
			var entry: Variant = learnset[i]
			if typeof(entry) != TYPE_DICTIONARY:
				_err(lw, "must be an object like {\"level\": 1, \"move\": \"bump\"}")
				continue
			_int(entry, "level", lw, 1, 100)
			if not moves.has(entry.get("move")):
				_err(lw, "unknown move '%s'" % str(entry.get("move")))

	var evolutions: Variant = s.get("evolutions")
	if typeof(evolutions) != TYPE_ARRAY:
		_err(where, "'evolutions' must be a list (use [] for none)")
		return
	for i in evolutions.size():
		var ew := "%s › evolutions[%d]" % [where, i]
		var evo: Variant = evolutions[i]
		if typeof(evo) != TYPE_DICTIONARY:
			_err(ew, "must be an object")
			continue
		var target: Variant = evo.get("to")
		if not species.has(target):
			_err(ew, "unknown target species '%s'" % str(target))
		elif target == s.get("id"):
			_err(ew, "a Daemon can't upgrade into itself")
		if not _one_of(evo, "trigger", ew, EVOLUTION_TRIGGERS.keys()):
			continue
		match evo["trigger"]:
			"level":
				_int(evo, "level", ew, 2, 100)
			"item":
				var item_id: Variant = evo.get("item")
				if not items.has(item_id):
					_err(ew, "unknown item '%s'" % str(item_id))
				elif items[item_id].get("effect", {}).get("id") != "evolve":
					_err(ew, "item '%s' doesn't have the 'evolve' effect" % item_id)

	var cmdb: Variant = s.get("cmdb")
	if typeof(cmdb) != TYPE_DICTIONARY:
		_err(where, "'cmdb' must be an object with 'category' and 'entry'")
	else:
		_string(cmdb, "category", where + " › cmdb")
		_string(cmdb, "entry", where + " › cmdb")


# --- helpers -----------------------------------------------------------------

## Turns a list of records into {id: record}, flagging bad or duplicate ids.
func _index(list: Variant, file: String) -> Dictionary:
	var out := {}
	if typeof(list) != TYPE_ARRAY:
		_err(file, "%s.json is missing or isn't a list" % file)
		return out
	var id_pattern := RegEx.create_from_string("^[a-z0-9_]+$")
	for i in list.size():
		var rec: Variant = list[i]
		var where := "%s[%d]" % [file, i]
		if typeof(rec) != TYPE_DICTIONARY:
			_err(where, "must be an object")
			continue
		var id: Variant = rec.get("id")
		if typeof(id) != TYPE_STRING or id_pattern.search(id) == null:
			_err(where, "'id' must be lower_snake_case")
		elif out.has(id):
			_err(where, "duplicate id '%s'" % id)
		else:
			out[id] = rec
	return out


## Checks {"effect": {"id": ..., "params": {...}}}. Returns params, or {} if unusable.
func _effect(rec: Dictionary, where: String, allowed: Dictionary) -> Dictionary:
	var effect: Variant = rec.get("effect")
	if typeof(effect) != TYPE_DICTIONARY:
		_err(where, "'effect' must be an object with 'id' and 'params'")
		return {}
	if not _one_of(effect, "id", where + " › effect", allowed.keys()):
		return {}
	var params: Variant = effect.get("params")
	if typeof(params) != TYPE_DICTIONARY:
		_err(where + " › effect", "'params' must be an object (use {} for none)")
		return {}
	var ok := true
	for key: String in allowed[effect["id"]]:
		if not params.has(key):
			_err(where + " › effect", "'%s' needs param '%s'" % [effect["id"], key])
			ok = false
	if not ok:
		return {}
	# Non-empty marker so effects with no params still count as valid.
	return params if not params.is_empty() else {"_": true}


func _string(rec: Dictionary, field: String, where: String) -> bool:
	var v: Variant = rec.get(field)
	if typeof(v) != TYPE_STRING or (v as String).strip_edges().is_empty():
		_err(where, "'%s' must be non-empty text" % field)
		return false
	return true


func _int(rec: Dictionary, field: String, where: String, lo: int, hi: int) -> bool:
	var v: Variant = rec.get(field)
	if not _is_int(v):
		_err(where, "'%s' must be a whole number" % field)
		return false
	if v < lo or v > hi:
		_err(where, "'%s' is %d, must be %d to %d" % [field, int(v), lo, hi])
		return false
	return true


func _fraction(rec: Dictionary, field: String, where: String) -> bool:
	var v: Variant = rec.get(field)
	if not _is_number(v) or float(v) <= 0.0 or float(v) > 1.0:
		_err(where, "'%s' must be a number above 0 and at most 1" % field)
		return false
	return true


func _one_of(rec: Dictionary, field: String, where: String, allowed: Variant) -> bool:
	var v: Variant = rec.get(field)
	if typeof(v) != TYPE_STRING or not v in allowed:
		_err(where, "'%s' is %s, must be one of: %s" % [field, JSON.stringify(v), ", ".join(PackedStringArray(allowed))])
		return false
	return true


static func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


static func _is_int(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or (typeof(v) == TYPE_FLOAT and is_equal_approx(v, roundf(v)))


func _err(where: String, msg: String) -> void:
	errors.append("%s: %s" % [where, msg])
