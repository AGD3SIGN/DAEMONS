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
const TILE_BEHAVIORS: PackedStringArray = ["none", "hot_zone", "ledge_down", "water", "door", "counter"]
const FACINGS: PackedStringArray = ["up", "down", "left", "right"]
const DIALOGUE_COMMANDS := {
	"set_flag": ["flag"],
	"give_item": ["item"],
	"give_daemon": ["species", "level"],
	"heal_party": [],
	"start_battle": [],  # needs "trainer" (id from data/trainers) or "foe"
	"give_cert": ["cert"],
	"move_npc": ["npc", "path"],
	"open_shop": ["stock"],
	"open_rack": [],
	"name_player": [],
	"choose_starter": ["options"],
	"move_player": ["path"],
}
const EVENT_TYPES := {
	"warp": ["to_map", "to_spawn"],
	"sign": ["dialogue"],
	"npc": ["id", "facing"],  # plus "dialogue" and/or "trainer"
	"trigger": ["dialogue"],
	"hidden_item": ["item", "flag"],
	"barrier": ["open_flags"],
}

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
var tiles: Dictionary = {}   # tile name -> {name, atlas, collision, behavior}
var dialogues: Dictionary = {}  # dialogue id -> list of steps
var encounters: Dictionary = {}  # map id -> {rate, zones: {tile name: [slots]}}
var trainers: Dictionary = {}    # trainer id -> {name, team, ai, prize, sight, intro, defeat, after, cert}
var certifications: Dictionary = {}  # cert id -> {id, name, department, type, order}


## raw = {"types": ..., "moves": ..., "species": ..., "items": ..., "config_profiles": ...}
## (each value is the parsed JSON of that file)
func validate(raw: Dictionary) -> PackedStringArray:
	errors = PackedStringArray()
	_validate_types(raw.get("types"))
	_validate_profiles(raw.get("config_profiles"))
	_validate_tiles(raw.get("tiles"))
	moves = _index(raw.get("moves"), "moves")
	items = _index(raw.get("items"), "items")
	species = _index(raw.get("species"), "species")
	for id: String in moves:
		_validate_move(moves[id], "moves › " + id)
	for id: String in items:
		_validate_item(items[id], "items › " + id)
	for id: String in species:
		_validate_species(species[id], "species › " + id)
	_validate_certifications(raw.get("certifications"))
	_validate_trainers(raw.get("trainers", {}))
	_validate_dialogue_files(raw.get("dialogue", {}))
	_validate_encounters(raw.get("encounters", {}))
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
		var immunities: Variant = types[id].get("status_immunities", [])
		if typeof(immunities) != TYPE_ARRAY:
			_err(where, "'status_immunities' must be a list of status ids")
		else:
			for status: Variant in immunities:
				if not status in STATUSES:
					_err(where, "unknown status '%s' in status_immunities" % str(status))
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


# --- overworld tiles and maps ------------------------------------------------

func _validate_tiles(raw: Variant) -> void:
	tiles = {}
	if typeof(raw) != TYPE_ARRAY:
		_err("tiles", "tiles.json is missing or isn't a list")
		return
	var seen_atlas := {}
	for i in raw.size():
		var t: Variant = raw[i]
		var where := "tiles[%d]" % i
		if typeof(t) != TYPE_DICTIONARY or not _string(t, "name", where):
			continue
		where = "tiles › " + String(t["name"])
		if tiles.has(t["name"]):
			_err(where, "duplicate tile name")
			continue
		tiles[t["name"]] = t
		var atlas: Variant = t.get("atlas")
		if typeof(atlas) != TYPE_ARRAY or atlas.size() != 2 or not _is_int(atlas[0]) or not _is_int(atlas[1]) or atlas[0] < 0 or atlas[1] < 0:
			_err(where, "'atlas' must be [column, row]")
		elif seen_atlas.has(str(atlas)):
			_err(where, "same atlas cell as '%s'" % seen_atlas[str(atlas)])
		else:
			seen_atlas[str(atlas)] = t["name"]
		if typeof(t.get("collision")) != TYPE_BOOL:
			_err(where, "'collision' must be true or false")
		_one_of(t, "behavior", where, TILE_BEHAVIORS)


## Checks one map file (data/maps/<id>.json). Needs tiles validated first.
func validate_map(m: Variant, map_id: String) -> PackedStringArray:
	var before := errors.size()
	var where := "maps › " + map_id
	if typeof(m) != TYPE_DICTIONARY:
		_err(where, "must be an object")
		return errors.slice(before)
	if m.get("id") != map_id:
		_err(where, "'id' must match the file name")
	_string(m, "name", where)
	if m.has("tint") and (typeof(m["tint"]) != TYPE_STRING or not Color.html_is_valid(m["tint"])):
		_err(where, "'tint' must be a hex color")
	var legend: Variant = m.get("legend")
	if typeof(legend) != TYPE_DICTIONARY or legend.is_empty():
		_err(where, "'legend' must map characters to tile names")
		legend = {}
	for ch: String in legend:
		if ch.length() != 1:
			_err(where + " › legend", "key '%s' must be one character" % ch)
		elif not tiles.has(legend[ch]):
			_err(where + " › legend", "'%s' is an unknown tile '%s'" % [ch, str(legend[ch])])
	var rows: Variant = m.get("rows")
	if typeof(rows) != TYPE_ARRAY or rows.is_empty():
		_err(where, "'rows' must be a non-empty list of strings")
		return errors.slice(before)
	var width := String(rows[0]).length()
	for y in rows.size():
		var row := String(rows[y])
		if row.length() != width:
			_err(where, "row %d is %d wide, expected %d" % [y, row.length(), width])
		for x in row.length():
			if not legend.has(row[x]):
				_err(where, "unknown character '%s' at (%d, %d)" % [row[x], x, y])
	var spawns: Variant = m.get("spawns")
	if typeof(spawns) != TYPE_DICTIONARY or not spawns.has("default"):
		_err(where, "'spawns' must include \"default\"")
		return errors.slice(before)
	for spawn_name: String in spawns:
		var sp: Dictionary = spawns[spawn_name]
		var sw := where + " › spawns › " + spawn_name
		if not _int(sp, "x", sw, 0, width - 1) or not _int(sp, "y", sw, 0, rows.size() - 1):
			continue
		_one_of(sp, "facing", sw, FACINGS)
		var ch: String = String(rows[int(sp["y"])])[int(sp["x"])]
		var tile: Dictionary = tiles.get(legend.get(ch, ""), {})
		if tile.get("collision", true) or tile.get("behavior") == "water":
			_err(sw, "spawn is on a tile you can't stand on")
	_validate_events(m.get("events", []), where, rows, legend)
	return errors.slice(before)


func _validate_events(events: Variant, where: String, rows: Array, legend: Dictionary) -> void:
	if typeof(events) != TYPE_ARRAY:
		_err(where, "'events' must be a list")
		return
	var npc_ids := {}
	var width := String(rows[0]).length()
	for i in events.size():
		var e: Variant = events[i]
		var ew := "%s › events[%d]" % [where, i]
		if typeof(e) != TYPE_DICTIONARY or not _one_of(e, "type", ew, EVENT_TYPES.keys()):
			continue
		ew += " (%s)" % e["type"]
		if not _int(e, "x", ew, 0, width - 1) or not _int(e, "y", ew, 0, rows.size() - 1):
			continue
		var missing := false
		for key: String in EVENT_TYPES[e["type"]]:
			if not e.has(key):
				_err(ew, "needs '%s'" % key)
				missing = true
		if missing:
			continue
		var row := String(rows[int(e["y"])])
		var tile: Dictionary = tiles.get(legend.get(row[int(e["x"])], ""), {}) if int(e["x"]) < row.length() else {}
		if e.has("dialogue") and not dialogues.has(e["dialogue"]):
			_err(ew, "unknown dialogue '%s'" % str(e["dialogue"]))
		match e["type"]:
			"warp":
				if not FileAccess.file_exists("res://data/maps/%s.json" % e["to_map"]):
					_err(ew, "warp to unknown map '%s'" % str(e["to_map"]))
			"npc":
				_one_of(e, "facing", ew, FACINGS)
				if not e.has("dialogue") and not e.has("trainer"):
					_err(ew, "an NPC needs 'dialogue', 'trainer' or both")
				if e.has("trainer") and not trainers.has(e["trainer"]):
					_err(ew, "unknown trainer '%s'" % str(e["trainer"]))
				if npc_ids.has(e["id"]):
					_err(ew, "duplicate npc id '%s'" % str(e["id"]))
				npc_ids[e["id"]] = true
				if tile.get("collision", true):
					_err(ew, "NPC stands on a solid tile")
				var look: Variant = e.get("look", {})
				if typeof(look) == TYPE_DICTIONARY and look.has("sprite"):
					var sprite_path := "res://assets/sprites/characters/%s.png" % str(look["sprite"])
					if not ResourceLoader.exists(sprite_path):  # not FileAccess: exports repack images, the .png isn't there
						_err(ew, "no character art '%s' (expected %s)" % [str(look["sprite"]), sprite_path])
			"trigger":
				if e.has("w"):
					_int(e, "w", ew, 1, width)
				if e.has("h"):
					_int(e, "h", ew, 1, rows.size())
			"barrier":
				if typeof(e["open_flags"]) != TYPE_ARRAY:
					_err(ew, "'open_flags' must be a list of flags")
			"hidden_item":
				if not items.has(e["item"]):
					_err(ew, "unknown item '%s'" % str(e["item"]))
				_string(e, "flag", ew)


# --- dialogue ----------------------------------------------------------------

## raw = {file name: {dialogue id: [steps]}}. Ids must be unique across all files.
func _validate_dialogue_files(raw: Variant) -> void:
	dialogues = {}
	if typeof(raw) != TYPE_DICTIONARY:
		_err("dialogue", "dialogue files didn't load")
		return
	for file: String in raw:
		var content: Variant = raw[file]
		if typeof(content) != TYPE_DICTIONARY:
			_err("dialogue › " + file, "must be an object of dialogue id -> steps")
			continue
		for id: String in content:
			if dialogues.has(id):
				_err("dialogue › %s › %s" % [file, id], "duplicate dialogue id")
				continue
			dialogues[id] = content[id]
			_validate_steps(content[id], "dialogue › %s › %s" % [file, id])


func _validate_steps(steps: Variant, where: String) -> void:
	if typeof(steps) != TYPE_ARRAY:
		_err(where, "must be a list of steps")
		return
	for i in steps.size():
		var step: Variant = steps[i]
		var sw := "%s[%d]" % [where, i]
		if typeof(step) != TYPE_DICTIONARY:
			_err(sw, "each step must be an object")
			continue
		var kinds := 0
		for key in ["text", "choice", "if_flag", "if_cert", "cmd"]:
			if step.has(key):
				kinds += 1
		if kinds != 1:
			_err(sw, "needs exactly one of text, choice, if_flag, if_cert or cmd")
			continue
		if step.has("text"):
			_string(step, "text", sw)
		elif step.has("choice"):
			_string(step, "choice", sw)
			_validate_steps(step.get("yes", []), sw + " › yes")
			_validate_steps(step.get("no", []), sw + " › no")
		elif step.has("if_flag") or step.has("if_cert"):
			if step.has("if_flag"):
				_string(step, "if_flag", sw)
			elif not certifications.has(step["if_cert"]):
				_err(sw, "unknown certification '%s'" % str(step["if_cert"]))
			_validate_steps(step.get("then", []), sw + " › then")
			_validate_steps(step.get("else", []), sw + " › else")
		else:
			_validate_command(step, sw)


func _validate_command(step: Dictionary, where: String) -> void:
	if not _one_of(step, "cmd", where, DIALOGUE_COMMANDS.keys()):
		return
	for key: String in DIALOGUE_COMMANDS[step["cmd"]]:
		if not step.has(key):
			_err(where, "'%s' needs '%s'" % [step["cmd"], key])
			return
	match step["cmd"]:
		"set_flag":
			_string(step, "flag", where)
			if step.has("value") and typeof(step["value"]) != TYPE_BOOL:
				_err(where, "'value' must be true or false")
		"give_item":
			if not items.has(step["item"]):
				_err(where, "unknown item '%s'" % str(step["item"]))
			if step.has("count"):
				_int(step, "count", where, 1, 99)
		"give_daemon":
			if not species.has(step["species"]):
				_err(where, "unknown species '%s'" % str(step["species"]))
			_int(step, "level", where, 1, 100)
		"start_battle":
			if step.has("trainer"):
				if not trainers.has(step["trainer"]):
					_err(where, "unknown trainer '%s'" % str(step["trainer"]))
			elif step.has("foe"):
				_validate_team(step["foe"], where + " › foe")
			else:
				_err(where, "'start_battle' needs 'trainer' or 'foe'")
			if step.has("ai"):
				_one_of(step, "ai", where, ["random", "basic", "smart"])
		"give_cert":
			if not certifications.has(step["cert"]):
				_err(where, "unknown certification '%s'" % str(step["cert"]))
		"open_shop":
			var stock: Variant = step["stock"]
			if typeof(stock) != TYPE_ARRAY or stock.is_empty():
				_err(where, "'stock' must be a list of item ids")
			else:
				for item_id: Variant in stock:
					if not items.has(item_id):
						_err(where, "unknown item '%s' in stock" % str(item_id))
					elif int(items[item_id].get("price", 0)) <= 0:
						_err(where, "'%s' has no price, so it can't be sold in a shop" % str(item_id))
		"choose_starter":
			var options: Variant = step["options"]
			if typeof(options) != TYPE_ARRAY or options.is_empty():
				_err(where, "'options' must be a list of species")
			else:
				for species_id: Variant in options:
					if not species.has(species_id):
						_err(where, "unknown species '%s'" % str(species_id))
			if step.has("level"):
				_int(step, "level", where, 1, 100)
		"move_player":
			var player_path: Variant = step["path"]
			if typeof(player_path) != TYPE_ARRAY or player_path.is_empty():
				_err(where, "'path' must be a list of directions")
			else:
				for dir: Variant in player_path:
					if not dir in FACINGS:
						_err(where, "unknown direction '%s' in path" % str(dir))
		"move_npc":
			_string(step, "npc", where)
			var path: Variant = step["path"]
			if typeof(path) != TYPE_ARRAY or path.is_empty():
				_err(where, "'path' must be a list like [\"left\", \"left\"]")
			else:
				for dir: Variant in path:
					if not dir in FACINGS:
						_err(where, "unknown direction '%s' in path" % str(dir))


## [[species_id, level], ...]
func _validate_team(team: Variant, where: String) -> void:
	if typeof(team) != TYPE_ARRAY or team.is_empty() or team.size() > 6:
		_err(where, "must be a list of 1 to 6 [species, level] pairs")
		return
	for entry: Variant in team:
		if typeof(entry) != TYPE_ARRAY or entry.size() != 2 or not species.has(entry[0]) or not _is_int(entry[1]) or entry[1] < 1 or entry[1] > 100:
			_err(where, "bad entry %s (want [species_id, level 1-100])" % JSON.stringify(entry))


# --- certifications and trainers ---------------------------------------------

func _validate_certifications(raw: Variant) -> void:
	certifications = _index(raw, "certifications")
	for id: String in certifications:
		var c: Dictionary = certifications[id]
		var where := "certifications › " + id
		_string(c, "name", where)
		_string(c, "department", where)
		_one_of(c, "type", where, types.keys())
		_int(c, "order", where, 1, 99)


## raw = {file name: {trainer id: {...}}}. Ids are unique across files.
func _validate_trainers(raw: Variant) -> void:
	trainers = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return
	for file: String in raw:
		var content: Variant = raw[file]
		if typeof(content) != TYPE_DICTIONARY:
			_err("trainers › " + file, "must be an object of trainer id -> trainer")
			continue
		for id: String in content:
			var where := "trainers › %s › %s" % [file, id]
			if trainers.has(id):
				_err(where, "duplicate trainer id")
				continue
			var t: Variant = content[id]
			if typeof(t) != TYPE_DICTIONARY:
				_err(where, "must be an object")
				continue
			trainers[id] = t
			_string(t, "name", where)
			_validate_team(t.get("team"), where + " › team")
			_one_of(t, "ai", where, ["random", "basic", "smart"])
			_int(t, "prize", where, 0, 999999)
			if t.has("sight"):
				_int(t, "sight", where, 0, 10)
			for key in ["intro", "defeat", "after"]:
				_string(t, key, where)
			if t.has("story") and typeof(t["story"]) != TYPE_BOOL:
				_err(where, "'story' must be true or false")
			if t.has("cert") and not certifications.has(t["cert"]):
				_err(where, "unknown certification '%s'" % str(t["cert"]))


# --- wild encounters ---------------------------------------------------------

## raw = {map id: {"rate": 0..1, "zones": {tile name: [{species, min, max, weight}]}}}
func _validate_encounters(raw: Variant) -> void:
	encounters = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return
	for map_id: String in raw:
		var table: Variant = raw[map_id]
		var where := "encounters › " + map_id
		if typeof(table) != TYPE_DICTIONARY:
			_err(where, "must be an object with 'rate' and 'zones'")
			continue
		encounters[map_id] = table
		if not FileAccess.file_exists("res://data/maps/%s.json" % map_id):
			_err(where, "no map called '%s'" % map_id)
		if not _is_number(table.get("rate")) or float(table["rate"]) <= 0.0 or float(table["rate"]) > 1.0:
			_err(where, "'rate' must be a chance per step above 0 and at most 1")
		var zones: Variant = table.get("zones")
		if typeof(zones) != TYPE_DICTIONARY or zones.is_empty():
			_err(where, "'zones' must map tile names to encounter lists")
			continue
		for tile_name: String in zones:
			var zw := where + " › " + tile_name
			if not tiles.has(tile_name):
				_err(zw, "unknown tile '%s'" % tile_name)
			elif not tiles[tile_name]["behavior"] in ["hot_zone", "water"]:
				_err(zw, "tile '%s' isn't a hot_zone or water tile" % tile_name)
			var slots: Variant = zones[tile_name]
			if typeof(slots) != TYPE_ARRAY or slots.is_empty():
				_err(zw, "must be a non-empty list")
				continue
			for i in slots.size():
				var slot: Variant = slots[i]
				var sw := "%s[%d]" % [zw, i]
				if typeof(slot) != TYPE_DICTIONARY:
					_err(sw, "must be an object")
					continue
				if not species.has(slot.get("species")):
					_err(sw, "unknown species '%s'" % str(slot.get("species")))
				if _int(slot, "min", sw, 1, 100) and _int(slot, "max", sw, 1, 100) and slot["min"] > slot["max"]:
					_err(sw, "'min' can't be above 'max'")
				_int(slot, "weight", sw, 1, 1000)


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

## Optional "fx": the move's battle effect, a list of steps (see scripts/battle/ui/battle_fx.gd).
func _validate_fx(m: Dictionary, where: String) -> void:
	if not m.has("fx"):
		return
	var fx: Variant = m["fx"]
	if typeof(fx) != TYPE_ARRAY:
		_err(where, "'fx' must be a list of steps")
		return
	for i in fx.size():
		var sw := "%s › fx[%d]" % [where, i]
		var step: Variant = fx[i]
		if typeof(step) != TYPE_DICTIONARY:
			_err(sw, "each fx step must be an object like {\"kind\": \"burst\"}")
			continue
		_one_of(step, "kind", sw, BattleFx.KINDS)
		if step.has("glyph") and not String(step["glyph"]) in BattleFx.GLYPHS:
			_err(sw, "unknown glyph '%s' (allowed: %s)" % [str(step["glyph"]), ", ".join(BattleFx.GLYPHS)])
		if step.has("on") and not String(step["on"]) in ["user", "target"]:
			_err(sw, "'on' must be \"user\" or \"target\"")
		if step.has("color"):
			var c := String(step["color"])
			if c != "type" and not Color.html_is_valid(c):
				_err(sw, "'color' must be \"type\" or a hex color like \"#ff8800\", not '%s'" % c)


func _validate_move(m: Dictionary, where: String) -> void:
	_string(m, "name", where)
	_string(m, "description", where)
	_one_of(m, "type", where, types.keys() + ["none"])  # "none" = typeless (Force Quit)
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
	_validate_fx(m, where)
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
