class_name BattleState
extends RefCounted
## Everything about one battle in progress. BattleSim reads and changes it.
## All randomness comes from `rng`, so a battle with the same seed and the same actions
## always plays out the same way.

const PLAYER := 0
const FOE := 1

var sides: Array[BattleSide] = []
var rng: RandomNumberGenerator
var is_wild: bool = true
var turn: int = 0
var field: Dictionary = {}          # field-wide effects (none yet)
var escape_attempts: int = 0        # used by the run formula (Phase 2c)
var outcome: String = ""            # "" while ongoing, then "player_won", "player_lost" or "fled"
var end_reported: bool = false
## A side whose active Daemon crashed and still has others must pick one with
## BattleSim.forced_switch() before the next turn.
var needs_switch: Array[bool] = [false, false]
## Player stack indices that have faced the current foe Daemon. They share its EXP.
var participants: Array[int] = []
## Player stack indices that levelled up this battle (checked for upgrades at the end).
var leveled_up: Dictionary = {}


func _init(player: BattleSide, foe: BattleSide, p_rng: RandomNumberGenerator, p_is_wild: bool = true) -> void:
	sides = [player, foe]
	rng = p_rng
	is_wild = p_is_wild
	if player.active_index >= 0:
		participants = [player.active_index]


func is_over() -> bool:
	return outcome != ""


static func opponent(side: int) -> int:
	return 1 - side
