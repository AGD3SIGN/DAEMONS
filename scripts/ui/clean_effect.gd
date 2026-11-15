class_name CleanEffect
extends Control
## The shared "corruption cleaned" effect (2026-11-15), the same for every species, made in code (no extra art):
##   1. the corrupted sprite glitch-slices (bands of rows jump sideways)
##   2. dark squares fall away from it
##   3. a stepped palette swap into the clean sprite: 4 hard steps through an ordered dither, no crossfade, no glow
## Usage: var fx := CleanEffect.new(); add_child(fx); await fx.play(corrupted_tex, clean_tex)
## time_scale 0 finishes instantly (tests, animations off).

signal finished

const STEP := 0.07          # seconds per frame of the effect
const SLICE_FRAMES := 6
const FALL_FRAMES := 7
const SWAP_STEPS := 4
## 4x4 ordered-dither thresholds: a pixel turns clean once the step passes its value.
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

var time_scale := 1.0
var pixel_scale := 2.0       # the sprite is drawn this many screen pixels per art pixel

var _tex: Texture2D
var _squares: Array = []     # [Vector2 pos, float fall] in art pixels
var _show_squares := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func play(corrupted: Texture2D, clean: Texture2D) -> void:
	if corrupted == null or clean == null:
		_tex = clean
		queue_redraw()
		return
	var bad := corrupted.get_image()
	var good := clean.get_image()
	bad.convert(Image.FORMAT_RGBA8)
	good.convert(Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 443
	# 1. glitch slices
	for f in SLICE_FRAMES:
		_tex = ImageTexture.create_from_image(sliced(bad, rng))
		queue_redraw()
		await _frame()
	# 2. dark squares fall away
	_tex = ImageTexture.create_from_image(bad)
	_squares.clear()
	for i in 8:
		_squares.append([Vector2(rng.randi_range(10, 50), rng.randi_range(10, 40)), 0.0])
	_show_squares = true
	for f in FALL_FRAMES:
		for sq: Array in _squares:
			sq[1] = float(sq[1]) + 3.0 + f
		queue_redraw()
		await _frame()
	_show_squares = false
	# 3. stepped palette swap
	for step in range(1, SWAP_STEPS + 1):
		_tex = ImageTexture.create_from_image(swap_step(bad, good, step))
		queue_redraw()
		await _frame()
		await _frame()
	_tex = clean
	queue_redraw()
	finished.emit()


func _frame() -> void:
	if time_scale <= 0.0 or not is_inside_tree():
		return
	await get_tree().create_timer(STEP * time_scale).timeout


## Bands of rows shifted sideways by 2-4 px, a new pattern every call.
static func sliced(src: Image, rng: RandomNumberGenerator) -> Image:
	var img := src.duplicate() as Image
	var w := img.get_width()
	for band in 3:
		var y0 := rng.randi_range(0, img.get_height() - 6)
		var shift := rng.randi_range(2, 4) * (1 if rng.randf() < 0.5 else -1)
		for y in range(y0, y0 + rng.randi_range(2, 5)):
			var line := src.get_region(Rect2i(0, y, w, 1))
			img.fill_rect(Rect2i(0, y, w, 1), Color(0, 0, 0, 0))
			img.blit_rect(line, Rect2i(0, 0, w, 1), Vector2i(shift, y))
	return img


## Step k of SWAP_STEPS: pixels whose dither threshold is below k/SWAP_STEPS show the clean image.
@warning_ignore("integer_division")
static func swap_step(bad: Image, good: Image, step: int) -> Image:
	var img := bad.duplicate() as Image
	var limit := 16 * step / SWAP_STEPS
	for y in img.get_height():
		for x in img.get_width():
			if int(BAYER[(y % 4) * 4 + (x % 4)]) < limit:
				img.set_pixel(x, y, good.get_pixel(x, y))
	return img


func _draw() -> void:
	if _tex == null:
		return
	var size_px := Vector2(_tex.get_width(), _tex.get_height()) * pixel_scale
	var origin := (size - size_px) / 2.0
	draw_texture_rect(_tex, Rect2(origin.floor(), size_px), false)
	if _show_squares:
		for sq: Array in _squares:
			var p: Vector2 = sq[0] + Vector2(0, float(sq[1]))
			if p.y < 64:
				draw_rect(Rect2((origin + p * pixel_scale).floor(), Vector2(3, 3) * pixel_scale), Color("0b0b10"))
