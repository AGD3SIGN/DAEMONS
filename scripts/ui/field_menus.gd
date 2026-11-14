class_name FieldMenus
extends Control
## Menus used outside battle, all as awaitable flows:
##   open_pause()        CMDB / STACK / BAG / CARD / SAVE / OPTIONS (+ DEBUG in debug builds)
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
	side.setup(Vector4(1, 0, 1, 0), Vector4(-112, 6, -6, 6 + 17 + 8 * MenuList.ROW_H + 6), 8)
	add_child(side)
	sub = MenuList.new()
	sub.setup(Vector4(1, 1, 1, 1), Vector4(-112, -6 - (17 + 4 * MenuList.ROW_H + 6), -6, -6), 4)
	add_child(sub)
	summary = SummaryPanel.new()
	add_child(summary)
	cmdb_panel = CmdbPanel.new()
	add_child(cmdb_panel)
	card = TrainerCardPanel.new()
	add_child(card)
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

func open_pause() -> void:
	var options := PackedStringArray(["CMDB", "STACK", "BAG", "CARD", "SAVE", "OPTIONS"])
	if OS.is_debug_build():
		options.append("DEBUG")
	options.append("CLOSE")
	var start := 0
	while true:
		var r := await side.choose("MENU", options, [], start)
		if r["action"] != "pick" or options[r["index"]] == "CLOSE":
			break
		start = r["index"]
		side.close()
		match options[r["index"]]:
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
			"OPTIONS":
				await options_screen()
			"DEBUG":
				SceneRouter.goto(DEBUG_MENU)
				return
	side.close()


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
	for letters in NAME_KEY_ROWS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		box.add_child(row)
		for ch in letters:
			add_key.call(row, ch, 18.0, func() -> void:
				if edit.text.length() < NAME_MAX:
					edit.text += ch
					edit.caret_column = edit.text.length())
		if letters.length() < 10:
			add_key.call(row, "SPC", 26.0, func() -> void:
				if edit.text.length() < NAME_MAX and not edit.text.is_empty():
					edit.text += " ")
			add_key.call(row, "DEL", 26.0, func() -> void:
				edit.text = edit.text.left(-1))
			add_key.call(row, "OK", 22.0, func() -> void:
				edit.text_submitted.emit(edit.text))
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
			"DONE",
		])
		list.allow_lr = true
		list.describe = func(i: int) -> String: return ["How fast text types out.", "Background music (coming with the soundtrack).",
			"Sound effects.", "Turn off to skip battle animations.",
			"Phones/tablets: save when the app goes to the background.",
			"Title screen scanlines and scan bar.", "Stops the title screen's bigger animations.", "Save and close."][i]
		var r := await list.choose("OPTIONS   (left/right to change)", rows, [], cursor)
		list.allow_lr = false
		list.describe = Callable()
		cursor = r["index"]
		if r["action"] == "cancel" or (r["action"] == "pick" and cursor == 7):
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
		var choice := await sub.choose(d.display_name(), PackedStringArray(["SUMMARY", "SWAP", "ITEM", "CANCEL"]))
		sub.close()
		if choice["action"] != "pick":
			continue
		match choice["index"]:
			0:
				await summary.open(GameState.active_stack, start)
			1:
				var other := await list.choose("Swap %s with?" % d.display_name(), stack_rows(), [], start)
				if other["action"] == "pick":
					GameState.swap_stack(start, other["index"])
					start = other["index"]
			2:
				var item_id := await _pick_bag_item("Use which item?", func(id: String) -> bool: return ItemUse.needs_target(id))
				if not item_id.is_empty():
					await _say_all(ItemUse.use_on(item_id, d)["messages"])
	list.close()


func stack_rows() -> PackedStringArray:
	var rows := PackedStringArray()
	for d: DaemonInstance in GameState.active_stack:
		var tag := "CRASHED" if d.is_fainted() else d.status.to_upper().left(3)
		rows.append("%-10s Lv%-3d %3d/%-3d %s" % [d.display_name(), d.level, d.current_uptime, d.max_uptime(), tag])
	return rows


# --- Bag ---------------------------------------------------------------------

func bag_screen() -> void:
	var pocket := 0
	var start := 0
	while true:
		var ids := pocket_items(POCKETS[pocket])
		var r := await _show_pocket(pocket, ids, start)
		if r["action"] == "left" or r["action"] == "right":
			pocket = wrapi(pocket + (1 if r["action"] == "right" else -1), 0, POCKETS.size())
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
		var r := await list.choose("Use on which Daemon?", stack_rows())
		if r["action"] == "pick":
			await _say_all(ItemUse.use_on(item_id, GameState.active_stack[r["index"]])["messages"])
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
