class_name BattleInfoPanel
extends Panel
## Name / level / status / Uptime bar box. The player's version also shows Uptime numbers and
## an EXP bar. Bars animate smoothly; the numbers count along with the bar.

const STATUS_TAGS := {
	"throttled": ["THR", Color("d8a820")], "corrupted": ["COR", Color("9050c0")],
	"overheated": ["OVH", Color("e06020")], "standby": ["SBY", Color("8890a0")],
	"hung": ["HNG", Color("4098d0")],
}
const BAR_BG := Color("384058")
const BAR_GREEN := Color("48c048")
const BAR_YELLOW := Color("e8c030")
const BAR_RED := Color("e04830")
const EXP_BLUE := Color("4080e0")

var is_player := false
var time_scale: float = 1.0
var max_uptime: int = 1
var shown_uptime: float = 0.0:
	set(value):
		shown_uptime = value
		if _numbers != null:
			_numbers.text = "%d/%d" % [roundi(value), max_uptime]
		queue_redraw()
var exp_ratio: float = 0.0:
	set(value):
		exp_ratio = clampf(value, 0.0, 1.0)
		queue_redraw()

var _name: Label
var _level: Label
var _tag: Label
var _numbers: Label


func setup(p_is_player: bool) -> void:
	is_player = p_is_player
	custom_minimum_size = Vector2(138, 40) if is_player else Vector2(124, 30)
	_name = _add_label(Vector2(6, 5), HORIZONTAL_ALIGNMENT_LEFT)
	_level = _add_label(Vector2(6, 5), HORIZONTAL_ALIGNMENT_RIGHT)
	_level.offset_right = -6
	_tag = _add_label(Vector2(6, 16), HORIZONTAL_ALIGNMENT_LEFT)
	_tag.add_theme_color_override("font_color", Color("707088"))
	if is_player:
		_numbers = _add_label(Vector2(6, 26), HORIZONTAL_ALIGNMENT_RIGHT)
		_numbers.offset_right = -6


func show_daemon(display_name: String, level: int, uptime: int, maximum: int, status: String, exp_fraction: float = 0.0) -> void:
	_name.text = display_name
	set_level(level)
	set_status(status)
	max_uptime = maxi(1, maximum)
	shown_uptime = uptime
	exp_ratio = exp_fraction
	visible = true


func set_level(level: int) -> void:
	_level.text = "Lv%d" % level


func set_status(status: String) -> void:
	if STATUS_TAGS.has(status):
		_tag.text = STATUS_TAGS[status][0]
		_tag.add_theme_color_override("font_color", STATUS_TAGS[status][1])
	else:
		_tag.text = "UP"
		_tag.add_theme_color_override("font_color", Color("707088"))


func set_uptime(uptime: int, maximum: int) -> void:
	max_uptime = maxi(1, maximum)
	shown_uptime = uptime


func animate_uptime(to: int, maximum: int) -> void:
	max_uptime = maxi(1, maximum)
	var duration := clampf(absf(to - shown_uptime) / max_uptime * 1.2, 0.2, 1.0) * time_scale
	var tween := create_tween()
	tween.tween_property(self, "shown_uptime", float(to), duration)
	await tween.finished


func animate_exp(to_ratio: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "exp_ratio", clampf(to_ratio, 0.0, 1.0), 0.5 * time_scale)
	await tween.finished


func _draw() -> void:
	var bar := Rect2(32, 18, size.x - 40, 5)
	draw_rect(bar.grow(1), BAR_BG)
	var ratio := clampf(shown_uptime / max_uptime, 0.0, 1.0)
	var color := BAR_GREEN if ratio > 0.5 else (BAR_YELLOW if ratio > 0.2 else BAR_RED)
	draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * ratio), bar.size.y)), color)
	if is_player:
		var exp_bar := Rect2(32, size.y - 5, size.x - 40, 2)
		draw_rect(exp_bar.grow(1), BAR_BG)
		draw_rect(Rect2(exp_bar.position, Vector2(roundf(exp_bar.size.x * exp_ratio), exp_bar.size.y)), EXP_BLUE)


func _add_label(pos: Vector2, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.anchor_right = 1.0
	label.offset_left = pos.x
	label.offset_top = pos.y
	label.horizontal_alignment = align
	add_child(label)
	return label
