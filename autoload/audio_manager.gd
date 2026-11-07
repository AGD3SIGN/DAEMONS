extends Node
## Plays music (with crossfades) and one-shot SFX, and owns volume settings.
## Music hooks arrive in Phase 7; volume options in Phase 6.

var music_volume: float = 1.0
var sfx_volume: float = 1.0


func play_music(_track_id: String) -> void:
	pass


func play_sfx(_sfx_id: String) -> void:
	pass
