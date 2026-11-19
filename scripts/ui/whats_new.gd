class_name WhatsNew
extends Control
## WHAT'S NEW screen, shown once on the title screen after an update.
## Built to "What's New Screen - Implementation Spec" (Nov 18, 2026; summary in docs/whats-new-spec.md): a cream
## terminal panel with a dark title bar, a fake log line with a blinking cursor, tagged entries and an OK footer.
## Content comes from data/whats_new.json (newest update first); Settings.last_seen_update remembers what was seen.
##
## Units: the spec's CSS px. The panel is drawn in a design frame (Layout.frame) scaled to fit the screen, the
## same way BattleScene draws its battle frame. Phones held upright get the narrow layout (tag above text,
## full-width OK, no key hint); everything else gets the desktop layout (tag column, hint + OK footer).
##
## Show rule (pending): nothing new -> nothing. A brand-new player (no setting yet and no save) is just marked
## up to date. Otherwise the newest update shows until OK, then its id is saved.
## Input: OK has focus. A / Enter / Space / B / Escape, or a click or tap on OK, close it. Taps elsewhere do
## nothing. Up/Down and the wheel scroll the list when it overflows. Nothing behind it takes input.

signal closed

const MAX_ENTRIES := 12
const MAX_TEXT := 80

# --- tokens (spec "Visual tokens") ---------------------------------------------
const PANEL := Color("F2F1EA")
const FOOTER := Color("E6E4DA")
const INK := Color("1E1E24")
const FRAME := Color("2B2F3A")
const MUTED := Color("4E5262")
const MUTED_2 := Color("5A5E6A")
const DATE := Color("C9CBD6")
const DIVIDER := Color("CFCDC2")
const OK_HOVER := Color("1E2230")
const FOCUS_RING := Color("2B4C9B")
const RING_OUTER := Color("141826")
const RING_INNER := Color("3A4058")
const SHADOW := Color("0B0E17")
const TAG_COLORS := {
	"NEW": Color("0E6B5C"),
	"UI": Color("2B4C9B"),
	"BALANCE": Color("A3470A"),
	"MOVES": Color("6A3D9A"),
	"AI": Color("3A3F4B"),
}

const SILKSCREEN := "res://assets/fonts/Silkscreen-Regular.ttf"
const VT323 := "res://assets/fonts/VT323-Regular.ttf"


## Every size and gap for one layout, in spec px.
class Layout:
	var phone := false
	var frame := Vector2(1280, 720)
	var panel_w := 860.0
	var margin := 32.0              # least space kept around the panel inside the frame
	var rings := Vector3(4, 2, 12)  # outer ring, inner ring, drop shadow
	var title_size := 28
	var date_size := 18
	var tag_size := 14
	var ok_size := 22
	var text_size := 30
	var line_height := 1.1
	var sub_size := 24
	var log_size := 24
	var hint_size := 26
	var bar_pad := Vector2(24, 12)          # x, y
	var log_pad := Vector4(28, 14, 28, 6)   # left, top, right, bottom
	var list_pad := Vector4(28, 4, 28, 8)
	var row_pad := 12.0
	var tag_col := 112.0
	var tag_gap := 20.0
	var footer_pad := Vector4(28, 14, 24, 16)
	var ok_min := Vector2(120, 48)

	static func desktop() -> Layout:
		return Layout.new()

	static func phone_layout(view: Vector2) -> Layout:
		var l := Layout.new()
		l.phone = true
		l.frame = Vector2(390, maxf(390.0 * view.y / maxf(1.0, view.x), 420.0))
		l.panel_w = 390.0 - 28.0
		l.margin = 14.0
		l.rings = Vector3(3, 2, 8)
		l.title_size = 24
		l.date_size = 14
		l.tag_size = 12
		l.text_size = 26
		l.line_height = 1.05
		l.sub_size = 22
		l.log_size = 21
		l.bar_pad = Vector2(18, 12)
		l.log_pad = Vector4(18, 14, 18, 6)
		l.list_pad = Vector4(18, 4, 18, 8)
		l.tag_gap = 6.0
		l.footer_pad = Vector4(18, 14, 18, 16)
		l.ok_min = Vector2(0, 52)
		return l

	## Phone layout for screens taller than wide (BattleLayout.pick does the same), desktop otherwise.
	static func pick(view: Vector2) -> Layout:
		return phone_layout(view) if view.y > view.x else desktop()


var update: Dictionary = {}
var layout: Layout
var scroll := 0.0

var _silk: Font
var _vt: Font
var _stage: Control
var _panel: PanelArt
var _list: ListArt
var _ok: OkButton
var _lines: Control
var _blink := 0.0
var _closing := false
var _base_scale := 1.0
# Measured in _measure() (spec px, relative to the panel's top-left).
var _bar_h := 0.0
var _log_h := 0.0
var _list_h := 0.0       # visible list height
var _content_h := 0.0    # full list height
var _footer_h := 0.0
var _panel_h := 0.0
var _rows: Array[Dictionary] = []


# --- who sees it ---------------------------------------------------------------

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


## Newest update id (what to remember once the screen closes), or "" if there are no updates.
static func newest_id(updates: Array) -> String:
	return str(updates[0].get("id", "")) if not updates.is_empty() else ""


## Shows the screen if this player has an unseen update, waits for OK and remembers it. Also quietly marks new
## players as up to date. Returns true if it was shown.
static func show_if_new(parent: Node) -> bool:
	var updates: Array = DataRegistry.whats_new.get("updates", [])
	var latest := newest_id(updates)
	if latest.is_empty() or latest == Settings.last_seen_update:
		return false
	var update_data := pending(updates, Settings.last_seen_update, SaveManager.has_save())
	if not update_data.is_empty():
		var screen := WhatsNew.new()
		parent.add_child(screen)
		screen.setup(update_data)
		await screen.closed
		screen.queue_free()
	Settings.last_seen_update = latest
	Settings.save_settings()
	return not update_data.is_empty()


## Tag color; an unknown tag is gray (tag-ai) with a warning.
static func tag_color(tag: String, warn := true) -> Color:
	var key := tag.to_upper()
	if not TAG_COLORS.has(key):
		if warn:
			push_warning("WhatsNew: unknown tag '%s', showing it gray" % tag)
		return TAG_COLORS["AI"]
	return TAG_COLORS[key]


## "> patch_notes.log loaded — 6 changes" (desktop) or "> 6 changes" (phone); the count comes from the data.
static func log_text(count: int, phone: bool) -> String:
	var changes := "%d change%s" % [count, "" if count == 1 else "s"]
	return "> " + changes if phone else "> patch_notes.log loaded — " + changes


## Desktop footer hint for the current controller.
static func hint_text() -> String:
	match InputPrompts.scheme:
		"keyboard", "touch":
			return "Press Enter to continue"
	return "Press %s to continue" % InputPrompts.label("ui_accept")


## Greedy word wrap: the lines of `text` that fit `width` at `size`.
static func wrap_text(font: Font, text: String, size: int, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in text.split(" ", false):
		var trial := word if line.is_empty() else line + " " + word
		if line.is_empty() or font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
			line = trial
		else:
			out.append(line)
			line = word
	if not line.is_empty():
		out.append(line)
	return out


static func rounded(ci: CanvasItem, rect: Rect2, color: Color, radius: int, corners := 15) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.anti_aliasing = false
	box.corner_radius_top_left = radius if corners & 1 else 0
	box.corner_radius_top_right = radius if corners & 2 else 0
	box.corner_radius_bottom_right = radius if corners & 4 else 0
	box.corner_radius_bottom_left = radius if corners & 8 else 0
	ci.draw_style_box(box, rect)


# --- building ------------------------------------------------------------------

func setup(data: Dictionary) -> void:
	update = data
	name = "WhatsNew"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # blocks everything behind; taps outside the panel do nothing
	_silk = load(SILKSCREEN)
	_vt = load(VT323)
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_panel = PanelArt.new()
	_panel.screen = self
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_panel)
	_list = ListArt.new()
	_list.screen = self
	_list.name = "List"
	_list.clip_contents = true
	_panel.add_child(_list)
	_ok = OkButton.new()
	_ok.screen = self
	_ok.name = "OK"
	_ok.pressed.connect(close)
	_panel.add_child(_ok)
	_lines = Scanlines.new()
	_lines.name = "Scanlines"
	_lines.visible = Settings.panel_scanlines
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_lines)
	resized.connect(_relayout)
	_relayout()
	_ok.grab_focus()
	_open_motion()


func _relayout() -> void:
	if update.is_empty() or not is_inside_tree():
		return
	var view := size if size.x > 0.0 and size.y > 0.0 else get_viewport_rect().size
	layout = Layout.pick(view)
	_measure()
	# Scale the design frame to fit the screen, centered (fractional, like the tall battle layout).
	_base_scale = minf(view.x / layout.frame.x, view.y / layout.frame.y)
	_stage.size = layout.frame
	_stage.pivot_offset = layout.frame / 2.0
	_stage.scale = Vector2.ONE * _base_scale
	_stage.position = (view - layout.frame) / 2.0
	var top := floorf((layout.frame.y - _panel_h - layout.rings.z) / 2.0)
	_panel.position = Vector2(floorf((layout.frame.x - layout.panel_w) / 2.0), maxf(top, layout.margin))
	_panel.size = Vector2(layout.panel_w, _panel_h)
	_list.position = Vector2(4, 4 + _bar_h + _log_h)
	_list.size = Vector2(layout.panel_w - 8, _list_h)
	var ok_w := layout.panel_w - 8 - layout.footer_pad.x - layout.footer_pad.z if layout.phone else layout.ok_min.x
	_ok.size = Vector2(ok_w, layout.ok_min.y)
	_ok.position = Vector2(layout.panel_w - 4 - layout.footer_pad.z - ok_w, _panel_h - 4 - layout.footer_pad.w - layout.ok_min.y)
	_lines.position = Vector2(4, 4)
	_lines.size = Vector2(layout.panel_w - 8, _panel_h - 8)
	scroll = clampf(scroll, 0.0, max_scroll())
	queue_redraw_all()


## Heights of every part and the wrapped rows, for the current layout.
func _measure() -> void:
	var l := layout
	_bar_h = l.bar_pad.y * 2 + _silk.get_height(l.title_size)
	if l.phone:
		_bar_h += 4 + _silk.get_height(l.date_size)
	_log_h = l.log_pad.y + _vt.get_height(l.log_size) + l.log_pad.w
	_footer_h = 4 + l.footer_pad.y + l.ok_min.y + l.footer_pad.w
	var inner_w := l.panel_w - 8 - l.list_pad.x - l.list_pad.z
	var text_w := inner_w if l.phone else inner_w - l.tag_col - l.tag_gap
	_rows.clear()
	var y := l.list_pad.y
	var entries: Array = update.get("entries", [])
	for i in entries.size():
		var e: Dictionary = entries[i]
		var row := {"tag": str(e.get("tag", "")).to_upper(), "y": y}
		row["lines"] = wrap_text(_vt, str(e.get("text", "")), l.text_size, text_w)
		row["credit"] = wrap_text(_vt, str(e.get("credit", "")), l.sub_size, text_w) if e.has("credit") else PackedStringArray()
		var chip_h := tag_chip_size(String(row["tag"])).y
		var text_h := (row["lines"] as PackedStringArray).size() * l.text_size * l.line_height \
			+ (row["credit"] as PackedStringArray).size() * l.sub_size * l.line_height
		var body := chip_h + l.tag_gap + text_h if l.phone else maxf(chip_h + 3, text_h)
		row["h"] = ceilf(l.row_pad * 2 + body)
		_rows.append(row)
		y += float(row["h"]) + (2.0 if i < entries.size() - 1 else 0.0)  # 2px dashed divider between rows
	_content_h = y + l.list_pad.w
	var room := l.frame.y - l.margin * 2 - l.rings.z - 8 - _bar_h - _log_h - _footer_h
	_list_h = minf(_content_h, maxf(room, 60.0))
	_panel_h = 8 + _bar_h + _log_h + _list_h + _footer_h


func tag_chip_size(tag: String) -> Vector2:
	var w := _silk.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, layout.tag_size).x + maxf(0, tag.length() - 1)
	return Vector2(ceilf(w) + 16, layout.tag_size + 7)  # padding 4 8 3


func max_scroll() -> float:
	return maxf(0.0, _content_h - _list_h)


func queue_redraw_all() -> void:
	for c: CanvasItem in [_panel, _list, _ok, _lines]:
		if c != null:
			c.queue_redraw()


# --- input ---------------------------------------------------------------------

func _gui_input(_event: InputEvent) -> void:
	accept_event()  # clicks and taps outside the panel do nothing


## Keys, pad buttons and the touch deck are read here, before the GUI: otherwise ui_up / ui_down would be used
## up moving focus off OK, and the list would never scroll (2026-11-18, Brandon on iPhone: "I can't scroll").
func _input(event: InputEvent) -> void:
	if _closing or update.is_empty():
		return
	if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:
		return  # pointers go to the GUI: OK, the list (drag / wheel), or the backdrop (ignored)
	if event.is_pressed():
		_ok.keyboard_focus = true
		_ok.queue_redraw()
	var key := event as InputEventKey
	var closes := event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") \
		or (key != null and key.pressed and not key.echo and key.keycode in [KEY_SPACE, KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER])
	if closes:
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		get_viewport().set_input_as_handled()
		scroll_by(-layout.text_size * 2.0)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		get_viewport().set_input_as_handled()
		scroll_by(layout.text_size * 2.0)
	elif event.is_pressed() or event.is_action_type():
		get_viewport().set_input_as_handled()  # nothing behind the screen reacts while it's open


## Holding Up/Down (keys, pad or the touch d-pad) keeps scrolling smoothly after a short pause.
const HOLD_DELAY := 0.25
const HOLD_SPEED := 900.0  # spec px per second
var _held := 0.0


func _hold_scroll(delta: float) -> void:
	var dir := 0.0
	for pair: Array in [["ui_up", "ui_down"], ["move_up", "move_down"]]:
		dir = dir if dir != 0.0 else Input.get_axis(pair[0], pair[1])
	if dir == 0.0:
		_held = 0.0
		return
	_held += delta
	if _held > HOLD_DELAY:
		scroll_by(signf(dir) * HOLD_SPEED * delta)


func scroll_by(amount: float) -> void:
	if max_scroll() <= 0.0:
		return
	scroll = clampf(scroll + amount, 0.0, max_scroll())
	_list.queue_redraw()


func close() -> void:
	if _closing:
		return
	_closing = true
	if Settings.wants_reduced_motion() or not is_inside_tree():
		closed.emit()
		return
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.08)
	t.finished.connect(func() -> void: closed.emit())


func _open_motion() -> void:
	if Settings.wants_reduced_motion():
		return
	modulate.a = 0.0
	_stage.scale = Vector2.ONE * _base_scale * 0.96
	var t := create_tween().set_parallel()
	t.tween_property(self, "modulate:a", 1.0, 0.12)
	t.tween_property(_stage, "scale", Vector2.ONE * _base_scale, 0.12)


func _process(delta: float) -> void:
	if not _closing and layout != null:
		_hold_scroll(delta)
	var was := cursor_on()
	_blink += delta
	if cursor_on() != was and _panel != null:
		_panel.queue_redraw()


## The log line's "_" blinks 0.5s on, 0.5s off, hard cut.
func cursor_on() -> bool:
	return fmod(_blink, 1.0) < 0.5


## Silkscreen with 1px letter spacing; `bold` draws it twice a pixel apart (no Silkscreen Bold file is bundled).
func draw_spaced(ci: CanvasItem, text: String, at: Vector2, font_size: int, color: Color, bold := false) -> float:
	var x := at.x
	for ch in text:
		ci.draw_string(_silk, Vector2(x, at.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		if bold:
			ci.draw_string(_silk, Vector2(x + 1, at.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		x += _silk.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 1
	return x - at.x - 1


func spaced_width(text: String, font_size: int) -> float:
	return _silk.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + maxf(0, text.length() - 1)


## The frame, title bar, log line and footer (the list and OK are their own children).
class PanelArt extends Control:
	var screen: WhatsNew

	func _draw() -> void:
		var l := screen.layout
		var w := size.x
		var h := size.y
		var r := l.rings
		# Retro edge: solid drop shadow, then the inner ring, the outer ring and the 4px frame.
		var ring := r.x + r.y
		WhatsNew.rounded(self, Rect2(-ring, -ring + r.z, w + ring * 2, h + ring * 2), WhatsNew.SHADOW, 14)
		WhatsNew.rounded(self, Rect2(-ring, -ring, w + ring * 2, h + ring * 2), WhatsNew.RING_INNER, 14)
		WhatsNew.rounded(self, Rect2(-r.x, -r.x, w + r.x * 2, h + r.x * 2), WhatsNew.RING_OUTER, 12)
		WhatsNew.rounded(self, Rect2(0, 0, w, h), WhatsNew.FRAME, 8)
		WhatsNew.rounded(self, Rect2(4, 4, w - 8, h - 8), WhatsNew.PANEL, 4)
		# Title bar: WHAT'S NEW, and the date (right on desktop, its own line on phones).
		var bar := Rect2(4, 4, w - 8, screen._bar_h)
		WhatsNew.rounded(self, bar, WhatsNew.FRAME, 4, 1 | 2)
		var silk := screen._silk
		var base := roundf(bar.position.y + l.bar_pad.y + silk.get_ascent(l.title_size))
		screen.draw_spaced(self, "WHAT'S NEW", Vector2(bar.position.x + l.bar_pad.x, base), l.title_size, WhatsNew.PANEL, true)
		var label := str(screen.update.get("label", ""))
		if l.phone:
			var date_base := roundf(base + silk.get_descent(l.title_size) + 4 + silk.get_ascent(l.date_size))
			screen.draw_spaced(self, label, Vector2(bar.position.x + l.bar_pad.x, date_base), l.date_size, WhatsNew.DATE)
		else:
			var date_w := screen.spaced_width(label, l.date_size)
			var date_base := roundf(bar.position.y + (bar.size.y + silk.get_ascent(l.date_size) - silk.get_descent(l.date_size)) / 2.0)
			screen.draw_spaced(self, label, Vector2(bar.end.x - l.bar_pad.x - date_w, date_base), l.date_size, WhatsNew.DATE)
		# Log line with the blinking cursor.
		var vt := screen._vt
		var log_y := roundf(bar.end.y + l.log_pad.y + vt.get_ascent(l.log_size))
		var text := WhatsNew.log_text((screen.update.get("entries", []) as Array).size(), l.phone)
		var log_x := 4 + l.log_pad.x
		draw_string(vt, Vector2(log_x, log_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.log_size, WhatsNew.MUTED)
		if screen.cursor_on():
			var tw := vt.get_string_size(text + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, l.log_size).x
			draw_string(vt, Vector2(log_x + tw, log_y), "_", HORIZONTAL_ALIGNMENT_LEFT, -1, l.log_size, WhatsNew.MUTED)
		# Footer: fill, 4px frame top border, and the key hint (desktop only; touch players have no A/Enter).
		var foot := Rect2(4, h - 4 - screen._footer_h, w - 8, screen._footer_h)
		WhatsNew.rounded(self, foot, WhatsNew.FOOTER, 4, 4 | 8)
		draw_rect(Rect2(foot.position, Vector2(foot.size.x, 4)), WhatsNew.FRAME)
		if not l.phone:
			var hint := WhatsNew.hint_text()
			var hy := roundf(foot.position.y + 4 + l.footer_pad.y + (l.ok_min.y + vt.get_ascent(l.hint_size) - vt.get_descent(l.hint_size)) / 2.0)
			draw_string(vt, Vector2(foot.position.x + l.footer_pad.x, hy), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, l.hint_size, WhatsNew.MUTED)


## The entries, clipped to the list area and scrolled.
class ListArt extends Control:
	var screen: WhatsNew

	## Wheel, a drag with the mouse, or a finger drag (touch arrives as emulated mouse motion) scrolls.
	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			screen.scroll_by(screen.layout.text_size * (-1.5 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.5))
		var motion := event as InputEventMouseMotion
		if motion != null and motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			screen.scroll_by(-motion.relative.y)
		var drag := event as InputEventScreenDrag
		if drag != null and not ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true):
			screen.scroll_by(-drag.relative.y)
		accept_event()

	func _draw() -> void:
		var l := screen.layout
		var vt := screen._vt
		var x0 := l.list_pad.x
		var w := size.x - l.list_pad.x - l.list_pad.z
		for i in screen._rows.size():
			var row: Dictionary = screen._rows[i]
			var top := float(row["y"]) - screen.scroll
			if top > size.y or top + float(row["h"]) < 0:
				continue
			var tag: String = row["tag"]
			var chip := screen.tag_chip_size(tag)
			var y := top + l.row_pad
			var chip_at := Vector2(x0, y + (0.0 if l.phone else 3.0))
			WhatsNew.rounded(self, Rect2(chip_at, chip), WhatsNew.tag_color(tag), 3)
			screen.draw_spaced(self, tag, Vector2(chip_at.x + 8, roundf(chip_at.y + 4 + screen._silk.get_ascent(l.tag_size))), l.tag_size, WhatsNew.PANEL)
			var tx := x0 if l.phone else x0 + l.tag_col + l.tag_gap
			var ty := y + (chip.y + l.tag_gap if l.phone else 0.0)
			for line: String in row["lines"]:
				draw_string(vt, Vector2(tx, roundf(ty + vt.get_ascent(l.text_size))), line, HORIZONTAL_ALIGNMENT_LEFT, -1, l.text_size, WhatsNew.INK)
				ty += l.text_size * l.line_height
			for line: String in row["credit"]:
				draw_string(vt, Vector2(tx, roundf(ty + vt.get_ascent(l.sub_size))), line, HORIZONTAL_ALIGNMENT_LEFT, -1, l.sub_size, WhatsNew.MUTED_2)
				ty += l.sub_size * l.line_height
			if i < screen._rows.size() - 1:  # 2px dashed divider, none after the last row
				var dy := top + float(row["h"])
				var dx := x0
				while dx < x0 + w:
					draw_rect(Rect2(dx, dy, minf(6.0, x0 + w - dx), 2), WhatsNew.DIVIDER)
					dx += 10.0
		_draw_scrollbar()

	## When the list overflows, a thin bar on the right shows there's more and where you are (our addition).
	func _draw_scrollbar() -> void:
		var most := screen.max_scroll()
		if most <= 0.0:
			return
		var track := Rect2(size.x - 9, 6, 4, size.y - 12)
		draw_rect(track, WhatsNew.DIVIDER)
		var thumb_h := maxf(24.0, track.size.y * size.y / (size.y + most))
		var y := track.position.y + (track.size.y - thumb_h) * screen.scroll / most
		draw_rect(Rect2(track.position.x, y, track.size.x, thumb_h), WhatsNew.MUTED)


## OK: cream fill and a 3px frame border; hover or focus swaps to the dark fill with cream text. The 3px focus
## ring (3px out) shows while the cursor is driven by a keyboard or controller.
class OkButton extends Control:
	signal pressed
	var screen: WhatsNew
	var keyboard_focus := true
	var _hover := false
	var _down := false

	func _init() -> void:
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func() -> void:
			_hover = true
			queue_redraw())
		mouse_exited.connect(func() -> void:
			_hover = false
			_down = false
			queue_redraw())
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _ready() -> void:
		keyboard_focus = InputPrompts.scheme != "touch"

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
			keyboard_focus = false
			if mb.pressed:
				_down = true
			elif _down:
				_down = false
				pressed.emit()
			accept_event()
			queue_redraw()

	func _draw() -> void:
		var l := screen.layout
		var lit := _hover or has_focus()
		if has_focus() and keyboard_focus:
			WhatsNew.rounded(self, Rect2(-6, -6, size.x + 12, size.y + 12), WhatsNew.FOCUS_RING, 7)
			WhatsNew.rounded(self, Rect2(-3, -3, size.x + 6, size.y + 6), WhatsNew.FOOTER, 5)
		WhatsNew.rounded(self, Rect2(Vector2.ZERO, size), WhatsNew.FRAME, 4)
		WhatsNew.rounded(self, Rect2(3, 3, size.x - 6, size.y - 6), WhatsNew.OK_HOVER if lit else WhatsNew.PANEL, 2)
		var silk := screen._silk
		var label := "> OK"
		var tw := screen.spaced_width(label, l.ok_size) + 1
		var base := (size.y + silk.get_ascent(l.ok_size) - silk.get_descent(l.ok_size)) / 2.0
		screen.draw_spaced(self, label, Vector2(roundf((size.x - tw) / 2.0), roundf(base)), l.ok_size, WhatsNew.PANEL if lit else WhatsNew.INK, true)


## Optional scanlines over the panel (Settings.panel_scanlines, off by default): 1px of #141826 at 6% every 3px.
class Scanlines extends Control:
	func _draw() -> void:
		var c := Color(WhatsNew.RING_OUTER, 0.06)
		var y := 0.0
		while y < size.y:
			draw_rect(Rect2(0, y, size.x, 1), c)
			y += 3.0
