class_name TitleHero
extends Node2D
## Title layer 6, the 400x330 hero stage: expanding rings, rising embers, the featured legendary
## (bobbing, flame flicker / core pulse / eye blink in a shader) and its ground shadow.
## The sprite comes from data/title_screen.json: the LEFT half of a pixel map, mirrored.

const S := preload("res://scripts/ui/title/title_style.gd")
const SHADER := preload("res://scripts/ui/title/legendary_sprite.gdshader")
const KINDS := {"flicker": 1, "core_accent": 2, "core": 3, "eye": 4}

var time := 0.0          # always running (flicker, pulse, blink, embers)
var motion := 0.0        # stops when reduced motion is on (bob, shadow, rings)
var accent := S.ACCENT_DEFAULT:
	set(value):
		accent = value
		if _material:
			_material.set_shader_parameter("accent", value)

var sprite: Sprite2D
var sprite_size := Vector2i.ZERO
var _material: ShaderMaterial
var _silhouette: Texture2D
var _shadow_tex: GradientTexture2D


## Full sprite rows from the stored left half: each row padded to 16 with "." and mirrored.
static func mirror_rows(half: Array) -> PackedStringArray:
	var rows := PackedStringArray()
	for row: String in half:
		var h := row.rpad(16, ".")
		rows.append(h + h.reverse())
	return rows


## {"image", "kinds", "silhouette"} Images for a sprite record (see data/title_screen.json).
static func build_images(sprite_data: Dictionary, accent_color: Color) -> Dictionary:
	var rows := mirror_rows(sprite_data["half"])
	var palette: Dictionary = sprite_data.get("palette", {})
	var anim: Dictionary = sprite_data.get("anim", {})
	var w := rows[0].length()
	var h := rows.size()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var kinds := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var sil := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var ch := rows[y][x]
			if ch == "." or not palette.has(ch):
				continue
			var spec := str(palette[ch])
			img.set_pixel(x, y, accent_color if spec == "accent" else Color(spec))
			var kind: int = KINDS.get(anim.get(ch, ""), 0)
			kinds.set_pixel(x, y, Color8(kind * 40, 0, 0, 255))
			sil.set_pixel(x, y, S.FLAME)
	return {"image": img, "kinds": kinds, "silhouette": sil}


func setup(sprite_data: Dictionary) -> void:
	var images := build_images(sprite_data, accent)
	var img: Image = images["image"]
	sprite_size = img.get_size()
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("kinds", ImageTexture.create_from_image(images["kinds"]))
	_material.set_shader_parameter("sprite_size", Vector2(sprite_size))
	_material.set_shader_parameter("accent", accent)
	_silhouette = ImageTexture.create_from_image(images["silhouette"])
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.material = _material
	sprite.scale = Vector2.ONE * S.SPRITE_PIXEL
	_shadow_tex = GradientTexture2D.new()
	_shadow_tex.fill = GradientTexture2D.FILL_RADIAL
	_shadow_tex.fill_from = Vector2(0.5, 0.5)
	_shadow_tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(S.FLAME, 0.55))
	g.set_color(1, Color(S.FLAME, 0.0))
	_shadow_tex.gradient = g
	_update()


func ring_center() -> Vector2:
	return S.RING_ORIGIN + Vector2.ONE * S.RING_SIZE / 2.0


func sprite_rect() -> Rect2:
	var size := Vector2(sprite_size) * S.SPRITE_PIXEL
	return Rect2(ring_center() - size / 2.0 + Vector2(0, bob()), size)


## 0 at rest, 1 at the top of the bob (3.2 s ease-in-out up and back).
func bob_amount() -> float:
	var p := fposmod(motion / S.T_BOB, 1.0)
	return S.ease_in_out(p * 2.0) if p < 0.5 else S.ease_in_out(2.0 - p * 2.0)


func bob() -> float:
	return -14.0 * bob_amount()


func _process(_delta: float) -> void:
	_update()


func _update() -> void:
	if sprite == null:
		return
	sprite.position = sprite_rect().position
	_material.set_shader_parameter("time", time)
	queue_redraw()


func _draw() -> void:
	if sprite == null:
		return
	_draw_rings()
	_draw_embers()
	_draw_glow()
	_draw_shadow()


func _draw_rings() -> void:
	for i in 2:
		var p := fposmod((motion - i * S.T_RINGS / 2.0) / S.T_RINGS, 1.0)
		var e := S.ease_out(p)
		var scale_k := lerpf(0.6, 1.6, e)
		var color: Color = S.FLAME if i == 0 else accent
		draw_arc(ring_center(), S.RING_SIZE / 2.0 * scale_k, 0.0, TAU, 96,
			Color(color, 0.8 * (1.0 - e)), S.RING_STROKE * scale_k, true)


func _draw_embers() -> void:
	for i in S.EMBER_COUNT:
		var dur := lerpf(S.T_EMBER_MIN, S.T_EMBER_MAX, S.hash01(i, 11.0))
		var p := fposmod((time - i * S.T_EMBER_STAGGER) / dur, 1.0)
		var e := S.ease_out(p)
		var start := S.EMBER_ORIGIN + Vector2(lerpf(-100, 100, S.hash01(i, 12.0)), 0)
		var drift := lerpf(-60, 60, S.hash01(i, 13.0))
		var pos := start + Vector2(drift * e, -260.0 * e)
		var alpha := p / 0.15 if p < 0.15 else 1.0 - (p - 0.15) / 0.85
		var color: Color = S.FLAME if i % 2 == 0 else S.FLAME_HOT
		draw_rect(Rect2(pos - Vector2.ONE * S.EMBER_SIZE / 2.0, Vector2.ONE * S.EMBER_SIZE), Color(color, clampf(alpha, 0, 1)))


## drop-shadow(0 0 18px flame) at 65%: the flame silhouette stamped around the sprite.
func _draw_glow() -> void:
	var r := sprite_rect()
	for ring in 3:
		var radius := S.SPRITE_GLOW * (ring + 1) / 3.0
		for a in 8:
			var off := Vector2.from_angle(TAU * a / 8.0 + ring * 0.4) * radius
			draw_texture_rect(_silhouette, Rect2(r.position + off, r.size), false, Color(1, 1, 1, 0.65 * 0.09 * (1.0 - ring * 0.25)))


func _draw_shadow() -> void:
	var k := bob_amount()
	var w := S.SHADOW_SIZE.x * lerpf(1.0, 0.78, k)
	var top := ring_center().y + Vector2(sprite_size).y * S.SPRITE_PIXEL / 2.0 + S.SHADOW_GAP
	var rect := Rect2(Vector2(ring_center().x - w / 2.0, top), Vector2(w, S.SHADOW_SIZE.y))
	draw_texture_rect(_shadow_tex, rect, false, Color(1, 1, 1, lerpf(0.55, 0.3, k) / 0.55))
