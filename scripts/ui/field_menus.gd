class_name FieldMenus
extends Control
## Menus used outside battle, all as awaitable flows:
##   open_pause(app)     your phone: MAPS / CMDB / STACK / BAG / CARD / SAVE / CONTROLS / SETTINGS / FEEDBACK
##                       (+ DEBUG in debug builds); open_pause("MAP") goes straight to Maps
##   feedback_screen()   send a bug report or idea to the team (see FeedbackClient)
##   stack_screen()      summary, swap order, use an item on a Daemon
##   bag_screen()        4 pockets (left/right), use / toss
##   cmdb_screen()       every Daemon, seen/caught, entries
##   rack_screen()       Server Rack: withdraw / deposit / move between 12 racks of 30
##   shop(stock)         Supply Closet: buy / sell
## Messages and yes/no questions go through the Overworld's text box (world.show_message / ask).

const POCKETS := ["items", "keys", "scripts", "key_items"]
const POCKET_NAMES := {"items": "ITEMS", "keys": "QUARANTINE KEYS", "scripts": "SCRIPTS", "key_items": "KEY ITEMS"}
const DEBUG_MENU := "res://scenes/debug/debug_menu.tscn"

var world: Overworld
var list: MenuList
var side: MenuList      # top-right: pause, rack, shop
var sub: MenuList       # bottom-right: small submenus over a list (SUMMARY/SWAP, USE/TOSS)
var summary: SummaryPanel
var cmdb_panel: CmdbPanel
var card: TrainerCardPanel
var phone: Phone
var yes_no: MenuList     # bottom-right, just above the text box: the overworld's YES / NO

var _qty_panel: Panel
var _qty_label: Label
var _qty_open := false
var _qty := 1
var _qty_max := 1
var _qty_price := 0
signal _qty_done(qty: int)

var _last_rack := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	list = MenuList.new()
	list.setup(Vector4(0, 0, 1, 1), Vector4(6, 6, -6, -6), 11, 2)
	add_child(list)
	side = MenuList.new()
	side.setup(Vector4(1, 0, 1, 0), Vector4(-112, 6, -6, 6 + 17 + 9 * MenuList.ROW_H + 6), 9)
	add_child(side)
	sub = MenuList.new()
	sub.setup(Vector4(1, 1, 1, 1), Vector4(-112, -6 - (17 + 5 * MenuList.ROW_H + 6), -6, -6), 5)
	add_child(sub)
	summary = SummaryPanel.new()
	add_child(summary)
	cmdb_panel = CmdbPanel.new()
	add_child(cmdb_panel)
	card = TrainerCardPanel.new()
	add_child(card)
	phone = Phone.new()
	add_child(phone)
	yes_no = MenuList.new()
	yes_no.setup(Vector4(1, 1, 1, 1), Vector4(-62, -50 - (5 + 2 * MenuList.ROW_H + 5), -4, -50), 2)
	add_child(yes_no)
	_qty_panel = Panel.new()
	_qty_panel.anchor_left = 1
	_qty_panel.anchor_right = 1
	_qty_panel.anchor_top = 1
	_qty_panel.anchor_bottom = 1
	_qty_panel.offset_left = -126
	_qty_panel.offset_right = -6
	_qty_panel.offset_top = -82
	_qty_panel.offset_bottom = -52
	_qty_panel.visible = false
	add_child(_qty_panel)
	_qty_label = Label.new()
	_qty_label.position = Vector2(8, 5)
	_qty_label.add_theme_constant_override("line_spacing", 2)
	_qty_panel.add_child(_qty_label)


# --- pause -------------------------------------------------------------------

func open_pause(start_app: String = "") -> void:
	var last := "MAP"
	var app := start_app
	while true:
		if app.is_empty():
			app = await phone.home(last)
			if app.is_empty():
				break
		last = app
		match app:
			"MAP":
				await phone.maps()
				if start_app == "MAP":
					break  # the map button is a quick look: closing Maps puts the phone away
			"CMDB":
				await cmdb_screen()
			"STACK":
				await stack_screen()
			"BAG":
				await bag_screen()
			"CARD":
				await card.open()
			"SAVE":
				await save_flow()
			"CONTROLS":
				await controls_screen()
			"OPTIONS":
				await options_screen()
			"FEEDBACK":
				await feedback_screen()
			"DEBUG":
				SceneRouter.goto(DEBUG_MENU)
				return
		_hide_talk()  # e.g. "Saved." must not linger over the next app (Brandon, 2026-11-15)
		app = ""
		start_app = ""


# --- feedback ----------------------------------------------------------------

const FEEDBACK_KEY_ROWS: PackedStringArray = ["ABCDEFGHIJ", "KLMNOPQRST", "UVWXYZ0123", "456789.,!?", "'-:()/"]
const FEEDBACK_PANEL := Vector2(304, 168)

## Feedback client used by feedback_screen (tests swap in a fake transport).
var feedback: FeedbackClient
## How the confirm page is opened (tests replace it).
var open_url: Callable = FeedbackClient.open_confirm


## Pause > FEEDBACK: pick a kind, write it, confirm, send. The relay answers with a confirm page that opens in
## the browser ("I'm human" captcha); only then does it become an issue in the private feedback repo.
func feedback_screen() -> void:
	if not FeedbackClient.is_configured():
		await world.show_message("Feedback isn't set up in this build yet. Thanks for wanting to help!")
		return
	if feedback == null:
		feedback = FeedbackClient.new()
		add_child(feedback)
	var saved := FeedbackClient.load_outbox()
	if not saved.is_empty() and await world.ask("You have feedback that didn't send last time. Send it now?"):
		FeedbackClient.save_outbox(saved.slice(1))
		await _send_feedback(saved[0])
		return
	var kinds := PackedStringArray(["BUG", "IDEA", "OTHER"])
	var r := await side.choose("FEEDBACK", kinds)
	side.close()
	if r["action"] != "pick":
		return
	var category := kinds[r["index"]].to_lower()
	var message := await _write_feedback(kinds[r["index"]])
	if message.is_empty():
		return
	var problem := FeedbackClient.check_message(message)
	if not problem.is_empty():
		await world.show_message(problem)
		return
	await world.show_message("We'll send your message plus the game version, platform and where you are. No save data or personal info.")
	if not await world.ask("Send it? Your browser will open so you can confirm you're a person."):
		return
	await _send_feedback(FeedbackClient.payload(category, message))


func _send_feedback(data: Dictionary) -> void:
	world.text_box.visible = true
	world.text_box.show_now("Sending...")
	var result := await feedback.send(data)
	if result.get("ok", false):
		open_url.call(String(result["confirm_url"]))
		await world.show_message("Your browser opened. Click \"Send feedback\" there to finish. Thank you!")
	elif result.get("offline", false):
		FeedbackClient.queue(data)
		await world.show_message("Couldn't reach the feedback server. It's saved; open FEEDBACK again when you're online.")
	else:
		await world.show_message(String(result.get("error", "Something went wrong. Please try again later.")))


## The writing box: a multi-line field (keyboard / on-screen keyboard on phones) plus a letter grid for gamepads.
## Returns the text, or "" if the player backed out.
func _write_feedback(kind: String) -> String:
	var panel := Panel.new()
	panel.name = "FeedbackEntry"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -FEEDBACK_PANEL.x / 2.0
	panel.offset_right = FEEDBACK_PANEL.x / 2.0
	panel.offset_top = -FEEDBACK_PANEL.y / 2.0
	panel.offset_bottom = FEEDBACK_PANEL.y / 2.0
	add_child(panel)
	var label := Label.new()
	label.name = "Prompt"
	label.text = "FEEDBACK: %s" % kind
	label.position = Vector2(8, 6)
	panel.add_child(label)
	var max_len := int(FeedbackClient.config().get("max_message", 2000))
	var edit := TextEdit.new()
	edit.name = "Edit"
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.placeholder_text = "What happened? What would make it better?"
	edit.position = Vector2(8, 18)
	edit.size = Vector2(FEEDBACK_PANEL.x - 16, 56)
	panel.add_child(edit)
	var result := FeedbackResult.new()
	panel.add_child(result)
	var finish := func() -> void: result.done.emit(edit.text)
	var cancel := func() -> void: result.done.emit("")
	var keys := _letter_keys(FEEDBACK_KEY_ROWS, max_len, edit, "SEND", finish)
	keys.name = "Keys"
	keys.position = Vector2(8, 78)
	panel.add_child(keys)
	var hint := Label.new()
	hint.name = "Hint"
	hint.text = feedback_hint()
	hint.add_theme_color_override("font_color", Color("505068"))
	hint.position = Vector2(8, FEEDBACK_PANEL.y - 16)
	panel.add_child(hint)
	edit.text_changed.connect(func() -> void:
		if edit.text.length() > max_len:
			edit.text = edit.text.left(max_len))
	edit.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventKey and e.pressed:
			var key := e as InputEventKey
			if key.keycode == KEY_ESCAPE:
				edit.accept_event()
				cancel.call()
			elif key.keycode in [KEY_ENTER, KEY_KP_ENTER] and (key.ctrl_pressed or key.meta_pressed):
				edit.accept_event()
				finish.call())
	var back := NameEntryBack.new()
	back.cancelled.connect(cancel)
	panel.add_child(back)
	if InputPrompts.scheme in ["xbox", "playstation", "nintendo"]:
		keys.get_child(0).get_child(0).grab_focus()
	else:
		edit.grab_focus()
	var text: String = await result.done
	panel.queue_free()
	return text.strip_edges()


static func feedback_hint() -> String:
	match InputPrompts.scheme:
		"touch":
			return "Tap SEND when you're done."
		"keyboard":
			return "Ctrl+Enter or SEND: done   Esc: back"
	return "%s: type / SEND   %s: back" % [InputPrompts.label("ui_accept"), InputPrompts.label("ui_cancel")]


class FeedbackResult extends Node:
	signal done(text: String)


# --- story pickers -----------------------------------------------------------

const NAME_PRESETS: PackedStringArray = ["ALEX", "SAM", "RILEY", "JORDAN", "CASEY"]
const NAME_MAX := 10
const NAME_PANEL_W := 200.0

## Pick a preset or type one. Returns the chosen name (never empty).
func choose_name() -> String:
	if world != null and world.auto_choice != null:
		return NAME_PRESETS[0].capitalize()
	var options := NAME_PRESETS.duplicate()
	options.append("TYPE NAME")
	while true:
		var r := await side.choose("YOUR NAME?", options)
		side.close()
		if r["action"] != "pick":
			continue  # a name is required
		if r["index"] < NAME_PRESETS.size():
			return NAME_PRESETS[r["index"]].capitalize()
		var typed := await _type_name()
		if not typed.is_empty():
			return typed
	return NAME_PRESETS[0].capitalize()


func _type_name() -> String:
	var panel := Panel.new()
	panel.name = "NameEntry"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -NAME_PANEL_W / 2.0
	panel.offset_right = NAME_PANEL_W / 2.0
	panel.offset_top = 36
	add_child(panel)
	var label := Label.new()
	label.name = "Prompt"
	label.text = "YOUR NAME?"
	label.position = Vector2(8, 6)
	panel.add_child(label)
	var edit := LineEdit.new()
	edit.name = "Edit"
	edit.max_length = NAME_MAX
	edit.placeholder_text = "max %d letters" % NAME_MAX
	panel.add_child(edit)
	var hint := Label.new()
	hint.name = "Hint"
	hint.text = name_entry_hint()
	hint.add_theme_color_override("font_color", Color("505068"))
	panel.add_child(hint)
	var keys := _name_keys(edit)
	keys.name = "Keys"
	panel.add_child(keys)
	# Stack by real (theme) heights so nothing overlaps whatever the font and padding are.
	var y := label.position.y + label.get_combined_minimum_size().y + 3.0
	edit.position = Vector2(8, y)
	edit.size = Vector2(NAME_PANEL_W - 16, edit.get_combined_minimum_size().y)
	y += edit.size.y + 4.0
	keys.position = Vector2(8, y)
	y += keys.get_combined_minimum_size().y + 4.0
	hint.position = Vector2(8, y)
	panel.offset_bottom = panel.offset_top + y + hint.get_combined_minimum_size().y + 7.0
	# Keyboard players type straight into the field; with a gamepad the cursor starts on the letter grid.
	if InputPrompts.scheme in ["xbox", "playstation", "nintendo"]:
		keys.get_child(0).get_child(0).grab_focus()
	else:
		edit.grab_focus()
	var cancel := func() -> void:
		edit.text_submitted.emit("")
	edit.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
			edit.accept_event()
			cancel.call())
	# B / Circle (or X / Backspace while on the grid) backs out to the name list.
	var back := NameEntryBack.new()
	back.cancelled.connect(cancel)
	panel.add_child(back)
	var typed: String = await edit.text_submitted
	panel.queue_free()
	return clean_name(typed)


const NAME_KEY_ROWS: PackedStringArray = ["ABCDEFGHIJ", "KLMNOPQRST", "UVWXYZ0123", "456789"]


## On-screen letter grid for the name box, so a gamepad (or mouse/touch) can enter a name without a
## keyboard. Letters append, SPC adds a space, DEL removes the last letter, OK submits.
func _name_keys(edit: LineEdit) -> VBoxContainer:
	return _letter_keys(NAME_KEY_ROWS, NAME_MAX, edit, "OK", func() -> void: edit.text_submitted.emit(edit.text))


## A letter grid that types into `target` (LineEdit or TextEdit), at most `max_len` characters. The last row
## gets SPC / DEL / the `done_label` key, which calls `on_done`.
func _letter_keys(rows: PackedStringArray, max_len: int, target: Control, done_label: String, on_done: Callable) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	var focus := StyleBoxFlat.new()
	focus.bg_color = UiTheme.BORDER
	var add_key := func(row: HBoxContainer, text: String, width: float, action: Callable) -> void:
		var b := Button.new()
		b.text = text
		b.focus_mode = Control.FOCUS_ALL
		b.custom_minimum_size = Vector2(width, 11)
		b.add_theme_stylebox_override("focus", focus)
		b.add_theme_color_override("font_focus_color", UiTheme.PAPER)
		b.add_theme_color_override("font_hover_color", UiTheme.INK)
		b.mouse_entered.connect(b.grab_focus)
		b.pressed.connect(action)
		row.add_child(b)
	var type_text := func(s: String) -> void:
		var current: String = target.get("text")
		if current.length() + s.length() > max_len:
			return
		target.set("text", current + s)
		if target is LineEdit:
			(target as LineEdit).caret_column = (target as LineEdit).text.length()
		elif target is TextEdit:
			var te := target as TextEdit
			te.set_caret_line(te.get_line_count() - 1)
			te.set_caret_column(te.get_line(te.get_line_count() - 1).length())
	for letters in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		box.add_child(row)
		for ch in letters:
			add_key.call(row, ch, 18.0, func() -> void: type_text.call(ch))
		if letters == rows[rows.size() - 1]:
			add_key.call(row, "SPC", 26.0, func() -> void:
				if not String(target.get("text")).is_empty():
					type_text.call(" "))
			add_key.call(row, "DEL", 26.0, func() -> void:
				target.set("text", String(target.get("text")).left(-1)))
			add_key.call(row, done_label, 8.0 * done_label.length() + 6.0, on_done)
	return box


## Turns ui_cancel that nothing else used (B on a gamepad, X/Backspace while on the grid) into "back".
class NameEntryBack extends Node:
	signal cancelled

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			cancelled.emit()


## Letters, digits and spaces only, trimmed, at most NAME_MAX characters.
static func clean_name(typed: String) -> String:
	var out := ""
	for ch in typed.strip_edges():
		var c := ch.unicode_at(0)
		if ch == " " or (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122):
			out += ch
	return out.strip_edges().left(NAME_MAX)


static func name_entry_hint() -> String:
	match InputPrompts.scheme:
		"touch":
			return "Done: confirm   (blank = back)"
		"keyboard":
			return "Enter: OK   Esc: back"
	return "%s: key   %s: back" % [InputPrompts.label("ui_accept"), InputPrompts.label("ui_cancel")]


## Starter choice from the e-waste bin. Shows each one's sprite, type and CMDB line.
func choose_starter(options: Array) -> String:
	if world != null and world.auto_choice != null:
		return options[0]
	var preview := TextureRect.new()
	preview.anchor_left = 1
	preview.anchor_right = 1
	preview.offset_left = -84
	preview.offset_top = 30
	preview.size = Vector2(64, 64)
	add_child(preview)
	var rows := PackedStringArray()
	for species_id: String in options:
		var data := DataRegistry.get_species(species_id)
		rows.append("%-10s %s" % [data["name"], String(DataRegistry.types[data["types"][0]]["name"]).to_upper()])
	list.describe = func(i: int) -> String:
		preview.texture = DaemonSprites.front(options[i])
		var data := DataRegistry.get_species(options[i])
		return "%s. %s" % [data["cmdb"]["category"], data["cmdb"]["entry"]]
	var chosen := ""
	while chosen.is_empty():
		var r := await list.choose("THE E-WASTE BIN", rows)
		if r["action"] != "pick":
			continue
		var name: String = DataRegistry.get_species(options[r["index"]])["name"]
		list.visible = false
		preview.visible = false
		if await world.ask("Take %s?" % name):
			chosen = options[r["index"]]
		preview.visible = true
	list.describe = Callable()
	list.close()
	preview.queue_free()
	return chosen


# --- save and options --------------------------------------------------------

func save_flow() -> void:
	if not await world.ask("Save your progress?"):
		return
	var error := SaveManager.save_game()
	AudioManager.play_sfx("confirm")
	await _say(error if not error.is_empty() else "Saved. Play time %s." % TrainerCardPanel.format_time(GameState.play_time_sec))


## Pause > CONTROLS: every button for what you're holding right now (keyboard, pad brand or touch).
func controls_screen() -> void:
	var rows := PackedStringArray()
	for row: Array in InputPrompts.controls():
		rows.append("%-10s %s" % row)
	rows.append("DONE")
	var names := {"keyboard": "KEYBOARD", "xbox": "XBOX PAD", "playstation": "PLAYSTATION PAD",
		"nintendo": "SWITCH PAD", "touch": "TOUCH"}
	list.describe = func(_i: int) -> String:
		return "Follows what you use: keys, pad or touch."
	await list.choose("CONTROLS  (%s)" % names.get(InputPrompts.scheme, "KEYBOARD"), rows, [], rows.size() - 1)
	list.describe = Callable()
	list.close()


func options_screen() -> void:
	var cursor := 0
	while true:
		var on_off := "ON" if Settings.battle_animations else "OFF"
		var rows := PackedStringArray([
			"TEXT SPEED    < %s >" % Settings.text_speed.to_upper(),
			"MUSIC VOLUME  < %d%% >" % roundi(Settings.music_volume * 100),
			"SFX VOLUME    < %d%% >" % roundi(Settings.sfx_volume * 100),
			"BATTLE ANIMS  < %s >" % on_off,
			"AUTOSAVE      < %s >" % ("ON" if Settings.autosave_on_suspend else "OFF"),
			"CRT EFFECTS   < %s >" % ("ON" if Settings.crt_effects else "OFF"),
			"LESS MOTION   < %s >" % ("ON" if Settings.reduced_motion else "OFF"),
			"CONTROL HINTS < %s >" % ("ON" if Settings.control_hints else "OFF"),
			"DONE",
		])
		list.allow_lr = true
		list.describe = func(i: int) -> String: return ["How fast text types out.", "Background music (coming with the soundtrack).",
			"Sound effects.", "Turn off to skip battle animations.",
			"Phones/tablets: save when the app goes to the background.",
			"Title screen scanlines and scan bar.", "Stops the title screen's bigger animations.",
			"Shows which buttons open the menu and talk, in the top corner.", "Save and close."][i]
		var r := await list.choose("OPTIONS   (left/right to change)", rows, [], cursor)
		list.allow_lr = false
		list.describe = Callable()
		cursor = r["index"]
		if r["action"] == "cancel" or (r["action"] == "pick" and cursor == 8):
			break
		var step := -1 if r["action"] == "left" else 1
		match cursor:
			0:
				var order := Settings.TEXT_SPEED_ORDER
				Settings.text_speed = order[wrapi(order.find(Settings.text_speed) + step, 0, order.size())]
			1:
				Settings.music_volume = clampf(snappedf(Settings.music_volume + 0.1 * step, 0.1), 0.0, 1.0)
			2:
				Settings.sfx_volume = clampf(snappedf(Settings.sfx_volume + 0.1 * step, 0.1), 0.0, 1.0)
				Settings.apply()
				AudioManager.play_sfx("select")
			3:
				Settings.battle_animations = not Settings.battle_animations
			4:
				Settings.autosave_on_suspend = not Settings.autosave_on_suspend
			5:
				Settings.crt_effects = not Settings.crt_effects
			6:
				Settings.reduced_motion = not Settings.reduced_motion
			7:
				Settings.control_hints = not Settings.control_hints
	Settings.apply()
	Settings.save_settings()
	list.close()


# --- Active Stack ------------------------------------------------------------

func stack_screen() -> void:
	var start := 0
	while not GameState.active_stack.is_empty():
		var r := await list.choose("ACTIVE STACK", stack_rows(), [], start)
		if r["action"] != "pick":
			break
		start = r["index"]
		var d: DaemonInstance = GameState.active_stack[start]
		var choice := await sub.choose(d.display_name(), PackedStringArray(["SUMMARY", "MOVES", "SWAP", "ITEM", "CANCEL"]))
		sub.close()
		if choice["action"] != "pick":
			continue
		match choice["index"]:
			0:
				await summary.open(GameState.active_stack, start)
			1:
				await moves_screen(d)
			2:
				var other := await list.choose("Swap %s with?" % d.display_name(), stack_rows(), [], start)
				if other["action"] == "pick":
					GameState.swap_stack(start, other["index"])
					start = other["index"]
			3:
				var item_id := await _pick_bag_item("Use which item?", func(id: String) -> bool: return ItemUse.needs_target(id))
				if not item_id.is_empty():
					await _use_on(item_id, d)
	list.close()


## Uses an item on a Daemon, then asks about any move it wants but has no room for (Overclock Chip).
func _use_on(item_id: String, d: DaemonInstance) -> void:
	var result := ItemUse.use_on(item_id, d)
	await _say_all(result["messages"])
	for move_id: String in result.get("pending_moves", []):
		await offer_move(d, move_id)


# --- moves -------------------------------------------------------------------

## STACK > MOVES: see each move's details, change the order, and re-install moves the Daemon learned
## before. Nothing is overwritten without asking (player feedback, 2026-11-14).
func moves_screen(d: DaemonInstance) -> void:
	var start := 0
	while true:
		var rows := PackedStringArray()
		for slot: Dictionary in d.moves:
			rows.append("%-15s CYC %2d/%-2d" % [MoveText.name_of(slot["id"]), int(slot["pp"]), int(DataRegistry.get_move(slot["id"])["max_pp"])])
		var old_moves := d.relearnable_moves()
		rows.append("RE-INSTALL A MOVE (%d)" % old_moves.size())
		var enabled: Array = []
		for i in d.moves.size():
			enabled.append(true)
		enabled.append(not old_moves.is_empty())
		list.describe = func(i: int) -> String:
			if i < d.moves.size():
				return MoveText.describe(d.moves[i]["id"], int(d.moves[i]["pp"]))
			return "Moves %s learned before. Install one again." % d.display_name()
		var r := await list.choose("%s · MOVES   pick one to move it" % d.display_name(), rows, enabled, start)
		list.describe = Callable()
		if r["action"] != "pick":
			break
		if r["index"] >= d.moves.size():
			var pick := await _pick_move("Re-install which move?", old_moves)
			if not pick.is_empty():
				await offer_move(d, pick)
			continue
		start = r["index"]
		var where := await list.choose("Move %s to which slot?" % MoveText.name_of(d.moves[start]["id"]), _slot_rows(d), [], start)
		if where["action"] == "pick" and d.swap_moves(start, where["index"]):
			start = where["index"]
	list.close()


## Installs move_id: straight into a free slot, or asks which move to replace (cursor on NO when
## confirming). Returns true if it was installed.
func offer_move(d: DaemonInstance, move_id: String) -> bool:
	var new_name := MoveText.name_of(move_id)
	if d.knows_move(move_id):
		return false
	if d.learn_move(move_id):
		AudioManager.play_sfx("confirm")
		await _say("%s installed %s!" % [d.display_name(), new_name])
		return true
	while true:
		list.describe = func(i: int) -> String:
			return MoveText.describe(d.moves[i]["id"], int(d.moves[i]["pp"])) if i < d.moves.size() else MoveText.describe(move_id)
		var rows := _slot_rows(d)
		rows.append("KEEP MY MOVES")
		var r := await list.choose("Replace which move with %s?" % new_name, rows)
		list.describe = Callable()
		if r["action"] != "pick" or r["index"] >= d.moves.size():
			if world == null or await world.ask("Skip installing %s?" % new_name, "", false):
				break
			continue
		var old_name := MoveText.name_of(d.moves[r["index"]]["id"])
		if world == null or await world.ask("Forget %s and install %s?" % [old_name, new_name], "", false):
			d.learn_move(move_id, r["index"])
			AudioManager.play_sfx("confirm")
			list.close()
			await _say("%s uninstalled %s and installed %s!" % [d.display_name(), old_name, new_name])
			return true
	list.close()
	await _say("%s kept its moves. %s can be installed later from STACK > MOVES." % [d.display_name(), new_name])
	return false


func _slot_rows(d: DaemonInstance) -> PackedStringArray:
	var rows := PackedStringArray()
	for i in d.moves.size():
		rows.append("%d  %s" % [i + 1, MoveText.name_of(d.moves[i]["id"])])
	return rows


func _pick_move(title: String, ids: PackedStringArray) -> String:
	var rows := PackedStringArray()
	for id in ids:
		rows.append(MoveText.name_of(id))
	list.describe = func(i: int) -> String: return MoveText.describe(ids[i]) if i < ids.size() else ""
	var r := await list.choose(title, rows)
	list.describe = Callable()
	return ids[r["index"]] if r["action"] == "pick" else ""


func stack_rows() -> PackedStringArray:
	var rows := PackedStringArray()
	for d: DaemonInstance in GameState.active_stack:
		var tag := "CRASHED" if d.is_fainted() else d.status.to_upper().left(3)
		rows.append("%-10s Lv%-3d %3d/%-3d %s" % [d.display_name(), d.level, d.current_uptime, d.max_uptime(), tag])
	return rows


# --- Bag ---------------------------------------------------------------------

## Bag pages: the 4 item pockets, then QUARANTINED (corrupted Hexforged you caught, waiting for a Help Desk).
const QUARANTINED_PAGE := 4


func bag_screen() -> void:
	var pocket := 0
	var start := 0
	while true:
		if pocket == QUARANTINED_PAGE:
			var q := await _show_quarantined()
			if q["action"] == "left" or q["action"] == "right":
				pocket = wrapi(pocket + (1 if q["action"] == "right" else -1), 0, POCKETS.size() + 1)
				start = 0
				continue
			if q["action"] != "pick":
				break
			await _say("It's locked down until a Help Desk scans it. Have you tried turning it off and on again?")
			continue
		var ids := pocket_items(POCKETS[pocket])
		var r := await _show_pocket(pocket, ids, start)
		if r["action"] == "left" or r["action"] == "right":
			pocket = wrapi(pocket + (1 if r["action"] == "right" else -1), 0, POCKETS.size() + 1)
			start = 0
			continue
		if r["action"] != "pick":
			break
		start = r["index"]
		var item_id: String = ids[start]
		var choice := await sub.choose(DataRegistry.get_item(item_id)["name"], PackedStringArray(["USE", "TOSS", "CANCEL"]))
		sub.close()
		if choice["action"] != "pick":
			continue
		match choice["index"]:
			0:
				await _use_item(item_id)
			1:
				await _toss(item_id)
	list.close()


## Help Desk cleaning: the shared CleanEffect on a dark panel, corrupted idle -> clean idle. Awaitable.
func clean_animation(d: DaemonInstance) -> void:
	var panel := ColorRect.new()
	panel.color = Color(0.03, 0.04, 0.08, 0.92)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var fx := CleanEffect.new()
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.offset_bottom = -48  # clear of the text box
	fx.time_scale = world.time_scale if world != null else 1.0
	panel.add_child(fx)
	var clean_tex := DaemonSprites.pose(d.species_id, "idle")
	if clean_tex == null:
		clean_tex = DaemonSprites.front(d.species_id)
	AudioManager.play_sfx("error")
	await fx.play(DaemonSprites.corrupted_pose(d.species_id, "idle"), clean_tex)
	AudioManager.play_sfx("unlock")
	panel.queue_free()


## The QUARANTINED page: one row per corrupted Hexforged you're holding. They can't battle or be used.
func quarantined_rows() -> PackedStringArray:
	var rows := PackedStringArray()
	for d: DaemonInstance in GameState.quarantined:
		rows.append("%-16s Lv%d" % [d.display_name(), d.level])
	return rows


func _show_quarantined() -> Dictionary:
	var rows := quarantined_rows()
	var enabled: Array = []
	if rows.is_empty():
		rows.append("(empty)")
		enabled = [false]
	list.allow_lr = true
	list.describe = func(_i: int) -> String: return "Corrupted. Can't battle. Any Help Desk can clean it."
	var r := await list.choose("QUARANTINED", rows, enabled, 0)
	list.allow_lr = false
	list.describe = Callable()
	return r


func pocket_items(pocket: String) -> Array[String]:
	var ids: Array[String] = []
	for item_id: String in DataRegistry.items:  # data order keeps the bag tidy
		if DataRegistry.items[item_id]["pocket"] == pocket and int(GameState.bag.get(item_id, 0)) > 0:
			ids.append(item_id)
	return ids


func _show_pocket(pocket: int, ids: Array[String], start: int, title_suffix: String = "") -> Dictionary:
	var rows := PackedStringArray()
	for item_id in ids:
		rows.append("%-16s x%d" % [DataRegistry.get_item(item_id)["name"], int(GameState.bag[item_id])])
	var enabled: Array = []
	if rows.is_empty():
		rows.append("(empty)")
		enabled = [false]
	list.allow_lr = true
	list.describe = func(i: int) -> String: return DataRegistry.get_item(ids[i])["description"] if i < ids.size() else ""
	var r := await list.choose("%s%s" % [POCKET_NAMES[POCKETS[pocket]], title_suffix], rows, enabled, start)
	list.allow_lr = false
	list.describe = Callable()
	return r


func _use_item(item_id: String) -> void:
	if ItemUse.needs_target(item_id):
		var r := await list.choose("Use on which Hexforged?", stack_rows())
		if r["action"] == "pick":
			await _use_on(item_id, GameState.active_stack[r["index"]])
	else:
		await _say_all(ItemUse.use_in_field(item_id)["messages"])


func _toss(item_id: String) -> void:
	if DataRegistry.get_item(item_id)["pocket"] == "key_items":
		await _say("That's too important to throw away.")
		return
	var qty := await choose_quantity(int(GameState.bag[item_id]), 0)
	if qty <= 0:
		return
	var item_name: String = DataRegistry.get_item(item_id)["name"]
	if await world.ask("Toss %d %s?" % [qty, item_name]):
		GameState.bag[item_id] = int(GameState.bag[item_id]) - qty
		if int(GameState.bag[item_id]) <= 0:
			GameState.bag.erase(item_id)
		await _say("Tossed %d %s." % [qty, item_name])


## Lets the player pick any bag item that passes `filter`. Returns "" if they back out.
func _pick_bag_item(title: String, filter: Callable) -> String:
	var ids: Array[String] = []
	for pocket: String in POCKETS:
		for item_id in pocket_items(pocket):
			if filter.call(item_id):
				ids.append(item_id)
	if ids.is_empty():
		await _say("You don't have anything that can be used on it.")
		return ""
	var rows := PackedStringArray()
	for item_id in ids:
		rows.append("%-16s x%d" % [DataRegistry.get_item(item_id)["name"], int(GameState.bag[item_id])])
	var r := await list.choose(title, rows)
	return ids[r["index"]] if r["action"] == "pick" else ""


# --- CMDB --------------------------------------------------------------------

func cmdb_screen() -> void:
	var ids: Array = DataRegistry.species.keys()
	var start := 0
	while true:
		var rows := PackedStringArray()
		var enabled: Array = []
		for i in ids.size():
			var seen: bool = GameState.cmdb_seen.get(ids[i], false)
			var caught: bool = GameState.cmdb_caught.get(ids[i], false)
			rows.append("#%03d %-11s %s" % [DataRegistry.cmdb_number(ids[i]), DataRegistry.species[ids[i]]["name"] if seen else "----------", "*" if caught else ""])
			enabled.append(seen)
		list.describe = func(_i: int) -> String: return "SEEN %d   QUARANTINED* %d" % [GameState.cmdb_seen.size(), GameState.cmdb_caught.size()]
		var r := await list.choose("CMDB", rows, enabled, start)
		list.describe = Callable()
		if r["action"] != "pick":
			break
		start = r["index"]
		list.visible = false
		await cmdb_panel.open(ids[start])
	list.close()


# --- Server Rack -------------------------------------------------------------

func rack_screen() -> void:
	var options := PackedStringArray(["WITHDRAW", "DEPOSIT", "MOVE", "CLOSE"])
	var start := 0
	while true:
		var r := await side.choose("SERVER RACK", options, [], start)
		if r["action"] != "pick" or r["index"] == 3:
			break
		start = r["index"]
		side.close()
		match r["index"]:
			0:
				var pick := await _pick_from_racks("Withdraw which?")
				if not pick.is_empty():
					var d: DaemonInstance = GameState.racks[pick[0]][pick[1]]
					var reason := GameState.withdraw(pick[0], pick[1])
					await _say(reason if not reason.is_empty() else "%s joined your Active Stack." % d.display_name())
			1:
				var s := await list.choose("Deposit which?", stack_rows())
				if s["action"] == "pick":
					var rack := await _pick_rack("Into which rack?")
					if rack >= 0:
						var d: DaemonInstance = GameState.active_stack[s["index"]]
						var reason := GameState.deposit(s["index"], rack)
						await _say(reason if not reason.is_empty() else "%s was stored in Rack %d." % [d.display_name(), rack + 1])
			2:
				var pick := await _pick_from_racks("Move which?")
				if not pick.is_empty():
					var rack := await _pick_rack("Move to which rack?")
					if rack >= 0:
						var reason := GameState.move_between_racks(pick[0], pick[1], rack)
						await _say(reason if not reason.is_empty() else "Moved to Rack %d." % (rack + 1))
		list.close()
	side.close()
	list.close()


## Browse racks with left/right. Returns [rack, slot] or [] if backed out.
func _pick_from_racks(title: String) -> Array:
	while true:
		var rack: Array = GameState.racks[_last_rack]
		var rows := PackedStringArray()
		for d: DaemonInstance in rack:
			rows.append("%-10s Lv%-3d %s" % [d.display_name(), d.level, DataRegistry.get_species(d.species_id)["name"]])
		var enabled: Array = []
		if rows.is_empty():
			rows.append("(empty)")
			enabled = [false]
		list.allow_lr = true
		var r := await list.choose("%s  RACK %d (%d/%d)" % [title, _last_rack + 1, rack.size(), GameState.RACK_SLOTS], rows, enabled)
		list.allow_lr = false
		match r["action"]:
			"left":
				_last_rack = wrapi(_last_rack - 1, 0, GameState.RACKS)
			"right":
				_last_rack = wrapi(_last_rack + 1, 0, GameState.RACKS)
			"pick":
				return [_last_rack, r["index"]]
			_:
				return []
	return []


func _pick_rack(title: String) -> int:
	var rows := PackedStringArray()
	for i in GameState.RACKS:
		rows.append("RACK %-2d  %2d/%d" % [i + 1, GameState.racks[i].size(), GameState.RACK_SLOTS])
	var r := await list.choose(title, rows, [], _last_rack)
	return r["index"] if r["action"] == "pick" else -1


# --- Supply Closet -----------------------------------------------------------

func shop(stock: Array) -> void:
	var options := PackedStringArray(["BUY", "SELL", "QUIT"])
	var start := 0
	while true:
		_hide_talk()
		var r := await side.choose("SUPPLY CLOSET", options, [], start)
		if r["action"] != "pick" or r["index"] == 2:
			break
		start = r["index"]
		side.close()
		if r["index"] == 0:
			await _buy(stock)
		else:
			await _sell()
		list.close()
	side.close()
	list.close()
	await _say("Thanks! Please close the door, the AC is on.")


func _buy(stock: Array) -> void:
	var start := 0
	while true:
		var rows := PackedStringArray()
		for item_id: String in stock:
			rows.append("%-15s %5d CR" % [DataRegistry.get_item(item_id)["name"], Shop.price(item_id)])
		list.describe = func(i: int) -> String: return DataRegistry.get_item(stock[i])["description"]
		_hide_talk()
		var r := await list.choose("BUY      You have %d CR" % GameState.credits, rows, [], start)
		list.describe = Callable()
		if r["action"] != "pick":
			return
		start = r["index"]
		var item_id: String = stock[start]
		var most := Shop.max_buyable(item_id)
		if most <= 0:
			await _say(Shop.buy(item_id, 1))
			continue
		var qty := await choose_quantity(most, Shop.price(item_id))
		if qty <= 0:
			continue
		var item_name: String = DataRegistry.get_item(item_id)["name"]
		if await world.ask("%d %s will be %d CR. OK?" % [qty, item_name, qty * Shop.price(item_id)]):
			var reason := Shop.buy(item_id, qty)
			AudioManager.play_sfx("confirm")
			await _say(reason if not reason.is_empty() else "Here you go! Thank you.")


func _sell() -> void:
	var pocket := 0
	var start := 0
	while true:
		var ids := pocket_items(POCKETS[pocket])
		_hide_talk()
		var r := await _show_pocket(pocket, ids, start, "  SELL  %d CR" % GameState.credits)
		if r["action"] == "left" or r["action"] == "right":
			pocket = wrapi(pocket + (1 if r["action"] == "right" else -1), 0, POCKETS.size())
			start = 0
			continue
		if r["action"] != "pick":
			return
		start = r["index"]
		var item_id: String = ids[start]
		if not Shop.can_sell(item_id):
			await _say(Shop.sell(item_id, 1))
			continue
		var qty := await choose_quantity(int(GameState.bag[item_id]), Shop.sell_price(item_id))
		if qty <= 0:
			continue
		if await world.ask("I can pay %d CR for that. OK?" % (qty * Shop.sell_price(item_id))):
			var reason := Shop.sell(item_id, qty)
			AudioManager.play_sfx("confirm")
			await _say(reason if not reason.is_empty() else "Turned over the item and received %d CR." % (qty * Shop.sell_price(item_id)))


## The clerk's speech box sits over the list's description line; close it while browsing
## (player feedback, 2026-11-14: "no description, hard to know what they are buying").
func _hide_talk() -> void:
	if world != null:
		world.text_box.visible = false
		world.hide_speaker()


## YES / NO next to the text box (the question itself is in the text box). BACK counts as NO.
## default_yes = false starts on NO, for anything that throws something away.
func confirm(default_yes: bool = true) -> bool:
	if world != null:  # stay clear of the touch buttons on the right
		yes_no.offset_right = -4.0 - TouchControls.reserved_right()
		yes_no.offset_left = yes_no.offset_right - 58.0
	var r := await yes_no.choose("", PackedStringArray(["YES", "NO"]), [], 0 if default_yes else 1)
	yes_no.close()
	return r["action"] == "pick" and r["index"] == 0


# --- quantity chooser --------------------------------------------------------

## Up/down = 1, left/right = 10. Accept returns the amount, cancel returns 0.
## unit_price > 0 also shows the total in credits.
func choose_quantity(maximum: int, unit_price: int) -> int:
	if world != null and world.auto_choice != null:
		return 1 if world.auto_choice else 0
	_qty = 1
	_qty_max = maxi(1, maximum)
	_qty_price = unit_price
	_render_qty()
	_qty_panel.visible = true
	_qty_open = true
	var qty: int = await _qty_done
	_qty_panel.visible = false
	return qty


func _render_qty() -> void:
	_qty_label.text = "x%2d" % _qty + ("   %d CR" % (_qty * _qty_price) if _qty_price > 0 else "")


func _unhandled_input(event: InputEvent) -> void:
	if not _qty_open:
		return
	var change := 0
	if event.is_action_pressed("ui_up", true):
		change = 1
	elif event.is_action_pressed("ui_down", true):
		change = -1
	elif event.is_action_pressed("ui_right", true):
		change = 10
	elif event.is_action_pressed("ui_left", true):
		change = -10
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_qty_open = false
		_qty_done.emit.call_deferred(_qty if event.is_action_pressed("ui_accept") else 0)
	else:
		return
	get_viewport().set_input_as_handled()
	if change != 0:
		_qty = clampi(_qty + change, 1, _qty_max)
		_render_qty()


# --- messages ----------------------------------------------------------------

func _say(text: String) -> void:
	if world != null and not text.is_empty():
		await world.show_message(text)


func _say_all(lines: Array) -> void:
	for line: String in lines:
		await _say(line)
