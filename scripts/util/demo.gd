class_name Demo
extends RefCounted
## The demo build (GDD §12: Acts 1-2, ending after Cert 2 with the Port City teaser).
## DEMO_BUILD is the export feature "demo_build" (export preset "Web (Demo)"); the project setting
## hexforged/demo_build turns it on in the editor and in tests. In a demo build, seeing the teaser goes straight to
## the "Thanks for playing" screen and the game ends there.

const FEATURE := "demo_build"
const SETTING := "hexforged/demo_build"
const TEASER_SPECIES := "cablesnake"
const TEASER_LEVEL := 16


static func is_demo_build() -> bool:
	return OS.has_feature(FEATURE) or bool(ProjectSettings.get_setting(SETTING, false))


## The scripted one-off at the end of Port City: a glitched Hexforged you can't catch, that flees after 2 turns.
## It is NOT the corruption reveal (that's the Power Plant): it never sets corruption_revealed.
static func teaser_battle_config() -> Dictionary:
	var config := {"foe": [[TEASER_SPECIES, TEASER_LEVEL]], "wild": true, "teaser": true, "zone": "coolant_loop"}
	if is_demo_build():
		config["return_scene"] = DemoEnd.SCENE
	return config
