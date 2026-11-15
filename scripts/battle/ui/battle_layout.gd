class_name BattleLayout
extends RefCounted
## Where everything sits in the battle, in design-frame pixels. Two layouts:
##   wide(): the Battle Scene spec's 960x640 frame (desktop, landscape, tablets), scaled by whole numbers.
##   tall(): 640x800 for phones held upright (2026-11-15, Brandon: "everything is hard to read"). The wide frame
##           only fit once on a portrait phone (about 75% of the width, under half the height). The tall frame puts
##           the Forgelings and their cards up top and the console + commands full width underneath, and scales to
##           fill the screen (fractional scaling is fine at phone pixel densities), so it's ~1.7x bigger.
## BattleScene picks one when the battle starts (pick()).

var tall_layout := false
var frame := Vector2(960, 640)
var allow_fractional := false     # true: scale to fill instead of whole-number steps
var horizon := 300.0              # where the back wall meets the floor
var foe_sprite_at := Vector2(639, 167)
var player_sprite_at := Vector2(112, 226)
var player_sprite_scale := 4.0    # the player's Forgeling is drawn bigger: closer to the camera
var foe_card_at := Vector2(28, 28)
var player_panel_at := Vector2(960 - 28 - 420, 384)
var capture_meter_at := Vector2(28, 162)
var stat_popup_at := Vector2(960 - 28 - 300, 150)
var console_rect := Rect2(16, 476, 928, 148)
var console_menu_width := 496.0   # console width while the command menu is open
var command_rect := Rect2(524, 476, 420, 148)
var back_rect := Rect2(358, 568, 130, 44)
var list_rect := Rect2(16, 16, 928, 454)
var wild_pad := Rect2(590, 318, 290, 64)
var host_pad := Rect2(40, 420, 400, 92)
var host_label_y := 402.0
var show_zone_tag := true


static func wide() -> BattleLayout:
	return BattleLayout.new()


static func tall() -> BattleLayout:
	var l := BattleLayout.new()
	l.tall_layout = true
	l.frame = Vector2(640, 800)
	l.allow_fractional = true
	l.horizon = 236.0
	# Field (top 470 px): foe up and to the right, its card top-left; your Forgeling bottom-left, its card beside it.
	l.foe_card_at = Vector2(16, 16)
	l.foe_sprite_at = Vector2(428, 112)
	l.wild_pad = Rect2(392, 268, 236, 56)
	l.host_label_y = 336.0
	l.capture_meter_at = Vector2(16, 144)
	l.player_sprite_scale = 3.0
	l.player_sprite_at = Vector2(16, 254)
	l.host_pad = Rect2(0, 412, 248, 62)
	l.player_panel_at = Vector2(640 - 12 - 420, 376)
	l.stat_popup_at = Vector2(640 - 16 - 300, 136)
	l.show_zone_tag = false
	# Console and commands stacked, full width.
	l.console_rect = Rect2(12, 478, 616, 148)
	l.console_menu_width = 616.0
	l.command_rect = Rect2(12, 636, 616, 152)
	l.back_rect = Rect2(12 + 616 - 146, 478 + 148 - 56, 130, 44)
	l.list_rect = Rect2(12, 12, 616, 456)
	return l


## Tall for portrait screens (taller than wide), wide otherwise.
static func pick(view: Vector2) -> BattleLayout:
	return tall() if view.y > view.x else wide()
