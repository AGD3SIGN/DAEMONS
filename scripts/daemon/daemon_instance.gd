class_name DaemonInstance
extends RefCounted
## One individual Daemon (caught, wild, or a trainer's): which species it is, how it was built,
## how trained it is, and its current condition. Pure data + rules, no nodes, so the battle sim
## and tests can use it directly. Species/move/profile data is read from DataRegistry.
##
## Methods that change level return a list of event dictionaries for the UI to play back:
##   {"type": "level_up", "level": 7, "stat_gains": {"uptime": 2, ...}}
##   {"type": "move_learned", "move": "heatsink_slam"}
##   {"type": "move_learn_pending", "move": "double_click"}   # 4 moves already; ask the player

const MAX_LEVEL := GrowthRate.MAX_LEVEL
const MAX_MOVES := 4
const MAX_BUILD_QUALITY := 31
const MAX_LOGS_PER_STAT := 252
const MAX_LOGS_TOTAL := 510
const STATS := DataValidator.STATS

var species_id: String = ""
var nickname: String = ""                 # "" = show the species name
var level: int = 1
var total_exp: int = 0                    # total exp earned, not exp into the current level
var current_uptime: int = 0
var status: String = ""                   # "" = healthy, else a status id (e.g. "corrupted")
var status_turns: int = 0                 # Standby: turns left before it wakes
var moves: Array[Dictionary] = []         # up to 4 of {"id": "ping", "pp": 35}
var build_quality: Dictionary = {}        # stat -> 0..31, hidden per-Daemon variance
var experience_logs: Dictionary = {}      # stat -> 0..252, total <= 510
var config_profile: String = "balanced"   # id from data/config_profiles.json
var original_trainer_id: int = 0


## Makes a fresh Daemon at a level: random Build Quality and Config Profile from rng,
## the last 4 moves it would know by that level, full Uptime.
static func create(p_species_id: String, p_level: int, rng: RandomNumberGenerator, p_ot_id: int = 0) -> DaemonInstance:
	var d := DaemonInstance.new()
	d.species_id = p_species_id
	d.level = clampi(p_level, 1, MAX_LEVEL)
	d.total_exp = GrowthRate.exp_for_level(d.growth_rate(), d.level)
	for stat in STATS:
		d.build_quality[stat] = rng.randi_range(0, MAX_BUILD_QUALITY)
		d.experience_logs[stat] = 0
	var profile_ids: Array = DataRegistry.config_profiles.keys()
	profile_ids.sort()  # independent of file order
	d.config_profile = profile_ids[rng.randi_range(0, profile_ids.size() - 1)]
	d.original_trainer_id = p_ot_id
	for move_id in d.default_moves():
		d.moves.append({"id": move_id, "pp": _max_pp(move_id)})
	d.current_uptime = d.max_uptime()
	return d


# --- identity ----------------------------------------------------------------

func species_data() -> Dictionary:
	return DataRegistry.get_species(species_id)


func display_name() -> String:
	return nickname if not nickname.is_empty() else String(species_data().get("name", species_id))


func growth_rate() -> String:
	return species_data().get("growth_rate", "medium_fast")


func types() -> Array:
	return species_data().get("types", [])


# --- stats -------------------------------------------------------------------

## Uptime = floor((2*Base + BQ + Logs/4) * L / 100) + L + 10
## Others = floor((floor((2*Base + BQ + Logs/4) * L / 100) + 5) * profile)   profile = 1.1 / 1.0 / 0.9
@warning_ignore("integer_division")
func get_stat(stat: String) -> int:
	var base := int(species_data()["base_stats"][stat])
	var core := (2 * base + int(build_quality.get(stat, 0)) + int(experience_logs.get(stat, 0)) / 4) * level / 100
	if stat == "uptime":
		return core + level + 10
	return (core + 5) * profile_percent(stat) / 100


## 110 if the Config Profile boosts this stat, 90 if it lowers it, else 100.
func profile_percent(stat: String) -> int:
	var profile: Dictionary = DataRegistry.config_profiles.get(config_profile, {})
	if profile.get("up") == stat:
		return 110
	if profile.get("down") == stat:
		return 90
	return 100


func max_uptime() -> int:
	return get_stat("uptime")


func stats() -> Dictionary:
	var out := {}
	for stat in STATS:
		out[stat] = get_stat(stat)
	return out


func is_fainted() -> bool:
	return current_uptime <= 0


## Help Desk: full Uptime, no status, full PP.
func heal_full() -> void:
	current_uptime = max_uptime()
	status = ""
	status_turns = 0
	for slot in moves:
		slot["pp"] = _max_pp(slot["id"])


# --- exp & levels ------------------------------------------------------------

func exp_to_next_level() -> int:
	if level >= MAX_LEVEL:
		return 0
	return GrowthRate.exp_for_level(growth_rate(), level + 1) - total_exp


## Adds exp, levelling up as many times as it earns. Returns events (see top of file).
func gain_exp(amount: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if level >= MAX_LEVEL or amount <= 0:
		return events
	var rate := growth_rate()
	total_exp = mini(total_exp + amount, GrowthRate.exp_for_level(rate, MAX_LEVEL))
	while level < MAX_LEVEL and total_exp >= GrowthRate.exp_for_level(rate, level + 1):
		events.append_array(_level_up_once())
	return events


## Overclock Chip: exactly one level.
func level_up() -> Array[Dictionary]:
	return gain_exp(exp_to_next_level())


func _level_up_once() -> Array[Dictionary]:
	var before := stats()
	level += 1
	var after := stats()
	var gains := {}
	for stat in STATS:
		gains[stat] = after[stat] - before[stat]
	if not is_fainted():
		current_uptime = mini(current_uptime + gains["uptime"], after["uptime"])
	var events: Array[Dictionary] = [{"type": "level_up", "level": level, "stat_gains": gains}]
	for move_id in moves_learned_at(level):
		var learn := _try_learn(move_id)
		if not learn.is_empty():
			events.append(learn)
	return events


## Experience Logs from a defeated foe's log_yield. Caps: 252 per stat, 510 total.
func add_experience_logs(log_yield: Dictionary) -> void:
	for stat: String in log_yield:
		if not stat in STATS:
			continue
		var total := 0
		for v: Variant in experience_logs.values():
			total += int(v)
		var current := int(experience_logs.get(stat, 0))
		var add := mini(int(log_yield[stat]), mini(MAX_LOGS_PER_STAT - current, MAX_LOGS_TOTAL - total))
		if add > 0:
			experience_logs[stat] = current + add


# --- moves -------------------------------------------------------------------

func knows_move(move_id: String) -> bool:
	for slot in moves:
		if slot["id"] == move_id:
			return true
	return false


func moves_learned_at(at_level: int) -> PackedStringArray:
	var out := PackedStringArray()
	for entry: Dictionary in species_data().get("learnset", []):
		if int(entry["level"]) == at_level:
			out.append(entry["move"])
	return out


## The last 4 distinct moves learnable at or below the current level, in learn order.
func default_moves() -> PackedStringArray:
	var known := PackedStringArray()
	for entry: Dictionary in species_data().get("learnset", []):
		if int(entry["level"]) <= level and not entry["move"] in known:
			known.append(entry["move"])
	return known.slice(maxi(0, known.size() - MAX_MOVES))


## Teaches a move. slot -1 = add to an empty slot; 0..3 = replace that slot.
## Returns false if the move is unknown, already known, or there's no room.
func learn_move(move_id: String, slot: int = -1) -> bool:
	if DataRegistry.get_move(move_id).is_empty() or knows_move(move_id):
		return false
	var entry := {"id": move_id, "pp": _max_pp(move_id)}
	if slot == -1:
		if moves.size() >= MAX_MOVES:
			return false
		moves.append(entry)
		return true
	if slot < 0 or slot >= moves.size():
		return false
	moves[slot] = entry
	return true


func _try_learn(move_id: String) -> Dictionary:
	if knows_move(move_id):
		return {}
	if learn_move(move_id):
		return {"type": "move_learned", "move": move_id}
	return {"type": "move_learn_pending", "move": move_id}


static func _max_pp(move_id: String) -> int:
	return int(DataRegistry.get_move(move_id).get("max_pp", 0))


# --- upgrading (evolution) ---------------------------------------------------

## Returns the species this Daemon would upgrade into for a trigger, or "" if none.
## trigger: "level" (after battle), "item" (pass item_id), "sync".
func check_evolution(trigger: String, item_id: String = "") -> String:
	for evo: Dictionary in species_data().get("evolutions", []):
		if evo["trigger"] != trigger:
			continue
		match trigger:
			"level":
				if level >= int(evo["level"]):
					return evo["to"]
			"item":
				if evo["item"] == item_id:
					return evo["to"]
			"sync":
				return evo["to"]
	return ""


## Switches species. Damage taken carries over (a Daemon missing 10 Uptime is still missing 10).
func evolve(target_species: String) -> void:
	var old_max := max_uptime()
	species_id = target_species
	var new_max := max_uptime()
	if not is_fainted():
		current_uptime = clampi(current_uptime + new_max - old_max, 1, new_max)


# --- saving ------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"species": species_id,
		"nickname": nickname,
		"level": level,
		"exp": total_exp,
		"uptime": current_uptime,
		"status": status,
		"status_turns": status_turns,
		"moves": moves.duplicate(true),
		"build_quality": build_quality.duplicate(),
		"experience_logs": experience_logs.duplicate(),
		"config_profile": config_profile,
		"ot_id": original_trainer_id,
	}


## Rebuilds from to_dict() output (also after a JSON round trip, where numbers become floats).
## Returns null if the species no longer exists in the data.
static func from_dict(d: Dictionary) -> DaemonInstance:
	var species_id_value := String(d.get("species", ""))
	if DataRegistry.get_species(species_id_value).is_empty():
		return null
	var out := DaemonInstance.new()
	out.species_id = species_id_value
	out.nickname = String(d.get("nickname", ""))
	out.level = clampi(int(d.get("level", 1)), 1, MAX_LEVEL)
	out.total_exp = maxi(int(d.get("exp", 0)), GrowthRate.exp_for_level(out.growth_rate(), out.level))
	out.status = String(d.get("status", ""))
	out.status_turns = maxi(0, int(d.get("status_turns", 0)))
	var saved_bq: Dictionary = d.get("build_quality", {})
	var saved_logs: Dictionary = d.get("experience_logs", {})
	for stat in STATS:
		out.build_quality[stat] = clampi(int(saved_bq.get(stat, 0)), 0, MAX_BUILD_QUALITY)
		out.experience_logs[stat] = clampi(int(saved_logs.get(stat, 0)), 0, MAX_LOGS_PER_STAT)
	var profile := String(d.get("config_profile", "balanced"))
	out.config_profile = profile if DataRegistry.config_profiles.has(profile) else "balanced"
	out.original_trainer_id = int(d.get("ot_id", 0))
	for slot: Dictionary in d.get("moves", []):
		var move_id := String(slot.get("id", ""))
		if not DataRegistry.get_move(move_id).is_empty() and out.moves.size() < MAX_MOVES:
			out.moves.append({"id": move_id, "pp": clampi(int(slot.get("pp", 0)), 0, _max_pp(move_id))})
	out.current_uptime = clampi(int(d.get("uptime", 0)), 0, out.max_uptime())
	return out
