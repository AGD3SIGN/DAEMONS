extends GutTest
## GDD: upgrades come from items and events, not only levels. Species "evolutions" triggers: level, item (firmware /
## patches), flag (a story event), cert (Certifications held). Existing species keep their triggers.


func before_each() -> void:
	GameState.reset()


func after_each() -> void:
	GameState.reset()


func _d(species: String, lvl: int) -> DaemonInstance:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	return DaemonInstance.create(species, lvl, rng, 1)


## Temporarily give a species a different trigger (restored after).
func _with_trigger(species_id: String, evo: Dictionary, body: Callable) -> void:
	var sp := DataRegistry.get_species(species_id)
	var saved: Array = sp["evolutions"].duplicate(true)
	sp["evolutions"] = [evo]
	await body.call()
	sp["evolutions"] = saved


func test_level_and_item_triggers_still_work() -> void:
	assert_eq(_d("chipmunk", 16).check_evolution("level"), "munkboard")
	assert_eq(_d("chipmunk", 10).check_evolution("level"), "")
	assert_eq(_d("floppit", 10).check_evolution("item", "legacy_driver"), "ziphare")
	assert_eq(_d("floppit", 10).check_evolution("item", "coffee"), "")


func test_flag_trigger() -> void:
	await _with_trigger("cablesnake", {"to": "patchviper", "trigger": "flag", "flag": "port443_flicker"}, func() -> void:
		var d := _d("cablesnake", 10)
		assert_eq(d.check_evolution("flag", "", {"flags": {}}), "")
		assert_eq(d.check_evolution("flag", "", {"flags": {"port443_flicker": true}}), "patchviper")
		GameState.add_daemon(d)
		GameState.flags["port443_flicker"] = true
		var done := GameState.apply_story_upgrades()
		assert_eq(done, [["Cablesnake", "Patchviper"]])
		assert_eq(d.species_id, "patchviper"))


func test_cert_trigger() -> void:
	await _with_trigger("pingo", {"to": "pengwan", "trigger": "cert", "certs": 2}, func() -> void:
		var d := _d("pingo", 8)
		GameState.add_daemon(d)
		GameState.certifications.append("desktop_support")
		assert_true(GameState.apply_story_upgrades().is_empty(), "1 Cert isn't enough")
		GameState.certifications.append("networking")
		GameState.apply_story_upgrades()
		assert_eq(d.species_id, "pengwan", "2 Certs: upgraded"))


func test_validator_knows_the_new_triggers() -> void:
	var raw := DataRegistry.read_raw(PackedStringArray())
	for s: Dictionary in raw["species"]:
		if s["id"] == "pingo":
			s["evolutions"] = [{"to": "pengwan", "trigger": "cert", "certs": 12}]
		if s["id"] == "cablesnake":
			s["evolutions"] = [{"to": "patchviper", "trigger": "flag"}]
	var errors := "\n".join(DataValidator.new().validate(raw))
	assert_string_contains(errors, "'certs' is 12")
	assert_string_contains(errors, "'flag' must be non-empty text")
