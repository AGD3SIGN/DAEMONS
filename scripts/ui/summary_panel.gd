class_name SummaryPanel
extends Panel
## A Daemon's summary in three pages: INFO (sprite, level, types, profile, CMDB entry),
## STATS (all six with Config Profile +/-), MOVES (type, PP, power, accuracy).
## Left/right flips pages, up/down switches Daemon, X/Z (or a click) closes.
## Build Quality stays hidden on purpose.

signal _closed

const PAGES := ["INFO", "STATS", "MOVES"]

var _stack: Array = []
var _index := 0
var _page := 0
var _open := false
var _sprite: TextureRect
var _header: Label
var _name: Label
var _body: Label
var _footer: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # let taps reach _unhandled_input (tap anywhere to continue)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 6
	offset_top = 6
	offset_right = -6
	offset_bottom = -6
	_header = _label(Vector2(8, 5))
	_name = _label(Vector2(8, 17))
	_sprite = TextureRect.new()
	_sprite.position = Vector2(8, 30)
	_sprite.size = Vector2(64, 64)
	add_child(_sprite)
	_body = _label(Vector2(80, 30))
	_body.add_theme_constant_override("line_spacing", 2)
	_footer = _label(Vector2(8, 100))
	_footer.size = Vector2(290, 60)
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer.add_theme_color_override("font_color", Color("505068"))
	_footer.add_theme_constant_override("line_spacing", 2)
	visible = false


func open(stack: Array, index: int) -> void:
	_stack = stack
	_index = index
	_page = 0
	_render()
	visible = true
	_open = true
	await _closed
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("ui_right"):
		_page = wrapi(_page + 1, 0, PAGES.size())
	elif event.is_action_pressed("ui_left"):
		_page = wrapi(_page - 1, 0, PAGES.size())
	elif event.is_action_pressed("ui_down"):
		_index = wrapi(_index + 1, 0, _stack.size())
	elif event.is_action_pressed("ui_up"):
		_index = wrapi(_index - 1, 0, _stack.size())
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept") \
			or (event is InputEventMouseButton and event.pressed):
		_open = false
		_closed.emit.call_deferred()
	else:
		return
	get_viewport().set_input_as_handled()
	_render()


func _render() -> void:
	var d: DaemonInstance = _stack[_index]
	var data := d.species_data()
	_header.text = "< %s >   %d/%d" % [PAGES[_page], _index + 1, _stack.size()]
	_name.text = "%s  Lv%d" % [d.display_name(), d.level]
	_sprite.texture = DaemonSprites.front(d.species_id)
	var types := "/".join(d.types().map(func(t: String) -> String: return String(DataRegistry.types[t]["name"]).to_upper()))
	var lines := PackedStringArray()
	_footer.text = ""
	match PAGES[_page]:
		"INFO":
			var profile: Dictionary = DataRegistry.config_profiles.get(d.config_profile, {})
			lines.append(String(data["name"]))
			lines.append(types)
			lines.append("Uptime %d/%d" % [d.current_uptime, d.max_uptime()])
			lines.append("Status: %s" % ("OK" if d.status.is_empty() else d.status.capitalize()))
			lines.append("Profile: %s" % profile.get("name", "?"))
			lines.append("EXP to next: %d" % d.exp_to_next_level())
			_footer.text = "%s. %s" % [data["cmdb"]["category"], data["cmdb"]["entry"]]
		"STATS":
			for stat: String in DaemonInstance.STATS:
				var mark := "+" if d.profile_percent(stat) > 100 else ("-" if d.profile_percent(stat) < 100 else " ")
				var value := "%d/%d" % [d.current_uptime, d.max_uptime()] if stat == "uptime" else str(d.get_stat(stat))
				lines.append("%-11s%s %s" % [BattleText.STAT_NAMES.get(stat, "Uptime"), mark, value])
		"MOVES":
			for slot: Dictionary in d.moves:
				var move := DataRegistry.get_move(slot["id"])
				lines.append("%-15s PP%2d/%-2d" % [move["name"], int(slot["pp"]), int(move["max_pp"])])
			_footer.text = _move_details(d)
	_body.text = "\n".join(lines)


## One line per move: type, category, power, accuracy ("-" = none / never misses).
static func _move_details(d: DaemonInstance) -> String:
	var parts := PackedStringArray()
	for slot: Dictionary in d.moves:
		var move := DataRegistry.get_move(slot["id"])
		var power := "-" if int(move["power"]) == 0 else str(int(move["power"]))
		var accuracy := "-" if int(move["accuracy"]) == 0 else str(int(move["accuracy"]))
		parts.append("%-14s %s %s P%-3s A%s" % [move["name"], String(DataRegistry.types[move["type"]]["name"]).left(3).to_upper(),
			String(move["category"]).left(3).to_upper(), power, accuracy])
	return "\n".join(parts)


func _label(pos: Vector2) -> Label:
	var label := Label.new()
	label.position = pos
	add_child(label)
	return label
