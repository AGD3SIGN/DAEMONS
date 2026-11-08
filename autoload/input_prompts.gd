extends Node
## Knows what the player is holding (keyboard, Xbox / PlayStation / Nintendo pad, or touch) from the
## last input, and names buttons to match: label("ui_accept") is "Z", "A", "Cross", "B" (Nintendo's
## confirm is on the right... its south button is labelled B) or "tap". UI listens to scheme_changed.

signal scheme_changed(scheme: String)

const SCHEMES: PackedStringArray = ["keyboard", "xbox", "playstation", "nintendo", "touch"]
const LABELS := {
	"keyboard":    {"ui_accept": "Z", "ui_cancel": "X", "menu": "Space", "run": "Shift"},
	"xbox":        {"ui_accept": "A", "ui_cancel": "B", "menu": "Start", "run": "X"},
	"playstation": {"ui_accept": "Cross", "ui_cancel": "Circle", "menu": "Options", "run": "Square"},
	"nintendo":    {"ui_accept": "B", "ui_cancel": "A", "menu": "+", "run": "Y"},
	"touch":       {"ui_accept": "the check button", "ui_cancel": "the back button", "menu": "the menu button", "run": "push the d-pad far"},
}

var scheme: String = "keyboard"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.is_touchscreen_available() and Input.get_connected_joypads().is_empty():
		scheme = "touch"


func _input(event: InputEvent) -> void:
	var detected := detect(event)
	if not detected.is_empty() and detected != scheme:
		scheme = detected
		scheme_changed.emit(scheme)


## Which scheme an event belongs to ("" if it says nothing, e.g. a tiny stick wobble).
static func detect(event: InputEvent) -> String:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return "touch"
	if event is InputEventKey or (event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION):
		return "keyboard"
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		return brand_from_name(Input.get_joy_name(event.device))
	return ""


## Controller brand from its reported name. Unknown pads use the Xbox layout (most common).
static func brand_from_name(joy_name: String) -> String:
	var n := joy_name.to_lower()
	for word in ["playstation", "dualshock", "dualsense", "ps3", "ps4", "ps5", "sony"]:
		if word in n:
			return "playstation"
	for word in ["nintendo", "switch", "joy-con", "joycon", "pro controller"]:
		if word in n:
			return "nintendo"
	return "xbox"


## Button name for an action in the current scheme (or a given one).
func label(action: String, for_scheme: String = "") -> String:
	var s := for_scheme if not for_scheme.is_empty() else scheme
	return LABELS.get(s, LABELS["keyboard"]).get(action, action)


## "press Z" / "press A" / "tap the check button" style verb + button.
func press(action: String) -> String:
	return ("tap " if scheme == "touch" else "press ") + label(action)
