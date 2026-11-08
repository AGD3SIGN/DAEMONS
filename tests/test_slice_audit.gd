extends GutTest
## Phase 7: the scripted playtest. Fails if the slice has soft-locks, unreachable things,
## broken flags or unawarded certs. Writes the full report to docs/slice-audit.md.

func test_slice_has_no_problems() -> void:
	var audit := SliceAudit.run()
	var file := FileAccess.open("res://docs/slice-audit.md", FileAccess.WRITE)
	if file != null:
		file.store_string(audit.report() + "\n")
		file.close()
	assert_eq(audit.problems.size(), 0, "\n".join(audit.problems))


func test_audit_catches_a_soft_lock() -> void:
	# Prove the audit isn't a rubber stamp: replace the Department's exit mat with wall.
	var m := DataRegistry.get_map("department_1")
	var saved_rows: Array = m["rows"].duplicate()
	var rows: Array = m["rows"]
	rows[17] = "I".repeat(15)
	var audit := SliceAudit.run()
	m["rows"] = saved_rows
	assert_gt(audit.problems.size(), 0)
	assert_string_contains(" ".join(audit.problems), "department_1")
