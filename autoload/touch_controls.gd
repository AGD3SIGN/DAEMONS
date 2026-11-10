extends CanvasLayer
## On-screen controls for touchscreens. Shown when the device has a touchscreen and no gamepad is
## connected; hidden as soon as a gamepad connects or a gamepad button is pressed.
##   - Floating d-pad: put your left thumb down anywhere in the lower-left area and drag. Push past
##     the ring to run.
##   - A (confirm, check icon) and B (back, arrow icon) bottom-right; MENU (three lines) top-right.
##   - Buttons are at least 44pt (Apple's minimum touch target) and stay inside the safe area
##     (notches, rounded corners, home indicator).
## Everything is sent as the same named input actions the keyboard and gamepad use (move_*, ui_*,
## ui_accept, ui_cancel, menu, run), so no game code knows the difference. Taps outside the control
## zones still work as normal taps on menus.
## Web, phone held upright: the page (web/touch_deck.js) shrinks the game to a screen at the top and
## draws a control deck below it. Then this overlay hides (deck mode) and the deck's presses come in
## through window.daemonsDeck as the same actions.

signal shown_changed(shown: bool)

const MIN_TARGET_PT := 44.0
const BUTTON_PT := 58.0
const DPAD_RING_PT := 62.0
const REPEAT_DELAY := 0.35
const REPEAT_RATE := 0.1
## Buttons the web control deck may press.
const DECK_ACTIONS: PackedStringArray = ["ui_accept", "ui_cancel", "menu", "run"]
const DIR_ACTIONS := {
	Vector2i.UP: ["move_up", "ui_up"], Vector2i.DOWN: ["move_down", "ui_down"],
	Vector2i.LEFT: ["move_left", "ui_left"], Vector2i.RIGHT: ["move_right", "ui_right"],
}

var shown := false
## Any reason here hides the overlay without switching it off. Battles use suppress("battle"):
## everything there is already tappable and the buttons would cover the HP panel.
var _suppressed := {}
## Tests/automation can override the device's points-per-logical-pixel and safe area.
var points_scale_override: float = -1.0
var safe_margins_override: Variant = null  # Vector4(left, top, right, bottom) in logical px

var _view: Control
var _dpad_touch := -1
var _dpad_origin := Vector2.ZERO
var _dpad_pos := Vector2.ZERO
var _dir := Vector2i.ZERO
var _running := false
var _repeat_timer := 0.0
var _button_touches := {}  # touch index -> action
## The web page's control deck is showing (portrait phone): no overlay, input comes from the deck.
var deck := false
var _deck_callback: JavaScriptObject


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_view = Drawer.new()
	_view.controls = self
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	get_viewport().size_changed.connect(_view.queue_redraw)
	set_shown(DisplayServer.is_touchscreen_available() and Input.get_connected_joypads().is_empty())
	if OS.has_feature("web"):
		_deck_callback = JavaScriptBridge.create_callback(_on_deck_message)
		var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
		window.daemonsDeck = _deck_callback
		set_deck(bool(window.daemonsDeckShown))


## Messages from web/touch_deck.js: ["shown", bool], ["button", action, pressed], ["dir", x, y].
func _on_deck_message(args: Array) -> void:
	if args.is_empty():
		return
	match String(args[0]):
		"shown":
			set_deck(bool(args[1]))
		"button":
			deck_button(String(args[1]), bool(args[2]))
		"dir":
			deck_direction(Vector2i(int(args[1]), int(args[2])))


func set_deck(on: bool) -> void:
	if on == deck:
		return
	_release_all()
	deck = on
	_view.visible = is_active() and not deck


func deck_button(action: String, pressed: bool) -> void:
	if action in DECK_ACTIONS:
		_send(action, pressed)


func deck_direction(dir: Vector2i) -> void:
	var d := Vector2i(signi(dir.x), signi(dir.y))
	_set_direction(d if d.x == 0 or d.y == 0 else Vector2i.ZERO, false)


func set_shown(value: bool) -> void:
	shown = value
	_view.visible = is_active() and not deck
	if not value:
		_release_all()
	shown_changed.emit(value)
	_view.queue_redraw()


## Temporarily hide the overlay (e.g. during battle). Call release(reason) when done.
func suppress(reason: String) -> void:
	_suppressed[reason] = true
	if not deck:
		_release_all()
	_view.visible = is_active() and not deck


func release(reason: String) -> void:
	_suppressed.erase(reason)
	_view.visible = is_active() and not deck


func is_active() -> bool:
	return shown and _suppressed.is_empty()


func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if connected:
		set_shown(false)
	elif DisplayServer.is_touchscreen_available() and Input.get_connected_joypads().is_empty():
		set_shown(true)


# --- layout (logical pixels, the same space as the game's 320x180 view) -------

## Physical points -> logical pixels. 44pt on a 3x iPhone at 4x game scale = 33 logical px.
func points_to_logical(points: float) -> float:
	var per_point := points_scale_override if points_scale_override > 0.0 else _logical_per_point()
	return points * per_point


func _logical_per_point() -> float:
	var window := get_viewport().get_window()
	var view_size := get_viewport().get_visible_rect().size
	if view_size.x <= 0.0:
		return 0.25
	var window_px_per_logical := float(window.size.x) / view_size.x
	var px_per_point := DisplayServer.screen_get_scale()
	if OS.get_name() == "Android":
		px_per_point = maxf(1.0, DisplayServer.screen_get_dpi() / 160.0)
	return px_per_point / maxf(window_px_per_logical, 0.0001)


## Insets from notches/rounded corners, in logical px: Vector4(left, top, right, bottom).
func safe_margins() -> Vector4:
	if safe_margins_override != null:
		return safe_margins_override
	if not OS.has_feature("mobile"):
		return Vector4.ZERO  # desktop "safe areas" are just the menu bar/Dock, not notches
	var view_size := get_viewport().get_visible_rect().size
	var window := get_viewport().get_window()
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or window.size.x <= 0:
		return Vector4.ZERO
	var k := float(window.size.x) / view_size.x
	var screen := DisplayServer.screen_get_size()
	return Vector4(safe.position.x / k, safe.position.y / k,
		maxf(0.0, screen.x - safe.end.x) / k, maxf(0.0, screen.y - safe.end.y) / k)


func button_radius() -> float:
	return maxf(points_to_logical(BUTTON_PT), points_to_logical(MIN_TARGET_PT)) / 2.0


func layout() -> Dictionary:
	var size := get_viewport().get_visible_rect().size
	var m := safe_margins()
	var r := button_radius()
	var a := Vector2(size.x - m.z - r - 6.0, size.y - m.w - r * 2.2 - 4.0)
	var b := a + Vector2(-r * 2.3, r * 1.1)
	var menu_r := maxf(r * 0.7, points_to_logical(MIN_TARGET_PT) / 2.0)
	var menu := Vector2(size.x - m.z - menu_r - 4.0, m.y + menu_r + 4.0)
	var ring := points_to_logical(DPAD_RING_PT) / 2.0 + 6.0
	return {
		"a": a, "b": b, "menu": menu, "r": r, "menu_r": menu_r, "ring": ring,
		"dpad_zone": Rect2(m.x, size.y * 0.3, maxf(0.0, size.x * 0.45 - m.x), maxf(0.0, size.y * 0.7 - m.w)),
		"dpad_home": Vector2(m.x + ring + 10.0, size.y - m.w - ring - 10.0),
	}


func _button_at(pos: Vector2) -> String:
	var l := layout()
	if pos.distance_to(l["a"]) <= l["r"] * 1.15:
		return "ui_accept"
	if pos.distance_to(l["b"]) <= l["r"] * 1.15:
		return "ui_cancel"
	if pos.distance_to(l["menu"]) <= l["menu_r"] * 1.2:
		return "menu"
	return ""


func in_control_zone(pos: Vector2) -> bool:
	return not _button_at(pos).is_empty() or layout()["dpad_zone"].has_point(pos)


# --- input -------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and shown:
		set_shown(false)  # someone picked up a controller
		return
	if event is InputEventScreenTouch and event.pressed and not shown:
		set_shown(true)  # a real touch proves a touchscreen, even with a pad paired (the iOS Simulator reports one)
	if not is_active() or deck:
		return
	if event is InputEventScreenTouch:
		if _handle_touch(event):
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == _dpad_touch:
			_dpad_pos = event.position
			_update_direction()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION:
		# Touches on our controls also create fake mouse clicks; don't let them press menus underneath.
		if in_control_zone(event.position):
			get_viewport().set_input_as_handled()


## Returns true if the touch belonged to the controls.
func _handle_touch(event: InputEventScreenTouch) -> bool:
	if event.pressed:
		var action := _button_at(event.position)
		if not action.is_empty():
			_button_touches[event.index] = action
			_send(action, true)
			_view.queue_redraw()
			return true
		if _dpad_touch == -1 and layout()["dpad_zone"].has_point(event.position):
			_dpad_touch = event.index
			_dpad_origin = event.position
			_dpad_pos = event.position
			_view.queue_redraw()
			return true
		return false
	if _button_touches.has(event.index):
		_send(_button_touches[event.index], false)
		_button_touches.erase(event.index)
		_view.queue_redraw()
		return true
	if event.index == _dpad_touch:
		_dpad_touch = -1
		_set_direction(Vector2i.ZERO, false)
		_view.queue_redraw()
		return true
	return false


func _update_direction() -> void:
	var offset := _dpad_pos - _dpad_origin
	var ring: float = layout()["ring"]
	var dir := Vector2i.ZERO
	if offset.length() > ring * 0.3:
		dir = Vector2i(signi(roundi(offset.x)), 0) if absf(offset.x) > absf(offset.y) else Vector2i(0, signi(roundi(offset.y)))
	_set_direction(dir, offset.length() > ring * 1.25)
	_view.queue_redraw()


func _set_direction(dir: Vector2i, run: bool) -> void:
	if dir != _dir:
		if _dir != Vector2i.ZERO:
			for action: String in DIR_ACTIONS[_dir]:
				_send(action, false)
		_dir = dir
		_repeat_timer = REPEAT_DELAY
		if _dir != Vector2i.ZERO:
			for action: String in DIR_ACTIONS[_dir]:
				_send(action, true)
	if run != _running:
		_running = run
		_send("run", run)


## Holding a direction repeats ui_* presses so menus scroll, like holding a key.
func _process(delta: float) -> void:
	if not (is_active() or deck) or _dir == Vector2i.ZERO:
		return
	_repeat_timer -= delta
	if _repeat_timer <= 0.0:
		_repeat_timer = REPEAT_RATE
		_send(DIR_ACTIONS[_dir][1], true)


func _send(action: String, pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	Input.parse_input_event(e)


func _release_all() -> void:
	for index: int in _button_touches:
		_send(_button_touches[index], false)
	_button_touches.clear()
	_dpad_touch = -1
	_set_direction(Vector2i.ZERO, false)


func dpad_state() -> Dictionary:
	return {"active": _dpad_touch != -1, "origin": _dpad_origin, "pos": _dpad_pos, "pressed": _button_touches.values()}


# --- drawing (vector shapes, so they stay crisp at any screen density) --------

class Drawer extends Control:
	var controls: Node

	func _draw() -> void:
		var l: Dictionary = controls.layout()
		var state: Dictionary = controls.dpad_state()
		var fill := Color(1, 1, 1, 0.22)
		var edge := Color(1, 1, 1, 0.55)
		var pressed_fill := Color(1, 1, 1, 0.45)
		var ink := Color(0.1, 0.12, 0.2, 0.75)
		# D-pad: where your thumb is, or a faint hint at the home spot.
		var center: Vector2 = state["origin"] if state["active"] else l["dpad_home"]
		var ring: float = l["ring"]
		draw_circle(center, ring, Color(1, 1, 1, 0.12 if state["active"] else 0.07))
		draw_arc(center, ring, 0, TAU, 48, edge if state["active"] else Color(1, 1, 1, 0.25), 2.0)
		var knob: Vector2 = center
		if state["active"]:
			var offset: Vector2 = state["pos"] - center
			knob = center + offset.limit_length(ring * 1.2)
		draw_circle(knob, ring * 0.42, pressed_fill if state["active"] else fill)
		# A: check mark.
		var r: float = l["r"]
		_button(l["a"], r, "ui_accept" in state["pressed"], fill, pressed_fill, edge)
		var a: Vector2 = l["a"]
		draw_polyline(PackedVector2Array([a + Vector2(-r * 0.42, 0), a + Vector2(-r * 0.1, r * 0.32), a + Vector2(r * 0.45, -r * 0.35)]), ink, maxf(2.0, r * 0.16))
		# B: back arrow.
		_button(l["b"], r, "ui_cancel" in state["pressed"], fill, pressed_fill, edge)
		var b: Vector2 = l["b"]
		var w := maxf(2.0, r * 0.15)
		draw_line(b + Vector2(r * 0.4, 0), b + Vector2(-r * 0.4, 0), ink, w)
		draw_polyline(PackedVector2Array([b + Vector2(-r * 0.05, -r * 0.35), b + Vector2(-r * 0.4, 0), b + Vector2(-r * 0.05, r * 0.35)]), ink, w)
		# MENU: three lines.
		var mr: float = l["menu_r"]
		_button(l["menu"], mr, "menu" in state["pressed"], fill, pressed_fill, edge)
		var mc: Vector2 = l["menu"]
		for i in 3:
			var y := (i - 1) * mr * 0.32
			draw_line(mc + Vector2(-mr * 0.42, y), mc + Vector2(mr * 0.42, y), ink, maxf(1.5, mr * 0.12))

	func _button(center: Vector2, radius: float, pressed: bool, fill: Color, pressed_fill: Color, edge: Color) -> void:
		draw_circle(center, radius, pressed_fill if pressed else fill)
		draw_arc(center, radius, 0, TAU, 40, edge, 2.0)
