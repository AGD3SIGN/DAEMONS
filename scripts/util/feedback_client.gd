class_name FeedbackClient
extends Node
## Sends in-game feedback to the DAEMONS feedback relay (services/feedback-worker), which files it as an issue
## in the private feedback repo after the player passes a captcha in their browser.
##
##   var client := FeedbackClient.new(); add_child(client)
##   var result := await client.send(FeedbackClient.payload("bug", "The shop froze"))
##   -> {"ok": true, "confirm_url": "https://.../confirm/<id>"}   then open that URL in the browser
##   -> {"ok": false, "offline": true}                            no connection; saved to the outbox
##   -> {"ok": false, "error": "Too much feedback..."}            the relay said no
##
## Nothing personal is sent: the message, the game version/build, the platform, where you are on the map,
## play time, how many certs and Daemons you have. No save file, no name, no account.

const OUTBOX := "user://feedback_outbox.json"
const TIMEOUT := 15.0

## Tests replace this with a Callable(url: String, body: String) -> Dictionary {"code": int, "body": String}.
var transport: Callable


static func config() -> Dictionary:
	return DataRegistry.feedback


static func endpoint() -> String:
	return String(config().get("endpoint", "")).trim_suffix("/")


static func is_configured() -> bool:
	return endpoint().begins_with("https://")


static func platform_id() -> String:
	if OS.has_feature("web"):
		return "web"
	match OS.get_name():
		"macOS":
			return "macos"
		"Windows":
			return "windows"
		"iOS":
			return "ios"
		"Android":
			return "android"
	return "linux"


## Game details attached to every report (only the keys the relay accepts).
static func context() -> Dictionary:
	var where: Dictionary = GameState.location
	var daemons := GameState.active_stack.size()
	for rack: Array in GameState.racks:
		daemons += rack.size()
	return {
		"version": String(ProjectSettings.get_setting("application/config/version", "")),
		"build": TitleScreenBuild.number(),
		"platform": platform_id(),
		"map": String(where.get("map", "")),
		"x": int(where.get("x", 0)),
		"y": int(where.get("y", 0)),
		"play_minutes": int(GameState.play_time_sec / 60.0),
		"certs": GameState.certifications.size(),
		"daemons": daemons,
		"language": OS.get_locale_language(),
	}


static func payload(category: String, message: String) -> Dictionary:
	return {"category": category, "message": message.strip_edges(), "context": context()}


## "" if the message is fine, otherwise what's wrong with it (shown to the player).
static func check_message(message: String) -> String:
	var length := message.strip_edges().length()
	var low := int(config().get("min_message", 10))
	var high := int(config().get("max_message", 2000))
	if length < low:
		return "Please write at least %d characters." % low
	if length > high:
		return "Please keep it under %d characters." % high
	return ""


## Posts a draft to the relay. Never throws; see the class notes for the result shapes.
func send(data: Dictionary) -> Dictionary:
	if not is_configured():
		return {"ok": false, "error": "Feedback isn't set up in this build yet."}
	var response := await _post(endpoint() + "/drafts", JSON.stringify(data))
	var code := int(response.get("code", 0))
	if code == 0:
		return {"ok": false, "offline": true}
	var parsed: Variant = JSON.parse_string(String(response.get("body", "")))
	var body: Dictionary = parsed if parsed is Dictionary else {}
	if code == 200 and String(body.get("confirm_url", "")).begins_with(endpoint() + "/confirm/"):
		return {"ok": true, "confirm_url": String(body["confirm_url"])}
	return {"ok": false, "error": String(body.get("error", "The feedback server said no (%d)." % code))}


func _post(url: String, body: String) -> Dictionary:
	if transport.is_valid():
		return await transport.call(url, body)
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	add_child(http)
	var err := http.request(url, PackedStringArray(["content-type: application/json"]), HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		return {"code": 0}
	var result: Array = await http.request_completed
	http.queue_free()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"code": 0}
	return {"code": int(result[1]), "body": (result[3] as PackedByteArray).get_string_from_utf8()}


# --- outbox (feedback written while offline) ----------------------------------------

static func load_outbox() -> Array:
	if not FileAccess.file_exists(OUTBOX):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(OUTBOX))
	return parsed if parsed is Array else []


static func save_outbox(items: Array) -> void:
	if items.is_empty():
		if FileAccess.file_exists(OUTBOX):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(OUTBOX))
		return
	var file := FileAccess.open(OUTBOX, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(items))


static func queue(data: Dictionary) -> void:
	var items := load_outbox()
	items.append(data)
	save_outbox(items.slice(-5))  # keep the last few at most


## Opens the confirm page. On the web it reuses the player's click (browsers block pop-ups otherwise).
static func open_confirm(url: String) -> void:
	OS.shell_open(url)


## Small helper so the client doesn't depend on the title screen script.
class TitleScreenBuild:
	static func number() -> int:
		var text := FileAccess.get_file_as_string("res://data/build_info.json")
		var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
		return int(parsed.get("build", 0)) if parsed is Dictionary else 0
