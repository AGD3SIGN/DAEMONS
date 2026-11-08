extends Node
## Plays music (with crossfades) and one-shot SFX, and owns volume settings.
## Music hooks arrive in Phase 7; volume options in Phase 6.
## Until real SFX exist, a few placeholder blips are synthesized in code (square waves).
## Real files at res://assets/audio/sfx/<id>.wav or .ogg replace them automatically.

const SFX_DIR := "res://assets/audio/sfx/"
const MIX_RATE := 22050
## id -> [start Hz, end Hz, seconds, volume 0..1]
const PLACEHOLDER_SFX := {
	"bump": [110.0, 70.0, 0.08, 0.5],
	"select": [880.0, 880.0, 0.04, 0.35],
	"confirm": [660.0, 990.0, 0.08, 0.35],
}

var music_volume: float = 1.0
var sfx_volume: float = 1.0

var _sfx_cache: Dictionary = {}


func play_music(_track_id: String) -> void:
	pass


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
	var samples := int(MIX_RATE * float(spec[2]))
	var data := PackedByteArray()
	data.resize(samples)
	var phase := 0.0
	for i in samples:
		var t := float(i) / samples
		var freq := lerpf(spec[0], spec[1], t)
		phase = fmod(phase + freq / MIX_RATE, 1.0)
		var amp := float(spec[3]) * (1.0 - t)  # fade out
		var value := int((1 if phase < 0.5 else -1) * amp * 100.0)
		data[i] = value & 0xFF  # signed 8-bit
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
