extends Node
## Player options that apply to every save: text speed, volumes, battle animations.
## Stored in user://settings.cfg, separate from save files.

const PATH := "user://settings.cfg"

## Tests point this elsewhere so they never touch real settings.
var path: String = PATH
const TEXT_SPEEDS := {"slow": 30.0, "mid": 60.0, "fast": 120.0, "instant": 0.0}
const TEXT_SPEED_ORDER: PackedStringArray = ["slow", "mid", "fast", "instant"]

var text_speed: String = "mid"
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var battle_animations: bool = true
var autosave_on_suspend: bool = true  # mobile: save when the app goes to the background


func _ready() -> void:
	load_settings()
	apply()


## Characters per second for typewriter text (0 = show instantly).
func chars_per_second() -> float:
	return TEXT_SPEEDS.get(text_speed, 60.0)


func apply() -> void:
	AudioManager.music_volume = music_volume
	AudioManager.sfx_volume = sfx_volume


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("options", "text_speed", text_speed)
	cfg.set_value("options", "music_volume", music_volume)
	cfg.set_value("options", "sfx_volume", sfx_volume)
	cfg.set_value("options", "battle_animations", battle_animations)
	cfg.set_value("options", "autosave_on_suspend", autosave_on_suspend)
	cfg.save(path)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	text_speed = String(cfg.get_value("options", "text_speed", text_speed))
	if not TEXT_SPEEDS.has(text_speed):
		text_speed = "mid"
	music_volume = clampf(float(cfg.get_value("options", "music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("options", "sfx_volume", sfx_volume)), 0.0, 1.0)
	battle_animations = bool(cfg.get_value("options", "battle_animations", battle_animations))
	autosave_on_suspend = bool(cfg.get_value("options", "autosave_on_suspend", autosave_on_suspend))
