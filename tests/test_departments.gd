extends GutTest
## The five department challenges (2026-11-15: "something different each time, and harder as you go").
##   1 Desktop Support: ticket triage (pick the right fix; a wrong one starts a fight)
##   2 Networking: packet lanes (you slide along arrows; solvable, no soft-lock spots)
##   3 DevOps: run six pipeline stages in order (out of order rolls back and spawns bugs)
##   4 Facilities: power budget in a dark room (over 12 kW trips everything back)
##   5 SecOps: sneak past turning cameras, read three logs, name the compromised account

var world: Overworld


func before_each() -> void:
	GameState.reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	GameState.add_daemon(DaemonInstance.create("chipmunk", 30, rng, 1))
	GameState.flags["got_starter"] = true


func after_each() -> void:
	SceneRouter.params = {}
	GameState.reset()


func _open(map_id: String) -> void:
	SceneRouter.params = {"map": map_id, "spawn": "default"}
	world = load(Overworld.SCENE).instantiate()
	world.allow_scene_change = false
	world.auto_advance_text = true
	world.auto_choice = true
	world.auto_picks = []
	watch_signals(world)
	add_child_autofree(world)
	world.set_time_scale(0.0)
	await wait_process_frames(2)
	await wait_until(func() -> bool: return world.is_idle(), 5.0)


func _logged(part: String) -> bool:
	for line in world.dialogue_log:
		if part in line:
			return true
	return false


## Stand at `at` facing `dir` and press A.
func _use(at: Vector2i, dir: Vector2i) -> void:
	world.player.setup(world.map, at, dir)
	await world.interact()
	await wait_until(func() -> bool: return world.is_idle(), 5.0)


func _door_open() -> bool:
	return world.map.is_walkable(Vector2i(7, 9))


# --- 1. ticket triage -----------------------------------------------------------------------------------------------

func test_desktop_support_tickets() -> void:
	await _open("department_1")
	assert_true(_logged("ticket queue"), "the receptionist explains it")
	assert_false(_door_open())
	world.auto_picks = [0]  # REINSTALL OS: wrong
	await _use(Vector2i(3, 13), Vector2i.UP)
	assert_signal_emitted(world, "battle_requested", "a wrong fix makes the user's Daemon attack")
	assert_false(GameState.flags.get("ticket_a_fixed", false))
	for t: Array in [[Vector2i(3, 13), 1], [Vector2i(11, 13), 2], [Vector2i(12, 16), 3]]:
		world.auto_picks = [t[1]]
		await _use(t[0], Vector2i.UP)
	for id in ["ticket_a_fixed", "ticket_b_fixed", "ticket_c_fixed"]:
		assert_true(GameState.flags.get(id, false), id)
	assert_true(_door_open(), "all three tickets closed")


# --- 2. packet lanes --------------------------------------------------------------------------------------------------

const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const SLIDE := {"slide_up": Vector2i.UP, "slide_down": Vector2i.DOWN, "slide_left": Vector2i.LEFT, "slide_right": Vector2i.RIGHT}


## Where one press of `dir` from `from` ends up, riding lanes like PlayerController does (or `from` if blocked).
func _lane_move(map: MapView, from: Vector2i, dir: Vector2i) -> Vector2i:
	var c := from + dir
	if not map.is_walkable(c):
		return from
	var ridden := {c: true}
	while SLIDE.has(map.tile_info(c)["behavior"]):
		var d: Vector2i = SLIDE[map.tile_info(c)["behavior"]]
		if not map.is_walkable(c + d) or ridden.has(c + d):
			break
		c += d
		ridden[c] = true
	return c


func _lane_reach(map: MapView, start: Vector2i) -> Dictionary:  # cell -> moves
	var dist := {start: 0}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var at: Vector2i = queue.pop_front()
		for d in DIRS:
			var to := _lane_move(map, at, d)
			if not dist.has(to):
				dist[to] = int(dist[at]) + 1
				queue.append(to)
	return dist


func test_packet_lanes_carry_you_and_the_floor_is_solvable_without_traps() -> void:
	await _open("department_2")
	assert_true(_logged("carries you like a packet"))
	var map := world.map
	var start := Vector2i(7, 20)
	var goal := Vector2i(7, 10)
	var dist := _lane_reach(map, start)
	assert_true(dist.has(goal), "Ping's door is reachable")
	assert_gte(int(dist.get(goal, 0)), 12, "and it takes real routing (%d moves)" % int(dist.get(goal, 0)))
	for cell: Vector2i in dist:
		var back := _lane_reach(map, cell)
		assert_true(back.has(goal) or back.has(start), "no soft-lock at %s" % cell)
	# A real lane ride: (8,19) is a left lane at the bottom; stepping on rides it until it stops.
	world.player.setup(map, Vector2i(8, 20), Vector2i.UP)
	await world.player.try_step(Vector2i.UP)
	assert_eq(world.player.cell, _lane_move(map, Vector2i(8, 20), Vector2i.UP), "the player ends where the solver says")
	assert_ne(world.player.cell, Vector2i(8, 19), "the lane carried you past the tile you stepped on")


# --- 3. the pipeline ---------------------------------------------------------------------------------------------------

const STAGES := [["LINT", Vector2i(10, 16), Vector2i.UP], ["BUILD", Vector2i(2, 12), Vector2i.UP],
	["TEST", Vector2i(6, 18), Vector2i.UP], ["SCAN", Vector2i(8, 18), Vector2i.UP],
	["STAGING", Vector2i(12, 12), Vector2i.UP], ["DEPLOY", Vector2i(4, 16), Vector2i.UP]]


func test_devops_pipeline_in_order_opens_out_of_order_rolls_back() -> void:
	await _open("department_3")
	assert_false(_door_open())
	await _use(STAGES[1][1], STAGES[1][2])  # BUILD first: wrong
	assert_true(_logged("BUILD: FAILED"))
	assert_signal_emitted(world, "battle_requested", "a failed build spawns bugs")
	assert_eq(int(GameState.counters.get("pipeline", -1)), 0)
	for stage: Array in STAGES:
		await _use(stage[1], stage[2])
		assert_true(_logged("%s: PASSED" % stage[0]), stage[0])
	assert_true(GameState.flags.get("pipeline_green", false))
	assert_true(_door_open(), "six green stages")


func test_the_friday_hotfix_is_a_trap() -> void:
	GameState.counters["pipeline"] = 3
	await _open("department_3")
	await _use(Vector2i(7, 14), Vector2i.UP)
	assert_true(_logged("Friday at 4:59"))
	assert_eq(int(GameState.counters["pipeline"]), 0, "rolled back")


# --- 4. the power budget ---------------------------------------------------------------------------------------------

func _breaker(id: String) -> void:
	var at := {"servers": 2, "coffee": 4, "cooling": 6, "rig": 8, "door": 10, "heater": 12}
	if id == "lights":
		await _use(Vector2i(2, 16), Vector2i.LEFT)
	else:
		await _use(Vector2i(int(at[id]), 12), Vector2i.UP)


func test_facilities_power_budget() -> void:
	await _open("department_4")
	assert_eq(int(GameState.counters["load"]), 12, "Ransom left it at the limit: servers + rig + heater")
	assert_ne(world._tint.color, Color.WHITE, "brownout: the room is dark")
	await _breaker("lights")
	assert_true(_logged("main breaker trips"), "lights first goes over 12 kW")
	assert_eq(int(GameState.counters["load"]), 12)
	for id in ["rig", "heater", "lights", "cooling", "door"]:
		await _breaker(id)
	assert_true(_logged("Too dark to read"), "labels can't be read in the dark")
	assert_true(_logged("BREAKER: COOLING, 3 kW."), "but can once the lights are on")
	assert_eq(world._tint.color, Color.WHITE, "lights on")
	assert_eq(int(GameState.counters["load"]), 12)
	assert_true(_door_open(), "servers + cooling + door + lights, rig off")
	await _breaker("servers")
	assert_true(_logged("Rolf screams"), "never turn the servers off")
	assert_false(_door_open(), "back to how Ransom left it")


# --- 5. stealth + forensics ------------------------------------------------------------------------------------------

func _cameras() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in world.map.map_data["events"]:
		if e["type"] == "camera":
			out.append(e)
	return out


## The cells cameras watch after `t` of your steps (same rules as CameraEvent).
func _watched(cams: Array[Dictionary], t: int) -> Dictionary:
	var out := {}
	for c in cams:
		var turns: Array = c.get("turns", [c["facing"]])
		var f: String = turns[(t / int(c.get("turn_every", 1))) % turns.size()]
		var d: Vector2i = MapView.FACING_VECTORS[f]
		for i in range(1, int(c["range"]) + 1):
			var cell := Vector2i(int(c["x"]), int(c["y"])) + d * i
			if world.map.tile_info(cell)["collision"]:
				break
			out[cell] = true
	return out


func test_secops_floor_is_sneakable_to_every_log() -> void:
	await _open("department_5")
	var cams := _cameras()
	var period := 1
	for c in cams:
		var n: int = c.get("turns", []).size()
		if n > 1:
			var p: int = n * int(c.get("turn_every", 1))
			var g := period
			var b := p
			while b != 0:
				var tmp := b
				b = g % b
				g = tmp
			period = period * p / g
	var watched: Array = []
	for t in period:
		watched.append(_watched(cams, t))
	var logs := {Vector2i(3, 13): 1, Vector2i(11, 15): 2, Vector2i(7, 17): 4}
	var start := [Vector2i(7, 20), 0, 0]
	var seen := {start: 0}
	var queue: Array = [start]
	var best := -1
	while not queue.is_empty():
		var s: Array = queue.pop_front()
		if s[0] == Vector2i(7, 10) and s[2] == 7:
			best = seen[s]
			break
		for d in DIRS:
			var c: Vector2i = s[0] + d
			if not world.map.is_walkable(c):
				continue
			var nt: int = (int(s[1]) + 1) % period
			if watched[nt].has(c):
				continue
			var ns := [c, nt, int(s[2]) | int(logs.get(c, 0))]
			if not seen.has(ns):
				seen[ns] = int(seen[s]) + 1
				queue.append(ns)
	assert_gt(best, 0, "you can read all three logs and reach the console unseen")
	assert_gte(best, 30, "and it's the hardest room (%d moves)" % best)


func test_cameras_send_you_back_and_the_console_wants_the_right_account() -> void:
	await _open("department_5")
	world.player.setup(world.map, Vector2i(1, 19), Vector2i.UP)  # the x1 column is always watched
	await world.player.try_step(Vector2i.UP)
	await wait_until(func() -> bool: return world.is_idle(), 5.0)
	assert_true(_logged("Escorting you back"))
	assert_eq(world.player.cell, Vector2i(7, 20), "back in the lobby")
	await _use(Vector2i(7, 10), Vector2i.LEFT)
	assert_true(_logged("Read all three"), "the console wants all three logs first")
	for flag in ["log_auth", "log_vpn", "log_badge"]:
		GameState.flags[flag] = true
	world.auto_picks = [0]  # kevin.r: wrong (MFA blocked him)
	await _use(Vector2i(7, 10), Vector2i.LEFT)
	assert_true(_logged("kevin.r is clean"))
	assert_false(GameState.flags.get("log_auth", false), "logs re-shredded")
	assert_eq(world.player.cell, Vector2i(7, 20), "escorted out")
	for flag in ["log_auth", "log_vpn", "log_badge"]:
		GameState.flags[flag] = true
	world.auto_picks = [2]  # svc_backup
	await _use(Vector2i(7, 10), Vector2i.LEFT)
	assert_true(GameState.flags.get("sec_found", false))
	assert_true(_door_open())
	for e in world.events:
		if e is CameraEvent:
			assert_false(e.is_on(), "cameras power down once it's solved")


func test_challenge_sounds_exist() -> void:
	for id in ["unlock", "error", "alarm", "trip", "lane", "click"]:
		var stream: AudioStream = AudioManager._sfx_stream(id)
		assert_not_null(stream, id)
		assert_gt(stream.get_length(), 0.0, "%s has sound in it" % id)
