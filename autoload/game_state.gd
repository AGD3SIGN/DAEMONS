extends Node
## Single source of truth for the player's run: Active Stack, Server Rack, bag, flags,
## credits, certifications and CMDB. SaveManager serializes this (Phase 6).

const MAX_STACK := 6
const RACKS := 12
const RACK_SLOTS := 30
const DEFAULT_HELP_DESK := {"map": "help_desk", "x": 6, "y": 7, "facing": "up"}

var player_name: String = ""
var credits: int = 0
var play_time_sec: float = 0.0
var active_stack: Array = []        # up to 6 DaemonInstances
var racks: Array = []               # 12 racks, each a list of up to 30 DaemonInstances (no gaps)
var bag: Dictionary = {}            # item_id -> count
var flags: Dictionary = {}          # story flag -> bool
var certifications: PackedStringArray = []
var cmdb_seen: Dictionary = {}      # species_id -> true
var cmdb_caught: Dictionary = {}    # species_id -> true
var cmdb_found_at: Dictionary = {}  # species_id -> map name where it was first met in the wild
var location: Dictionary = {}       # {"map": id, "x": cell x, "y": cell y, "facing": "down"}
var counters: Dictionary = {}       # story/puzzle numbers (power load, pipeline stage), name -> int; play stats as "stat_<name>"
var tickets: Dictionary = {}        # help desk ticket id -> "open" | "resolved" | "skipped" (see Progress)
var kudos: Dictionary = {}          # Kudos id -> true once unlocked
var visited: Dictionary = {}
var quarantined: Array = []         # corrupted Forgelings you caught, waiting for a Help Desk clean (can't battle)
var cmdb_compromised: Dictionary = {}  # species_id -> true once you've seen a corrupted one
var cmdb_recovered: Dictionary = {}    # species_id -> true once a Help Desk cleaned one of yours
var cmdb_unknown: Dictionary = {}      # species_id -> true after the demo teaser (CMDB "Status: UNKNOWN")        # region-map place id -> true (the phone's Maps app)
var repel_steps: int = 0            # Firewall Rule steps left
var trainer_id: int = 0             # shown on the trainer card; stamped on caught Daemons
var last_help_desk: Dictionary = {} # where you wake up after a black-out
var clock_running: bool = false     # play time only counts during gameplay


func _process(delta: float) -> void:
	if clock_running:
		play_time_sec += delta


func _init() -> void:
	reset()


## Clears everything for a new game.
func reset() -> void:
	player_name = ""
	credits = 0
	play_time_sec = 0.0
	active_stack.clear()
	racks = []
	for i in RACKS:
		racks.append([])
	bag.clear()
	flags.clear()
	certifications.clear()
	cmdb_seen.clear()
	cmdb_caught.clear()
	cmdb_found_at.clear()
	location.clear()
	visited.clear()
	quarantined.clear()
	cmdb_compromised.clear()
	cmdb_recovered.clear()
	cmdb_unknown.clear()
	counters.clear()
	tickets.clear()
	kudos.clear()
	repel_steps = 0
	trainer_id = 0
	last_help_desk = DEFAULT_HELP_DESK.duplicate()
	clock_running = false


# --- Active Stack ------------------------------------------------------------

## Adds a Daemon to the Active Stack, or the Server Rack if the stack is full.
## Returns "stack", "rack" or "full" (everything is full).
## Returns where it went: "stack", "rack", "full", or "quarantined" (a corrupted Forgeling never joins the stack
## or rack; it waits in the Quarantined pocket until a Help Desk cleans it).
func add_daemon(d: DaemonInstance) -> String:
	cmdb_seen[d.species_id] = true
	cmdb_caught[d.species_id] = true
	if d.is_corrupted:
		cmdb_compromised[d.species_id] = true
		quarantined.append(d)
		return "quarantined"
	if active_stack.size() < MAX_STACK:
		active_stack.append(d)
		return "stack"
	return "rack" if rack_add(d) >= 0 else "full"


## Story upgrades (flag / cert triggers): upgrades every Forgeling in the stack and racks that now qualifies.
## Returns [[old name, new name], ...] for the messages. Called after dialogue sets a flag or awards a Cert.
func apply_story_upgrades() -> Array:
	var done := []
	var everyone: Array = active_stack.duplicate()
	for rack: Array in racks:
		everyone.append_array(rack)
	for d: DaemonInstance in everyone:
		if d.is_corrupted:
			continue
		for trigger in ["flag", "cert"]:
			var target := d.check_evolution(trigger)
			if not target.is_empty():
				var old_name := d.display_name()
				d.evolve(target)
				Progress.count("upgrades")
				cmdb_seen[target] = true
				cmdb_caught[target] = true
				done.append([old_name, d.display_name()])
				break
	return done


## GDD: each Certification raises the level cap; EXP stops at the cap until the next Cert (data/level_caps.json).
func level_cap() -> int:
	if DataRegistry.level_caps.is_empty():
		return DaemonInstance.MAX_LEVEL
	return int(DataRegistry.level_caps[mini(certifications.size(), DataRegistry.level_caps.size() - 1)])


## GDD: corruption is a slow reveal. Until the Power Plant event sets this flag, no ERR:: Forgelings spawn and the
## Quarantined pocket, Help Desk cleaning and CMDB COMPROMISED status stay hidden.
func corruption_revealed() -> bool:
	return bool(flags.get("corruption_revealed", false))


## Help Desk scan ("Have you tried turning it off and on again?"): cleans the quarantined Forgeling at `index`
## and adds it like a new catch. Returns where it went ("stack", "rack", "full") or "" if there's nothing there.
func clean_quarantined(index: int) -> String:
	if index < 0 or index >= quarantined.size():
		return ""
	var d: DaemonInstance = quarantined[index]
	quarantined.remove_at(index)
	d.is_corrupted = false
	d.status = ""
	cmdb_recovered[d.species_id] = true
	return add_daemon(d)


func has_usable_daemon() -> bool:
	for d: DaemonInstance in active_stack:
		if not d.is_fainted():
			return true
	return false


## Level of the first Daemon that can fight (Firewall Rules compare against it).
func lead_level() -> int:
	for d: DaemonInstance in active_stack:
		if not d.is_fainted():
			return d.level
	return 0


func swap_stack(a: int, b: int) -> void:
	if a == b or a < 0 or b < 0 or a >= active_stack.size() or b >= active_stack.size():
		return
	var temp: DaemonInstance = active_stack[a]
	active_stack[a] = active_stack[b]
	active_stack[b] = temp


## Credits lost when you black out: percent% of what you carry (data/balance.json), never more than
## cap_base + cap_per_cert for each cert you hold, so a late-game wallet isn't wiped by one bad fight.
func blackout_loss() -> int:
	var rule: Dictionary = DataRegistry.balance.get("loss_penalty", {})
	var by_percent := floori(credits * int(rule.get("percent", 10)) / 100.0)
	var cap := int(rule.get("cap_base", 300)) + int(rule.get("cap_per_cert", 300)) * certifications.size()
	return clampi(by_percent, 0, cap)


func heal_stack() -> void:
	for d: DaemonInstance in active_stack:
		d.heal_full()


# --- Server Rack -------------------------------------------------------------

## Puts a Daemon in the first rack with room (or `rack_index` if given). Returns the rack, or -1.
func rack_add(d: DaemonInstance, rack_index: int = -1) -> int:
	var order: Array = range(RACKS) if rack_index < 0 else [rack_index]
	for i: int in order:
		if racks[i].size() < RACK_SLOTS:
			racks[i].append(d)
			return i
	return -1


func rack_total() -> int:
	var total := 0
	for rack: Array in racks:
		total += rack.size()
	return total


## Stack -> rack. Refuses to leave you without a Daemon that can fight. Returns "" or a reason.
func deposit(stack_index: int, rack_index: int) -> String:
	if stack_index < 0 or stack_index >= active_stack.size():
		return "There's no Forgeling there."
	if racks[rack_index].size() >= RACK_SLOTS:
		return "That rack is full."
	var d: DaemonInstance = active_stack[stack_index]
	var others_can_fight := false
	for i in active_stack.size():
		if i != stack_index and not active_stack[i].is_fainted():
			others_can_fight = true
	if not others_can_fight:
		return "You need at least one Forgeling that can fight."
	active_stack.remove_at(stack_index)
	racks[rack_index].append(d)
	return ""


## Rack -> stack. Returns "" or a reason.
func withdraw(rack_index: int, slot: int) -> String:
	if active_stack.size() >= MAX_STACK:
		return "Your Active Stack is full."
	if slot < 0 or slot >= racks[rack_index].size():
		return "There's no Forgeling there."
	active_stack.append(racks[rack_index][slot])
	racks[rack_index].remove_at(slot)
	return ""


## Rack -> another rack. Returns "" or a reason.
func move_between_racks(from_rack: int, slot: int, to_rack: int) -> String:
	if from_rack == to_rack:
		return "It's already in that rack."
	if racks[to_rack].size() >= RACK_SLOTS:
		return "That rack is full."
	if slot < 0 or slot >= racks[from_rack].size():
		return "There's no Forgeling there."
	racks[to_rack].append(racks[from_rack][slot])
	racks[from_rack].remove_at(slot)
	return ""


# --- saving ------------------------------------------------------------------

## Everything a save file needs. Daemons go through DaemonInstance.to_dict().
func to_dict() -> Dictionary:
	return {
		"player_name": player_name,
		"trainer_id": trainer_id,
		"credits": credits,
		"play_time_sec": play_time_sec,
		"active_stack": active_stack.map(func(d: DaemonInstance) -> Dictionary: return d.to_dict()),
		"racks": racks.map(func(rack: Array) -> Array: return rack.map(func(d: DaemonInstance) -> Dictionary: return d.to_dict())),
		"bag": bag.duplicate(),
		"flags": flags.duplicate(),
		"certifications": Array(certifications),
		"cmdb_seen": cmdb_seen.keys(),
		"cmdb_caught": cmdb_caught.keys(),
		"cmdb_found_at": cmdb_found_at.duplicate(),
		"location": location.duplicate(),
		"visited": visited.keys(),
		"quarantined": quarantined.map(func(d: DaemonInstance) -> Dictionary: return d.to_dict()),
		"cmdb_compromised": cmdb_compromised.keys(),
		"cmdb_recovered": cmdb_recovered.keys(),
		"cmdb_unknown": cmdb_unknown.keys(),
		"counters": counters.duplicate(),
		"tickets": tickets.duplicate(),
		"kudos": kudos.keys(),
		"last_help_desk": last_help_desk.duplicate(),
		"repel_steps": repel_steps,
	}


## Restores from to_dict() output (after a JSON round trip numbers are floats; handled here).
## Daemons whose species no longer exists are dropped.
func from_dict(d: Dictionary) -> void:
	reset()
	player_name = String(d.get("player_name", ""))
	trainer_id = int(d.get("trainer_id", 0))
	credits = int(d.get("credits", 0))
	play_time_sec = float(d.get("play_time_sec", 0.0))
	for entry: Dictionary in d.get("active_stack", []):
		var daemon := DaemonInstance.from_dict(entry)
		if daemon != null and active_stack.size() < MAX_STACK:
			active_stack.append(daemon)
	var saved_racks: Array = d.get("racks", [])
	for i in mini(saved_racks.size(), RACKS):
		for entry: Dictionary in saved_racks[i]:
			var daemon := DaemonInstance.from_dict(entry)
			if daemon != null and racks[i].size() < RACK_SLOTS:
				racks[i].append(daemon)
	for item_id: String in d.get("bag", {}):
		bag[item_id] = int(d["bag"][item_id])
	flags = d.get("flags", {}).duplicate()
	certifications = PackedStringArray(d.get("certifications", []))
	for species_id: String in d.get("cmdb_seen", []):
		cmdb_seen[species_id] = true
	for species_id: String in d.get("cmdb_caught", []):
		cmdb_caught[species_id] = true
	cmdb_found_at = d.get("cmdb_found_at", {}).duplicate()
	location = _cell_dict(d.get("location", {}))
	for entry: Dictionary in d.get("quarantined", []):
		var q := DaemonInstance.from_dict(entry)
		if q != null:
			quarantined.append(q)
	for species_id: String in d.get("cmdb_compromised", []):
		cmdb_compromised[species_id] = true
	for species_id: String in d.get("cmdb_recovered", []):
		cmdb_recovered[species_id] = true
	for species_id: String in d.get("cmdb_unknown", []):
		cmdb_unknown[species_id] = true
	for name: String in d.get("counters", {}):
		counters[name] = int(d["counters"][name])
	for id: String in d.get("tickets", {}):
		tickets[id] = String(d["tickets"][id])
	for id: String in d.get("kudos", []):
		kudos[id] = true
	for place: String in d.get("visited", []):
		visited[place] = true
	if not d.has("visited"):
		_guess_visited()
	if d.has("last_help_desk"):
		last_help_desk = _cell_dict(d["last_help_desk"])
	repel_steps = int(d.get("repel_steps", 0))


## Marks the map's region-map place as visited (called whenever the overworld loads a map).
func visit(map_id: String) -> void:
	var place := DataRegistry.region_of(map_id)
	if not place.is_empty():
		visited[place] = true


## Saves from before the Maps app (2026-11-15) don't list visited places: everything on the road from home to
## where you saved counts, which is the only way to get there.
func _guess_visited() -> void:
	var here := DataRegistry.region_of(String(location.get("map", "")))
	if here.is_empty():
		return
	var links: Array = DataRegistry.region_map.get("links", [])
	var from := {"onboarding_town": ""}
	var queue := ["onboarding_town"]
	while not queue.is_empty():
		var at: String = queue.pop_front()
		for link: Array in links:
			for side in 2:
				if link[side] == at and not from.has(link[1 - side]):
					from[link[1 - side]] = at
					queue.append(link[1 - side])
	var step := here
	while from.has(step):
		visited[step] = true
		step = from[step]
		if step.is_empty():
			break


static func _cell_dict(loc: Dictionary) -> Dictionary:
	if not loc.has("map"):
		return {}
	return {"map": String(loc["map"]), "x": int(loc.get("x", 0)), "y": int(loc.get("y", 0)), "facing": String(loc.get("facing", "down"))}
