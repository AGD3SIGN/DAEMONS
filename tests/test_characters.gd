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
	assert_eq(out.get_size(), Vector2i(72, 112))
	for i in 12:
		var c := out.get_pixel((i % 3) * 24 + 12, (i / 3) * 28 + 16)
		var want := Color.from_hsv(i / 16.0, 0.7, 0.9)
		assert_almost_eq(Vector3(c.r, c.g, c.b), Vector3(want.r, want.g, want.b), Vector3.ONE * 0.02,
			"frame %d holds pose %d, whole" % [i, i])
		assert_gt(out.get_pixel((i % 3) * 24 + 12, (i / 3) * 28 + 27).a, 0.5, "frame %d: feet on the bottom row" % i)
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
	assert_eq(sprite.texture.get_size(), Vector2(72, 112), "Kevin's own art")
	assert_eq(sprite.offset, Vector2(-4, -12), "24x28 frame centered on the 16 px tile, feet on it")
	assert_eq(world.player._sprite.offset, Vector2(-4, -12), "the player too")
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


func test_every_character_sheet_is_24x28_and_small_palette() -> void:
	var files := DirAccess.get_files_at("res://assets/sprites/characters/")
	var count := 0
	for f in files:
		if f.get_extension() != "png":
			continue
		var battle := f.ends_with("_battle.png") or f.ends_with("_poses.png")
		count += 0 if battle else 1
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/characters/" + f))
		var want := Vector2i(192, 72) if f.ends_with("_poses.png") else (Vector2i(96, 72) if battle else Vector2i(72, 112))
		assert_eq(img.get_size(), want, f)
		var colors := {}
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.5:
					colors[img.get_pixel(x, y).to_rgba32()] = true
		var limit := 16 if battle else 12
		assert_lte(colors.size(), limit, "%s uses %d colors; run the polish pass with --colors %d" % [f, colors.size(), limit])
	assert_eq(count, 33, "18 + 15 imported 2026-11-19 (Ping, the Brute, Route 2 / Port City / Dept 2 / Basement trainers, townsfolk)")


## Every sprite a map NPC or a trainer names has art, so nobody falls back to a placeholder by typo.
func test_every_named_character_sprite_exists() -> void:
	var names := {}
	for t: Dictionary in DataRegistry.trainers.values():
		if not String(t.get("sprite", "")).is_empty():
			names[t["sprite"]] = "trainer"
	for file in DirAccess.get_files_at("res://data/maps/"):
		if file.ends_with(".json"):
			var text := FileAccess.get_file_as_string("res://data/maps/" + file)
			var re := RegEx.create_from_string("\"sprite\": \"([a-z0-9_]+)\"")
			for m in re.search_all(text):
				names[m.get_string(1)] = file
	assert_gt(names.size(), 20)
	for id: String in names:
		assert_true(ResourceLoader.exists(CharacterSprites.ART_DIR + id + ".png"), "%s (used in %s) has art" % [id, names[id]])


func test_every_character_has_battle_art_and_the_intro_uses_it() -> void:
	# The battle intro used the small walking frame scaled up 3x, which lost the faces.
	for file in DirAccess.get_files_at(CharacterSprites.ART_DIR):
		if not file.ends_with(".png") or file.ends_with("_battle.png") or file.ends_with("_poses.png"):
			continue
		var battle := CharacterSprites.ART_DIR + file.get_basename() + "_battle.png"
		assert_true(ResourceLoader.exists(battle), file + " has battle art (import_character.gd)")
	for from_behind in [false, true]:
		var frame: AtlasTexture = BattleScene.trainer_frame("kevin", from_behind)
		assert_string_ends_with(frame.atlas.resource_path, "kevin_battle.png")
		assert_eq(frame.region.size, BattleScene.TRAINER_SIZE, "drawn 1:1, no blocky scaling")
	assert_eq(BattleScene.trainer_frame("kevin", true).region.position.x, BattleScene.TRAINER_SIZE.x, "back is the second frame")


## 2026-11-19 (Brandon: "keep pixel perfect alignment, sometimes the characters look slightly off"): frames
## were centered on the whole drawing, so a fishing rod or antenna pushed the body sideways and a character
## jumped up to 5 px when it turned. Frames are centered on the body now: it stays within 1 px.
func test_characters_stay_put_when_they_turn_and_step() -> void:
	for f in DirAccess.get_files_at(CharacterSprites.ART_DIR):
		if not f.ends_with(".png") or f.ends_with("_battle.png") or f.ends_with("_poses.png") or f.begins_with("zz_"):
			continue
		var img := Image.load_from_file(ProjectSettings.globalize_path(CharacterSprites.ART_DIR + f))
		var fw := img.get_width() / 3
		var stands := []
		for r in 4:
			var xs := []
			for c in 3:
				xs.append(_torso_x(img, c * fw, r * 28, fw))
			assert_lte(xs.max() - xs.min(), 1.0, "%s doesn't slide while stepping (row %d)" % [f, r])
			stands.append(xs[0])
		assert_lte(stands.max() - stands.min(), 1.0, "%s stays on its tile when it turns: %s" % [f, stands])


## Middle opaque column of the torso rows (9-19) of one frame.
func _torso_x(img: Image, x0: int, y0: int, w: int) -> float:
	var xs := []
	for y in range(9, 20):
		for x in w:
			if img.get_pixel(x0 + x, y0 + y).a > 0.5:
				xs.append(x)
	xs.sort()
	return xs[xs.size() / 2] if not xs.is_empty() else 0.0
