extends GutTest
## WHAT'S NEW popup (2026-11-18): data/whats_new.json notes shown once on the title screen after an update.

const UPDATES := [
	{"id": "b", "title": "UPDATE B", "notes": ["Newest thing."]},
	{"id": "a", "title": "UPDATE A", "notes": ["Older thing."]},
]

var _saved_seen := ""
var _saved_slots: PackedStringArray


func before_each() -> void:
	_saved_seen = Settings.last_seen_update
	_saved_slots = SaveManager.slot_paths
	SaveManager.slot_paths = PackedStringArray(["user://test_whats_new_a.json", "user://test_whats_new_b.json"])


func after_each() -> void:
	Settings.last_seen_update = _saved_seen
	SaveManager.slot_paths = _saved_slots


func test_tests_never_touch_real_settings() -> void:
	assert_true(Settings.under_test)
	assert_eq(Settings.path, Settings.TEST_PATH)


func test_who_sees_the_popup() -> void:
	assert_eq(WhatsNew.pending(UPDATES, "a", true)["id"], "b", "an older player sees the newest update")
	assert_eq(WhatsNew.pending(UPDATES, "a", false)["id"], "b", "even without a save, once they've seen one")
	assert_true(WhatsNew.pending(UPDATES, "b", true).is_empty(), "already seen")
	assert_eq(WhatsNew.pending(UPDATES, "", true)["id"], "b", "played before this feature existed (has a save)")
	assert_true(WhatsNew.pending(UPDATES, "", false).is_empty(), "a brand-new player isn't told what changed")
	assert_true(WhatsNew.pending([], "", true).is_empty())


func test_the_shipped_notes_are_valid_and_fit() -> void:
	var updates: Array = DataRegistry.whats_new.get("updates", [])
	assert_false(updates.is_empty(), "data/whats_new.json has an update")
	var popup := WhatsNew.new()
	popup.theme = UiTheme.get_theme()
	add_child_autofree(popup)
	popup.setup(updates[0])
	await wait_process_frames(2)
	var panel: Panel = popup.get_node("Panel")
	var notes: Control = popup.get_node("Panel/Notes")
	assert_true(get_viewport().get_visible_rect().encloses(panel.get_global_rect()), "fits the screen")
	assert_eq(notes.get_child_count(), updates[0]["notes"].size(), "one row per note")
	assert_lte(notes.get_combined_minimum_size().y, WhatsNew.NOTES_ROOM, "every note fits above the OK button")
	assert_true((popup.get_node("Panel/OK") as Button).has_focus(), "OK has the cursor (keyboard / controller)")


func test_shows_once_then_remembers() -> void:
	DataRegistry.whats_new = {"updates": UPDATES}
	Settings.last_seen_update = "a"
	var shown := []
	var run := func() -> void: shown.append(await WhatsNew.show_if_new(self))
	run.call()
	await wait_process_frames(2)
	var popup: WhatsNew = find_child("WhatsNew", true, false)
	assert_not_null(popup)
	var first_row: Node = popup.get_node("Panel/Notes").get_child(0)
	assert_eq((first_row.get_child(1) as Label).text, "Newest thing.")
	(popup.get_node("Panel/OK") as Button).pressed.emit()
	await wait_process_frames(2)
	assert_eq(shown, [true])
	assert_eq(Settings.last_seen_update, "b")
	shown.clear()
	run.call()
	await wait_process_frames(2)
	assert_eq(shown, [false], "not again")
	DataRegistry.load_all()


func test_new_players_are_marked_up_to_date_quietly() -> void:
	DataRegistry.whats_new = {"updates": UPDATES}
	Settings.last_seen_update = ""
	assert_false(await WhatsNew.show_if_new(self))
	assert_eq(Settings.last_seen_update, "b")
	assert_null(find_child("WhatsNew", true, false))
	DataRegistry.load_all()


func test_back_closes_it_too() -> void:
	var popup := WhatsNew.new()
	popup.theme = UiTheme.get_theme()
	add_child_autofree(popup)
	popup.setup(UPDATES[0])
	var closed := []
	popup.closed.connect(func() -> void: closed.append(true))
	var back := InputEventAction.new()
	back.action = "ui_cancel"
	back.pressed = true
	popup._unhandled_input(back)
	assert_eq(closed, [true])
