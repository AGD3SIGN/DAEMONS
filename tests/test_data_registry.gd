extends GutTest
## Phase 1a: data files load cleanly, the type chart matches docs/design.md, and the validator
## catches broken data with readable errors.

var _raw: Dictionary


func before_each() -> void:
	_raw = DataRegistry.read_raw().duplicate(true)


## Validates _raw and returns the error list.
func _validate() -> PackedStringArray:
	return DataValidator.new().validate(_raw)


func _species(id: String) -> Dictionary:
	for s: Dictionary in _raw["species"]:
		if s["id"] == id:
			return s
	return {}


func _move(id: String) -> Dictionary:
	for m: Dictionary in _raw["moves"]:
		if m["id"] == id:
			return m
	return {}


func _assert_error_contains(errors: PackedStringArray, text: String) -> void:
	for e in errors:
		if text in e:
			pass_test("found: " + e)
			return
	fail_test("no error containing '%s'. Got: %s" % [text, errors])


# --- real data ---------------------------------------------------------------

func test_real_data_has_no_errors() -> void:
	var errors := PackedStringArray()
	DataRegistry.read_raw(errors)
	assert_eq(errors.size(), 0, "parse errors: %s" % errors)
	assert_eq(DataRegistry.errors.size(), 0, "data errors: %s" % DataRegistry.errors)


func test_expected_counts() -> void:
	assert_eq(DataRegistry.types.size(), 12)
	assert_eq(DataRegistry.moves.size(), 31, "30 learnable + Force Quit")
	assert_eq(DataRegistry.species.size(), 22)
	assert_eq(DataRegistry.items.size(), 12)


func test_lookups() -> void:
	assert_eq(DataRegistry.get_species("pingo")["name"], "Pingo")
	assert_eq(DataRegistry.get_move("ping")["type"], "network")
	assert_eq(DataRegistry.get_item("root_key")["pocket"], "keys")
	assert_true(DataRegistry.get_species("missingno").is_empty())


func test_starters_share_base_stat_total() -> void:
	for line in [["chipmunk", "munkboard", "mainmunk"], ["pingo", "pengwan", "emperoute"], ["glowbit", "scriptfly", "compilume"]]:
		var totals := []
		for id: String in line:
			var total := 0
			for v: Variant in DataRegistry.get_species(id)["base_stats"].values():
				total += int(v)
			totals.append(total)
		assert_eq(totals, [310, 405, 530], "%s line" % line[0])


# --- type chart (spot checks against docs/design.md) ------------------------

func test_starter_triangle() -> void:
	assert_eq(DataRegistry.type_multiplier("hardware", ["software"]), 2.0)
	assert_eq(DataRegistry.type_multiplier("software", ["network"]), 2.0)
	assert_eq(DataRegistry.type_multiplier("network", ["hardware"]), 2.0)
	assert_eq(DataRegistry.type_multiplier("software", ["hardware"]), 0.5)


func test_security_is_immune_to_malware() -> void:
	assert_eq(DataRegistry.type_multiplier("malware", ["security"]), 0.0)
	assert_eq(DataRegistry.type_multiplier("security", ["malware"]), 2.0)


func test_blank_cells_are_neutral() -> void:
	assert_eq(DataRegistry.type_multiplier("data", ["hardware"]), 1.0)
	assert_eq(DataRegistry.type_multiplier("peripheral", ["malware"]), 1.0)


func test_dual_types_multiply() -> void:
	# Fanbat is Hardware/Power. Network: 2 x 1 = 2. Power: 2 x 0.5 = 1.
	# Peripheral: 1 x 0.5 = 0.5. Legacy: 2 x 1 = 2.
	var fanbat: Array = DataRegistry.get_species("fanbat")["types"]
	assert_eq(DataRegistry.type_multiplier("network", fanbat), 2.0)
	assert_eq(DataRegistry.type_multiplier("power", fanbat), 1.0)
	assert_eq(DataRegistry.type_multiplier("peripheral", fanbat), 0.5)
	assert_eq(DataRegistry.type_multiplier("legacy", fanbat), 2.0)


# --- validator catches broken data ------------------------------------------

func test_unknown_learnset_move() -> void:
	_species("chipmunk")["learnset"][2]["move"] = "heatsnk_slam"
	_assert_error_contains(_validate(), "species › chipmunk › learnset[2]: unknown move 'heatsnk_slam'")


func test_unknown_evolution_target() -> void:
	_species("pingo")["evolutions"][0]["to"] = "routeru"
	_assert_error_contains(_validate(), "species › pingo › evolutions[0]: unknown target species 'routeru'")


func test_evolution_item_must_exist_and_evolve() -> void:
	_species("floppit")["evolutions"][0]["item"] = "coffee"
	_assert_error_contains(_validate(), "item 'coffee' doesn't have the 'evolve' effect")
	_species("floppit")["evolutions"][0]["item"] = "magic_disk"
	_assert_error_contains(_validate(), "unknown item 'magic_disk'")


func test_missing_required_field() -> void:
	_species("dustbunny").erase("catch_rate")
	_assert_error_contains(_validate(), "species › dustbunny: 'catch_rate' must be a whole number")


func test_out_of_range_stat() -> void:
	_species("dustbunny")["base_stats"]["bandwidth"] = 300
	_assert_error_contains(_validate(), "'bandwidth' is 300, must be 1 to 255")


func test_unknown_type_on_move() -> void:
	_move("ping")["type"] = "wifi"
	_assert_error_contains(_validate(), "moves › ping: 'type' is \"wifi\"")


func test_bad_effect_params() -> void:
	_move("infect")["effect"]["params"]["status"] = "sleepy"
	_assert_error_contains(_validate(), "moves › infect › effect: 'status' is \"sleepy\"")
	_move("ping")["effect"] = {"id": "drain", "params": {}}
	_assert_error_contains(_validate(), "moves › ping › effect: 'drain' needs param 'fraction'")


func test_status_move_with_power() -> void:
	_move("overclock")["power"] = 40
	_assert_error_contains(_validate(), "moves › overclock: status moves must have power 0")


func test_duplicate_id() -> void:
	_raw["moves"].append(_move("bump").duplicate(true))
	_assert_error_contains(_validate(), "duplicate id 'bump'")


func test_bad_type_chart_multiplier() -> void:
	_raw["types"]["chart"]["hardware"]["software"] = 3
	_assert_error_contains(_validate(), "types › chart › hardware › software: multiplier must be 0, 0.5 or 2")


func test_missing_file_is_reported() -> void:
	_raw.erase("items")
	_assert_error_contains(_validate(), "items.json is missing or isn't a list")
