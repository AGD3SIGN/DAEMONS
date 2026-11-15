class_name CmdbPanel
extends Panel
## One CMDB (Configuration Management Database) entry, written like an asset record.
## Seen Daemons show their sprite and basics; Quarantined ones also show the full entry.

signal _closed

var _open := false
var _sprite: TextureRect
var _text: Label
var _entry: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # let taps reach _unhandled_input (tap anywhere to continue)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 6
	offset_top = 6
	offset_right = -6
	offset_bottom = -6
	_sprite = TextureRect.new()
	_sprite.position = Vector2(10, 12)
	_sprite.size = Vector2(64, 64)
	add_child(_sprite)
	_text = Label.new()
	_text.position = Vector2(84, 10)
	_text.add_theme_constant_override("line_spacing", 3)
	add_child(_text)
	_entry = Label.new()
	_entry.position = Vector2(10, 86)
	_entry.size = Vector2(288, 70)
	_entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_entry)
	visible = false


func open(species_id: String) -> void:
	var data := DataRegistry.get_species(species_id)
	var number := DataRegistry.cmdb_number(species_id)
	var caught: bool = GameState.cmdb_caught.get(species_id, false)
	var types := "/".join(data["types"].map(func(t: String) -> String: return String(DataRegistry.types[t]["name"]).to_upper()))
	_sprite.texture = DaemonSprites.front(species_id)
	_text.text = "ASSET DMN-%03d\n%s\n%s\n%s\nFound: %s" % [number, data["name"], data["cmdb"]["category"], types,
		GameState.cmdb_found_at.get(species_id, "Unknown")]
	_entry.text = data["cmdb"]["entry"] if caught else "No data. Quarantine one to complete this record."
	var status := status_line(species_id)
	if not status.is_empty():
		_entry.text = status + "\n" + _entry.text
	visible = true
	_open = true
	await _closed
	visible = false


## Corruption status on the record (2026-11-15): COMPROMISED once you've seen a corrupted one, Recovered once a
## Help Desk has cleaned one of yours. "" for species you've only met clean.
static func status_line(species_id: String) -> String:
	if not GameState.corruption_revealed():
		# Before the Power Plant reveal only the demo teaser's glitched sighting shows anything.
		return "Status: UNKNOWN" if GameState.cmdb_unknown.get(species_id, false) else ""
	if GameState.cmdb_recovered.get(species_id, false):
		return "Status: Recovered"
	if GameState.cmdb_compromised.get(species_id, false):
		return "Status: COMPROMISED | Note: Unauthorized code detected. Do not connect to production."
	return ""


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept") \
			or (event is InputEventMouseButton and event.pressed):
		get_viewport().set_input_as_handled()
		_open = false
		_closed.emit.call_deferred()
