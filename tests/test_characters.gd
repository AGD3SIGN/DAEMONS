extends GutTest
## Overworld character art: the importer, NPC sprite ids, standing on the tile, and draw order.

const ImportCharacter := preload("res://tools/art_import/import_character.gd")


func test_importer_finds_poses_off_an_even_grid() -> void:
	# 3x4 poses in a block that is centered with wide margins (like the ChatGPT sheets), so an even
	# 3-way split of the canvas would cut through them.
	var src := Image.create(1254, 1254, false, Image.FORMAT_RGBA8)
	src.fill(Color("ff00ff"))
	for i in 12:
		var x := 260 + (i % 3) * 300
		var y := 30 + (i / 3) * 310
		src.fill_rect(Rect2i(x, y, 150, 260), Color("282830"))                   # outline
		src.fill_rect(Rect2i(x + 13, y + 13, 124, 234), Color.from_hsv(i / 16.0, 0.7, 0.9))  # body
	var path := ProjectSettings.globalize_path("user://char_sheet.png")
	src.save_png(path)
	assert_eq(ImportCharacter.import_character(path, "zz_test"), "")
	var out := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/characters/zz_test.png"))
	assert_eq(out.get_size(), Vector2i(48, 96))
	for i in 12:
		var c := out.get_pixel((i % 3) * 16 + 8, (i / 3) * 24 + 14)
		var want := Color.from_hsv(i / 16.0, 0.7, 0.9)
		assert_almost_eq(Vector3(c.r, c.g, c.b), Vector3(want.r, want.g, want.b), Vector3.ONE * 0.02,
			"frame %d holds pose %d, whole" % [i, i])
		assert_gt(out.get_pixel((i % 3) * 16 + 8, (i / 3) * 24 + 23).a, 0.5, "frame %d: feet on the bottom row" % i)
	assert_eq(out.get_pixel(0, 0).a, 0.0, "background removed")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://assets/sprites/characters/zz_test.png"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://assets/sprites/characters/zz_test_battle.png"))
	DirAccess.remove_absolute(path)


func test_npcs_with_art_use_it_and_stand_on_their_tile() -> void:
	SceneRouter.params = {"map": "onboarding_town"}
	var world: Overworld = load(Overworld.SCENE).instantiate()
	world.allow_scene_change = false
	add_child_autofree(world)
	await wait_process_frames(2)
	var kevin: NpcEvent = world.find_npc("kevin")
	assert_eq(kevin.sprite_id, "kevin")
	var sprite: Sprite2D = kevin._sprite
	assert_eq(sprite.texture.get_size(), Vector2(48, 96), "Kevin's own art")
	assert_eq(sprite.offset, Vector2(0, -8), "24-tall frame lifted 8 px so the feet stay on the 16 px tile")
	assert_eq(world.player._sprite.offset, Vector2(0, -8), "the player too")
	SceneRouter.params = {}


func test_lower_characters_draw_in_front() -> void:
	assert_gt(CharacterSprites.depth(9), CharacterSprites.depth(8))
	SceneRouter.params = {"map": "onboarding_town"}
	var world: Overworld = load(Overworld.SCENE).instantiate()
	world.allow_scene_change = false
	add_child_autofree(world)
	await wait_process_frames(2)
	assert_eq(world.player.z_index, CharacterSprites.depth(world.player.cell.y))
	var kevin: NpcEvent = world.find_npc("kevin")
	assert_eq(kevin.z_index, CharacterSprites.depth(kevin.cell.y))
	SceneRouter.params = {}


func test_every_character_sheet_is_16x24_and_small_palette() -> void:
	var files := DirAccess.get_files_at("res://assets/sprites/characters/")
	var count := 0
	for f in files:
		if f.get_extension() != "png":
			continue
		var battle := f.ends_with("_battle.png")
		count += 0 if battle else 1
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/characters/" + f))
		assert_eq(img.get_size(), Vector2i(96, 72) if battle else Vector2i(48, 96), f)
		var colors := {}
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.5:
					colors[img.get_pixel(x, y).to_rgba32()] = true
		var limit := 16 if battle else 12
		assert_lte(colors.size(), limit, "%s uses %d colors; run the polish pass with --colors %d" % [f, colors.size(), limit])
	assert_eq(count, 18)


func test_every_character_has_battle_art_and_the_intro_uses_it() -> void:
	# The battle intro used the 16x24 walking frame scaled up 3x, which lost the faces.
	for file in DirAccess.get_files_at(CharacterSprites.ART_DIR):
		if not file.ends_with(".png") or file.ends_with("_battle.png"):
			continue
		var battle := CharacterSprites.ART_DIR + file.get_basename() + "_battle.png"
		assert_true(ResourceLoader.exists(battle), file + " has battle art (import_character.gd)")
	for from_behind in [false, true]:
		var frame: AtlasTexture = BattleScene.trainer_frame("kevin", from_behind)
		assert_string_ends_with(frame.atlas.resource_path, "kevin_battle.png")
		assert_eq(frame.region.size, BattleScene.TRAINER_SIZE, "drawn 1:1, no blocky scaling")
	assert_eq(BattleScene.trainer_frame("kevin", true).region.position.x, BattleScene.TRAINER_SIZE.x, "back is the second frame")
