extends GutTest
## WHAT'S NEW screen (spec "What's New Screen - Implementation Spec", Nov 18 2026; docs/whats-new-spec.md).

const UPDATES := [
	{"id": "b", "label": "UPDATE · B", "entries": [{"tag": "NEW", "text": "Newest thing."}]},
	{"id": "a", "label": "UPDATE · A", "entries": [{"tag": "UI", "text": "Older thing."}]},
]

var _saved_seen := ""
var _saved_lines := false
var _saved_slots: PackedStringArray
var _saved_scheme := ""


func before_each() -> void:
	_saved_seen = Settings.last_seen_update
	_saved_lines = Settings.panel_scanlines
	_saved_scheme = InputPrompts.scheme
	_saved_slots = SaveManager.slot_paths
	SaveManager.slot_paths = PackedStringArray(["user://test_whats_new_a.json", "user://test_whats_new_b.json"])


func after_each() -> void:
	Settings.last_seen_update = _saved_seen
	Settings.panel_scanlines = _saved_lines
	InputPrompts.scheme = _saved_scheme
	SaveManager.slot_paths = _saved_slots
	DataRegistry.load_all()


## A screen in a parent of the given size (landscape = desktop layout, portrait = phone layout).
func _screen(view: Vector2, data: Dictionary = {}) -> WhatsNew:
	var holder := Control.new()
	holder.size = view
	add_child_autofree(holder)
	var screen := WhatsNew.new()
	holder.add_child(screen)
	screen.setup(data if not data.is_empty() else DataRegistry.whats_new["updates"][0])
	return screen


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


func _action(action: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


func test_tests_never_touch_real_settings() -> void:
	assert_true(Settings.under_test)
	assert_eq(Settings.path, Settings.TEST_PATH)


func test_who_sees_it() -> void:
	assert_eq(WhatsNew.pending(UPDATES, "a", true)["id"], "b", "an older player sees the newest update")
	assert_true(WhatsNew.pending(UPDATES, "b", true).is_empty(), "already seen")
	assert_eq(WhatsNew.pending(UPDATES, "", true)["id"], "b", "played before this screen existed (has a save)")
	assert_true(WhatsNew.pending(UPDATES, "", false).is_empty(), "a brand-new player isn't told what changed")
	assert_true(WhatsNew.pending([], "", true).is_empty())


## The Nov 18 notes (the spec's reference content).
func _nov_18() -> Dictionary:
	for u: Dictionary in DataRegistry.whats_new["updates"]:
		if u["id"] == "2026-11-18":
			return u
	return {}


func test_nov_18_entries_come_from_data_with_tag_colors_and_credit() -> void:
	var update: Dictionary = _nov_18()
	var entries: Array = update["entries"]
	assert_eq(entries.size(), 6)
	assert_eq(entries.map(func(e: Dictionary) -> String: return e["tag"]), ["NEW", "NEW", "UI", "BALANCE", "MOVES", "AI"])
	assert_eq(entries[0]["credit"], "Thanks for the idea!")
	assert_eq(WhatsNew.tag_color("NEW"), Color("0E6B5C"))
	assert_eq(WhatsNew.tag_color("BALANCE"), Color("A3470A"))
	assert_eq(WhatsNew.tag_color("mystery", false), Color("3A3F4B"), "unknown tags fall back to tag-ai gray")
	var screen := _screen(Vector2(320, 180), update)
	assert_eq(screen._rows.size(), 6)
	assert_eq((screen._rows[0]["credit"] as PackedStringArray).size(), 1, "the credit sub-line on entry 1")
	assert_eq((screen._rows[1]["credit"] as PackedStringArray).size(), 0)


func test_log_line_counts_entries_and_the_cursor_blinks() -> void:
	assert_eq(WhatsNew.log_text(6, false), "> patch_notes.log loaded — 6 changes")
	assert_eq(WhatsNew.log_text(1, true), "> 1 change")
	var screen := _screen(Vector2(320, 180))
	screen._blink = 0.2
	assert_true(screen.cursor_on())
	screen._blink = 0.7
	assert_false(screen.cursor_on(), "off for the second half of each second (hard cut)")
	screen._blink = 1.1
	assert_true(screen.cursor_on())


func test_desktop_layout_fits_with_a_tag_column() -> void:
	var screen := _screen(Vector2(320, 180), _nov_18())
	assert_false(screen.layout.phone)
	assert_eq(screen.layout.panel_w, 860.0)
	var panel := screen.get_node("Stage/Panel") as Control
	assert_true(Rect2(Vector2.ZERO, screen.layout.frame).encloses(Rect2(panel.position, panel.size)), "panel inside the frame")
	assert_almost_eq(screen.max_scroll(), 0.0, 0.01, "six entries fit without scrolling")
	var ok := screen.get_node("Stage/Panel/OK") as Control
	assert_gte(ok.size.x, 120.0)
	assert_gte(ok.size.y, 48.0)
	assert_true(ok.has_focus(), "OK has focus when it opens")
	assert_eq(screen._rows[0]["lines"].size(), 1, "desktop text sits beside the tag column on one line")


func test_phone_layout_stacks_tags_and_has_a_full_width_ok() -> void:
	var screen := _screen(Vector2(180, 390))
	assert_true(screen.layout.phone)
	var panel := screen.get_node("Stage/Panel") as Control
	var ok := screen.get_node("Stage/Panel/OK") as Control
	assert_eq(panel.size.x, 390.0 - 28.0, "fills the width minus 14px each side")
	assert_gte(ok.size.y, 52.0)
	assert_almost_eq(ok.size.x, panel.size.x - 8 - 36, 0.5, "full-width OK")
	assert_true(Rect2(Vector2.ZERO, screen.layout.frame).encloses(Rect2(panel.position, panel.size)))
	assert_eq(WhatsNew.hint_text().is_empty(), false)


func test_every_input_closes_it_but_taps_outside_do_not() -> void:
	for how in ["ui_accept", "ui_cancel", "space", "escape", "enter", "click"]:
		var screen := _screen(Vector2(320, 180))
		var closed := []
		screen.closed.connect(func() -> void: closed.append(true))
		match how:
			"ui_accept", "ui_cancel":
				screen._input(_action(how))
			"space":
				screen._input(_key(KEY_SPACE))
			"escape":
				screen._input(_key(KEY_ESCAPE))
			"enter":
				screen._input(_key(KEY_ENTER))
			"click":
				var ok := screen.get_node("Stage/Panel/OK") as Control
				var down := InputEventMouseButton.new()
				down.button_index = MOUSE_BUTTON_LEFT
				down.pressed = true
				ok._gui_input(down)
				var up := InputEventMouseButton.new()
				up.button_index = MOUSE_BUTTON_LEFT
				ok._gui_input(up)
		await wait_seconds(0.15)
		assert_eq(closed, [true], "%s closes it" % how)
	var stays := _screen(Vector2(320, 180))
	var closed_outside := []
	stays.closed.connect(func() -> void: closed_outside.append(true))
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	tap.position = Vector2(2, 2)
	stays._gui_input(tap)
	stays._input(tap)
	await wait_seconds(0.15)
	assert_eq(closed_outside, [], "a tap outside the panel does nothing")


func test_long_lists_scroll_with_the_title_and_footer_pinned() -> void:
	var entries := []
	for i in 12:
		entries.append({"tag": "NEW", "text": "Change number %d with a few more words to wrap it." % i})
	var screen := _screen(Vector2(320, 180), {"id": "long", "label": "UPDATE · LONG", "entries": entries})
	assert_gt(screen.max_scroll(), 0.0, "twelve entries overflow")
	var list := screen.get_node("Stage/Panel/List") as Control
	var panel := screen.get_node("Stage/Panel") as Control
	assert_lte(panel.position.y + panel.size.y, screen.layout.frame.y, "the panel stays on screen")
	var list_top := list.position.y
	var ok_top := (screen.get_node("Stage/Panel/OK") as Control).position.y
	screen._input(_action("ui_down"))
	assert_gt(screen.scroll, 0.0, "Down scrolls the list")
	assert_eq(list.position.y, list_top, "the title bar and log line don't move")
	assert_eq((screen.get_node("Stage/Panel/OK") as Control).position.y, ok_top, "the footer doesn't move")
	for i in 40:
		screen.scroll_by(100)
	assert_eq(screen.scroll, screen.max_scroll())
	screen.scroll = 0.0
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.relative = Vector2(0, -80)
	list._gui_input(drag)
	assert_eq(screen.scroll, 80.0, "dragging up with a finger or mouse scrolls down")
	Input.action_press("move_down")
	for i in 10:
		screen._process(0.05)
	Input.action_release("move_down")
	assert_gt(screen.scroll, 80.0, "holding the d-pad keeps scrolling")
	var short := _screen(Vector2(320, 180))
	short._input(_action("ui_down"))
	assert_eq(short.scroll, 0.0, "no scrolling when it all fits")


func test_scanlines_are_off_by_default_and_toggle() -> void:
	var fresh: Node = load("res://autoload/settings.gd").new()
	assert_false(fresh.panel_scanlines, "default off")
	fresh.free()
	Settings.panel_scanlines = false
	assert_false(_screen(Vector2(320, 180)).get_node("Stage/Panel/Scanlines").visible)
	Settings.panel_scanlines = true
	assert_true(_screen(Vector2(320, 180)).get_node("Stage/Panel/Scanlines").visible)


func test_shows_once_per_update_then_stays_hidden() -> void:
	DataRegistry.whats_new = {"updates": UPDATES}
	Settings.last_seen_update = "a"
	var shown := []
	var run := func() -> void: shown.append(await WhatsNew.show_if_new(self))
	run.call()
	await wait_process_frames(2)
	var screen: WhatsNew = find_child("WhatsNew", true, false)
	assert_not_null(screen)
	screen._input(_action("ui_accept"))
	await wait_seconds(0.15)
	assert_eq(shown, [true])
	assert_eq(Settings.last_seen_update, "b", "saved on OK")
	Settings.load_settings()
	assert_eq(Settings.last_seen_update, "b", "still remembered after a relaunch")
	shown.clear()
	run.call()
	await wait_process_frames(2)
	assert_eq(shown, [false], "not again")


func test_new_players_are_marked_up_to_date_quietly() -> void:
	DataRegistry.whats_new = {"updates": UPDATES}
	Settings.last_seen_update = ""
	assert_false(await WhatsNew.show_if_new(self))
	assert_eq(Settings.last_seen_update, "b")
	assert_null(find_child("WhatsNew", true, false))


## Every shipped update is valid and its newest entry is the one the title screen shows.
func test_shipped_updates_are_newest_first_and_fit() -> void:
	var updates: Array = DataRegistry.whats_new["updates"]
	assert_eq(updates[0]["id"], "2026-11-19", "the newest update is shown")
	for u: Dictionary in updates:
		for desktop in [true, false]:
			var screen := _screen(Vector2(320, 180) if desktop else Vector2(180, 390), u)
			var panel := screen.get_node("Stage/Panel") as Control
			assert_true(Rect2(Vector2.ZERO, screen.layout.frame).encloses(Rect2(panel.position, panel.size)),
				"%s fits (%s)" % [u["id"], "desktop" if desktop else "phone"])
			if desktop:
				assert_eq(screen.max_scroll(), 0.0, "%s needs no scrolling on desktop" % u["id"])
