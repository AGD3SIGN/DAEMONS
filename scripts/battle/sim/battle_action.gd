class_name BattleAction
extends RefCounted
## One side's choice for a turn. Build with the static helpers:
##   BattleAction.fight(0)  BattleAction.switch_to(2)  BattleAction.item("coffee", 0)  BattleAction.run()

enum Kind { FIGHT, SWITCH, ITEM, RUN }

var kind: Kind = Kind.FIGHT
var slot: int = -1        # FIGHT: move slot 0..3
var index: int = -1       # SWITCH: stack index to bring in; ITEM: stack index of the target
var item_id: String = ""  # ITEM


static func fight(move_slot: int) -> BattleAction:
	var a := BattleAction.new()
	a.kind = Kind.FIGHT
	a.slot = move_slot
	return a


static func switch_to(stack_index: int) -> BattleAction:
	var a := BattleAction.new()
	a.kind = Kind.SWITCH
	a.index = stack_index
	return a


static func item(p_item_id: String, target_index: int) -> BattleAction:
	var a := BattleAction.new()
	a.kind = Kind.ITEM
	a.item_id = p_item_id
	a.index = target_index
	return a


static func run() -> BattleAction:
	var a := BattleAction.new()
	a.kind = Kind.RUN
	return a


func describe() -> String:
	match kind:
		Kind.FIGHT:
			return "fight(%d)" % slot
		Kind.SWITCH:
			return "switch(%d)" % index
		Kind.ITEM:
			return "item(%s, %d)" % [item_id, index]
	return "run"
