class_name CaptureMeter
extends Panel
## The Quarantine progress bar shown while a key works on a wild Daemon: three segments,
## SCAN / ISOLATE / ENCRYPT. Each passed stage (a "capture_shake" event) fills green; the stage
## where the Daemon breaks free fills part way and turns red. BattlePlayer drives it.

const STAGES: PackedStringArray = ["SCAN", "ISOLATE", "ENCRYPT"]
const SEGMENT_W := 58
const GAP := 2
const PAD := 3
const BAR_Y := 13
const BAR_H := 6
const SIZE := Vector2(PAD * 2 + SEGMENT_W * 3 + GAP * 2, 22)
const TRACK := Color("384058")
const FILL := Color("4098d0")   # working
const OK := Color("48c048")     # stage passed
const FAIL := Color("e04830")   # broke free here

var progress: Array[float] = [0.0, 0.0, 0.0]
var states: PackedStringArray = ["", "", ""]  # "" working/pending, "ok", "fail"


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	reset()
	visible = false


## Empty bar, all stages waiting.
func reset() -> void:
	for i in STAGES.size():
		progress[i] = 0.0
		states[i] = ""
	queue_redraw()


func set_progress(stage: int, value: float) -> void:
	progress[stage] = clampf(value, 0.0, 1.0)
	queue_redraw()


func set_state(stage: int, value: String) -> void:
	states[stage] = value
	queue_redraw()


## How many stages are filled and passed (for tests and the battle log).
func passed() -> int:
	return Array(states).count("ok")


func segment_rect(stage: int) -> Rect2:
	return Rect2(PAD + stage * (SEGMENT_W + GAP), BAR_Y, SEGMENT_W, BAR_H)


## Label color: grey while waiting, ink while working, green when passed, red where it broke free.
func label_color(stage: int) -> Color:
	match states[stage]:
		"ok":
			return OK.darkened(0.35)
		"fail":
			return FAIL
	return UiTheme.INK if progress[stage] > 0.0 else UiTheme.MUTED


func _draw() -> void:
	# Text is drawn here (not with Labels) so it's centered on its segment with the 8 px pixel font.
	var font := UiTheme.get_theme().default_font
	for i in STAGES.size():
		var r := segment_rect(i)
		draw_string(font, Vector2(r.position.x, 11), STAGES[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 8, label_color(i))
		draw_rect(r, TRACK)
		var fill := FILL
		match states[i]:
			"ok":
				fill = OK
			"fail":
				fill = FAIL
		var w := floorf((r.size.x - 2) * progress[i])
		if w > 0:
			draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(w, r.size.y - 2)), fill)
