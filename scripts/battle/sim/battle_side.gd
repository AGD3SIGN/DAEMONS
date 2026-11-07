class_name BattleSide
extends RefCounted
## One side of a battle: its Active Stack, which Daemon is out, its items, and the temporary
## battle-only state of the active Daemon (stat stages, volatile effects) that resets on switch.

var name: String = ""
var stack: Array[DaemonInstance] = []
var active_index: int = -1
var items: Dictionary = {}      # item_id -> count. The caller copies it back to the bag after battle.
var stages: Dictionary = {}     # stat -> -6..6 (DataValidator.STAGE_STATS)
var volatile: Dictionary = {}   # e.g. {"looping_turns": 2}; cleared on switch
var voluntary_switches: int = 0 # switches chosen as an action (not after a crash); the AI caps these


func _init(p_name: String, p_stack: Array[DaemonInstance], p_items: Dictionary = {}) -> void:
	name = p_name
	stack = p_stack
	items = p_items
	active_index = first_usable_index()
	reset_volatile()


func active() -> DaemonInstance:
	return stack[active_index] if active_index >= 0 else null


func first_usable_index() -> int:
	for i in stack.size():
		if not stack[i].is_fainted():
			return i
	return -1


func has_usable() -> bool:
	return first_usable_index() >= 0


func reset_volatile() -> void:
	stages = {}
	for stat in DataValidator.STAGE_STATS:
		stages[stat] = 0
	volatile = {}
