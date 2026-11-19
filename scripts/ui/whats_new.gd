class_name WhatsNew
extends Control
## "WHAT'S NEW" popup shown once on the title screen after an update (2026-11-18, Brandon: alert players to
## changes when the game opens after an update). The notes come from data/whats_new.json (newest update first);
## Settings.last_seen_update remembers the newest id this player has seen.
##
## Rules (should_show): nothing new -> no popup. A brand-new player (no setting yet and no save) never sees it;
## their marker is just set. Otherwise the newest update's notes show until OK.
## OK closes it with ui_accept / ui_cancel (keyboard, controller), a click or a tap.

signal closed

const MAX_NOTES := 5
const MAX_NOTE_LENGTH := 80
const PANEL := Vector2(304, 168)
const NOTES_ROOM := PANEL.y - 42.0  # height for the notes between the header and OK

var _ok: Button


## The update to show for this player, or {} for none. `has_save`: whether a save exists (an old player).
static func pending(updates: Array, last_seen: String, has_save: bool) -> Dictionary:
	if updates.is_empty():
		return {}
	var newest: Dictionary = updates[0]
	if str(newest.get("id", "")) == last_seen:
		return {}
	if last_seen.is_empty() and not has_save:
		return {}  # a new player: everything is new, nothing to announce
	return newest


## Newest update id (what to remember once the popup closes), or "" if there are no updates.
static func newest_id(updates: Array) -> String:
	return str(updates[0].get("id", "")) if not updates.is_empty() else ""


## Shows the popup if this player has an unseen update, waits for OK and remembers it. Also quietly marks new
## players as up to date. Returns true if the popup was shown.
static func show_if_new(parent: Node) -> bool:
	var updates: Array = DataRegistry.whats_new.get("updates", [])
	var latest := newest_id(updates)
	if latest.is_empty() or latest == Settings.last_seen_update:
		return false
	var update := pending(updates, Settings.last_seen_update, SaveManager.has_save())
	if not update.is_empty():
		var popup := WhatsNew.new()
		popup.theme = UiTheme.get_theme()
		parent.add_child(popup)
		popup.setup(update)
		await popup.closed
		popup.queue_free()
	Settings.last_seen_update = latest
	Settings.save_settings()
	return not update.is_empty()


func setup(update: Dictionary) -> void:
	name = "WhatsNew"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # nothing underneath reacts while it's open
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var panel := Panel.new()
	panel.name = "Panel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -PANEL.x / 2.0
	panel.offset_right = PANEL.x / 2.0
	panel.offset_top = -PANEL.y / 2.0
	panel.offset_bottom = PANEL.y / 2.0
	add_child(panel)
	var header := Label.new()
	header.name = "Header"
	header.text = "WHAT'S NEW  %s" % str(update.get("title", ""))
	header.position = Vector2(8, 6)
	panel.add_child(header)
	# One row per note: a ">" marker and the text, so wrapped lines stay indented under their own note.
	var notes := VBoxContainer.new()
	notes.name = "Notes"
	notes.position = Vector2(8, 20)
	notes.size = Vector2(PANEL.x - 16, 0)
	notes.add_theme_constant_override("separation", 2)
	for n: Variant in update.get("notes", []):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var mark := Label.new()
		mark.text = ">"
		mark.add_theme_color_override("font_color", UiTheme.BORDER)
		mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(mark)
		var text := Label.new()
		text.text = str(n)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.custom_minimum_size = Vector2(PANEL.x - 32, 0)
		row.add_child(text)
		notes.add_child(row)
	panel.add_child(notes)
	_ok = CursorButton.new("OK")
	_ok.name = "OK"
	_ok.size = Vector2(40, 14)
	_ok.position = Vector2(PANEL.x - 48, PANEL.y - 20)
	_ok.pressed.connect(_close)
	panel.add_child(_ok)
	_ok.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	if is_queued_for_deletion() or not visible:
		return
	visible = false
	closed.emit()
