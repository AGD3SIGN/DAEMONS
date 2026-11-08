extends GutTest
## Sprite sheets: the importer, pose lookup, and battles playing the poses.

const ImportSheet := preload("res://tools/art_import/import_sheet.gd")


func test_sheet_poses_come_from_the_right_cells() -> void:
	assert_true(DaemonSprites.has_sheet("pengwan"))
	var hurt := DaemonSprites.pose("pengwan", "hurt") as AtlasTexture
	assert_eq(hurt.region, Rect2(0, 64, 64, 64), "hurt = row 2, column 1")
	assert_eq((DaemonSprites.pose("emperoute", "back") as AtlasTexture).region, Rect2(0, 128, 64, 64))
	assert_eq((DaemonSprites.front("pengwan") as AtlasTexture).region, Rect2(0, 0, 64, 64), "front = idle")
	assert_eq((DaemonSprites.back("pengwan") as AtlasTexture).region, Rect2(0, 128, 64, 64), "back = back idle")
	assert_null(DaemonSprites.pose("chipmunk", "idle"), "no sheet yet")
	assert_false(DaemonSprites.front("chipmunk") is AtlasTexture, "placeholder still works")


func test_importer_keys_out_magenta_and_keeps_a_white_belly() -> void:
	# A fake 4x4 sheet on magenta: dark-outlined blue body with a white belly in every cell.
	var src := Image.create(400, 400, false, Image.FORMAT_RGBA8)
	src.fill(Color("ff00ff"))
	for cell in 16:
		var o := Vector2i((cell % 4) * 100, (cell / 4) * 100)
		src.fill_rect(Rect2i(o + Vector2i(20, 20), Vector2i(60, 70)), Color("1b2a44"))
		src.fill_rect(Rect2i(o + Vector2i(25, 25), Vector2i(50, 60)), Color("3c8ee0"))
		src.fill_rect(Rect2i(o + Vector2i(38, 50), Vector2i(24, 30)), Color.WHITE)
	var path := ProjectSettings.globalize_path("user://fake_sheet.png")
	src.save_png(path)
	assert_eq(ImportSheet.import_sheet(path, "zz_test"), "")
	var out := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/daemons/zz_test_sheet.png"))
	assert_eq(out.get_size(), Vector2i(256, 256))
	assert_eq(out.get_pixel(2, 2).a, 0.0, "background is transparent")
	assert_eq(out.get_pixel(32, 40), Color.WHITE, "belly kept")
	assert_eq(out.get_pixel(64 + 32, 64 + 40), Color.WHITE, "same in another cell")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://assets/sprites/daemons/zz_test_sheet.png"))
	DirAccess.remove_absolute(path)


func test_battle_with_sheet_art_plays_poses() -> void:
	var scene: BattleScene = load(BattleScene.SCENE).instantiate()
	var team: Array[DaemonInstance] = [DaemonInstance.create("pengwan", 30, RandomNumberGenerator.new(), 1)]
	scene.setup({"foe": [["emperoute", 30]], "player_stack": team, "items": {}, "auto": true, "time_scale": 0.0})
	add_child(scene)
	var seen := {}
	var watch := func() -> void:
		for s: TextureRect in [scene.foe_sprite, scene.player_sprite]:
			if s.texture is AtlasTexture:
				seen[(s.texture as AtlasTexture).region.position] = true
	var timer := Timer.new()
	timer.wait_time = 0.001
	timer.timeout.connect(watch)
	add_child_autofree(timer)
	timer.start()
	await wait_for_signal(scene.finished, 60.0)
	scene.free()
	assert_true(seen.has(Vector2(0, 0)), "foe idle shown")
	assert_true(seen.has(Vector2(0, 128)), "player back shown")
	assert_gt(seen.size(), 2, "more poses than just the two idles: %s" % [seen.keys()])
