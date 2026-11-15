class_name ControlHint
extends PanelContainer
## Overworld corner tag: "Space PHONE  M MAP  Z TALK" in the buttons of whatever you're holding, so a browser
## player knows how to open the menu (player feedback, 2026-11-14). Hidden on touch (the overlay has
## real buttons), while a menu or dialogue is open, and when Options > CONTROL HINTS is off.

var world: Overworld
var _label: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 1.0
	anchor_right = 1.0
	offset_top = 4
	offset_right = -4
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	modulate = Color(1, 1, 1, 0.85)
	_label = Label.new()
	add_child(_label)


func _ready() -> void:
	InputPrompts.scheme_changed.connect(func(_s: String) -> void: refresh())
	refresh()


func text() -> String:
	return "%s PHONE  %s MAP  %s TALK" % [InputPrompts.label("menu"), InputPrompts.label("map"), InputPrompts.label("ui_accept")]


func refresh() -> void:
	_label.text = text()


func should_show() -> bool:
	if not Settings.control_hints or InputPrompts.scheme == "touch" or world == null:
		return false
	# Not world.is_idle(): that's false mid-step, which made the tag blink on every step.
	return world.is_free() and not world.text_box.visible and not world.banner_showing()


func _process(_delta: float) -> void:
	visible = should_show()
