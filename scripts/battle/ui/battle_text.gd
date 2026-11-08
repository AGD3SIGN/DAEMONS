class_name BattleText
extends RefCounted
## Turns a BattleEvent into the line shown in the battle text box ("" = no text for it).
## Used by the console battle now and by the battle screen in Phase 3. All wording is original.

const STAT_NAMES := {
	"throughput": "Throughput", "hardening": "Hardening", "compute": "Compute",
	"encryption": "Encryption", "bandwidth": "Bandwidth", "accuracy": "accuracy", "evasion": "evasion",
}


static func describe(e: Dictionary, is_wild: bool, foe_trainer: String = "") -> String:
	match e["type"]:
		"battle_start":
			return "" if is_wild else "%s opened a ticket against you!" % e["foe"]
		"switch_in":
			if e["side"] == BattleState.PLAYER:
				return "Deploying %s!" % e["daemon"]
			return ("A wild %s spawned!" % e["daemon"]) if is_wild else ("%s deployed %s!" % [foe_trainer if foe_trainer else "The foe", e["daemon"]])
		"switch_out":
			if e["side"] == BattleState.PLAYER:
				return "%s, log off!" % e["daemon"]
			return "%s pulled %s offline." % [foe_trainer if foe_trainer else "The foe", e["daemon"]]
		"item_used":
			if e["target_index"] == -1:
				return "You plugged in a %s!" % e["item_name"]
			return "%s used %s on %s." % ["You" if e["side"] == BattleState.PLAYER else (foe_trainer if foe_trainer else "The foe"), e["item_name"], e["target"]]
		"heal":
			return "%s restored %d Uptime." % [_name(e, is_wild), e["amount"]]
		"revived":
			return "%s rebooted!" % _name(e, is_wild)
		"out_of_pp":
			return "%s has no PP left!" % _name(e, is_wild)
		"move_used":
			return "%s ran %s!" % [_named(e["user"], e["side"], is_wild), e["move_name"]]
		"move_missed":
			return "%s's request timed out!" % _named(e["user"], e["side"], is_wild)
		"move_failed":
			return "But there was nothing to target..." if e["reason"] == "no_target" else "But it failed!"
		"damage":
			return "Critical hit!" if e.get("critical", false) else ""
		"hit_count":
			return "Hit %d times!" % e["count"]
		"effectiveness":
			return "It hit a weak spot!" if float(e["multiplier"]) > 1.0 else "It barely made a dent..."
		"no_effect":
			return "It doesn't affect %s..." % _named(e["target"], e["side"], is_wild)
		"drain":
			return "%s siphoned some Uptime!" % _name(e, is_wild)
		"recoil":
			return "%s took a power surge from the recoil!" % _name(e, is_wild)
		"stat_changed":
			var stat: String = STAT_NAMES.get(e["stat"], e["stat"])
			var delta := int(e["delta"])
			var how := ("rose" if delta == 1 else "rose sharply") if delta > 0 else ("fell" if delta == -1 else "harshly fell")
			return "%s's %s %s!" % [_name(e, is_wild), stat, how]
		"stat_change_failed":
			var stat_name: String = STAT_NAMES.get(e["stat"], e["stat"])
			return "%s's %s can't go any %s!" % [_name(e, is_wild), stat_name, "higher" if int(e["direction"]) > 0 else "lower"]
		"status_applied":
			return _status_applied(_name(e, is_wild), e["status"])
		"status_failed":
			return "But it failed!"
		"status_blocked":
			match e["status"]:
				"standby":
					return "%s is in Standby." % _name(e, is_wild)
				"hung":
					return "%s is Hung and won't respond!" % _name(e, is_wild)
			return "%s is Throttled! It can't move!" % _name(e, is_wild)
		"status_cured":
			match e["status"]:
				"standby":
					return "%s woke from Standby!" % _name(e, is_wild)
				"hung":
					return "%s is responding again!" % _name(e, is_wild)
			return "%s is no longer %s." % [_name(e, is_wild), String(e["status"]).capitalize()]
		"looping":
			return "%s is Looping!" % _name(e, is_wild)
		"hurt_itself":
			return "It hit itself on the next iteration!"
		"looping_ended":
			return "%s broke out of the loop!" % _name(e, is_wild)
		"status_damage":
			return ("%s is hurt by corrupted data!" if e["status"] == "corrupted" else "%s is hurt by the heat!") % _name(e, is_wild)
		"fainted":
			return "%s crashed!" % _name(e, is_wild)
		"exp_gained":
			return "%s gained %d EXP!" % [e["daemon"], e["amount"]]
		"level_up":
			return "%s patched up to Lv %d!" % [e["daemon"], e["level"]]
		"move_learned":
			return "%s installed %s!" % [e["daemon"], _move_name(e["move"])]
		"move_learn_pending":
			return "%s wants to install %s, but all 4 slots are full." % [e["daemon"], _move_name(e["move"])]
		"switch_needed":
			return "Choose a Daemon to deploy." if e["side"] == BattleState.PLAYER else ""
		"fled":
			return "You disconnected safely!"
		"run_failed":
			return "Couldn't disconnect!"
		"capture_shake":
			return ["Transferring...", "Transferring... 50%", "Transferring... 99%"][clampi(int(e["n"]) - 1, 0, 2)]
		"captured":
			return "Done! %s was Quarantined!" % e["daemon"]
		"capture_failed":
			return ["It ejected the key instantly!", "Scan failed! It broke free!",
				"So close! The transfer was interrupted!", "Argh! It broke free at 99%!"][clampi(int(e["shakes"]), 0, 3)]
		"battle_end":
			match e["outcome"]:
				"player_won":
					return "" if is_wild else "You closed %s's ticket!" % (foe_trainer if foe_trainer else "the foe")
				"player_lost":
					return "All your Daemons crashed... System failure!"
			return ""
		"upgrade_ready":
			return "Your %s is upgrading!" % e["daemon"]
		"invalid_action":
			return String(e["reason"])
	return ""


static func _status_applied(name: String, status: String) -> String:
	match status:
		"throttled":
			return "%s is Throttled! It may not respond!" % name
		"corrupted":
			return "%s's data got Corrupted!" % name
		"overheated":
			return "%s Overheated!" % name
		"standby":
			return "%s went into Standby!" % name
		"hung":
			return "%s Hung!" % name
		"looping":
			return "%s got stuck in a loop!" % name
	return "%s is %s." % [name, status]


static func _name(e: Dictionary, is_wild: bool) -> String:
	return _named(e.get("daemon", ""), int(e.get("side", 0)), is_wild)


## Foe Daemons get a prefix so it's clear whose turn it is.
static func _named(daemon_name: String, side: int, is_wild: bool) -> String:
	if side == BattleState.FOE:
		return ("Wild " if is_wild else "Foe ") + daemon_name
	return daemon_name


static func _move_name(move_id: String) -> String:
	return DataRegistry.get_move(move_id).get("name", move_id)
