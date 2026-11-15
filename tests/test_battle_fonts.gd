extends GutTest
## Battle text readability (2026-11-15): names, levels, numbers and buttons use Press Start 2P, and every label
## fits its button at one shared size per panel.


func _buttons(labels: Array, width: float, height: float) -> Array[TermButton]:
	var out: Array[TermButton] = []
	for i in labels.size():
		var b := TermButton.new(labels[i], "[%d]" % (i + 1))
		b.font_size = 16
		b.size = Vector2(width, height)
		add_child_autofree(b)
		out.append(b)
	return out


func test_panel_shares_one_size_and_every_label_fits() -> void:
	var f := BattleStyle.press_start()
	# Desktop move cell (about 194x56) with the longest move name in the game.
	var buttons := _buttons(["Special Delivery", "Thermal Runaway", "Infinite Loop", "Data Dump"], 194, 56)
	TermButton.share_size(buttons)
	var shared := buttons[0].size_cap
	assert_gte(shared, 12, "move names stay at a readable size")
	for b in buttons:
		assert_eq(b.size_cap, shared)
		var lines := b.fit_lines(f, b.label_text, b.text_room(), shared)
		for i in range(1, lines.size()):
			assert_lte(f.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, lines[0]).x, b.text_room(), lines[i])


func test_commands_keep_full_size_on_phones() -> void:
	var buttons := _buttons(["EXECUTE", "STACK", "INVENTORY", "DISCONNECT"], 296, 64)
	for b in buttons:
		b.font_size = 18
	TermButton.share_size(buttons)
	assert_eq(buttons[0].size_cap, 18)


func test_fit_size_shrinks_only_when_needed() -> void:
	var f := BattleStyle.press_start()
	assert_eq(BattleStyle.fit_size(f, "Chipmunk", 400, 26, 16), 26)
	var s := BattleStyle.fit_size(f, "Coolapotamus", 250, 26, 12)
	assert_lt(s, 26)
	assert_lte(f.get_string_size("Coolapotamus", HORIZONTAL_ALIGNMENT_LEFT, -1, s).x, 250.0)
