class_name GrowthRate
extends RefCounted
## The six EXP curves. exp_for_level() is the TOTAL exp a Daemon needs to be at that level.
## Level 1 is always 0. Integer math with floor division, Gen-3 style curves.

const MAX_LEVEL := 100
const RATES: PackedStringArray = ["fast", "medium_fast", "medium_slow", "slow", "erratic", "fluctuating"]


@warning_ignore("integer_division")
static func exp_for_level(rate: String, level: int) -> int:
	var n := clampi(level, 1, MAX_LEVEL)
	if n == 1:
		return 0
	var cube := n * n * n
	match rate:
		"fast":
			return 4 * cube / 5
		"medium_fast":
			return cube
		"medium_slow":
			return 6 * cube / 5 - 15 * n * n + 100 * n - 140
		"slow":
			return 5 * cube / 4
		"erratic":
			if n < 50:
				return cube * (100 - n) / 50
			if n < 68:
				return cube * (150 - n) / 100
			if n < 98:
				return cube * ((1911 - 10 * n) / 3) / 500
			return cube * (160 - n) / 100
		"fluctuating":
			if n < 15:
				return cube * ((n + 1) / 3 + 24) / 50
			if n < 36:
				return cube * (n + 14) / 50
			return cube * (n / 2 + 32) / 50
	push_error("GrowthRate: unknown rate '%s'" % rate)
	return cube


## Highest level whose total exp is <= total_exp.
static func level_for_exp(rate: String, total_exp: int) -> int:
	var level := 1
	while level < MAX_LEVEL and exp_for_level(rate, level + 1) <= total_exp:
		level += 1
	return level
