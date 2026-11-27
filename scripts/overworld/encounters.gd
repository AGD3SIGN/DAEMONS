class_name Encounters
extends RefCounted
## Wild encounter rolls. Each zone has a few common Forgelings and rarer extras (slot "rarity").
## Each step on a hot_zone (or water) tile rolls the map's rate
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


## A slot's weight: its "rarity" tier (common / uncommon / rare / very_rare, weights in
## data/balance.json › encounter_rarity) or a raw "weight".
static func slot_weight(slot: Dictionary) -> int:
	if slot.has("rarity"):
		return int(DataRegistry.balance.get("encounter_rarity", {}).get(slot["rarity"], 1))
	return int(slot.get("weight", 1))


## Weighted pick.
static func pick_slot(slots: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0
	for slot: Dictionary in slots:
		total += slot_weight(slot)
	var roll_value := rng.randi_range(1, total)
	for slot: Dictionary in slots:
		roll_value -= slot_weight(slot)
		if roll_value <= 0:
			return slot
	return slots[-1]
