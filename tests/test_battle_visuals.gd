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
