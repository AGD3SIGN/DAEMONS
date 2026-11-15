extends GutTest
## GDD demo roster: Nos. 001-025 are demo: true; Pyrewall (000), Hallucinaut (026), Uptimus (027) and the expansion
## creatures are false. Acts 1-2 encounter tables may only use demo species, plus pending candidates (Brandon decides).


func test_demo_flags_follow_the_gdd() -> void:
	for id: String in DataRegistry.species:
		var n := DataRegistry.cmdb_number(id)
		var expected := n >= 1 and n <= 25
		assert_eq(bool(DataRegistry.species[id]["demo"]), expected, "%s (#%03d)" % [id, n])
	assert_false(DataRegistry.species["pyrewall"]["demo"])


func test_act_1_2_tables_use_only_demo_species_or_pending_candidates() -> void:
	assert_true(DataRegistry.errors.is_empty(), "data loads: %s" % [DataRegistry.errors])
	var pending := {}
	for c: Dictionary in DataRegistry.demo_roster["pending_candidates"]:
		pending[c["species"]] = true
	for area: String in DataRegistry.demo_roster["act_1_2_areas"]:
		for zone: Array in DataRegistry.encounters.get(area, {}).get("zones", {}).values():
			for slot: Dictionary in zone:
				var id: String = slot["species"]
				assert_true(DataRegistry.species[id]["demo"] or pending.has(id), "%s in %s" % [id, area])


func test_validation_catches_a_non_demo_species() -> void:
	var raw := DataRegistry.read_raw(PackedStringArray())
	raw["encounters"]["route_1"]["zones"]["cable_tangle"].append({"species": "orcable", "min": 3, "max": 4, "weight": 5})
	raw["demo_roster"]["pending_candidates"] = raw["demo_roster"]["pending_candidates"].filter(
		func(c: Dictionary) -> bool: return c["species"] != "antsistor")
	var errors := "\n".join(DataValidator.new().validate(raw))
	assert_string_contains(errors, "'orcable' isn't in the demo roster")
	assert_string_contains(errors, "'antsistor' isn't in the demo roster", "approving or rejecting takes it off the pending list")
