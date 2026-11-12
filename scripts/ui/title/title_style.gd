class_name TitleStyle
extends RefCounted
## Every value from the "DAEMONS Start Screen — Style Guide" (2026-11-11) in one place.
## Positions and sizes are in the guide's 1280x720 frame; TitleScreen scales the frame to fit.

const FRAME := Vector2(1280, 720)

# --- color tokens ------------------------------------------------------------
const BG_VOID := Color("#05070f")
const BG_MID := Color("#0a1230")
const BG_GLOW := Color("#12224a")
const ACCENT_DEFAULT := Color("#2fd8ff")
const ACCENT_PRESETS := [Color("#2fd8ff"), Color("#b6ff3b"), Color("#ff3fa4"), Color("#ffc53d")]
const LIME := Color("#b6ff3b")
const MAGENTA := Color("#ff3fa4")
const AMBER := Color("#ffc53d")
const TRACE_IDLE := Color("#1d3a6e")
const LOGO_SHADOW := Color("#1b2f66")
const TEXT_HI := Color("#ffffff")
const TEXT_BASE := Color("#e8fbff")
const TEXT_DIM := Color("#8fa3c8")
const TERMINAL := Color("#6fd3a0")
const FLAME := Color("#ff7a1a")
const FLAME_HOT := Color("#ffd23f")
const FLAME_SOFT := Color("#ffb27a")
const CARD_BG := Color(10 / 255.0, 6 / 255.0, 14 / 255.0, 0.72)
const FLOOR_LINE_H := Color(47 / 255.0, 216 / 255.0, 1.0, 0.45)
const FLOOR_LINE_V := Color(47 / 255.0, 216 / 255.0, 1.0, 0.35)

# --- fonts -------------------------------------------------------------------
const DISPLAY_FONT := "res://assets/fonts/PressStart2P-Regular.ttf"
const BODY_FONT := "res://assets/fonts/VT323-Regular.ttf"

# --- layout (1280x720 frame) -------------------------------------------------
const TITLE_TOP := 54.0
const LOGO_SIZE := 92
const LOGO_LINE := 104.0
const LOGO_SPACING := 6
const LOGO_SHADOW_DROP := 6.0
const LOGO_GLOW := 24.0
const TAGLINE_GAP := 14.0
const TAGLINE_SIZE := 30
const TAGLINE_SPACING := 8

const HERO_POS := Vector2(440, 232)       # 400x330 stage, centered
const HERO_SIZE := Vector2(400, 330)
const RING_ORIGIN := Vector2(60, 10)      # stage-local top-left of the 280 px rings
const RING_SIZE := 280.0
const RING_STROKE := 3.0
const SPRITE_PIXEL := 11.0
const SPRITE_GLOW := 18.0
const SHADOW_SIZE := Vector2(240, 18)
const SHADOW_GAP := 14.0
const EMBER_COUNT := 10
const EMBER_SIZE := 6.0
const EMBER_ORIGIN := Vector2(200, 200)

const CARD_RIGHT := 64.0
const CARD_TOP := 300.0
const CARD_WIDTH := 230.0
const CARD_PAD := Vector2(18, 16)         # x = left/right, y = top/bottom
const CARD_BORDER := 2.0
const CARD_GLOW := 22.0
const CARD_LINE_GAP := 6.0
const CARD_LABEL_SIZE := 10
const CARD_LABEL_SPACING := 2
const CARD_NAME_SIZE := 18
const CARD_SUB_SIZE := 22
const CARD_NUM_SIZE := 20

const PROMPT_TOP := 566.0
const PROMPT_SIZE := 20
const PROMPT_GLOW := 12.0
const MENU_GAP := 10.0                    # between PRESS START and the menu row
const MENU_SIZE := 16
const MENU_ITEM_GAP := 28.0
const MENU_ITEM_H := 44.0
const MENU_PAD_X := 12.0
const MENU_GLOW := 10.0
const ARROW_GAP := 10.0
const ARROW := [Vector2(0, 0), Vector2(4, 0), Vector2(4, 2), Vector2(6, 2), Vector2(6, 4),
	Vector2(8, 4), Vector2(8, 6), Vector2(10, 6), Vector2(10, 10), Vector2(8, 10), Vector2(8, 12), Vector2(6, 12),
	Vector2(6, 14), Vector2(4, 14), Vector2(4, 16), Vector2(0, 16)]

const BOOT_LEFT := 28.0
const BOOT_BOTTOM := 22.0
const BOOT_SIZE := 22
const BOOT_LINE := 24.0
const VERSION_RIGHT := 28.0
const VERSION_SIZE := 22

const BIT_COUNT := 18
const BIT_SIZES := [18, 24, 30, 36]
const BIT_GLYPHS := "01{}#>"

const FLOOR_TOP := 440.0                  # 720 - (-40) - 320
const FLOOR_LEFT := -320.0
const FLOOR_WIDTH := 1920.0
const FLOOR_DEPTH := 320.0
const FLOOR_TILT_DEG := 62.0
const FLOOR_PERSPECTIVE := 360.0
const FLOOR_CELL := 64.0
const FLOOR_FADE := 0.45

const TRACES := [
	"M0 120 H180 L220 160 H360 L390 130 H470",
	"M0 260 H120 L160 220 H300",
	"M1280 100 H1100 L1060 140 H920 L890 110 H810",
	"M1280 240 H1160 L1120 200 H980",
	"M60 0 V60 L100 100 V180",
	"M1220 0 V70 L1180 110 V170",
]
const TRACE_ALPHA := 0.55
const TRACE_PAD_R := 5.0

# --- timings (seconds) -------------------------------------------------------
const T_FLOOR := 1.4
const T_TRACE_A := 3.6
const T_TRACE_B := 5.2
const T_TRACE_B_START := -2.0
const T_GLITCH := 4.5
const T_GLITCH_LIME := -0.15
const T_BOB := 3.2
const T_RINGS := 2.8
const T_EMBER_MIN := 2.2
const T_EMBER_MAX := 3.7
const T_EMBER_STAGGER := 0.37
const T_BLINK_PROMPT := 1.1
const T_ARROW := 0.7
const T_BOOT_LINE := 1.6
const BOOT_STEPS := 28
const T_SCAN_BAR := 6.0
const SCAN_BAR_H := 140.0


## Fixed "random" in [0, 1) from an index and a salt, so every launch looks the same.
static func hash01(i: float, salt: float = 0.0) -> float:
	var v := sin(i * 12.9898 + salt * 78.233) * 43758.5453
	return v - floorf(v)


## CSS ease-in-out (close enough: smoothstep).
static func ease_in_out(p: float) -> float:
	return p * p * (3.0 - 2.0 * p)


## CSS ease-out (close enough: quadratic).
static func ease_out(p: float) -> float:
	return 1.0 - (1.0 - p) * (1.0 - p)


## Parses the guide's simple SVG paths (M, H, V, L with absolute coordinates) into points.
static func parse_path(d: String) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var tokens := PackedStringArray()
	for m in RegEx.create_from_string("[MHVL]|-?[0-9]+(\\.[0-9]+)?").search_all(d):
		tokens.append(m.get_string())
	var cur := Vector2.ZERO
	var i := 0
	while i < tokens.size():
		var cmd := tokens[i]
		match cmd:
			"M", "L":
				cur = Vector2(float(tokens[i + 1]), float(tokens[i + 2]))
				i += 3
			"H":
				cur.x = float(tokens[i + 1])
				i += 2
			"V":
				cur.y = float(tokens[i + 1])
				i += 2
			_:
				push_error("TitleStyle: unsupported path command %s" % cmd)
				return pts
		pts.append(cur)
	return pts
