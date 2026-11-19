extends GutTest
## Your phone (2026-11-15): the menu button opens it, the map button opens Maps directly, Maps knows where you
## are and where you've been, and every map in the game belongs to one place on the valley map.

var world: Overworld


func before_each() -> void:
	GameState.reset()
	GameState.flags["got_starter"] = true


func after_each() -> void:
	SceneRouter.params = {}
	GameState.reset()


func _open(map_id: String) -> void:
	GameState.location = {"map": map_id, "x": 5, "y": 5, "facing": "down"}
	SceneRouter.params = {"map": map_id, "spawn": "default"}
	world = load(Overworld.SCENE).instantiate()
	world.allow_scene_change = false
	world.auto_advance_text = true
	add_child_autofree(world)
	world.set_time_scale(0.0)
	await wait_process_frames(3)


func _press(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await wait_process_frames(2)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await wait_process_frames(2)


func test_every_map_belongs_to_one_place_on_the_valley_map() -> void:
	assert_true(DataRegistry.errors.is_empty(), "data loads: %s" % [DataRegistry.errors])
	for map_id in DataRegistry.map_ids():
		assert_ne(DataRegistry.region_of(map_id), "", "%s is on the valley map" % map_id)
	assert_eq(DataRegistry.region_of("department_1"), "patch_town")
	assert_eq(DataRegistry.region_of("player_house"), "onboarding_town")


func test_region_map_validation_catches_mistakes() -> void:
	var raw := DataRegistry.read_raw(PackedStringArray())
	raw["region_map"] = {"locations": [
		{"id": "a", "name": "A", "kind": "town", "x": 10, "y": 10, "maps": ["route_1"], "blurb": "x"},
		{"id": "b", "name": "B", "kind": "castle", "x": 900, "y": 10, "maps": ["route_1"], "blurb": "x"}],
		"links": [["a", "nowhere"]]}
	var errors := DataValidator.new().validate(raw)
	var text := "\n".join(errors)
	assert_string_contains(text, "kind")
	assert_string_contains(text, "'x' is 900")
	assert_string_contains(text, "already belongs to 'a'")
	assert_string_contains(text, "links")


func test_walking_into_a_map_marks_its_place_visited_and_saves_it() -> void:
	await _open("department_1")
	assert_true(GameState.visited.has("patch_town"), "an indoor map counts for its town")
	var restored := GameState.to_dict()
	GameState.reset()
	GameState.from_dict(JSON.parse_string(JSON.stringify(restored)))
	assert_true(GameState.visited.has("patch_town"), "survives a save round trip")


func test_old_saves_count_the_road_from_home_as_visited() -> void:
	GameState.from_dict({"location": {"map": "port_city", "x": 1, "y": 1, "facing": "down"}})
	for place in ["onboarding_town", "route_1", "patch_town", "route_2", "wifi_dead_zone", "port_city"]:
		assert_true(GameState.visited.has(place), place)
	assert_false(GameState.visited.has("the_basement"), "nothing past where you saved")


func test_places_are_known_rumored_or_hidden() -> void:
	GameState.location = {"map": "patch_town", "x": 1, "y": 1}
	GameState.visited = {"onboarding_town": true, "route_1": true, "patch_town": true}
	assert_eq(Phone.place_state(Phone.place("patch_town")), "known")
	assert_eq(Phone.place_state(Phone.place("route_2")), "rumored", "next to somewhere you've been: ???")
	assert_eq(Phone.place_state(Phone.place("wifi_dead_zone")), "hidden")
	assert_eq(Phone.place_state(Phone.place("hq_tower")), "hidden", "HQ Tower waits for Kalb's trace")
	GameState.flags["hq_traced"] = true
	assert_eq(Phone.place_state(Phone.place("hq_tower")), "known")


func test_maps_cursor_starts_here_and_moves_between_shown_places() -> void:
	GameState.location = {"map": "route_1", "x": 1, "y": 1}
	GameState.visited = {"onboarding_town": true, "route_1": true}
	var phone := Phone.new()
	add_child_autofree(phone)
	phone.map_cursor = Phone.here()
	assert_eq(phone.map_cursor, "route_1")
	assert_string_contains(phone.cursor_info()[0], "YOU ARE HERE")
	phone.move_map_cursor(Vector2.UP)
	assert_eq(phone.map_cursor, "patch_town", "Route 1 leads to Patch Town (GDD order)")
	assert_eq(phone.cursor_info()[0], "???", "not visited yet")
	phone.move_map_cursor(Vector2.UP)
	assert_eq(phone.map_cursor, "patch_town", "nothing shown further up")
	phone.move_map_cursor(Vector2.DOWN)
	phone.move_map_cursor(Vector2.DOWN)
	assert_eq(phone.map_cursor, "onboarding_town")


func test_menu_button_opens_the_phone_and_map_button_opens_maps() -> void:
	await _open("route_1")
	var phone: Phone = world.field_menus.phone
	await _press("map")
	await wait_until(func() -> bool: return phone.mode == "maps", 5.0)
	assert_eq(phone.mode, "maps", "the map button goes straight to Maps")
	assert_eq(phone.map_cursor, "route_1")
	await _press("ui_cancel")
	await wait_until(func() -> bool: return world.is_idle(), 5.0)
	SaveManager.delete_saves()
	SaveManager.slot_paths = SaveManager.SLOT_PATHS
	assert_false(phone.visible, "closing Maps from the map button puts the phone away")
	await _press("menu")
	await wait_until(func() -> bool: return phone.mode == "home", 5.0)
	assert_eq(phone.mode, "home")
	assert_eq(phone.apps[phone.selected][0], "MAP", "Maps is the first app")
	await _press("ui_accept")
	await wait_until(func() -> bool: return phone.mode == "maps", 5.0)
	await _press("ui_cancel")
	await wait_until(func() -> bool: return phone.mode == "home", 5.0)
	assert_eq(phone.mode, "home", "from the home screen, closing Maps goes back home")
	await _press("ui_cancel")
	await wait_until(func() -> bool: return world.is_idle(), 5.0)
	SaveManager.delete_saves()
	SaveManager.slot_paths = SaveManager.SLOT_PATHS
	assert_false(phone.visible)


func test_phone_lists_every_old_menu_entry() -> void:
	var ids := Phone.new().app_ids()
	for app in ["MAP", "CMDB", "STACK", "BAG", "CARD", "SAVE", "CONTROLS", "OPTIONS", "FEEDBACK"]:
		assert_has(ids, app)


func test_yes_no_box_is_on_screen_and_answers() -> void:
	await _open("route_1")
	var answer := [null]
	var run := func() -> void: answer[0] = await world.ask("Save your progress?")
	run.call()
	await wait_process_frames(2)
	var box: MenuList = world.field_menus.yes_no
	assert_true(box.is_choosing(), "YES / NO is showing")
	assert_true(get_viewport().get_visible_rect().encloses(box.get_global_rect()), "and on screen: %s" % box.get_global_rect())
	await _press("ui_down")    # YES -> NO
	await _press("ui_accept")
	await wait_until(func() -> bool: return answer[0] != null, 5.0)
	assert_eq(answer[0], false)


func test_saved_message_doesnt_linger_over_the_next_app() -> void:
	SaveManager.slot_paths = PackedStringArray(["user://test_phone_save_a.json", "user://test_phone_save_b.json"])
	await _open("route_1")
	var phone: Phone = world.field_menus.phone
	await _press("menu")
	await wait_until(func() -> bool: return phone.mode == "home", 5.0)
	phone.selected = phone.app_ids().find("SAVE")
	await _press("ui_accept")
	await wait_until(func() -> bool: return world.field_menus.yes_no.is_choosing(), 5.0)
	await _press("ui_accept")  # YES
	await wait_until(func() -> bool: return phone.mode == "home", 10.0)
	assert_eq(phone.mode, "home", "back on the phone after saving")
	assert_false(world.text_box.visible, "the Saved. message is gone")
	await _press("ui_cancel")
	await wait_until(func() -> bool: return world.is_idle(), 5.0)
	SaveManager.delete_saves()
	SaveManager.slot_paths = SaveManager.SLOT_PATHS


## Upright phones (2026-11-18): the home screen grows to fill a tall view, and taps still hit the right app.
func test_home_screen_grows_on_tall_views_and_taps_still_land() -> void:
	var holder := Control.new()
	holder.size = Vector2(320, 390)
	add_child_autofree(holder)
	var phone := Phone.new()
	holder.add_child(phone)
	await wait_process_frames(1)
	assert_eq(phone.home_scale(), 2.0, "about twice as big on an upright phone")
	var body := Rect2(phone.home_origin() + Phone.BODY.position * 2.0, Phone.BODY.size * 2.0)
	assert_true(Rect2(Vector2.ZERO, holder.size).encloses(body), "the whole phone is on screen")
	holder.size = Vector2(320, 180)
	await wait_process_frames(1)
	assert_eq(phone.home_scale(), 1.0, "desktop size unchanged")
	assert_eq(phone.home_origin(), phone.view_offset(), "same place as before on desktop")
	holder.size = Vector2(320, 390)
	await wait_process_frames(1)
	var picked := []
	var run := func() -> void: picked.append(await phone.home())
	run.call()
	await wait_process_frames(1)
	var target := phone.icon_rect(4).get_center() * phone.home_scale() + phone.home_origin()
	phone.warp_mouse(target)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = target
	phone._tap_home((target - phone.home_origin()) / phone.home_scale())
	await wait_process_frames(2)
	assert_eq(picked, [phone.apps[4][0]], "a tap on the scaled icon opens that app")
