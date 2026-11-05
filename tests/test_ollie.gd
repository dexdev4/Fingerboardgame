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
	var a := board.angles_deg()
	if OS.get_environment("TRACE") == str(scenario) and tick >= SETTLE and tick < SETTLE + 60:
		var fs := ""
		for f: Finger in input.fingers.values():
			fs += " [r%d on%s z%.2f ps%.1f F%.1fW]" % [f.role, "Y" if f.on_board else "n", f.local_pos.z, f.press_speed, f.press_force / board.tuning.board_weight()]
		print("t%d h%.1f p%.1f w%d k%s vy%.1f wx%.1f%s" % [tick, board.height_mm(), a.x, board.wheels_down, str(board._kicks_touching.values()), board.linear_velocity.y, board.angular_velocity.x, fs])
	log_rows.append([tick, board.height_mm(), a.x, board.speed_cm_s(), board.wheels_down])
	tick += 1
	if tick >= SETTLE + 150:
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
	schedule.append([SETTLE, func():
		var h := cam.get_viewport().get_visible_rect().size.y
		var tail := _screen_of_local(Vector3(0, 0, board.geo.half_length * 0.85))
		var front := _screen_of_local(Vector3(0, 0, -board.geo.axle_z))   # front bolts
		_touch(0, tail, true)
		_touch(1, front, true)
		# Back foot: quick flick down the screen (12% of screen height in 50 ms).
		_plan_move(0, SETTLE + 2, tail, Vector2(0, h * 0.12), 6)
		if slide:
			# Front foot: drag up toward the nose, starting just after the pop.
			_plan_move(1, SETTLE + 8, front, Vector2(0, -h * 0.22), 14)
	])
	schedule.append([SETTLE + 40, func():
		_touch(0, Vector2.ZERO, false)
		_touch(1, Vector2.ZERO, false)])


func _plan_push() -> void:
	schedule.append([SETTLE, func():
		var h := cam.get_viewport().get_visible_rect().size.y
		var beside := _screen_of_local(Vector3(board.geo.half_width * 3.0, -board.geo.rest_height, 0))
		_touch(0, beside, true)
		_plan_move(0, SETTLE + 1, beside, Vector2(0, h * 0.3), 12)])
	schedule.append([SETTLE + 14, func(): _touch(0, Vector2.ZERO, false)])


# ---- Reporting ------------------------------------------------------------------------------

func _report() -> void:
	var names := ["ollie + front slide", "ollie, no front slide", "push", "ollie + slide (repeat)"]
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
		print("  t%3d  h %6.1f mm  pitch %6.1f°  v %6.1f cm/s  wheels %d" % r)
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
			_expect(max_speed > 10.0, "a swipe beside the board should push it forward")
		3:
			_expect(str(results[0]) == str(results[3]), "same input must give the same result")


func _expect(ok: bool, what: String) -> void:
	print(("  PASS: " if ok else "  FAIL: ") + what)
	if not ok:
		failures += 1


func _finish() -> void:
	print("\n%d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
