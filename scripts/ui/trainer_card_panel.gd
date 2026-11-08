class_name TrainerCardPanel
extends Panel
## Trainer card: name, ID, credits, CMDB count, play time and the 8 Certifications
## (filled in with the department's type color once earned).

signal _closed

var _open := false
var _info: Label
var _badges: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 6
	offset_top = 6
	offset_right = -6
	offset_bottom = -6
	var title := Label.new()
	title.text = "TRAINER CARD - ROOT VALLEY IT"
	title.position = Vector2(8, 6)
	add_child(title)
	_info = Label.new()
	_info.position = Vector2(8, 22)
	_info.add_theme_constant_override("line_spacing", 3)
	add_child(_info)
	var header := Label.new()
	header.text = "CERTIFICATIONS"
	header.position = Vector2(8, 96)
	add_child(header)
	_badges = Badges.new()
	_badges.position = Vector2(8, 110)
	_badges.size = Vector2(292, 48)
	add_child(_badges)
	visible = false


func open() -> void:
	var name := GameState.player_name if not GameState.player_name.is_empty() else DialogueRunner.DEFAULT_PLAYER_NAME
	_info.text = "NAME     %s\nID No.   %05d\nCREDITS  %d CR\nCMDB     %d quarantined\nTIME     %s" % [
		name, GameState.trainer_id, GameState.credits, GameState.cmdb_caught.size(), format_time(GameState.play_time_sec)]
	_badges.queue_redraw()
	visible = true
	_open = true
	await _closed
	visible = false


static func format_time(seconds: float) -> String:
	var minutes := int(seconds) / 60
	return "%d:%02d" % [minutes / 60, minutes % 60]


func _unhandled_input(event: InputEvent) -> void:
	if _open and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept") \
			or (event is InputEventMouseButton and event.pressed)):
		get_viewport().set_input_as_handled()
		_open = false
		_closed.emit.call_deferred()


class Badges extends Control:
	func _draw() -> void:
		var certs: Array = DataRegistry.certifications.values()
		certs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["order"]) < int(b["order"]))
		var font := UiTheme.get_theme().default_font
		for i in certs.size():
			var cert: Dictionary = certs[i]
			var rect := Rect2(i * 36, 0, 30, 30)
			var earned: bool = cert["id"] in GameState.certifications
			var color := Color(String(DataRegistry.types[cert["type"]]["color"])) if earned else Color("d8d8d0")
			draw_rect(rect, color)
			draw_rect(rect, UiTheme.BORDER, false, 2.0)
			var abbrev := String(DataRegistry.types[cert["type"]]["name"]).left(3).to_upper()
			draw_string(font, Vector2(rect.position.x + 3, rect.position.y + 19), abbrev, HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
				Color.WHITE if earned else UiTheme.MUTED)
			draw_string(font, Vector2(rect.position.x + 11, rect.position.y + 44), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.INK)
