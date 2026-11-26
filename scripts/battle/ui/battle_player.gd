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
var _corrupted: Array[bool] = [false, false]  # this side's active Forgeling is an ERR:: version (foe only)
var _held: Array[bool] = [false, false]  # a pose is showing; the idle loop leaves it alone
var _trainer_up: Array[bool] = [false, false]  # a trainer figure is on screen for that side
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
		"battle_start":
			await _anim_trainers_in()
			await _say(text)
		"switch_in":
			if _trainer_up[side]:
				await _anim_trainer_out(side)
			_active[side] = int(e["index"])
			var d := state.sides[side].stack[_active[side]]
			var info: Dictionary = _shown[side][_active[side]]
			_panel(side).show_daemon(d.display_name(), int(info["level"]), int(e["uptime"]), int(e["max_uptime"]),
				info["status"], exp_fraction(_active[side]) if side == BattleState.PLAYER else 0.0)
			_panel(side).visible = false
			_species[side] = d.species_id
			_corrupted[side] = d.is_corrupted or (side == BattleState.FOE and bool(view.config.get("teaser", false)))
			_sprite(side).texture = DaemonSprites.back(d.species_id) if side == BattleState.PLAYER else DaemonSprites.front(d.species_id)
			if _corrupted[side]:
				var err := DaemonSprites.corrupted_pose(d.species_id, "idle")
				if err != null:
					_sprite(side).texture = err
			_sprite(side).flip_h = side == BattleState.PLAYER and DaemonSprites.flip_back(d.species_id)
			await _anim_enter(side)
			_rest(side)
			if side == BattleState.FOE:
				await _anim_card_in()
			else:
				_panel(side).visible = true
			await _say(text)
		"switch_out":
			_aura(side).looping = false  # Looping ends when it leaves
			await _say(text, false)
			await _anim_exit(side)
			_panel(side).visible = false
		"move_missed":
			await _anim_dodge(BattleState.opponent(side))
			await _say(text)
		"move_used":
			_last_move[side] = String(e.get("move", ""))
			await _say(text, false)
			var category := String(DataRegistry.get_move(String(e.get("move", ""))).get("category", "physical"))
			_hold_pose(side, "attack" if category == "physical" else "special")
			await _anim_lunge(side)
			await _play_move_fx(side, String(e.get("move", "")))
			_release_pose(side)
		"damage":
			# Multi-hit moves: the attacker lunges and plays the move's effect again for every hit after
			# the first, so Double Click visibly clicks twice (2026-11-19, Brandon).
			if int(e.get("hit", 1)) > 1 and String(e.get("source", "")) == "move":
				await _replay_attack(BattleState.opponent(side))
			_hold_pose(side, "hurt")
			_hit_flash(side, hit_strength(e))
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
			if e["status"] == "looping":
				_aura(side).looping = true
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
			_aura(side).status = ""
			_aura(side).looping = false
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
			await _anim_stage_passed(int(e["n"]) - 1)
			await _say(text, false)
		"capture_failed":
			await _anim_stage_failed(int(e["shakes"]))
			await _anim_break_free()
			await _say(text)
			view.capture_meter.visible = false
		"captured":
			await _anim_captured()
			await _say(text)
			view.capture_meter.visible = false
		"foe_fled":
			# The demo teaser's glitched Forgeling leaves on its own (2026-11-19 audit: it used to stay on screen).
			_aura(BattleState.FOE).status = ""
			await _anim_glitch_out(BattleState.FOE)
			view.foe_panel.visible = false
			await _say(text)
		"upgrade_ready":
			upgrades.append(e)
		"looping_ended":
			_aura(side).looping = false
			await _say(text)
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

## The move each side used last (for replaying a multi-hit move's attack on every hit).
var _last_move := {}
## How many attack animations have played (counted for the multi-hit tests).
var attacks_played := 0


## One more swing of the side's last move: attack pose, lunge and the move's effect.
func _replay_attack(attacker: int) -> void:
	var move_id := String(_last_move.get(attacker, ""))
	var category := String(DataRegistry.get_move(move_id).get("category", "physical"))
	_hold_pose(attacker, "attack" if category == "physical" else "special")
	await _anim_lunge(attacker)
	await _play_move_fx(attacker, move_id)
	_release_pose(attacker)

## The move's own effect (data/moves.json "fx"), drawn from the user to the target.
func _play_move_fx(side: int, move_id: String) -> void:
	attacks_played += 1
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
	return view.fx.get_global_transform().affine_inverse() * s.get_global_rect().get_center()


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
	if _corrupted[side]:  # corrupted art has front frames only; other poses keep its idle
		var err_pose := pose_name if DaemonSprites.CORRUPTED_FRAMES.has(pose_name) else "idle"
		tex = DaemonSprites.corrupted_pose(_species[side], err_pose)
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
	_update_aura(side)
	if _held[side] or _active[side] < 0:
		return
	var status := String(_shown[side][_active[side]].get("status", ""))
	if side == BattleState.FOE and STATUS_POSES.has(status):
		_set_pose(side, STATUS_POSES[status])
	else:
		_set_pose(side, "idle_b" if _breath_frame == 1 else "idle")


## The looping status effect over a Daemon (embers for Overheated, etc.), on both sides.
func _aura(side: int) -> StatusAura:
	var sprite := _sprite(side)
	if not sprite.has_meta("aura"):
		var aura := StatusAura.new()
		sprite.add_child(aura)
		sprite.set_meta("aura", aura)
	return sprite.get_meta("aura")


func _update_aura(side: int) -> void:
	var aura := _aura(side)
	aura.speed = 1.0 if _ts() > 0.0 else 0.0
	var status := ""
	if _active[side] >= 0 and not _shown[side][_active[side]].get("fainted", false):
		status = String(_shown[side][_active[side]].get("status", ""))
	aura.status = status


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

func _trainer(side: int) -> TextureRect:
	return view.player_trainer if side == BattleState.PLAYER else view.foe_trainer


## Battle start: you (from behind) and, in trainer battles, the opponent slide onto their platforms.
func _anim_trainers_in() -> void:
	if _ts() <= 0.0 or view.player_trainer == null:
		return
	var frames := [BattleScene.trainer_frame(String(view.config.get("player_sprite", "player")), true),
		null if state.is_wild else _foe_figure("challenge")]
	var t := _tween().set_parallel(true)
	for side in 2:
		if frames[side] == null:
			continue
		var fig := _trainer(side)
		var rest := _show_figure(fig, frames[side])
		fig.position = rest + Vector2(-160.0 if side == BattleState.PLAYER else 160.0, 0)
		fig.visible = true
		t.tween_property(fig, "position", rest, 0.45 * _ts()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_trainer_up[side] = true
	if _trainer_up.has(true):
		await t.finished
	else:
		t.kill()


## The foe trainer's figure for a moment of the battle: their pose if they have pose art, otherwise the
## standing figure.
func _foe_figure(pose: String) -> Texture2D:
	var sprite_id := String(view.config.get("trainer_sprite", ""))
	var posed := BattleScene.trainer_pose(sprite_id, pose)
	return posed if posed != null else BattleScene.trainer_frame(sprite_id, false)


## Puts a texture on a trainer figure at its own size, feet still centered on the same spot of the platform
## (whole pixels: frame sizes are even); returns the figure's resting position.
func _show_figure(fig: TextureRect, tex: Texture2D) -> Vector2:
	var base: Vector2 = fig.get_meta("rest")
	fig.texture = tex
	fig.size = tex.get_size()
	return base - Vector2((fig.size.x - BattleScene.TRAINER_SIZE.x) / 2.0, fig.size.y - BattleScene.TRAINER_SIZE.y)


## After the last Forgeling falls (2026-11-19): the foe trainer slides back in, "defeated" when you win or
## "confident" when you lose, for their closing line. Their Forgeling and card step aside first.
func foe_trainer_returns(pose: String) -> void:
	var fig := view.foe_trainer
	if fig == null or state.is_wild:
		return
	var tex := _foe_figure(pose)
	if tex == null:
		return
	view.foe_panel.visible = false
	if _sprite(BattleState.FOE).visible and _ts() > 0.0:
		await _anim_exit(BattleState.FOE)
	_sprite(BattleState.FOE).visible = false
	var rest := _show_figure(fig, tex)
	fig.visible = true
	_trainer_up[BattleState.FOE] = true
	if _ts() <= 0.0:
		fig.position = rest
		return
	fig.position = rest + Vector2(160.0, 0)
	var t := _tween()
	t.tween_property(fig, "position", rest, 0.4 * _ts()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await t.finished


## Just before a side's first Daemon comes out, its trainer steps off screen.
func _anim_trainer_out(side: int) -> void:
	var fig := _trainer(side)
	_trainer_up[side] = false
	var t := _tween()
	t.tween_property(fig, "position:x", fig.position.x + (-160.0 if side == BattleState.PLAYER else 160.0), 0.3 * _ts())
	await t.finished
	fig.visible = false

func _anim_enter(side: int) -> void:
	var s := _sprite(side)
	var base_scale := s.scale if s.scale != Vector2.ZERO else Vector2.ONE
	if side == BattleState.FOE and state.is_wild:
		await _anim_materialize(s)
		return
	s.visible = true
	s.modulate = Color.WHITE
	s.scale = base_scale
	s.position = Vector2(-140.0 if side == BattleState.PLAYER else 140.0, 0)
	var t := _tween()
	t.tween_property(s, "position", Vector2.ZERO, 0.45 * _ts()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await t.finished


## A wild Daemon materializes on its pad: a few hard flickers of a white silhouette, then the real colors.
func _anim_materialize(s: TextureRect) -> void:
	s.position = Vector2.ZERO
	s.visible = true
	var t := _tween()
	s.modulate = Color(4, 4, 4, 0.0)
	for i in 3:
		t.tween_property(s, "modulate", Color(4, 4, 4, 1.0), 0.06 * _ts())
		t.tween_property(s, "modulate", Color(4, 4, 4, 0.2), 0.06 * _ts())
	t.tween_property(s, "modulate", Color.WHITE, 0.2 * _ts())
	await t.finished


## The wild card slides in from the left after the Daemon appears.
func _anim_card_in() -> void:
	var card := view.foe_panel
	var rest := view.layout.foe_card_at
	card.position = rest - Vector2(card.size.x + 60, 0)
	card.visible = true
	var t := _tween()
	t.tween_property(card, "position", rest, 0.3 * _ts()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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


## How hard a hit lands, for the blink and shake (2026-11-19 audit: crits and super-effective hits looked like any
## other hit). "crit" beats "super"; "weak" is a resisted hit; status damage and the like are "normal".
static func hit_strength(e: Dictionary) -> String:
	if e.get("critical", false):
		return "crit"
	var eff := float(e.get("effectiveness", 1.0))
	if eff > 1.0:
		return "super"
	if eff > 0.0 and eff < 1.0:
		return "weak"
	return "normal"


## Blink + shake, scaled to the hit. Not awaited: runs while the bar drains. Tweens die with the node, so it's safe.
##   weak: two soft blinks, a 1px nudge      normal: three blinks, a 3px shake
##   super: hard shake, a quick white flash  crit: bigger shake with a jolt, a stronger flash and a burst of sparks
func _hit_flash(side: int, strength: String = "normal") -> void:
	var s := _sprite(side)
	if Settings.calm_effects():  # SHAKE & FLASH off: one soft dip, no shake, no white flash
		var dip := _tween()
		dip.tween_property(s, "modulate:a", 0.6, 0.1 * _ts())
		dip.tween_property(s, "modulate:a", 1.0, 0.2 * _ts())
		return
	var blinks := {"weak": 2, "normal": 3, "super": 4, "crit": 5}[strength] as int
	var shake_x: Array = {"weak": [1.0, -1.0, 0.0], "normal": [3.0, -3.0, 2.0, 0.0],
		"super": [6.0, -6.0, 4.0, -3.0, 0.0], "crit": [8.0, -8.0, 6.0, -5.0, 3.0, 0.0]}[strength]
	var blink := _tween()
	for i in blinks:
		blink.tween_property(s, "modulate:a", 0.4 if strength == "weak" else 0.15, 0.05 * _ts())
		blink.tween_property(s, "modulate:a", 1.0, 0.05 * _ts())
	var shake := _tween()
	for x: float in shake_x:
		shake.tween_property(s, "position:x", x, 0.04 * _ts())
	if strength == "crit":
		var jolt := _tween()
		jolt.tween_property(s, "position:y", -6.0, 0.05 * _ts())
		jolt.tween_property(s, "position:y", 0.0, 0.12 * _ts()).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	if (strength == "super" or strength == "crit") and _ts() > 0.0:
		view.fx.time_scale = _ts()
		var at := _sprite_center(side)
		var steps: Array = [{"kind": "flash", "color": "#ffffff", "alpha": 0.45 if strength == "crit" else 0.25, "parallel": true}]
		if strength == "crit":
			steps.append({"kind": "burst", "color": "#ffd84a", "count": 14, "radius": 26, "size": 3})
		view.fx.play(steps, at, at, Color.WHITE)


## A miss: the target hops aside and back, leaving a faint afterimage.
func _anim_dodge(side: int) -> void:
	if _ts() <= 0.0:
		return
	var s := _sprite(side)
	var away := -14.0 if side == BattleState.PLAYER else 14.0
	var t := _tween()
	t.tween_property(s, "position:x", away, 0.08 * _ts()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(s, "modulate:a", 0.45, 0.08 * _ts())
	t.tween_interval(0.08 * _ts())
	t.tween_property(s, "position:x", 0.0, 0.14 * _ts()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(s, "modulate:a", 1.0, 0.14 * _ts())
	await t.finished


func _anim_faint(side: int) -> void:
	var s := _sprite(side)
	var t := _tween()
	t.tween_property(s, "position:y", 48.0, 0.4 * _ts())
	t.parallel().tween_property(s, "modulate:a", 0.0, 0.4 * _ts())
	await t.finished
	s.visible = false


## A foe whose signal drops: color-split flicker and jitter, then it collapses to a bright line like a CRT
## switching off, and is gone.
func _anim_glitch_out(side: int) -> void:
	var s := _sprite(side)
	if _ts() <= 0.0:
		s.visible = false
		if side == BattleState.FOE:
			view.foe_panel.visible = false
		return
	var base_scale := s.scale
	var base_pivot := s.pivot_offset
	s.pivot_offset = s.size / 2.0
	var t := _tween()
	for i in 4:
		var tint := Color(0.4, 1.6, 1.8) if i % 2 == 0 else Color(1.8, 0.4, 1.4)
		t.tween_property(s, "modulate", tint, 0.04 * _ts())
		t.parallel().tween_property(s, "position:x", 6.0 if i % 2 == 0 else -6.0, 0.04 * _ts())
		t.tween_property(s, "modulate", Color(1, 1, 1, 0.3), 0.05 * _ts())
	t.tween_property(s, "position:x", 0.0, 0.03 * _ts())
	t.tween_property(s, "modulate", Color(3, 3, 3, 1), 0.06 * _ts())
	t.tween_property(s, "scale", Vector2(base_scale.x * 1.25, base_scale.y * 0.06), 0.12 * _ts()).set_trans(Tween.TRANS_QUAD)
	t.tween_property(s, "scale", Vector2(0.0, base_scale.y * 0.06), 0.1 * _ts())
	if view.foe_panel.visible and side == BattleState.FOE:
		t.parallel().tween_property(view.foe_panel, "modulate:a", 0.0, 0.1 * _ts())
	await t.finished
	s.visible = false
	if side == BattleState.FOE:
		view.foe_panel.visible = false
	s.scale = base_scale
	s.pivot_offset = base_pivot
	s.modulate = Color.WHITE
	view.foe_panel.modulate.a = 1.0


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
	key.position = view.player_slot.position + Vector2(48, 0)  # the key shares the field layer with the slots
	var t := _tween()
	t.tween_property(key, "position", view.foe_slot.position + Vector2(26, 14), 0.4 * _ts()).set_trans(Tween.TRANS_SINE)
	await t.finished
	var foe := _sprite(BattleState.FOE)
	foe.pivot_offset = Vector2(32, 48)
	var absorb := _tween()
	absorb.tween_property(foe, "modulate", Color(3, 3, 3, 1), 0.1 * _ts())
	absorb.tween_property(foe, "scale", Vector2.ZERO, 0.2 * _ts())
	await absorb.finished
	foe.visible = false
	var drop := _tween()
	drop.tween_property(key, "position", view.foe_slot.position + Vector2(26, 44), 0.25 * _ts()) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await drop.finished
	view.capture_meter.reset()
	view.capture_meter.visible = true


## One Quarantine stage (SCAN, ISOLATE, ENCRYPT) fills and turns green; the key's light blinks.
func _anim_stage_passed(stage: int) -> void:
	var meter := view.capture_meter
	var t := _tween()
	t.tween_method(func(v: float) -> void: meter.set_progress(stage, v), 0.0, 1.0, 0.45 * _ts())
	t.parallel().tween_property(view.key_sprite, "modulate", Color(1.6, 1.6, 1.6), 0.2 * _ts())
	t.tween_property(view.key_sprite, "modulate", Color.WHITE, 0.15 * _ts())
	await t.finished
	meter.set_state(stage, "ok")
	var hold := _tween()
	hold.tween_interval(0.15 * _ts())
	await hold.finished


## The stage it breaks free in fills part way, then turns red.
func _anim_stage_failed(stage: int) -> void:
	var meter := view.capture_meter
	stage = clampi(stage, 0, CaptureMeter.STAGES.size() - 1)
	var t := _tween()
	t.tween_method(func(v: float) -> void: meter.set_progress(stage, v), 0.0, 0.55, 0.3 * _ts())
	await t.finished
	meter.set_state(stage, "fail")
	var hold := _tween()
	hold.tween_interval(0.25 * _ts())
	await hold.finished


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
