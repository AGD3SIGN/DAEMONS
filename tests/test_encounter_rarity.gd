extends GutTest
## Zone rarity (2026-11-26): each zone has a couple of common Forgelings and rarer extras, so the early game
## doesn't hand out the whole roster. Slots use a "rarity" tier; weights live in data/balance.json.

const EARLY := ["onboarding_town", "route_1", "route_2", "wifi_dead_zone", "port_city"]


func _slots(area: String) -> Array:
	var out := []
	for zone: Array in DataRegistry.encounters.get(area, {}).get("zones", {}).values():
		out.append_array(zone)
	return out


func _upgraded_forms() -> Dictionary:
	var out := {}
	for id: String in DataRegistry.species:
		for evo: Dictionary in DataRegistry.species[id].get("evolutions", []):
			out[evo["to"]] = true
	return out


func test_every_slot_uses_a_rarity_tier() -> void:
	for area: String in DataRegistry.encounters:
		for slot: Dictionary in _slots(area):
			assert_true(String(slot.get("rarity", "")) in DataValidator.RARITY_TIERS, "%s in %s" % [slot["species"], area])


func test_tiers_get_rarer() -> void:
	var w: Dictionary = DataRegistry.balance["encounter_rarity"]
	assert_gt(int(w["common"]), int(w["uncommon"]))
	assert_gt(int(w["uncommon"]), int(w["rare"]))
	assert_gt(int(w["rare"]), int(w["very_rare"]))


func test_early_zones_stay_small() -> void:
	for area: String in EARLY:
		var commons := 0
		for slot: Dictionary in _slots(area):
			if slot["rarity"] == "common":
				commons += 1
		assert_between(commons, 1, 2, "%s: one or two common Forgelings" % area)
	assert_lte(_slots("onboarding_town").size(), 2)
	assert_lte(_slots("route_1").size(), 6, "Route 1 is the first real route; keep it to a handful")


func test_no_upgraded_forms_in_the_wild_during_acts_1_2() -> void:
	var upgraded := _upgraded_forms()
	for area: String in EARLY:
		for slot: Dictionary in _slots(area):
			assert_false(upgraded.has(slot["species"]), "%s in %s" % [slot["species"], area])


func test_wild_upgraded_forms_are_rare_and_above_their_upgrade_level() -> void:
	var level_of := {}
	for id: String in DataRegistry.species:
		for evo: Dictionary in DataRegistry.species[id].get("evolutions", []):
			if evo.get("trigger") == "level":
				level_of[evo["to"]] = int(evo["level"])
	for id: String in ["serverllama", "bufferfish", "monarchive", "migratern", "beavbyte", "pangolock", "hoarddrive",
			"quarantis", "keyberman"]:
		for area: String in DataRegistry.encounters:
			for slot: Dictionary in _slots(area):
				if slot["species"] == id:
					assert_eq(slot["rarity"], "very_rare", "%s in %s" % [id, area])
					assert_gte(int(slot["min"]), level_of[id], "%s in %s" % [id, area])


func test_every_new_forgeling_can_be_found_in_the_wild() -> void:
	var wild := {}
	for area: String in DataRegistry.encounters:
		for slot: Dictionary in _slots(area):
			wild[slot["species"]] = true
	for id: String in ["fogfrog", "saasgull", "llambda", "serverllama", "pufflet", "bufferfish", "synclet", "monarchive",
			"ternlet", "migratern"]:
		assert_true(wild.has(id), id)


func test_a_rare_slot_rolls_far_less_than_a_common_one() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen := {}
	for i in 4000:
		var hit := Encounters.roll("route_1", "cable_tangle", rng, 1, false, 1.0)
		seen[hit["species"]] = int(seen.get(hit["species"], 0)) + 1
	assert_gt(int(seen.get("dustbunny", 0)), int(seen.get("floppit", 0)) * 5, "common vs rare: %s" % [seen])


func test_validator_catches_an_unknown_rarity() -> void:
	var raw := DataRegistry.read_raw(PackedStringArray())
	raw["encounters"]["route_1"]["zones"]["cable_tangle"][0]["rarity"] = "legendary"
	var errors := "\n".join(DataValidator.new().validate(raw))
	assert_string_contains(errors, "'rarity' must be one of")


## Nos. 062-079 (2026-11-26): every new Forgeling except Authound (a stage 3 that only comes from upgrading) is in the
## wild, and only after the demo zones.
func test_second_batch_lives_in_the_wild_after_the_demo() -> void:
	var wild := {}
	for area: String in DataRegistry.encounters:
		for slot: Dictionary in _slots(area):
			wild[slot["species"]] = area
	for id: String in ["badgerpot", "bowersort", "cellhog", "doublesting", "logster", "mantarray", "meerstat", "beavbit",
			"beavbyte", "lockling", "pangolock", "nutcache", "hoarddrive", "nymphscan", "quarantis", "pupkey", "keyberman"]:
		assert_true(wild.has(id), id)
		for area: String in EARLY:
			for slot: Dictionary in _slots(area):
				assert_ne(slot["species"], id, "%s in %s" % [id, area])
	assert_false(wild.has("authound"), "Authound only comes from upgrading Keyberman")
