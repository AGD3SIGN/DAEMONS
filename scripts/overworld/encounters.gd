class_name Encounters
extends RefCounted
## Wild encounter rolls. Each step on a hot_zone (or water) tile rolls the map's rate
## (data/encounters/<map>.json); a hit picks a slot by weight and a level in its range.
## A Firewall Rule (repel) blocks anything below the lead Daemon's level.


## Returns {"species": id, "level": n, "corrupted": bool} or {} for no encounter. A slot's "corrupted_chance"
## (0..1, default 0) is rolled only for species that can be corrupted (never Malware lines), and only once the story
## has revealed corruption (GameState.corruption_revealed(), set at the Power Plant).
## rate_override >= 0 replaces the table's rate.
static func roll(map_id: String, tile_name: String, rng: RandomNumberGenerator, lead_level: int, repel_active: bool, rate_override: float = -1.0) -> Dictionary:
	var table: Dictionary = DataRegistry.encounters.get(map_id, {})
	var slots: Array = table.get("zones", {}).get(tile_name, [])
	if slots.is_empty():
		return {}
	var rate := rate_override if rate_override >= 0.0 else float(table["rate"])
	if rng.randf() >= rate:
		return {}
	var slot := pick_slot(slots, rng)
	var level := rng.randi_range(int(slot["min"]), int(slot["max"]))
	if repel_active and level < lead_level:
		return {}
	var chance := float(slot.get("corrupted_chance", 0.0))
	var corrupted := chance > 0.0 and GameState.corruption_revealed() and DaemonInstance.can_be_corrupted(slot["species"]) \
		and rng.randf() < chance
	return {"species": slot["species"], "level": level, "corrupted": corrupted}


## Weighted pick.
static func pick_slot(slots: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0
	for slot: Dictionary in slots:
		total += int(slot["weight"])
	var roll_value := rng.randi_range(1, total)
	for slot: Dictionary in slots:
		roll_value -= int(slot["weight"])
		if roll_value <= 0:
			return slot
	return slots[-1]
