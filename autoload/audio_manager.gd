extends Node
## Plays music, jingles and one-shot SFX, and owns volume settings.
## Music: play_music("town") loads res://assets/audio/music/town.ogg (or .wav/.mp3) and loops it.
## Until the soundtrack exists the hooks are silent, but `current_music` still tracks what
## should be playing (tests check it). Track ids used so far: town, route, dead_zone, help_desk,
## department, battle_wild, battle_trainer, battle_rival, battle_boss, victory. Jingles: heal.
## Until real SFX exist, a few placeholder blips are synthesized in code (square waves).
## Real files at res://assets/audio/sfx/<id>.wav or .ogg replace them automatically.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const JINGLE_DIR := "res://assets/audio/jingles/"
const MIX_RATE := 22050
## id -> [start Hz, end Hz, seconds, volume 0..1], or a list of those played back to back.
const PLACEHOLDER_SFX := {
	"bump": [110.0, 70.0, 0.08, 0.5],
	"select": [880.0, 880.0, 0.04, 0.35],
	"confirm": [660.0, 990.0, 0.08, 0.35],
	# Department challenges (2026-11-15)
	"unlock": [[523.0, 523.0, 0.07, 0.35], [659.0, 659.0, 0.07, 0.35], [784.0, 784.0, 0.14, 0.35]],
	"error": [[220.0, 190.0, 0.12, 0.45], [170.0, 130.0, 0.2, 0.45]],
	"alarm": [[880.0, 880.0, 0.11, 0.4], [620.0, 620.0, 0.11, 0.4], [880.0, 880.0, 0.11, 0.4], [620.0, 620.0, 0.14, 0.4]],
	"trip": [[160.0, 40.0, 0.28, 0.6]],
	"lane": [[300.0, 1100.0, 0.12, 0.22]],
	"click": [[1300.0, 1300.0, 0.025, 0.25]],
}

var music_volume: float = 1.0
var sfx_volume: float = 1.0

var current_music: String = ""
var last_jingle: String = ""

var _sfx_cache: Dictionary = {}
var _music_player: AudioStreamPlayer


func play_music(track_id: String) -> void:
	if track_id == current_music:
		return
	current_music = track_id
	if _music_player == null:
		_music_player = AudioStreamPlayer.new()
		add_child(_music_player)
	_music_player.stop()
	var stream := _find_stream(MUSIC_DIR, track_id)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	_music_player.stream = stream
	_music_player.volume_db = linear_to_db(maxf(music_volume, 0.0001))
	_music_player.play()


func stop_music() -> void:
	current_music = ""
	if _music_player != null:
		_music_player.stop()


## Short fanfare (e.g. "heal" at the Help Desk). Placeholder blips until real files exist.
func play_jingle(jingle_id: String) -> void:
	last_jingle = jingle_id
	var stream := _find_stream(JINGLE_DIR, jingle_id)
	if stream == null:
		for sfx in ["select", "confirm", "confirm"]:
			play_sfx(sfx)
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = linear_to_db(maxf(music_volume, 0.0001))
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _find_stream(dir: String, id: String) -> AudioStream:
	if id.is_empty():
		return null
	for ext in [".ogg", ".wav", ".mp3"]:
		if ResourceLoader.exists(dir + id + ext):
			return load(dir + id + ext)
	return null


func play_sfx(sfx_id: String) -> void:
	var stream := _sfx_stream(sfx_id)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = linear_to_db(maxf(sfx_volume, 0.0001))
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _sfx_stream(sfx_id: String) -> AudioStream:
	if _sfx_cache.has(sfx_id):
		return _sfx_cache[sfx_id]
	var stream: AudioStream = null
	for ext in [".wav", ".ogg"]:
		if ResourceLoader.exists(SFX_DIR + sfx_id + ext):
			stream = load(SFX_DIR + sfx_id + ext)
			break
	if stream == null and PLACEHOLDER_SFX.has(sfx_id):
		stream = _square_blip(PLACEHOLDER_SFX[sfx_id])
	_sfx_cache[sfx_id] = stream
	return stream


static func _square_blip(spec: Array) -> AudioStreamWAV:
	var segments: Array = spec if typeof(spec[0]) == TYPE_ARRAY else [spec]
	var data := PackedByteArray()
	var phase := 0.0
	for seg: Array in segments:
		var samples := int(MIX_RATE * float(seg[2]))
		for i in samples:
			var t := float(i) / samples
			var freq := lerpf(seg[0], seg[1], t)
			phase = fmod(phase + freq / MIX_RATE, 1.0)
			var amp := float(seg[3]) * (1.0 - t * 0.85)  # fade out (not to silence, so tones join up)
			var value := int((1 if phase < 0.5 else -1) * amp * 100.0)
			data.append(value & 0xFF)  # signed 8-bit
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
