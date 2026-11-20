extends GutTest
## Battle visual gaps found in the 2026-11-19 audit.


func test_every_lasting_status_has_an_animation_and_looping_stacks() -> void:
	for status: String in BattleInfoPanel.STATUS_TAGS:
		assert_true(StatusAura.COLORS.has(status), "%s has an animation over the Forgeling" % status)
	var aura := StatusAura.new()
	add_child_autofree(aura)
	assert_false(aura.visible)
	aura.looping = true
	assert_true(aura.visible, "Looping shows on its own")
	aura.status = "hung"
	aura.looping = false
	assert_true(aura.visible, "Hung shows")
	aura.status = ""
	assert_false(aura.visible)


func test_looping_shows_while_it_lasts() -> void:
	var config := {"foe": [["dustbunny", 5]], "player_stack": [DaemonInstance.create("pingo", 5, RandomNumberGenerator.new())],
		"items": {}, "auto": true, "time_scale": 0.0, "seed": 1}
	var scene: BattleScene = load(BattleScene.SCENE).instantiate()
	scene.setup(config)
	add_child_autofree(scene)
	await wait_process_frames(3)
	var player: BattlePlayer = scene._player
	var aura := player._aura(BattleState.FOE)
	player._active[BattleState.FOE] = 0
	await player._play_event({"type": "status_applied", "side": BattleState.FOE, "daemon": "Dustbunny", "status": "looping"})
	assert_true(aura.looping, "on when it starts looping")
	await player._play_event({"type": "looping_ended", "side": BattleState.FOE, "daemon": "Dustbunny"})
	assert_false(aura.looping, "off when it snaps out of it")
	await wait_for_signal(scene.finished, 30.0)


func test_hits_are_scaled_by_how_hard_they_land() -> void:
	assert_eq(BattlePlayer.hit_strength({"critical": true, "effectiveness": 0.5}), "crit", "a crit beats a resist")
	assert_eq(BattlePlayer.hit_strength({"critical": false, "effectiveness": 2.0}), "super")
	assert_eq(BattlePlayer.hit_strength({"effectiveness": 0.5}), "weak")
	assert_eq(BattlePlayer.hit_strength({"effectiveness": 1.0}), "normal")
	assert_eq(BattlePlayer.hit_strength({"source": "looping"}), "normal")


func test_a_miss_dodges_and_comes_back_and_hits_settle() -> void:
	var config := {"foe": [["dustbunny", 5]], "player_stack": [DaemonInstance.create("pingo", 5, RandomNumberGenerator.new())],
		"items": {}, "auto": true, "time_scale": 0.0, "seed": 1}
	var scene: BattleScene = load(BattleScene.SCENE).instantiate()
	scene.setup(config)
	add_child_autofree(scene)
	await wait_for_signal(scene.finished, 30.0)  # let the auto battle finish so nothing else moves the sprite
	scene.time_scale = 0.05
	var player: BattlePlayer = scene._player
	var foe := scene.foe_sprite
	foe.visible = true
	foe.position = Vector2.ZERO
	foe.modulate = Color.WHITE
	await player._anim_dodge(BattleState.FOE)
	assert_eq(foe.position.x, 0.0, "back on its pad")
	assert_almost_eq(foe.modulate.a, 1.0, 0.01)
	for strength in ["weak", "normal", "super", "crit"]:
		player._hit_flash(BattleState.FOE, strength)
		await wait_seconds(0.4)
		assert_eq(foe.position, Vector2.ZERO, "%s hit settles back in place" % strength)


## Audit 2026-11-19: ten pairs of moves played the same animation, only recolored. Each move's sequence of effect
## kinds (with glyph and where it plays) is now its own.
func test_no_two_moves_share_an_animation() -> void:
	var seen := {}
	for move_id: String in DataRegistry.moves:
		var shape := []
		for step: Dictionary in DataRegistry.moves[move_id].get("fx", []):
			shape.append([step["kind"], step.get("glyph", ""), step.get("on", "target")])
		var key := str(shape)
		assert_false(seen.has(key), "%s plays the same animation as %s" % [move_id, seen.get(key, "")])
		seen[key] = move_id


## 2026-11-19 (Brandon): multi-hit moves swing and land once per hit, not one swing then a row of flashes.
func test_multi_hit_moves_swing_once_per_hit() -> void:
	var config := {"foe": [["dustbunny", 5]], "player_stack": [DaemonInstance.create("pingo", 5, RandomNumberGenerator.new())],
		"items": {}, "auto": true, "time_scale": 0.0, "seed": 1}
	var scene: BattleScene = load(BattleScene.SCENE).instantiate()
	scene.setup(config)
	add_child_autofree(scene)
	await wait_for_signal(scene.finished, 30.0)
	var player: BattlePlayer = scene._player
	player._active[BattleState.FOE] = 0
	var before := player.attacks_played
	await player._play_event({"type": "move_used", "side": BattleState.PLAYER, "user": "Pingo", "move": "double_click",
		"move_name": "Double Click"})
	for hit in [1, 2]:
		await player._play_event({"type": "damage", "side": BattleState.FOE, "daemon": "Dustbunny", "amount": 1,
			"uptime": 10 - hit, "max_uptime": 20, "critical": false, "effectiveness": 1.0, "source": "move", "hit": hit})
	assert_eq(player.attacks_played - before, 2, "Double Click's attack plays for both hits")
	await player._play_event({"type": "damage", "side": BattleState.FOE, "daemon": "Dustbunny", "amount": 1,
		"uptime": 5, "max_uptime": 20, "critical": false, "effectiveness": 1.0, "source": "status"})
	assert_eq(player.attacks_played - before, 2, "damage that isn't a move hit doesn't replay an attack")
