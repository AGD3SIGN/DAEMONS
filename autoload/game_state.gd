extends Node
## Single source of truth for the player's run: Active Stack, Server Rack, bag, flags,
## credits, certifications and CMDB. SaveManager serializes this. Filled in from Phase 5 on.

var player_name: String = ""
var credits: int = 0
var play_time_sec: float = 0.0
var active_stack: Array = []        # up to 6 DaemonInstances (Phase 1b)
var server_rack: Array = []         # 12 racks x 30 slots (Phase 5)
var bag: Dictionary = {}            # item_id -> count
var flags: Dictionary = {}          # story flag -> bool
var certifications: PackedStringArray = []
var cmdb_seen: Dictionary = {}      # species_id -> true
var cmdb_caught: Dictionary = {}    # species_id -> true
var location: Dictionary = {}       # {"map": id, "x": cell x, "y": cell y}


const MAX_STACK := 6


## Adds a Daemon to the Active Stack, or the Server Rack if the stack is full.
## Returns "stack" or "rack".
func add_daemon(d: DaemonInstance) -> String:
	cmdb_seen[d.species_id] = true
	cmdb_caught[d.species_id] = true
	if active_stack.size() < MAX_STACK:
		active_stack.append(d)
		return "stack"
	server_rack.append(d)
	return "rack"


## Clears everything for a new game.
func reset() -> void:
	player_name = ""
	credits = 0
	play_time_sec = 0.0
	active_stack.clear()
	server_rack.clear()
	bag.clear()
	flags.clear()
	certifications.clear()
	cmdb_seen.clear()
	cmdb_caught.clear()
	location.clear()
