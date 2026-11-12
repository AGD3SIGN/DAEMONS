extends GutTest
## Title screen, built to the "DAEMONS Start Screen — Style Guide" (2026-11-11).

const S := preload("res://scripts/ui/title/title_style.gd")
const TITLE := "res://scenes/ui/title_screen.tscn"


func _title() -> Control:
	var title: Control = load(TITLE).instantiate()
	add_child_autofree(title)
	return title


func after_each() -> void:
	Settings.reduced_motion = false
	Settings.crt_effects = true
	SaveManager.delete_saves()


func test_featured_legendary_comes_from_data() -> void:
	var data: Dictionary = DataRegistry.title_screen
	assert_eq(data["tagline"], "CATCH · FUSE · COMPILE")
	var pyrewall: Dictionary = data["featured"][0]
	assert_eq(pyrewall["name"], "PYREWALL")
	assert_eq(pyrewall["fusion"], "Phoenix × Firewall")
	var title := _title()
	var lines: Array = title.card_lines()
	assert_eq(lines[1][3], "PYREWALL")
	assert_string_contains(" ".join(lines.slice(3).map(func(l: Array) -> String: return l[3])), "Guardian of Port 443")


func test_validator_rejects_a_broken_sprite() -> void:
	var v := DataValidator.new()
	var raw := {"title_screen": {"tagline": "x", "prompt": "x", "boot_log": ["x"], "featured": [{
		"id": "x", "label": "x", "name": "x", "fusion": "x", "number": "1", "flavor": "x", "a11y": "x",
		"sprite": {"half": ["oz", "o.................."], "palette": {"o": "#000000"}, "anim": {"o": "spin"}}}]}}
	var errors := v.validate(raw)
	var title_errors := Array(errors).filter(func(e: String) -> bool: return e.begins_with("title_screen"))
	assert_eq(title_errors.size(), 3, "unknown 'z', a row over 16, a bad anim: %s" % [title_errors])


func test_pyrewall_mirrors_without_a_seam() -> void:
	var sprite: Dictionary = DataRegistry.title_screen["featured"][0]["sprite"]
	var rows := TitleHero.mirror_rows(sprite["half"])
	assert_eq(rows.size(), 23)
	for row in rows:
		assert_eq(row.length(), 32)
		assert_eq(row, row.reverse(), "symmetric around the center column")
	var images := TitleHero.build_images(sprite, S.ACCENT_DEFAULT)
	var img: Image = images["image"]
	assert_eq(img.get_size(), Vector2i(32, 23))
	assert_eq(img.get_pixel(14, 6), Color("#e8fbff"), "left eye")
	assert_eq(img.get_pixel(17, 6), Color("#e8fbff"), "right eye (mirrored)")
	assert_eq(img.get_pixel(15, 10), S.ACCENT_DEFAULT, "core follows the accent")
	var kinds: Image = images["kinds"]
	assert_eq(roundi(kinds.get_pixel(14, 6).r8 / 40.0), TitleHero.KINDS["eye"])
	assert_eq(roundi(kinds.get_pixel(0, 1).r8 / 40.0), TitleHero.KINDS["flicker"])
	assert_eq(img.get_pixel(1, 0).a, 0.0, "'.' is transparent")


func test_continue_is_greyed_out_and_skipped_without_a_save() -> void:
	SaveManager.delete_saves()
	var title := _title()
	assert_eq(Array(title.items).slice(0, 3), ["NEW GAME", "CONTINUE", "OPTIONS"])
	assert_eq(title.selected, 0, "NEW GAME selected by default")
	assert_false(title.enabled[1])
	title.move(1)
	assert_eq(title.items[title.selected], "OPTIONS", "skips CONTINUE")
	title.move(-1)
	assert_eq(title.selected, 0)
	title.move(-1)
	assert_eq(title.selected, title.items.size() - 1, "wraps at the start")
	title.move(1)
	assert_eq(title.selected, 0, "wraps at the end")


func test_tap_selects_then_a_second_tap_confirms() -> void:
	var title := _title()
	await wait_process_frames(2)
	title.vertical = true
	var options := Array(title.items).find("OPTIONS")
	var center: Vector2 = title.menu_rects()[options].get_center()
	var at: Vector2 = title._stage.get_global_transform() * center
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	tap.position = at
	title._unhandled_input(tap)
	assert_eq(title.selected, options, "first tap selects")
	assert_false(title.attract, "any input ends the attract state")
	assert_false(title._busy)
	title._unhandled_input(tap)
	assert_true(title._busy, "second tap opens Options")
	title._options.list._done.emit({"action": "cancel", "index": 0})
	await wait_process_frames(1)
	assert_false(title._busy, "back on the title")


func test_touch_copies_of_mouse_events_are_ignored() -> void:
	var title := _title()
	await wait_process_frames(2)
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	click.device = InputEvent.DEVICE_ID_EMULATION
	click.position = title._stage.get_global_transform() * title.menu_rects()[2].get_center()
	title._unhandled_input(click)
	assert_eq(title.selected, 0, "the touch itself is handled, not its emulated click")


func test_logo_glitch_keyframes() -> void:
	var T: GDScript = load("res://scripts/ui/title_screen.gd")
	assert_eq(T.glitch_slice(0.5)["band"], Vector2(0, 1), "idle most of the loop")
	assert_eq(T.glitch_slice(0.89)["offset"], Vector2(-6, 2))
	assert_eq(T.glitch_slice(0.91)["band"], Vector2(0.60, 0.92))
	assert_eq(T.glitch_slice(0.93)["offset"], Vector2(-3, 0))
	assert_eq(T.glitch_slice(0.95)["offset"], Vector2.ZERO)


func test_boot_log_types_one_line_after_the_other() -> void:
	var T: GDScript = load("res://scripts/ui/title_screen.gd")
	var line := "> mounting /dev/daemons … OK"
	assert_eq(T.typed(line, 0, 0.0), "")
	assert_between(T.typed(line, 0, 0.8).length(), 10, 20, "halfway")
	assert_eq(T.typed(line, 0, 1.6), line)
	assert_eq(T.typed("> 22 entities indexed", 1, 1.0), "", "line 2 waits for line 1")
	assert_eq(T.typed("> 22 entities indexed", 1, 3.2), "> 22 entities indexed")
	var title := _title()
	assert_eq(title._boot_lines[1], "> %d entities indexed" % DataRegistry.species.size(), "the real roster count")


func test_reduced_motion_stops_the_big_animations() -> void:
	var title := _title()
	Settings.reduced_motion = true
	var before: float = title._motion
	title._process(0.5)
	assert_eq(title._motion, before, "floor, bob, glitch, traces, bits, rings and arrow stop")
	assert_gt(title._time, 0.4, "PRESS START blink and flame flicker keep going")
	Settings.reduced_motion = false
	title._process(0.5)
	assert_gt(title._motion, before)


func test_crt_toggle_reaches_the_overlay() -> void:
	var title := _title()
	Settings.crt_effects = false
	title._process(0.0)
	assert_false(title._crt_mat.get_shader_parameter("crt"))
	Settings.crt_effects = true
	title._process(0.0)
	assert_true(title._crt_mat.get_shader_parameter("crt"))


func test_layout_matches_the_guide() -> void:
	var title := _title()
	await wait_process_frames(2)
	var card: Rect2 = title.card_rect()
	assert_eq(card.position, Vector2(986, 300), "right 64, top 300")
	assert_eq(card.size.x, 230.0)
	assert_almost_eq(title._logo.position.x + title._logo.width() / 2.0, 640.0, 1.0, "logo centered")
	assert_eq(title._logo.position.y, 54.0)
	assert_eq(title._hero.position, Vector2(440, 232))
	assert_eq(title._hero.ring_center(), Vector2(200, 150), "rings centered on the sprite")
	var sprite: Rect2 = title._hero.sprite_rect()
	assert_eq(sprite.size, Vector2(352, 253), "32x23 at 11 px")
	var rects: Array[Rect2] = title.menu_rects()
	assert_almost_eq(rects[0].position.y, 566.0 + title.prompt_line_h() + 10.0, 0.01, "10 px under PRESS START")
	assert_eq(rects[1].position.x - rects[0].end.x, 28.0, "items 28 px apart")


func test_version_tag_uses_the_build_number() -> void:
	var title := _title()
	assert_eq(title._version_text, "v%s · BUILD %04d" % [ProjectSettings.get_setting("application/config/version"),
		title.build_number()])


func test_options_have_crt_and_less_motion() -> void:
	var saved_path := Settings.path
	Settings.path = "user://test_settings.cfg"
	Settings.crt_effects = false
	Settings.reduced_motion = true
	Settings.save_settings()
	Settings.crt_effects = true
	Settings.reduced_motion = false
	Settings.load_settings()
	assert_false(Settings.crt_effects)
	assert_true(Settings.reduced_motion)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	Settings.path = saved_path


func test_pyrewall_is_a_legendary_daemon() -> void:
	var s := DataRegistry.get_species("pyrewall")
	assert_false(s.is_empty(), "in species.json")
	assert_true(s.get("legendary", false))
	assert_eq(s["types"], ["security", "power"])
	assert_eq(int(s["catch_rate"]), 3, "hard to quarantine")
	var known := []
	for entry: Dictionary in s["learnset"]:
		assert_true(DataRegistry.moves.has(entry["move"]), entry["move"])
		known.append(entry["move"])
	assert_has(known, "burn_rule", "signature move")
	assert_has(known, "ash_reboot", "signature move")
	assert_true(DaemonSprites.has_sheet("pyrewall"), "battle art from the title pixel map")
	var mon := DaemonInstance.create("pyrewall", 50, RandomNumberGenerator.new(), 1)
	assert_eq(mon.species_id, "pyrewall")


func test_title_card_shows_the_cmdb_number() -> void:
	var T: GDScript = load("res://scripts/ui/title_screen.gd")
	var number := "%03d" % (DataRegistry.species.keys().find("pyrewall") + 1)
	assert_eq(T.cmdb_number({"id": "pyrewall"}), number)
	assert_eq(T.cmdb_number({"id": "not_a_species_yet", "number": "000"}), "000", "fallback for a title-only legendary")
	var title := _title()
	assert_string_contains(" ".join(title.card_lines().slice(3).map(func(l: Array) -> String: return l[3])), "No. " + number)
