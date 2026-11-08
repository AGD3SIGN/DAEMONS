class_name BattlePlayer
extends RefCounted
## Plays BattleEvents on the battle screen one at a time: text in the text box plus the matching
## animation (slide in, lunge, hit flash, bars draining, crash, Quarantine Key throw and shakes,
## EXP bar, level-up popup). The sim has already finished the whole turn, so everything shown
## (Uptime, level, EXP, status) comes from the events, not from the Daemons' final state.

var view: BattleScene
var state: BattleState
## Player Daemons that earned an upgrade this battle (upgrade_ready events), for after the battle.
var upgrades: Array[Dictionary] = []

var _active: Array[int] = [-1, -1]
var _species: Array[String] = ["", ""]
var _held: Array[bool] = [false, false]  # a pose is showing; the idle loop leaves it alone
var _breath := 0.0
var _breath_frame := 0
var _shown: Array[Dictionary] = [{}, {}]  # side -> {stack index -> {level, exp, status}}


func _init(p_view: BattleScene) -> void:
	view = p_view
	state = p_view.state
	for side in 2:
		for i in state.sides[side].stack.size():
			var d := state.sides[side].stack[i]
			_shown[side][i] = {"level": d.level, "exp": d.total_exp, "status": d.status}


func play(events: Array[Dictionary]) -> void:
	for e in events:
		await _play_event(e)


## Fraction of the way to the next level, based on what's been shown so far.
func exp_fraction(index: int) -> float:
	var info: Dictionary = _shown[BattleState.PLAYER][index]
	var level := int(info["level"])
	if level >= DaemonInstance.MAX_LEVEL:
		return 1.0
	var rate := state.sides[BattleState.PLAYER].stack[index].growth_rate()
	var low := GrowthRate.exp_for_level(rate, level)
	var high := GrowthRate.exp_for_level(rate, level + 1)
	return clampf(float(int(info["exp"]) - low) / maxf(1.0, high - low), 0.0, 1.0)


func _play_event(e: Dictionary) -> void:
	var text := BattleText.describe(e, state.is_wild, view.trainer_name)
	var side := int(e.get("side", 0))
	match e["type"]:
		"turn_start", "turn_end", "switch_needed":
			pass
		"switch_in":
			_active[side] = int(e["index"])
			var d := state.sides[side].stack[_active[side]]
			var info: Dictionary = _shown[side][_active[side]]
			_panel(side).show_daemon(d.display_name(), int(info["level"]), int(e["uptime"]), int(e["max_uptime"]),
				info["status"], exp_fraction(_active[side]) if side == BattleState.PLAYER else 0.0)
			_panel(side).visible = false
			_species[side] = d.species_id
			_sprite(side).texture = DaemonSprites.back(d.species_id) if side == BattleState.PLAYER else DaemonSprites.front(d.species_id)
			await _anim_enter(side)
			_rest(side)
			_panel(side).visible = true
			await _say(text)
		"switch_out":
			await _say(text, false)
			await _anim_exit(side)
			_panel(side).visible = false
		"move_used":
			await _say(text, false)
			var category := String(DataRegistry.get_move(String(e.get("move", ""))).get("category", "physical"))
			_hold_pose(side, "attack" if category == "physical" else "special")
			await _anim_lunge(side)
			await _play_move_fx(side, String(e.get("move", "")))
			_release_pose(side)
		"damage":
			_hold_pose(side, "hurt")
			_hit_flash(side)
			await _panel(side).animate_uptime(int(e["uptime"]), int(e["max_uptime"]))
			_release_pose(side)
			await _say(text)
		"status_damage":
			await _say(text, false)
			_hold_pose(side, "hurt")
			_hit_flash(side)
			await _panel(side).animate_uptime(int(e["uptime"]), int(e["max_uptime"]))
			_release_pose(side)
		"heal", "revived":
			if int(e.get("target_index", -1)) == _active[side]:
				await _panel(side).animate_uptime(int(e["uptime"]), int(e["max_uptime"]))
			await _say(text)
		"drain", "recoil":
			await _panel(side).animate_uptime(int(e["uptime"]), int(e["max_uptime"]))
			await _say(text)
		"status_applied":
			if e["status"] != "looping":
				_shown[side][_active[side]]["status"] = e["status"]
				_panel(side).set_status(e["status"])
				_rest(side)
			await _say(text)
		"status_cured":
			var index := int(e.get("target_index", _active[side]))
			_shown[side][index]["status"] = ""
			if index == _active[side]:
				_panel(side).set_status("")
				_rest(side)
			await _say(text)
		"stat_changed":
			await _anim_tint(side, int(e["delta"]) > 0)
			await _say(text)
		"fainted":
			_hold_pose(side, "faint")
			await _anim_faint(side)
			_held[side] = false
			_panel(side).visible = false
			await _say(text)
		"exp_gained":
			var index := int(e["index"])
			_shown[BattleState.PLAYER][index]["exp"] = int(_shown[BattleState.PLAYER][index]["exp"]) + int(e["amount"])
			await _say(text)
			if index == _active[BattleState.PLAYER]:
				await view.player_panel.animate_exp(exp_fraction(index))
		"level_up":
			await _play_level_up(e, text)
		"move_learn_pending":
			await _say(text)
			await view.prompt_move_replace(e)
		"item_used":
			await _say(text)
			if int(e["target_index"]) == -1:
				await _anim_throw_key()
		"capture_shake":
			await _anim_key_shake()
			await _say(text, false)
		"capture_failed":
			await _anim_break_free()
			await _say(text)
		"captured":
			await _anim_captured()
			await _say(text)
		"upgrade_ready":
			upgrades.append(e)
		_:
			await _say(text)


func _play_level_up(e: Dictionary, text: String) -> void:
	var index := int(e["index"])
	_shown[BattleState.PLAYER][index]["level"] = int(e["level"])
	var gains: Dictionary = e["stat_gains"]
	if index == _active[BattleState.PLAYER]:
		var panel := view.player_panel
		await panel.animate_exp(1.0)
		panel.set_level(int(e["level"]))
		panel.set_uptime(roundi(panel.shown_uptime) + int(gains["uptime"]), panel.max_uptime + int(gains["uptime"]))
		panel.exp_ratio = 0.0
		await panel.animate_exp(exp_fraction(index))
	await _say(text)
	var lines := PackedStringArray()
	for stat: String in DaemonInstance.STATS:
		lines.append("%-10s +%d" % [BattleText.STAT_NAMES.get(stat, "Uptime"), int(gains[stat])])
	view.stat_popup_label.text = "\n".join(lines)
	view.stat_popup.visible = true
	await view.text_box.wait_for_advance()
	view.stat_popup.visible = false


# --- move effects ----------------------------------------------------------------

## The move's own effect (data/moves.json "fx"), drawn from the user to the target.
func _play_move_fx(side: int, move_id: String) -> void:
	var move := DataRegistry.get_move(move_id)
	var steps: Array = move.get("fx", [])
	if steps.is_empty() or _ts() <= 0.0:
		await view.get_tree().create_timer(0.2 * _ts()).timeout
		return
	var type_data: Dictionary = DataRegistry.types.get(String(move.get("type", "")), {})
	var type_color := Color(String(type_data.get("color", "#ffffff")))
	view.fx.time_scale = _ts()
	var user := _sprite_center(side)
	var target := _sprite_center(BattleState.opponent(side))
	await view.fx.play(steps, user, target, type_color)


func _sprite_center(side: int) -> Vector2:
	var s := _sprite(side)
	return s.get_global_rect().get_center() - view.fx.get_global_rect().position


# --- poses (only for Daemons with a sprite sheet) -----------------------------

## Front pose names; the player's Daemon is seen from behind, so it uses the back version.
const BACK_POSES := {"idle": "back", "idle_b": "back_b", "attack": "back_attack", "special": "back_attack",
	"hurt": "back_hurt", "faint": "back_hurt"}
## Foe poses for lasting statuses.
const STATUS_POSES := {"standby": "asleep", "overheated": "overheated", "throttled": "throttled"}


## Shows a pose; returns false if this Daemon has no sheet (then the sprite is left alone).
func _set_pose(side: int, pose_name: String) -> bool:
	if _species[side].is_empty():
		return false
	if side == BattleState.PLAYER:
		pose_name = BACK_POSES.get(pose_name, "back")
	var tex := DaemonSprites.pose(_species[side], pose_name)
	if tex == null:
		return false
	_sprite(side).texture = tex
	return true


func _hold_pose(side: int, pose_name: String) -> void:
	_held[side] = _set_pose(side, pose_name)


func _release_pose(side: int) -> void:
	_held[side] = false
	_rest(side)


## The resting pose: idle, or a status pose (foe side only; the back view has none).
func _rest(side: int) -> void:
	if _held[side] or _active[side] < 0:
		return
	var status := String(_shown[side][_active[side]].get("status", ""))
	if side == BattleState.FOE and STATUS_POSES.has(status):
		_set_pose(side, STATUS_POSES[status])
	else:
		_set_pose(side, "idle_b" if _breath_frame == 1 else "idle")


## Two-frame breathing loop, called every frame by the battle scene.
func tick(delta: float) -> void:
	if _ts() <= 0.0:
		return
	_breath += delta / _ts()
	if _breath < 0.5:
		return
	_breath = 0.0
	_breath_frame = 1 - _breath_frame
	for side in 2:
		if _sprite(side).visible:
			_rest(side)


# --- helpers -----------------------------------------------------------------

func _say(text: String, wait: bool = true) -> void:
	await view.text_box.show_text(text, wait)


func _panel(side: int) -> BattleInfoPanel:
	return view.player_panel if side == BattleState.PLAYER else view.foe_panel


func _sprite(side: int) -> TextureRect:
	return view.player_sprite if side == BattleState.PLAYER else view.foe_sprite


## Animation speed: the battle's time_scale, or 0 (instant) when battle animations are off in Options.
func _ts() -> float:
	return view.time_scale if Settings.battle_animations else 0.0


func _tween() -> Tween:
	return view.create_tween()


# --- animations --------------------------------------------------------------

func _anim_enter(side: int) -> void:
	var s := _sprite(side)
	s.visible = true
	s.modulate = Color.WHITE
	s.scale = Vector2.ONE
	s.position = Vector2(-140.0 if side == BattleState.PLAYER else 140.0, 0)
	var t := _tween()
	t.tween_property(s, "position", Vector2.ZERO, 0.45 * _ts()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await t.finished


func _anim_exit(side: int) -> void:
	var s := _sprite(side)
	var t := _tween()
	t.tween_property(s, "position", Vector2(-140.0 if side == BattleState.PLAYER else 140.0, 0), 0.3 * _ts())
	await t.finished
	s.visible = false


func _anim_lunge(side: int) -> void:
	var s := _sprite(side)
	var toward := Vector2(10, -4) if side == BattleState.PLAYER else Vector2(-10, 4)
	var t := _tween()
	t.tween_property(s, "position", toward, 0.08 * _ts())
	t.tween_property(s, "position", Vector2.ZERO, 0.1 * _ts())
	await t.finished


## Blink + shake. Not awaited: runs while the bar drains. Tweens die with the node, so it's safe.
func _hit_flash(side: int) -> void:
	var s := _sprite(side)
	var blink := _tween()
	for i in 3:
		blink.tween_property(s, "modulate:a", 0.15, 0.05 * _ts())
		blink.tween_property(s, "modulate:a", 1.0, 0.05 * _ts())
	var shake := _tween()
	for x in [3.0, -3.0, 2.0, 0.0]:
		shake.tween_property(s, "position:x", x, 0.04 * _ts())


func _anim_faint(side: int) -> void:
	var s := _sprite(side)
	var t := _tween()
	t.tween_property(s, "position:y", 48.0, 0.4 * _ts())
	t.parallel().tween_property(s, "modulate:a", 0.0, 0.4 * _ts())
	await t.finished
	s.visible = false


func _anim_tint(side: int, up: bool) -> void:
	var s := _sprite(side)
	var tint := Color(0.6, 0.8, 1.5) if up else Color(1.5, 0.6, 0.6)
	var t := _tween()
	for i in 2:
		t.tween_property(s, "modulate", tint, 0.12 * _ts())
		t.tween_property(s, "modulate", Color.WHITE, 0.12 * _ts())
	await t.finished


func _anim_throw_key() -> void:
	var key := view.key_sprite
	key.visible = true
	key.rotation = 0.0
	key.modulate = Color.WHITE
	key.global_position = view.player_slot.global_position + Vector2(48, 0)
	var t := _tween()
	t.tween_property(key, "global_position", view.foe_slot.global_position + Vector2(26, 14), 0.4 * _ts()).set_trans(Tween.TRANS_SINE)
	await t.finished
	var foe := _sprite(BattleState.FOE)
	foe.pivot_offset = Vector2(32, 48)
	var absorb := _tween()
	absorb.tween_property(foe, "modulate", Color(3, 3, 3, 1), 0.1 * _ts())
	absorb.tween_property(foe, "scale", Vector2.ZERO, 0.2 * _ts())
	await absorb.finished
	foe.visible = false
	var drop := _tween()
	drop.tween_property(key, "global_position", view.foe_slot.global_position + Vector2(26, 44), 0.25 * _ts()) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await drop.finished


func _anim_key_shake() -> void:
	var key := view.key_sprite
	key.pivot_offset = Vector2(6, 18)
	var t := _tween()
	t.tween_property(key, "rotation", 0.35, 0.1 * _ts())
	t.tween_property(key, "rotation", -0.35, 0.15 * _ts())
	t.tween_property(key, "rotation", 0.0, 0.1 * _ts())
	t.tween_interval(0.25 * _ts())
	await t.finished


func _anim_break_free() -> void:
	var foe := _sprite(BattleState.FOE)
	view.key_sprite.visible = false
	foe.visible = true
	var t := _tween()
	t.tween_property(foe, "scale", Vector2.ONE, 0.2 * _ts())
	t.parallel().tween_property(foe, "modulate", Color.WHITE, 0.2 * _ts())
	await t.finished


func _anim_captured() -> void:
	var t := _tween()
	t.tween_property(view.key_sprite, "modulate", Color(0.55, 0.55, 0.65), 0.3 * _ts())
	await t.finished
