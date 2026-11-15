extends GutTest
## In-game Feedback (pause menu): payload, limits, the relay round trip (faked), the offline outbox, and the form.

var world: Overworld
var _saved_config: Dictionary


func before_each() -> void:
	GameState.reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	GameState.add_daemon(DaemonInstance.create("chipmunk", 12, rng, 1))
	GameState.flags["got_starter"] = true
	GameState.location = {"map": "port_city", "x": 17, "y": 12, "facing": "up"}
	_saved_config = DataRegistry.feedback.duplicate()
	FeedbackClient.save_outbox([])


func after_each() -> void:
	DataRegistry.feedback = _saved_config
	FeedbackClient.save_outbox([])
	SceneRouter.params = {}
	GameState.reset()


func _configure() -> void:
	DataRegistry.feedback["endpoint"] = "https://feedback.example.workers.dev"


func _open() -> FieldMenus:
	SceneRouter.params = {"map": "port_city", "spawn": "default"}
	world = load(Overworld.SCENE).instantiate()
	world.allow_scene_change = false
	world.auto_advance_text = true
	world.auto_choice = true
	add_child_autofree(world)
	world.set_time_scale(0.0)
	await wait_process_frames(2)
	return world.field_menus


func _logged(part: String) -> bool:
	for line in world.dialogue_log:
		if part in line:
			return true
	return false


func test_payload_has_only_game_details() -> void:
	var p := FeedbackClient.payload("bug", "  The shop froze when I sold a key.  ")
	assert_eq(p["category"], "bug")
	assert_eq(p["message"], "The shop froze when I sold a key.", "trimmed")
	var c: Dictionary = p["context"]
	assert_eq(c["map"], "port_city")
	assert_eq(c["daemons"], 1)
	assert_has(["web", "macos", "windows", "ios", "android", "linux"], c["platform"])
	for key: String in c:
		assert_has(["version", "build", "platform", "map", "x", "y", "play_minutes", "certs", "daemons", "language"], key,
			"the relay accepts %s" % key)
	assert_false(c.has("player_name"), "nothing personal")


func test_message_limits_come_from_data() -> void:
	assert_string_contains(FeedbackClient.check_message("too short"), "at least 10")
	assert_eq(FeedbackClient.check_message("Kevin walked through a wall."), "")
	assert_string_contains(FeedbackClient.check_message("x".repeat(2001)), "under 2000")


func test_validator_wants_https_or_nothing() -> void:
	var raw := DataRegistry.read_raw().duplicate(true)
	raw["feedback"]["endpoint"] = "http://insecure.example"
	var errors := " | ".join(DataValidator.new().validate(raw))
	assert_string_contains(errors, "https://")


func test_send_success_returns_the_confirm_page() -> void:
	_configure()
	var client := FeedbackClient.new()
	add_child_autofree(client)
	var sent := []
	client.transport = func(url: String, body: String) -> Dictionary:
		sent.append([url, JSON.parse_string(body)])
		return {"code": 200, "body": JSON.stringify({"id": "x", "confirm_url": "https://feedback.example.workers.dev/confirm/abc"})}
	var result := await client.send(FeedbackClient.payload("idea", "Let me rename Forgelings in the rack."))
	assert_true(result["ok"])
	assert_eq(result["confirm_url"], "https://feedback.example.workers.dev/confirm/abc")
	assert_eq(sent[0][0], "https://feedback.example.workers.dev/drafts")
	assert_eq(sent[0][1]["category"], "idea")


func test_send_rejects_a_confirm_link_to_somewhere_else() -> void:
	_configure()
	var client := FeedbackClient.new()
	add_child_autofree(client)
	client.transport = func(_u: String, _b: String) -> Dictionary:
		return {"code": 200, "body": JSON.stringify({"confirm_url": "https://evil.example/phish"})}
	var result := await client.send(FeedbackClient.payload("bug", "Something odd happened here."))
	assert_false(result["ok"], "we only ever open our own relay's pages")


func test_offline_feedback_goes_to_the_outbox() -> void:
	_configure()
	var menus := await _open()
	menus.feedback = FeedbackClient.new()
	menus.add_child(menus.feedback)
	menus.feedback.transport = func(_u: String, _b: String) -> Dictionary: return {"code": 0}
	await menus._send_feedback(FeedbackClient.payload("bug", "Offline bug report here."))
	assert_eq(FeedbackClient.load_outbox().size(), 1)
	assert_true(_logged("saved"))


func test_a_successful_send_opens_the_browser() -> void:
	_configure()
	var menus := await _open()
	var opened := []
	menus.open_url = func(url: String) -> void: opened.append(url)
	menus.feedback = FeedbackClient.new()
	menus.add_child(menus.feedback)
	menus.feedback.transport = func(_u: String, _b: String) -> Dictionary:
		return {"code": 200, "body": JSON.stringify({"confirm_url": "https://feedback.example.workers.dev/confirm/1"})}
	await menus._send_feedback(FeedbackClient.payload("bug", "The rack ate my Fanbat."))
	assert_eq(opened, ["https://feedback.example.workers.dev/confirm/1"])
	assert_true(_logged("Send feedback"))


func test_too_much_feedback_shows_the_relay_message() -> void:
	_configure()
	var menus := await _open()
	menus.feedback = FeedbackClient.new()
	menus.add_child(menus.feedback)
	menus.feedback.transport = func(_u: String, _b: String) -> Dictionary:
		return {"code": 429, "body": JSON.stringify({"error": "Too much feedback from here this hour."})}
	await menus._send_feedback(FeedbackClient.payload("bug", "Spam spam spam spam."))
	assert_true(_logged("Too much feedback"))
	assert_true(FeedbackClient.load_outbox().is_empty(), "refused, not queued")


func test_unconfigured_builds_say_so() -> void:
	DataRegistry.feedback["endpoint"] = ""
	var menus := await _open()
	await menus.feedback_screen()
	assert_true(_logged("isn't set up"))


func test_pause_menu_has_feedback() -> void:
	var ids := Phone.new().app_ids()
	assert_eq(ids.find("FEEDBACK"), ids.find("OPTIONS") + 1, "the phone lists FEEDBACK after SETTINGS")


func test_writing_with_a_gamepad_and_sending() -> void:
	var menus := await _open()
	var saved := InputPrompts.scheme
	InputPrompts.scheme = "xbox"
	var result := []
	var run := func() -> void: result.append(await menus._write_feedback("BUG"))
	run.call()
	await wait_process_frames(2)
	var panel: Panel = menus.get_node("FeedbackEntry")
	assert_true(get_viewport().get_visible_rect().encloses(panel.get_global_rect()), "fits the screen")
	var keys: Control = panel.get_node("Keys")
	var first: Button = keys.get_child(0).get_child(0)
	assert_true(first.has_focus(), "the cursor starts on the letter grid")
	for i in 3:
		first.pressed.emit()  # "AAA"
	var last_row: HBoxContainer = keys.get_child(keys.get_child_count() - 1)
	(last_row.get_child(last_row.get_child_count() - 1) as Button).pressed.emit()  # SEND
	await wait_process_frames(2)
	assert_eq(result, ["AAA"])
	InputPrompts.scheme = saved


func test_escape_backs_out_of_the_writing_box() -> void:
	var menus := await _open()
	var result := []
	var run := func() -> void: result.append(await menus._write_feedback("IDEA"))
	run.call()
	await wait_process_frames(2)
	var edit: TextEdit = menus.get_node("FeedbackEntry/Edit")
	edit.text = "half-written thought"
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	edit.gui_input.emit(esc)
	await wait_process_frames(2)
	assert_eq(result, [""], "nothing is sent")
