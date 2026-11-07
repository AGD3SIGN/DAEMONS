extends Control
## Debug-only playground for the Phase 1 systems: browse every Daemon, change its level,
## roll new Build Quality / profiles, level up, upgrade, and check save/load on every change.
## Not part of the real game. Opens from the title screen in debug builds.

const TITLE_SCENE := "res://scenes/debug/debug_menu.tscn"  # "back" returns to the debug menu
const STAT_LABELS := {
	"uptime": "Uptime", "throughput": "Thrpt", "hardening": "Hardn",
	"compute": "Compt", "encryption": "Encry", "bandwidth": "Bandw",
}
const LOG_LINES := 5

var daemon: DaemonInstance
var save_ok := false

var _species_ids: Array = []
var _index := 0
var _level := 5
var _seed := 1
var _log := PackedStringArray()
var _left: Label
var _right: Label


func _ready() -> void:
	_species_ids = DataRegistry.species.keys()
	var bg := ColorRect.new()
	bg.color = Color("10142a")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_left = _make_label(Vector2(4, 4), Vector2(154, 150))
	_right = _make_label(Vector2(164, 4), Vector2(154, 150))
	var help := _make_label(Vector2(4, 160), Vector2(312, 20))
	help.modulate = Color(0.6, 0.65, 0.85)
	help.text = "<> Daemon  ^v Level  Z +1 Lv (chip)\nSHIFT Reroll  SPACE Upgrade  X Back"
	_rebuild()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_right"):
		change_species(1)
	elif event.is_action_pressed("move_left"):
		change_species(-1)
	elif event.is_action_pressed("move_up"):
		change_level(1)
	elif event.is_action_pressed("move_down"):
		change_level(-1)
	elif event.is_action_pressed("ui_accept"):
		overclock()
	elif event.is_action_pressed("run"):
		reroll()
	elif event.is_action_pressed("menu"):
		upgrade()
	elif event.is_action_pressed("ui_cancel"):
		SceneRouter.goto(TITLE_SCENE)
	else:
		return
	get_viewport().set_input_as_handled()


# --- actions (public so tests can drive them) --------------------------------

func change_species(step: int) -> void:
	_index = wrapi(_index + step, 0, _species_ids.size())
	_rebuild()


func change_level(step: int) -> void:
	_level = clampi(_level + step, 1, DaemonInstance.MAX_LEVEL)
	_rebuild()


func reroll() -> void:
	_seed += 1
	_rebuild()
	_add_log("Rolled seed %d" % _seed)


func overclock() -> void:
	var events := daemon.level_up()
	if events.is_empty():
		_add_log("Already Lv 100")
	for e in events:
		match e["type"]:
			"level_up":
				_add_log("Lv %d! Uptime +%d" % [e["level"], e["stat_gains"]["uptime"]])
			"move_learned":
				_add_log("+" + _move_name(e["move"]))
			"move_learn_pending":
				_add_log("Full: " + _move_name(e["move"]))
	_level = daemon.level
	_refresh()


func upgrade() -> void:
	var target := daemon.check_evolution("level")
	if target.is_empty():
		target = daemon.check_evolution("item", "legacy_driver")
	if target.is_empty():
		target = daemon.check_evolution("sync")
	if target.is_empty():
		_add_log("No upgrade yet")
	else:
		daemon.evolve(target)
		_index = _species_ids.find(target)
		_add_log("-> " + daemon.display_name())
	_refresh()


# --- drawing -----------------------------------------------------------------

func _rebuild() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	daemon = DaemonInstance.create(_species_ids[_index], _level, rng)
	_refresh()


func _refresh() -> void:
	var restored := DaemonInstance.from_dict(JSON.parse_string(JSON.stringify(daemon.to_dict())))
	save_ok = restored != null and restored.to_dict() == daemon.to_dict()

	var profile: Dictionary = DataRegistry.config_profiles[daemon.config_profile]
	var types := "/".join(daemon.types().map(func(t: String) -> String: return DataRegistry.types[t]["name"]))
	var lines := PackedStringArray([
		"< %s >" % daemon.display_name(),
		"Lv %d  %s" % [daemon.level, types],
		String(profile["name"]),
		"EXP %d" % daemon.total_exp,
		"Next lv: %d" % daemon.exp_to_next_level(),
		"",
		"STAT     VAL   BQ",
	])
	for stat: String in DaemonInstance.STATS:
		var bq := int(daemon.build_quality[stat])
		if stat == "uptime":
			lines.append("%-6s %7s  %2d" % [STAT_LABELS[stat], "%d/%d" % [daemon.current_uptime, daemon.max_uptime()], bq])
		else:
			var mark := "+" if profile["up"] == stat else ("-" if profile["down"] == stat else " ")
			lines.append("%-5s%s %7d  %2d" % [STAT_LABELS[stat], mark, daemon.get_stat(stat), bq])
	_left.text = "\n".join(lines)

	var right := PackedStringArray(["MOVES"])
	for slot in daemon.moves:
		right.append("%-15s %2d" % [_move_name(slot["id"]), slot["pp"]])
	for i in DaemonInstance.MAX_MOVES - daemon.moves.size():
		right.append("-")
	right.append("")
	right.append("Next: " + _next_upgrade_text())
	right.append("Save/load: " + ("OK" if save_ok else "MISMATCH"))
	right.append("")
	right.append_array(_log)
	_right.text = "\n".join(right)


func _next_upgrade_text() -> String:
	var evolutions: Array = daemon.species_data().get("evolutions", [])
	if evolutions.is_empty():
		return "none"
	var evo: Dictionary = evolutions[0]
	var target_name: String = DataRegistry.get_species(evo["to"])["name"]
	match evo["trigger"]:
		"level":
			return "%s %d" % [target_name, int(evo["level"])]
		"item":
			return target_name + " (item)"
	return target_name + " (Sync)"


func _add_log(text: String) -> void:
	_log.append(text)
	while _log.size() > LOG_LINES:
		_log.remove_at(0)
	if _right != null:
		_refresh()


func _move_name(move_id: String) -> String:
	return DataRegistry.get_move(move_id).get("name", move_id)


func _make_label(pos: Vector2, size_px: Vector2) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = size_px
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_constant_override("line_spacing", 1)
	add_child(label)
	return label
