extends Control
## Title screen, built to "DAEMONS Start Screen — Style Guide" (2026-11-11). All values live in
## TitleStyle; the copy and the featured legendary come from data/title_screen.json.
##
## The scene is designed on a 1280x720 frame. `_stage` holds it, scaled to fit the screen; the
## background, floor and overlays extend past the frame on wider/taller screens instead of bars.
## Layers back to front: background, traces + bits + floor (TitleBackdrop), logo + glitch copies,
## hero (TitleHero), card / prompt / menu / boot log / version (_fg), CRT overlay.
##
## Menu: NEW GAME · CONTINUE · OPTIONS (+ DEBUG in debug builds). Left/right (or up/down) move,
## accept/Start confirm, mouse hover selects and click confirms, a tap selects and a second tap on
## the selected item confirms. CONTINUE is greyed out and skipped without a save. On touch the menu
## stacks vertically.

const S := preload("res://scripts/ui/title/title_style.gd")
const DEBUG_MENU_SCENE := "res://scenes/debug/debug_menu.tscn"
const NEW_GAME_MAP := "player_house"
const BUILD_INFO := "res://data/build_info.json"
const BG_SHADER := preload("res://scripts/ui/title/title_background.gdshader")
const CRT_SHADER := preload("res://scripts/ui/title/crt_overlay.gdshader")

var accent := S.ACCENT_DEFAULT
var items := PackedStringArray()
var enabled: Array[bool] = []
var selected := 0
var attract := true          # until the first input: PRESS START blinks
var vertical := false        # touch: menu stacked vertically
var featured: Dictionary = {}

var _time := 0.0
var _motion := 0.0
var _reduced := false
var _busy := false
var _stick_latched := false

var _display: Font
var _body: Font
var _logo_font: FontVariation
var _tagline_font: FontVariation
var _label_font: FontVariation

var _bg_mat: ShaderMaterial
var _crt_mat: ShaderMaterial
var _stage: Node2D
var _backdrop: TitleBackdrop
var _logo: TitleLogo
var _glitch_magenta: TitleLogo
var _glitch_lime: TitleLogo
var _hero: TitleHero
var _fg: Node2D
var _overlay: ColorRect
var _sprite_label: Control
var _options: FieldMenus
var _boot_lines := PackedStringArray()
var _version_text := ""


func _ready() -> void:
	GameState.clock_running = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_fonts()
	_read_data()
	_build()
	_build_menu()
	_reduced = Settings.wants_reduced_motion()
	vertical = InputPrompts.scheme == "touch"
	InputPrompts.scheme_changed.connect(_on_scheme_changed)
	_process(0.0)


# --- setup -------------------------------------------------------------------

func _load_fonts() -> void:
	_display = load(S.DISPLAY_FONT)
	_body = load(S.BODY_FONT)
	_logo_font = _spaced(_display, S.LOGO_SPACING)
	_tagline_font = _spaced(_body, S.TAGLINE_SPACING)
	_label_font = _spaced(_display, S.CARD_LABEL_SPACING)


static func _spaced(base: Font, spacing: int) -> FontVariation:
	var v := FontVariation.new()
	v.base_font = base
	v.spacing_glyph = spacing
	return v


func _read_data() -> void:
	var data: Dictionary = DataRegistry.title_screen
	var list: Array = data.get("featured", [])
	featured = list[0] if not list.is_empty() else {}
	_boot_lines = PackedStringArray()
	for line: String in data.get("boot_log", []):
		_boot_lines.append(line.replace("{count}", str(DataRegistry.species.size())))
	_version_text = "v%s · BUILD %04d" % [ProjectSettings.get_setting("application/config/version", "0.0.0"), build_number()]


## Build number: data/build_info.json, which the web deploy fills in with its run number.
static func build_number() -> int:
	var text := FileAccess.get_file_as_string(BUILD_INFO)
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
	return int(parsed.get("build", 0)) if parsed is Dictionary else 0


func _build() -> void:
	var bg: ColorRect = $Background
	_bg_mat = ShaderMaterial.new()
	_bg_mat.shader = BG_SHADER
	bg.material = _bg_mat
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_stage = Node2D.new()
	_stage.name = "Stage"
	add_child(_stage)
	_backdrop = TitleBackdrop.new()
	_backdrop.body_font = _body
	_stage.add_child(_backdrop)

	_logo = _make_logo(S.TEXT_HI)
	_logo.shadow_color = S.LOGO_SHADOW
	_logo.shadow_drop = S.LOGO_SHADOW_DROP
	_logo.glow_color = accent
	_logo.glow_radius = S.LOGO_GLOW
	_glitch_magenta = _make_logo(S.MAGENTA)
	_glitch_lime = _make_logo(S.LIME)
	for copy: TitleLogo in [_glitch_magenta, _glitch_lime]:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD  # CSS mix-blend-mode: screen, close enough
		copy.material = mat
		copy.visible = false

	_hero = TitleHero.new()
	_hero.position = S.HERO_POS
	_hero.accent = accent
	_stage.add_child(_hero)
	if featured.has("sprite"):
		_hero.setup(featured["sprite"])
	# Screen readers: the sprite is the one decorative layer worth naming.
	_sprite_label = Control.new()
	_sprite_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite_label.position = S.HERO_POS
	_sprite_label.size = S.HERO_SIZE
	if "accessibility_name" in _sprite_label:
		_sprite_label.set("accessibility_name", str(featured.get("a11y", "")))
	_stage.add_child(_sprite_label)

	_fg = Node2D.new()
	_fg.name = "Foreground"
	_fg.draw.connect(_draw_fg)
	_stage.add_child(_fg)

	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_crt_mat = ShaderMaterial.new()
	_crt_mat.shader = CRT_SHADER
	_overlay.material = _crt_mat
	add_child(_overlay)


func _make_logo(c: Color) -> TitleLogo:
	var l := TitleLogo.new()
	l.text = "DAEMONS"
	l.font = _logo_font
	l.font_size = S.LOGO_SIZE
	l.line_height = S.LOGO_LINE
	l.color = c
	_stage.add_child(l)
	l.position = Vector2((S.FRAME.x - l.width()) / 2.0, S.TITLE_TOP)
	return l


func _build_menu() -> void:
	items = PackedStringArray(["NEW GAME", "CONTINUE", "OPTIONS"])
	if OS.is_debug_build():
		items.append("DEBUG")
	enabled = []
	for item in items:
		enabled.append(item != "CONTINUE" or SaveManager.has_save())
	selected = 0


func _on_scheme_changed(scheme: String) -> void:
	vertical = scheme == "touch"
	_fg.queue_redraw()


# --- per frame ---------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	_reduced = Settings.wants_reduced_motion()
	if not _reduced:
		_motion += delta
	# Fit the 1280x720 frame (whole frame visible, centered).
	var s := minf(size.x / S.FRAME.x, size.y / S.FRAME.y)
	if s <= 0.0:
		return
	var origin := (size - S.FRAME * s) / 2.0
	_stage.scale = Vector2.ONE * s
	_stage.position = origin
	var view := Rect2(-origin / s, size / s)
	for mat: ShaderMaterial in [_bg_mat, _crt_mat]:
		mat.set_shader_parameter("rect_size", size)
		mat.set_shader_parameter("frame_origin", origin)
		mat.set_shader_parameter("frame_scale", s)
	_crt_mat.set_shader_parameter("crt", Settings.crt_effects)
	_crt_mat.set_shader_parameter("accent", accent)
	_crt_mat.set_shader_parameter("scan_bar_y", -S.SCAN_BAR_H + fposmod(_motion / S.T_SCAN_BAR, 1.0) * (S.FRAME.y + S.SCAN_BAR_H))
	_backdrop.time = _time
	_backdrop.motion = _motion
	_backdrop.accent = accent
	_backdrop.view = view
	_backdrop.queue_redraw()
	_hero.time = _time
	_hero.motion = _motion
	_update_glitch()
	_fg.queue_redraw()


## Logo glitch, 4.5 s stepped: idle until 86%; slices at 88 / 90 / 92%; the magenta and lime
## copies flash at 88-93% (lime 0.15 s ahead), 7 px either side.
func _update_glitch() -> void:
	var home := Vector2((S.FRAME.x - _logo.width()) / 2.0, S.TITLE_TOP)
	var p := fposmod(_motion / S.T_GLITCH, 1.0)
	var slice := glitch_slice(p)
	_logo.position = home + slice["offset"]
	_logo.band = slice["band"]
	var pl := fposmod((_motion - S.T_GLITCH_LIME) / S.T_GLITCH, 1.0)
	_glitch_magenta.visible = p >= 0.88 and p < 0.93
	_glitch_lime.visible = pl >= 0.88 and pl < 0.93
	_glitch_magenta.position = home + Vector2(-7, 0)
	_glitch_lime.position = home + Vector2(7, 0)
	_glitch_magenta.modulate.a = 0.85
	_glitch_lime.modulate.a = 0.85


static func glitch_slice(p: float) -> Dictionary:
	if p >= 0.88 and p < 0.90:
		return {"offset": Vector2(-6, 2), "band": Vector2(0.10, 0.45)}
	if p >= 0.90 and p < 0.92:
		return {"offset": Vector2(5, -2), "band": Vector2(0.60, 0.92)}
	if p >= 0.92 and p < 0.94:
		return {"offset": Vector2(-3, 0), "band": Vector2(0.30, 0.60)}
	return {"offset": Vector2.ZERO, "band": Vector2(0, 1)}


# --- foreground drawing ------------------------------------------------------

func _line_h(f: Font, size_px: int) -> float:
	return f.get_ascent(size_px) + f.get_descent(size_px)


func _text_w(f: Font, text: String, size_px: int) -> float:
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x


func _draw_fg() -> void:
	_draw_tagline()
	_draw_card()
	_draw_prompt_and_menu()
	_draw_boot_log()


func _draw_tagline() -> void:
	var text: String = DataRegistry.title_screen.get("tagline", "")
	var y := S.TITLE_TOP + S.LOGO_LINE + S.TAGLINE_GAP
	var w := _text_w(_tagline_font, text, S.TAGLINE_SIZE)
	_fg.draw_string(_tagline_font, Vector2((S.FRAME.x - w) / 2.0, y + _tagline_font.get_ascent(S.TAGLINE_SIZE)), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, S.TAGLINE_SIZE, S.LIME)


## The card's text lines: [font, size, color, text] (the flavor line wraps to the card width).
func card_lines() -> Array:
	var inner := S.CARD_WIDTH - S.CARD_PAD.x * 2.0 - S.CARD_BORDER * 2.0
	var lines: Array = [
		[_label_font, S.CARD_LABEL_SIZE, S.FLAME_HOT, "★ " + str(featured.get("label", "LEGENDARY"))],
		[_display, S.CARD_NAME_SIZE, S.TEXT_HI, str(featured.get("name", ""))],
		[_body, S.CARD_SUB_SIZE, S.FLAME_SOFT, str(featured.get("fusion", ""))],
	]
	var number := "No. %s · %s" % [cmdb_number(featured), featured.get("flavor", "")]
	for wrapped in wrap_text(_body, number, S.CARD_NUM_SIZE, inner):
		lines.append([_body, S.CARD_NUM_SIZE, S.TEXT_DIM, wrapped])
	return lines


## The featured Daemon's CMDB asset number (its place in species.json), or the card's own "number"
## for one that isn't a species yet.
static func cmdb_number(f: Dictionary) -> String:
	var n := DataRegistry.cmdb_number(f.get("id", ""))
	return "%03d" % n if n >= 0 else str(f.get("number", "000"))


static func wrap_text(f: Font, text: String, size_px: int, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in text.split(" "):
		var attempt := word if line.is_empty() else line + " " + word
		if not line.is_empty() and f.get_string_size(attempt, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x > width:
			out.append(line)
			line = word
		else:
			line = attempt
	if not line.is_empty():
		out.append(line)
	return out


func card_rect() -> Rect2:
	var h := S.CARD_PAD.y * 2.0 + S.CARD_BORDER * 2.0
	var lines := card_lines()
	for i in lines.size():
		h += _line_h(lines[i][0], lines[i][1]) + (S.CARD_LINE_GAP if i > 0 else 0.0)
	return Rect2(S.FRAME.x - S.CARD_RIGHT - S.CARD_WIDTH, S.CARD_TOP, S.CARD_WIDTH, h)


func _draw_card() -> void:
	if featured.is_empty():
		return
	var r := card_rect()
	# 22 px flame glow at 35%, outside the border only (like a CSS box-shadow).
	for i in 6:
		var grow := S.CARD_GLOW * (i + 0.5) / 6.0
		_fg.draw_rect(r.grow(grow), Color(S.FLAME, 0.35 * 0.22 * (1.0 - i / 6.0)), false, S.CARD_GLOW / 6.0)
	_fg.draw_rect(r, S.CARD_BG)
	_fg.draw_rect(r.grow(-S.CARD_BORDER / 2.0), S.FLAME, false, S.CARD_BORDER)
	var y := r.position.y + S.CARD_BORDER + S.CARD_PAD.y
	var x := r.position.x + S.CARD_BORDER + S.CARD_PAD.x
	for line: Array in card_lines():
		var f: Font = line[0]
		var size_px: int = line[1]
		var text: String = line[3]
		var base := Vector2(x, y + f.get_ascent(size_px))
		if text.begins_with("★") and not f.has_char("★".unicode_at(0)):
			_draw_star(Vector2(x, y), size_px, line[2])
			_fg.draw_string(f, base + Vector2(size_px + S.CARD_LABEL_SPACING, 0), text.substr(1), HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, line[2])
		else:
			_fg.draw_string(f, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, line[2])
		y += _line_h(f, size_px) + S.CARD_LINE_GAP


## Press Start 2P has no ★, so the card label draws a 5x5 pixel star in its place.
func _draw_star(top_left: Vector2, size_px: int, c: Color) -> void:
	const STAR := ["..#..", ".###.", "#####", ".###.", "#.#.#"]
	var px := size_px / 5.0
	for row in STAR.size():
		for col in 5:
			if STAR[row][col] == "#":
				_fg.draw_rect(Rect2(top_left + Vector2(col, row) * px, Vector2.ONE * px), c)


func prompt_line_h() -> float:
	return _line_h(_display, S.PROMPT_SIZE)


## Hit/draw boxes for the menu items, in frame px.
func menu_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var top := S.PROMPT_TOP + prompt_line_h() + S.MENU_GAP
	if vertical:
		# Phones: one column of 44 px rows, just under PRESS START (pushed up if a debug row won't fit).
		top = minf(S.PROMPT_TOP + prompt_line_h() + 2.0, S.FRAME.y - items.size() * S.MENU_ITEM_H)
		var w := 0.0
		for item in items:
			w = maxf(w, _text_w(_display, item, S.MENU_SIZE) + S.MENU_PAD_X * 2.0)
		w += 40.0  # room for the arrow inside the row
		for i in items.size():
			rects.append(Rect2((S.FRAME.x - w) / 2.0, top + i * S.MENU_ITEM_H, w, S.MENU_ITEM_H))
		return rects
	var widths: Array[float] = []
	var total := 0.0
	for item in items:
		var w := _text_w(_display, item, S.MENU_SIZE) + S.MENU_PAD_X * 2.0
		widths.append(w)
		total += w
	total += S.MENU_ITEM_GAP * (items.size() - 1)
	var x := (S.FRAME.x - total) / 2.0
	for w in widths:
		rects.append(Rect2(x, top, w, S.MENU_ITEM_H))
		x += w + S.MENU_ITEM_GAP
	return rects


func _draw_prompt_and_menu() -> void:
	var prompt: String = DataRegistry.title_screen.get("prompt", "PRESS START")
	if attract and fposmod(_time / S.T_BLINK_PROMPT, 1.0) < 0.5:
		var w := _text_w(_display, prompt, S.PROMPT_SIZE)
		var at := Vector2((S.FRAME.x - w) / 2.0, S.PROMPT_TOP + _display.get_ascent(S.PROMPT_SIZE))
		TitleLogo.glow_text(_fg, _display, at, prompt, S.PROMPT_SIZE, Color(S.AMBER, 0.7), S.PROMPT_GLOW)
		_fg.draw_string(_display, at, prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, S.PROMPT_SIZE, S.AMBER)
	var rects := menu_rects()
	for i in items.size():
		var r := rects[i]
		var text := items[i]
		var tw := _text_w(_display, text, S.MENU_SIZE)
		var tx := r.position.x + (r.size.x - tw) / 2.0 if vertical else r.position.x + S.MENU_PAD_X
		var asc := _display.get_ascent(S.MENU_SIZE)
		var at := Vector2(tx, r.position.y + (r.size.y - _line_h(_display, S.MENU_SIZE)) / 2.0 + asc)
		if i == selected:
			TitleLogo.glow_text(_fg, _display, at, text, S.MENU_SIZE, accent, S.MENU_GLOW)
			_fg.draw_string(_display, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, S.MENU_SIZE, S.TEXT_HI)
			var p := fposmod(_motion / S.T_ARROW, 1.0)
			var nudge := 6.0 * (S.ease_in_out(p * 2.0) if p < 0.5 else S.ease_in_out(2.0 - p * 2.0))
			var arrow_at := Vector2(tx - S.ARROW_GAP - 10.0 + nudge, r.get_center().y - 8.0)
			var pts := PackedVector2Array()
			for v in S.ARROW:
				pts.append(v + arrow_at)
			_fg.draw_colored_polygon(pts, S.AMBER)
			if InputPrompts.scheme == "keyboard":
				_draw_focus_ring(r.grow(2.0))
		else:
			var c := S.TEXT_DIM if enabled[i] else Color(S.TEXT_DIM, 0.5)
			_fg.draw_string(_display, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, S.MENU_SIZE, c)


func _draw_focus_ring(r: Rect2) -> void:
	var c := S.AMBER
	_fg.draw_dashed_line(r.position, Vector2(r.end.x, r.position.y), c, 2.0, 6.0)
	_fg.draw_dashed_line(Vector2(r.end.x, r.position.y), r.end, c, 2.0, 6.0)
	_fg.draw_dashed_line(r.end, Vector2(r.position.x, r.end.y), c, 2.0, 6.0)
	_fg.draw_dashed_line(Vector2(r.position.x, r.end.y), r.position, c, 2.0, 6.0)


## How much of boot log line `i` has been typed after `t` seconds (28 steps over 1.6 s, then the next line).
static func typed(line: String, i: int, t: float) -> String:
	var steps := clampi(floori((t - i * S.T_BOOT_LINE) / S.T_BOOT_LINE * S.BOOT_STEPS), 0, S.BOOT_STEPS)
	return line.substr(0, ceili(line.length() * steps / float(S.BOOT_STEPS)))


func _draw_boot_log() -> void:
	var asc := _body.get_ascent(S.BOOT_SIZE)
	var top := S.FRAME.y - S.BOOT_BOTTOM - S.BOOT_LINE * _boot_lines.size()
	for i in _boot_lines.size():
		var y := top + i * S.BOOT_LINE + (S.BOOT_LINE - _line_h(_body, S.BOOT_SIZE)) / 2.0 + asc
		_fg.draw_string(_body, Vector2(S.BOOT_LEFT, y), typed(_boot_lines[i], i, _time), HORIZONTAL_ALIGNMENT_LEFT, -1, S.BOOT_SIZE, S.TERMINAL)
	var vw := _text_w(_body, _version_text, S.VERSION_SIZE)
	var vy := S.FRAME.y - S.BOOT_BOTTOM - _body.get_descent(S.VERSION_SIZE)
	_fg.draw_string(_body, Vector2(S.FRAME.x - S.VERSION_RIGHT - vw, vy), _version_text, HORIZONTAL_ALIGNMENT_LEFT, -1, S.VERSION_SIZE, S.TEXT_DIM)


# --- input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	# Touches also arrive as emulated mouse events; handle the touch, skip its copy.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventAction and event.action.begins_with("move_"):
		return  # the touch d-pad sends move_* and ui_* together; react once
	if _is_press(event):
		attract = false
	if event is InputEventScreenTouch and event.pressed:
		var hit := item_at(event.position)
		if hit >= 0:
			if hit == selected:
				activate(hit)
			else:
				select(hit)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		var hover := item_at(event.position)
		if hover >= 0:
			select(hover)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := item_at(event.position)
		if hit >= 0:
			select(hit)
			activate(hit)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadMotion and (event.axis == JOY_AXIS_LEFT_X or event.axis == JOY_AXIS_LEFT_Y):
		if absf(event.axis_value) < 0.3:
			_stick_latched = false
		elif absf(event.axis_value) > 0.6 and not _stick_latched:
			_stick_latched = true
			move(1 if event.axis_value > 0 else -1)
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left") \
			or event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		move(-1)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right") \
			or event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		move(1)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("menu"):
		activate(selected)
	else:
		return
	get_viewport().set_input_as_handled()


static func _is_press(event: InputEvent) -> bool:
	return (event is InputEventKey and event.pressed) or (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventAction and event.pressed)


## Menu item under a screen point, or -1.
func item_at(screen_pos: Vector2) -> int:
	var p := _stage.get_global_transform().affine_inverse() * screen_pos
	var rects := menu_rects()
	for i in rects.size():
		if rects[i].has_point(p):
			return i if enabled[i] else -1
	return -1


func select(i: int) -> void:
	if i < 0 or i >= items.size() or not enabled[i] or i == selected:
		return
	selected = i
	AudioManager.play_sfx("select")


## Moves the selection, wrapping at both ends and skipping greyed-out items.
func move(step: int) -> void:
	var i := selected
	for _n in items.size():
		i = wrapi(i + step, 0, items.size())
		if enabled[i]:
			break
	select(i)


func activate(i: int) -> void:
	if i < 0 or i >= items.size() or not enabled[i]:
		return
	attract = false
	AudioManager.play_sfx("confirm")
	match items[i]:
		"CONTINUE":
			if SaveManager.load_game().is_empty():
				SceneRouter.goto(Overworld.SCENE)
		"NEW GAME":
			new_game()
			SceneRouter.goto(Overworld.SCENE, {"map": NEW_GAME_MAP, "spawn": "new_game"})
		"OPTIONS":
			await open_options()
		"DEBUG":
			SceneRouter.goto(DEBUG_MENU_SCENE)


func open_options() -> void:
	_busy = true
	if _options == null:
		_options = FieldMenus.new()
		_options.theme = UiTheme.get_theme()
		add_child(_options)
	await _options.options_screen()
	_busy = false


## Fresh run: no Daemons yet. You wake up at home (intro trigger), name yourself, and get a
## starter from the manager at the Help Desk.
static func new_game() -> void:
	GameState.reset()
	GameState.trainer_id = randi_range(10000, 99999)
	GameState.credits = 3000
