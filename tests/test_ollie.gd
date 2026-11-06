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
var upside_start := Vector3.ZERO
## Total roll (rotation about the board's long axis), degrees, accumulated every tick.
var roll_total := 0.0
var straight_roll := 0.0
var prev_roll_rate := 0.0
var roll_peak := 0.0      # largest |roll| reached during the scenario, degrees
## Grind/slide scenarios: per tick [truck contacts, deck-slide contacts, z, speed cm/s].
var contact_rows: Array = []
var slide_results := {}
## Grind/slide scenarios: drop speed (units/s) and how high above the obstacle to release (units).
const DROP_SPEED := 4.0
const DROP_GAP := 0.01
## Carve scenarios: roll speed and how far toward the right rail both fingers rest (units).
const CARVE_SPEED := 4.0
const CARVE_OFFSET := 0.06
## Catch scenario: the front finger lifts this many ticks after the flick starts, and comes back
## down on the board (the catch) at CATCH_TOUCH — just after the pop, as a player would.
const CATCH_LIFT := 12
const CATCH_TOUCH := 22
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
	holder.size = Vector2i(720, 1280)   # portrait phone
	holder.own_world_3d = true
	root.add_child(holder)
	main = load("res://scenes/main.tscn").instantiate()
	holder.add_child(main)
	board = null   # fetched once main's _ready has run
	tick = 0
	roll_total = 0.0
	roll_peak = 0.0
	prev_roll_rate = 0.0
	contact_rows.clear()
	log_rows.clear()
	schedule.clear()
	match scenario:
		0: _plan_ollie(true)
		1: _plan_ollie(false)
		2: _plan_push()
		3: _plan_ollie(true)   # repeat of 0 — must match exactly
		4: _plan_stairs()
		5: _plan_upside_down()
		6: _plan_flip_attempt()
		7: _plan_drop_on("rail", false)
		8: _plan_drop_on("rail", true)
		9: _plan_drop_on("ledge", false)
		10: _plan_carve(0.0)
		11: _plan_carve(CARVE_OFFSET)
		12: _plan_catch()
		13: _plan_catch_adjust()
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
	# Roll rate about the board's long axis. Only count roll sustained over 2+ ticks: a single
	# wheel touching down first gives a one-tick contact spike that doesn't actually turn the
	# board (the same filter as the feel metrics' "peak spin").
	var rr := board.angular_velocity.dot(board.global_transform.basis.z)
	var sustained := signf(rr) * minf(absf(rr), absf(prev_roll_rate)) if signf(rr) == signf(prev_roll_rate) else 0.0
	prev_roll_rate = rr
	roll_total += rad_to_deg(sustained) / Engine.physics_ticks_per_second
	roll_peak = maxf(roll_peak, absf(roll_total))
	if tick >= SETTLE:
		contact_rows.append([board.truck_contacts, board.deck_slide_contacts, board.global_position.z, board.speed_cm_s()])
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


## Roll forward with both fingers resting `offset` toward the right rail (0 = centred).
func _plan_carve(offset: float) -> void:
	schedule.append([SETTLE, func():
		board.request_reset(board.spawn_xf, -board.spawn_xf.basis.z * CARVE_SPEED)])
	schedule.append([SETTLE + 2, func():
		_touch(0, _screen_of_local(Vector3(offset, 0, board.geo.half_length * 0.7)), true)
		_touch(1, _screen_of_local(Vector3(offset, 0, -board.geo.axle_z)), true)])


## Pop with NO front slide (it over-rotates), lift the front finger, then put it back on the
## board mid-air: a catch. It should stop the rotation, level the board and land it.
func _plan_catch() -> void:
	schedule.append([SETTLE, func(): _ollie_now(SETTLE, false)])
	schedule.append([SETTLE + CATCH_LIFT, func(): _touch(1, Vector2.ZERO, false)])
	schedule.append([SETTLE + CATCH_TOUCH, func():
		_touch(1, _screen_of_local(Vector3(0, 0, -board.geo.axle_z)), true)])


## Drop the board flat from a height, catch it with a finger and drag the finger sideways:
## the board should rotate (yaw) under the finger before it lands.
func _plan_catch_adjust() -> void:
	schedule.append([SETTLE, func():
		var xf := board.spawn_xf
		xf.origin += Vector3.UP * 0.6
		board.request_reset(xf)])
	schedule.append([SETTLE + 3, func():
		var at := _screen_of_local(Vector3(0, 0, -board.geo.axle_z))
		_touch(1, at, true)
		var vsz := cam.get_viewport().get_visible_rect().size
		_plan_move(1, SETTLE + 4, at, Vector2(minf(vsz.x, vsz.y) * 0.12, 0), 18)])


## Drop the board (moving along the line at DROP_SPEED) just above an in-line obstacle:
##   "rail"  → the LineRail flat bar (top at y = 0.12), "ledge" → the LineLedge edge (top 0.15).
## sideways = board turned 90° across the rail, deck bottom on it (boardslide); otherwise the
## trucks land on it (50-50). No fingers: this tests the grind/slide physics on its own.
func _plan_drop_on(what: String, sideways: bool) -> void:
	schedule.append([SETTLE, func():
		var g := board.geo
		var top := 0.12 if what == "rail" else 0.15
		var z := -9.4 if what == "rail" else -20.0
		var basis := Basis.IDENTITY
		var y: float
		if sideways:
			basis = Basis(Vector3.UP, PI * 0.5)
			y = top + DROP_GAP + g.thickness * 0.5            # deck bottom just above the rail
		else:
			y = top + DROP_GAP - (g.wheel_y - g.wheel_radius * 0.3)   # hanger bottom just above
		board.request_reset(Transform3D(basis, Vector3(0, y, z)), Vector3(0, 0, -DROP_SPEED))])   # on the line, x = 0


## Pop, then slide the front finger up AND off the side of the nose — a kickflip-style flick.
func _plan_flip_attempt() -> void:
	# The flick comes as the board rises off the tail (later than an ollie's slide).
	schedule.append([SETTLE, func(): _ollie_now(SETTLE, true, Vector2(0.18, -0.26), SLIDE_START + 4)])


## Both fingers land now (tail + front bolts), then: tail flick, optional front slide, lift.
## `slide_dir` = front finger motion as a fraction of the screen height (default: straight up).
func _ollie_now(at: int, slide: bool, slide_dir := Vector2(0.0, -0.22), slide_start := SLIDE_START) -> void:
	var vsz := cam.get_viewport().get_visible_rect().size
	var h := minf(vsz.x, vsz.y)   # finger distances in screen short sides
	var tail := _screen_of_local(Vector3(0, 0, board.geo.half_length * 0.85))
	var front := _screen_of_local(Vector3(0, 0, -board.geo.axle_z))   # front bolts
	_touch(0, tail, true)
	_touch(1, front, true)
	# Back foot: quick flick down the screen (12% of screen height in 50 ms).
	_plan_move(0, at + 2, tail, Vector2(0, h * 0.12), FLICK_TICKS)
	if slide:
		# Front foot: drag up toward the nose, starting just after the pop.
		_plan_move(1, at + slide_start, front, slide_dir * h, SLIDE_TICKS)
	schedule.append([at + slide_start + SLIDE_TICKS + 10, func():
		_touch(0, Vector2.ZERO, false)
		_touch(1, Vector2.ZERO, false)])


## Drop the board upside down just above the platform, moving forward and spinning — like a
## bailed trick. It should grab the ground and stop instead of sliding around.
func _plan_upside_down() -> void:
	schedule.append([SETTLE, func():
		var xf := board.spawn_xf
		xf.basis = xf.basis * Basis(Vector3.BACK, PI)           # rolled over onto the grip
		xf.origin += Vector3.UP * 0.12
		board.request_reset(xf, Vector3(0.4, 0, -3.0), Vector3(0, 6.0, 0))
		upside_start = xf.origin])


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
			var vsz := cam.get_viewport().get_visible_rect().size
			var h := minf(vsz.x, vsz.y)   # finger distances in screen short sides
			var beside := _screen_of_local(Vector3(board.geo.half_width * 2.2, -board.geo.rest_height, 0))   # just off the side
			_touch(0, beside, true)
			_plan_move(0, at + 1, beside, Vector2(0, h * 0.3), SWIPE_TICKS)])
		schedule.append([at + SWIPE_TICKS + 2, func(): _touch(0, Vector2.ZERO, false)])


# ---- Reporting ------------------------------------------------------------------------------

func _report() -> void:
	var names := ["ollie + front slide", "ollie, no front slide", "push", "ollie + slide (repeat)",
			"ollie down the stairs", "upside-down landing", "flip attempt (front finger off the side)",
			"50-50 on the flat bar", "boardslide on the flat bar", "50-50 on the ledge edge",
			"roll straight (fingers centred)", "carve (fingers toward the right rail)",
			"catch in the air (no front slide, then re-touch)", "catch and drag in the air (adjust)"]
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
	print("  roll: peak %.0f°, net %.0f°" % [roll_peak, roll_total])
	if scenario >= 7 and scenario <= 9:
		_report_grind(1 if scenario == 8 else 0)
	match scenario:
		0:
			straight_roll = roll_peak
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
		6:
			_expect(roll_peak > 90.0, "flicking off the side in the air rolls the board (>90°)")
			_expect(absf(straight_roll) < 30.0, "a straight ollie barely rolls (<30°)")
		5:
			var slide := Vector2(board.global_position.x - upside_start.x, board.global_position.z - upside_start.z).length()
			var stop_tick := -1
			for i in range(log_rows.size() - 1, SETTLE, -1):
				if log_rows[i][3] > 1.0:     # last tick still moving faster than 1 cm/s
					stop_tick = log_rows[i][0] - SETTLE
					break
			print("  slid %.2f units (%.0f mm real), stopped after %d ticks, yaw turned %.0f°"
					% [slide, slide * 100.0, stop_tick, board.angles_deg().z])
			_expect(slide < 0.6 and stop_tick < 60, "upside-down board grabs the ground (<6 cm slide, stops <0.5 s)")
		10:
			print("  yaw after the roll %.1f°" % board.angles_deg().z)
			_expect(absf(board.angles_deg().z) < 5.0, "centred fingers roll straight")
		11:
			var yaw := board.angles_deg().z
			var turned := 0.0
			print("  yaw after the roll %.1f° (negative = turned right)" % yaw)
			_expect(yaw < -20.0, "weight toward the right rail carves right (>20°)")
		12:
			var catch_pitch := 0.0
			for r in log_rows.slice(SETTLE + CATCH_TOUCH + 2):
				catch_pitch = maxf(catch_pitch, r[2])
			var no_catch_pitch := 0.0
			for r in results[1]:
				no_catch_pitch = maxf(no_catch_pitch, r[2])
			print("  max pitch after the catch %.1f° (no catch: %.1f°)" % [catch_pitch, no_catch_pitch])
			_expect(catch_pitch < no_catch_pitch - 10.0, "the catch stops the over-rotation")
			_expect(last[4] == 4 and absf(last[2]) < 10.0, "caught board lands on its wheels")
		13:
			print("  yaw turned in the air %.1f°" % board.angles_deg().z)
			_expect(absf(board.angles_deg().z) > 15.0, "dragging a caught finger rotates the board")
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


## How long/far the board stayed on the obstacle via trucks (col 0) or deck (col 1).
func _report_grind(col: int) -> void:
	var first := -1
	var last := -1
	for i in contact_rows.size():
		if contact_rows[i][col] > 0:
			if first < 0:
				first = i
			last = i
	if first < 0:
		print("  never made contact")
		_expect(false, "board locks onto the obstacle")
		return
	var dist := absf(contact_rows[last][2] - contact_rows[first][2])
	var v0: float = contact_rows[first][3]
	var v1: float = contact_rows[last][3]
	print("  on the obstacle for %d ticks (%.2f s), %.0f mm real, speed %.0f → %.0f cm/s, roll peak %.0f°"
			% [last - first + 1, (last - first + 1) / 120.0, dist * 100.0, v0, v1, roll_peak])
	_expect(dist > 0.8, "stays locked on for a real distance (>8 cm)")
	_expect(v1 < v0, "friction slows it down (a grind/slide, not ice)")
	slide_results[col] = [dist, v0 - v1, last - first + 1]


func _expect(ok: bool, what: String) -> void:
	print(("  PASS: " if ok else "  FAIL: ") + what)
	if not ok:
		failures += 1


func _finish() -> void:
	print("\n%d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
