## Headless physics check — simulates touch input and prints what the board does.
##   godot --headless --path . -s res://tests/test_ollie.gd
## Scenarios: ollie with front-foot slide, ollie without slide, pushing, determinism.
## Exits with code 1 if an expectation fails.
extends SceneTree

const SETTLE := 60   # ticks to let the board settle before input

var main: Node3D
var holder: SubViewport   # each scenario gets its own 1280×720 viewport and physics world
var board: Board
var input: FingerInput
var cam: Camera3D
var tick := 0
var schedule: Array = []     # [tick, Callable]
var log_rows: Array = []
var failures := 0
var scenario := 0
var results := {}
## Stairs scenario: the ollie starts when the board's centre passes this z (deterministic,
## it depends only on the simulated position).
var stairs_trigger_z := INF
## Roll-in speed for the stairs scenario (units/s; 10 units/s = 1 m/s real).
const STAIRS_SPEED := 5.0
## Finger timing (physics ticks at 120/s). The controls are tuned for slow, deliberate fingers:
const FLICK_TICKS := 14        # back foot: 12% of the screen height in ~0.12 s
const SLIDE_START := 14        # front foot starts sliding this long after the flick starts
const SLIDE_TICKS := 26        # front foot: 22% of the screen height in ~0.22 s
const SWIPE_TICKS := 24        # each push swipe: 30% of the screen height in 0.2 s
## How far before the platform edge (units) the board's centre is when the flick starts.
const STAIRS_LEAD := 1.2


var started := false


func _start_scenario() -> void:
	if holder:
		root.remove_child(holder)   # free now: a queued-free board would still collide this tick
		holder.free()
	# A fresh World3D per scenario = a fresh physics space, so a repeat run is a true repeat.
	holder = SubViewport.new()
	holder.size = Vector2i(1280, 720)
	holder.own_world_3d = true
	root.add_child(holder)
	main = load("res://scenes/main.tscn").instantiate()
	holder.add_child(main)
	board = null   # fetched once main's _ready has run
	tick = 0
	log_rows.clear()
	schedule.clear()
	match scenario:
		0: _plan_ollie(true)
		1: _plan_ollie(false)
		2: _plan_push()
		3: _plan_ollie(true)   # repeat of 0 — must match exactly
		4: _plan_stairs()
		_:
			_finish()


func _physics_process(_dt: float) -> bool:
	if not started:   # start every scenario the same way: from inside a physics tick
		started = true
		_start_scenario()
		return false
	if board == null:
		if main == null or not main.is_node_ready():
			return false
		board = main.board
		input = main.finger_input
		cam = main.camera
	for item in schedule:
		if item[0] == tick:
			item[1].call()
	if stairs_trigger_z != INF and board.global_position.z < stairs_trigger_z:
		stairs_trigger_z = INF
		_ollie_now(tick, true)
	var a := board.angles_deg()
	if OS.get_environment("TRACE") == str(scenario) and tick >= SETTLE and tick < SETTLE + 200:
		var fs := ""
		for f: Finger in input.fingers.values():
			fs += " [r%d on%s z%.2f ps%.1f F%.1fW]" % [f.role, "Y" if f.on_board else "n", f.local_pos.z, f.press_speed, f.press_force / board.tuning.board_weight()]
		print("t%d h%.1f p%.1f w%d k%s vy%.1f wx%.1f |w|%.1f%s" % [tick, board.height_mm(), a.x, board.wheels_down, str(board._kicks_touching.values()), board.linear_velocity.y, board.angular_velocity.x, board.angular_velocity.length(), fs])
	log_rows.append([tick, board.height_mm(), a.x, board.speed_cm_s(), board.wheels_down, board.angular_velocity.length()])
	tick += 1
	if tick >= SETTLE + (300 if scenario == 4 else 240):
		_report()
		scenario += 1
		_start_scenario()
	return false


# ---- Input helpers ------------------------------------------------------------------------

func _screen_of_local(local: Vector3) -> Vector2:
	var size := cam.get_viewport().get_visible_rect().size
	return ScreenMath.project(cam, size, board.global_transform * local)


func _touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = pressed
	input._unhandled_input(e)


func _drag(idx: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	input._unhandled_input(e)


## Moves finger `idx` from `from` by `delta` px over `ticks` ticks, an event every 2 ticks (60 Hz).
func _plan_move(idx: int, start_tick: int, from: Vector2, delta: Vector2, ticks: int) -> void:
	for k in range(2, ticks + 1, 2):
		var p := from + delta * (float(k) / ticks)
		schedule.append([start_tick + k, func(): _drag(idx, p)])


# ---- Scenarios ------------------------------------------------------------------------------

func _plan_ollie(slide: bool) -> void:
	schedule.append([SETTLE, func(): _ollie_now(SETTLE, slide)])


## Both fingers land now (tail + front bolts), then: tail flick, optional front slide, lift.
func _ollie_now(at: int, slide: bool) -> void:
	var h := cam.get_viewport().get_visible_rect().size.y
	var tail := _screen_of_local(Vector3(0, 0, board.geo.half_length * 0.85))
	var front := _screen_of_local(Vector3(0, 0, -board.geo.axle_z))   # front bolts
	_touch(0, tail, true)
	_touch(1, front, true)
	# Back foot: quick flick down the screen (12% of screen height in 50 ms).
	_plan_move(0, at + 2, tail, Vector2(0, h * 0.12), FLICK_TICKS)
	if slide:
		# Front foot: drag up toward the nose, starting just after the pop.
		_plan_move(1, at + SLIDE_START, front, Vector2(0, -h * 0.22), SLIDE_TICKS)
	schedule.append([at + SLIDE_START + SLIDE_TICKS + 10, func():
		_touch(0, Vector2.ZERO, false)
		_touch(1, Vector2.ZERO, false)])


## Roll toward the stair set at STAIRS_SPEED and ollie just before the edge.
func _plan_stairs() -> void:
	schedule.append([SETTLE, func():
		board.linear_velocity = -board.global_transform.basis.z * STAIRS_SPEED
		# Start the flick ~1 board length before the edge (platform edge at z = −1): the flick
		# and snap take ~15 ticks, during which the board covers almost a unit at this speed.
		stairs_trigger_z = -1.0 + STAIRS_LEAD])


## Three backward swipes on the ground beside the board, like three pushes.
func _plan_push() -> void:
	for k in 3:
		var at := SETTLE + k * (SWIPE_TICKS + 12)
		schedule.append([at, func():
			var h := cam.get_viewport().get_visible_rect().size.y
			var beside := _screen_of_local(Vector3(board.geo.half_width * 3.0, -board.geo.rest_height, 0))
			_touch(0, beside, true)
			_plan_move(0, at + 1, beside, Vector2(0, h * 0.3), SWIPE_TICKS)])
		schedule.append([at + SWIPE_TICKS + 2, func(): _touch(0, Vector2.ZERO, false)])


# ---- Reporting ------------------------------------------------------------------------------

func _report() -> void:
	var names := ["ollie + front slide", "ollie, no front slide", "push", "ollie + slide (repeat)",
			"ollie down the stairs"]
	var max_h := 0.0
	var max_pitch := 0.0
	var max_speed := 0.0
	var air_ticks := 0
	for r in log_rows.slice(SETTLE):
		max_h = maxf(max_h, r[1])
		max_pitch = maxf(max_pitch, r[2])
		max_speed = maxf(max_speed, r[3])
		if r[4] == 0:
			air_ticks += 1
	var last: Array = log_rows[-1]
	print("\n== %s ==" % names[scenario])
	print("max height %.1f mm | max pitch %.1f° | air %d ticks | max speed %.1f cm/s | end: h %.1f mm pitch %.1f° wheels %d"
			% [max_h, max_pitch, air_ticks, max_speed, last[1], last[2], last[4]])
	for r in log_rows.slice(SETTLE, SETTLE + 70, 4):
		print("  t%3d  h %6.1f mm  pitch %6.1f°  v %6.1f cm/s  wheels %d  spin %5.1f rad/s" % r)
	_feel_metrics()
	results[scenario] = log_rows.duplicate(true)
	match scenario:
		0:
			_expect(max_h > 8.0, "ollie should leave the ground clearly (>8 mm)")
			_expect(absf(last[2]) < 10.0 and last[4] >= 3, "with front slide the board should land flat on its wheels")
		1:
			_expect(max_h > 4.0, "no-slide pop should still lift")
			var slide_pitch := 0.0
			for r in results[0]:
				slide_pitch = maxf(slide_pitch, r[2])
			_expect(slide_pitch < max_pitch - 5.0, "front slide should catch the nose (less over-rotation)")
		2:
			_expect(max_speed > 60.0, "three swipes should reach stair-clearing speed (>60 cm/s)")
		3:
			_expect(str(results[0]) == str(results[3]), "same input must give the same result")
		4:
			var p := board.global_position
			print("  end position z %.2f, ground %.2f, roll %.1f°" % [p.z, board.ground_y, board.angles_deg().y])
			_expect(p.z < -2.0 and board.ground_y < 0.05, "board ends beyond the stairs, on the ground")
			_expect(last[4] == 4 and absf(last[2]) < 10.0 and absf(board.angles_deg().y) < 10.0,
					"stair landing on all four wheels")


## "Heavy & realistic" feel numbers (printed, not pass/fail):
##   peak spin   — how twitchy the board is (rad/s), sustained for 2+ ticks (one-tick contact
##                 spikes when a single wheel lands first are ignored)
##   bounces     — times all wheels left the ground again after the first touchdown
##   settle      — ticks from first touchdown until 4 wheels down and spin < 0.5 rad/s
##   coast       — speed kept at the end of the run vs the peak (rolling/drag losses)
func _feel_metrics() -> void:
	var rows := log_rows.slice(SETTLE)
	var peak_spin := 0.0
	var touched := -1
	var bounces := 0
	var settle := -1
	var was_down := true
	var air := false
	for i in rows.size() - 1:
		peak_spin = maxf(peak_spin, minf(rows[i][5], rows[i + 1][5]))
	for r in rows:
		if r[4] == 0:
			air = true
		if air and r[4] > 0 and touched < 0:
			touched = r[0]
		if touched >= 0 and was_down and r[4] == 0:
			bounces += 1
		if touched >= 0 and settle < 0 and r[4] == 4 and r[5] < 0.5:
			settle = r[0] - touched
		was_down = r[4] > 0
	var peak_v := 0.0
	for r in rows:
		peak_v = maxf(peak_v, r[3])
	print("  feel: peak spin %.1f rad/s | bounces %d | settle %d ticks | coast %.0f%% of peak speed | yaw drift %.1f°"
			% [peak_spin, bounces, settle, 100.0 * rows[-1][3] / maxf(peak_v, 0.001), board.angles_deg().z])


func _expect(ok: bool, what: String) -> void:
	print(("  PASS: " if ok else "  FAIL: ") + what)
	if not ok:
		failures += 1


func _finish() -> void:
	print("\n%d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
