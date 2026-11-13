class_name BattleInfoPanel
extends Control
## A Daemon's status card, built as a "process card" (Battle Scene spec, 2026-11-13): panel fill, a 3 px
## border in the side color, a solid 6 px black drop shadow, no rounded corners.
##   Wild / foe card (430 wide): [WILD] [UNVERIFIED] ... Lv / big name / UP + 20-segment bar + percent.
##   Player card (420 wide):     [HOST] name ... Lv / UP + 20-segment bar + HP/MAX, plus a thin EXP strip.
## The UP bar empties one segment at a time (about 40 ms each) when damage lands.

const STATUS_TAGS := {
	"throttled": ["THR", Color("d8a820")], "corrupted": ["COR", Color("b070e0")],
	"overheated": ["OVH", Color("ff7a3d")], "standby": ["SBY", Color("8fa8cf")],
	"hung": ["HNG", Color("4ab0f0")],
}
const WILD_SIZE := Vector2(430, 120)
const PLAYER_SIZE := Vector2(420, 86)
const SEGMENT_TIME := 0.04

var is_player := false
## Foe card only: true = a wild Daemon (WILD + UNVERIFIED), false = a trainer's (HOSTILE).
var wild := true:
	set(value):
		wild = value
		queue_redraw()
var time_scale: float = 1.0
var max_uptime: int = 1
var shown_uptime: float = 0.0:
	set(value):
		shown_uptime = value
		queue_redraw()
var exp_ratio: float = 0.0:
	set(value):
		exp_ratio = clampf(value, 0.0, 1.0)
		queue_redraw()
var display_name := ""
var level := 1
var status := ""


func setup(p_is_player: bool) -> void:
	is_player = p_is_player
	size = PLAYER_SIZE if is_player else WILD_SIZE
	custom_minimum_size = size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_daemon(p_name: String, p_level: int, uptime: int, maximum: int, p_status: String, exp_fraction: float = 0.0) -> void:
	display_name = p_name
	level = p_level
	status = p_status
	max_uptime = maxi(1, maximum)
	shown_uptime = uptime
	exp_ratio = exp_fraction
	visible = true
	queue_redraw()


func set_level(p_level: int) -> void:
	level = p_level
	queue_redraw()


func set_status(p_status: String) -> void:
	status = p_status
	queue_redraw()


func set_uptime(uptime: int, maximum: int) -> void:
	max_uptime = maxi(1, maximum)
	shown_uptime = uptime


func fraction() -> float:
	return clampf(shown_uptime / max_uptime, 0.0, 1.0)


## Drains or fills the bar a segment at a time; the numbers count along with it.
func animate_uptime(to: int, maximum: int) -> void:
	max_uptime = maxi(1, maximum)
	var from_seg := BattleStyle.segments(fraction())
	var to_seg := BattleStyle.segments(clampf(float(to) / max_uptime, 0.0, 1.0))
	var duration := maxi(1, absi(to_seg - from_seg)) * SEGMENT_TIME * time_scale
	var tween := create_tween()
	tween.tween_property(self, "shown_uptime", float(to), duration)
	await tween.finished


func animate_exp(to_ratio: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "exp_ratio", clampf(to_ratio, 0.0, 1.0), 0.5 * time_scale)
	await tween.finished


func side_color() -> Color:
	return BattleStyle.HOST if is_player else BattleStyle.WILD


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	BattleStyle.draw_panel(self, r, BattleStyle.PANEL, side_color())
	if is_player:
		_draw_player()
	else:
		_draw_wild()


func _status_tag(x: float, y: float) -> float:
	if not STATUS_TAGS.has(status):
		return 0.0
	return BattleStyle.draw_tag(self, Vector2(x, y), STATUS_TAGS[status][0], STATUS_TAGS[status][1], true,
		BattleStyle.ON_WILD)


func _draw_wild() -> void:
	var pad_x := 16.0
	var y := 12.0
	# Row 1: WILD + UNVERIFIED tags (HOSTILE for a trainer's Daemon), status, level right-aligned.
	var x := pad_x
	if wild:
		x += BattleStyle.draw_tag(self, Vector2(x, y + 2), "WILD", BattleStyle.WILD, true, BattleStyle.ON_WILD) + 6
		x += BattleStyle.draw_tag(self, Vector2(x, y + 2), "UNVERIFIED", BattleStyle.WILD, false, BattleStyle.ON_WILD) + 6
	else:
		x += BattleStyle.draw_tag(self, Vector2(x, y + 2), "HOSTILE", BattleStyle.WILD, true, BattleStyle.ON_WILD) + 6
	_status_tag(x, y + 2)
	var bold := BattleStyle.pixelify(700)
	draw_string(bold, Vector2(pad_x, y + bold.get_ascent(22)), "Lv%d" % level, HORIZONTAL_ALIGNMENT_RIGHT,
		size.x - pad_x * 2, 22, BattleStyle.TEXT_PRIMARY)
	# Row 2: the name.
	y += 24 + 6
	draw_string(bold, Vector2(pad_x, y + bold.get_ascent(36)), display_name, HORIZONTAL_ALIGNMENT_LEFT,
		size.x - pad_x * 2, 36, Color.WHITE)
	# Row 3: UP label, bar, percentage.
	y += 38 + 6
	_draw_up_row(Vector2(pad_x, y), size.x - pad_x * 2, 22, 12, "%d%%" % roundi(fraction() * 100.0), 46, 22)


func _draw_player() -> void:
	var pad_x := 16.0
	var y := 10.0
	var x := pad_x
	x += BattleStyle.draw_tag(self, Vector2(x, y + 4), "HOST", BattleStyle.HOST, true, BattleStyle.ON_HOST) + 8
	var bold := BattleStyle.pixelify(700)
	var lv := "Lv%d" % level
	var lv_w := bold.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var tag_w := 0.0
	if STATUS_TAGS.has(status):
		tag_w = BattleStyle.silkscreen().get_string_size(STATUS_TAGS[status][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 18
		_status_tag(size.x - pad_x - lv_w - tag_w, y + 4)
	draw_string(bold, Vector2(x, y + bold.get_ascent(26)), display_name, HORIZONTAL_ALIGNMENT_LEFT,
		size.x - pad_x - x - lv_w - tag_w - 8, 26, Color.WHITE)
	draw_string(bold, Vector2(pad_x, y + 2 + bold.get_ascent(20)), lv, HORIZONTAL_ALIGNMENT_RIGHT,
		size.x - pad_x * 2, 20, BattleStyle.TEXT_PRIMARY)
	y += 28 + 6
	var numbers := "%d/%d" % [roundi(shown_uptime), max_uptime]
	_draw_up_row(Vector2(pad_x, y), size.x - pad_x * 2, 20, 10, numbers, 84, 20)
	# Our addition (not in the spec): a thin EXP strip so level progress stays visible.
	var strip := Rect2(pad_x, size.y - 12 - 4, size.x - pad_x * 2, 4)
	draw_rect(strip, BattleStyle.SEG_EMPTY)
	draw_rect(Rect2(strip.position, Vector2(roundf(strip.size.x * exp_ratio), strip.size.y)), BattleStyle.EXP)


## "UP" label, the segmented bar, then right-aligned VT323 text (percentage or HP/MAX).
func _draw_up_row(at: Vector2, width: float, bar_h: float, seg_h: int, right_text: String, right_w: float,
		right_size: int) -> void:
	var label_font := BattleStyle.silkscreen()
	var label_w := label_font.get_string_size("UP", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(label_font, Vector2(at.x, at.y + (bar_h + label_font.get_ascent(14)) / 2.0 - 1), "UP",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, BattleStyle.LABEL)
	var bar := Rect2(at.x + label_w + 8, at.y, width - label_w - 8 - right_w - 8, bar_h)
	BattleStyle.draw_up_bar(self, bar, fraction(), seg_h)
	var vt := BattleStyle.vt323()
	draw_string(vt, Vector2(at.x + width - right_w, at.y + (bar_h + vt.get_ascent(right_size)) / 2.0 - 2), right_text,
		HORIZONTAL_ALIGNMENT_RIGHT, right_w, right_size, BattleStyle.TEXT_PRIMARY)
