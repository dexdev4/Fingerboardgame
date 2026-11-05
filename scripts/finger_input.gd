## Turns raw touches into Fingers and, every physics tick, works out what each finger is
## doing in *board space*. It never decides "which trick" — it only measures.
##
## Touch events are only stored here; all measuring happens in physics_update(), which the
## board calls from _integrate_forces, so input is sampled at fixed ticks (determinism).
class_name FingerInput
extends Node

var tuning: BoardTuning
var geo: BoardGeometry
var camera: Camera3D
var board: RigidBody3D
## Screen rectangles where touches belong to the UI (e.g. the reset button).
var ui_blockers: Callable = func(_p: Vector2) -> bool: return false

## Active touches, keyed by touch index.
var fingers := {}


func setup(t: BoardTuning, g: BoardGeometry, cam: Camera3D, b: RigidBody3D) -> void:
	tuning = t
	geo = g
	camera = cam
	board = b


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if not ui_blockers.call(event.position):
				fingers[event.index] = Finger.new(event.index, event.position)
		else:
			fingers.erase(event.index)   # lifting a finger simply removes its forces
	elif event is InputEventScreenDrag and fingers.has(event.index):
		fingers[event.index].screen_pos = event.position


func clear() -> void:
	fingers.clear()


func feet() -> Array[Finger]:
	var out: Array[Finger] = []
	for f: Finger in fingers.values():
		if f.role == Finger.Role.BACK_FOOT or f.role == Finger.Role.FRONT_FOOT:
			out.append(f)
	return out


func pushers() -> Array[Finger]:
	var out: Array[Finger] = []
	for f: Finger in fingers.values():
		if f.role == Finger.Role.PUSH:
			out.append(f)
	return out


## Called by the board once per physics tick, with the board's current transform.
func physics_update(board_xf: Transform3D, space: PhysicsDirectSpaceState3D, dt: float) -> void:
	var size := camera.get_viewport().get_visible_rect().size
	# Iterate in touch-index order so results never depend on dictionary ordering.
	var keys := fingers.keys()
	keys.sort()
	for k in keys:
		var f: Finger = fingers[k]
		f.sample(tuning.finger_velocity_ticks, dt)
		if f.role == Finger.Role.NONE:
			_assign_role(f, board_xf, space, size)
		match f.role:
			Finger.Role.BACK_FOOT, Finger.Role.FRONT_FOOT:
				_update_foot(f, board_xf, size, dt)
			Finger.Role.PUSH:
				_update_pusher(f, size, dt)


## Decide once, where the touch landed: back half → back foot, front half → front foot,
## ground near the board → push finger.
func _assign_role(f: Finger, board_xf: Transform3D, space: PhysicsDirectSpaceState3D, size: Vector2) -> void:
	var r := ScreenMath.ray(camera, size, f.screen_pos)
	var q := PhysicsRayQueryParameters3D.create(r[0], r[0] + r[1] * 100.0)
	var hit := space.intersect_ray(q)
	var local_z = null
	if not hit.is_empty() and hit.collider == board:
		local_z = (board_xf.affine_inverse() * hit.position).z
	else:
		# The board is thin and often seen edge-on, so also accept touches that land on the
		# deck plane within the catch margin.
		var lp = _deck_point(r, board_xf)
		if lp != null and _within_deck(lp):
			local_z = lp.z
	if local_z != null:
		var want := Finger.Role.BACK_FOOT if local_z > tuning.mm(tuning.foot_split_mm) else Finger.Role.FRONT_FOOT
		f.role = Finger.Role.IGNORED if _role_taken(want) else want
		return
	var ground_hit = ScreenMath.ray_plane(r, Vector3.ZERO, Vector3.UP)
	if ground_hit != null:
		var flat: Vector3 = ground_hit - board_xf.origin
		flat.y = 0.0
		if flat.length() <= tuning.mm(tuning.push_reach_mm):
			f.role = Finger.Role.PUSH
			return
	f.role = Finger.Role.IGNORED


func _role_taken(role: Finger.Role) -> bool:
	for f: Finger in fingers.values():
		if f.role == role:
			return true
	return false


## Measure a foot: contact point on the grip tape, its velocity over the deck, press speed.
func _update_foot(f: Finger, board_xf: Transform3D, size: Vector2, dt: float) -> void:
	var lp = _deck_point(ScreenMath.ray(camera, size, f.screen_pos), board_xf)
	if lp == null:
		f.on_board = false
		return
	f.on_board = _within_deck(lp)
	var raw: Vector3 = lp
	# Clamp onto the deck and lift onto the grip surface (which rises along the kicks).
	lp.x = clampf(lp.x, -geo.half_width, geo.half_width)
	lp.z = clampf(lp.z, -geo.half_length, geo.half_length)
	lp.y = geo.surface_y(lp.z)
	f.local_pos = lp

	# Velocity over the deck: where the finger is now vs. where it was at the start of the
	# window, BOTH measured against the board's current pose. This is the finger's own motion
	# relative to the deck — a finger held still reads zero even while the board flies.
	var lp0 = _deck_point(ScreenMath.ray(camera, size, f.window_start()), board_xf)
	var wt := f.window_time(dt)
	if lp0 != null and wt > 0.0:
		f.local_vel = Vector3(raw.x - lp0.x, 0.0, raw.z - lp0.z) / wt
	else:
		f.local_vel = Vector3.ZERO

	# Press speed: finger speed on screen toward the board end nearest to it, in screen
	# heights per second (resolution independent). For the back foot that end is the tail
	# (a flick down the screen); for the front foot it's the nose (a drag up toward the nose).
	var end := geo.tail_tip() if lp.z > 0.0 else geo.nose_tip()
	var p_c = ScreenMath.project(camera, size, board_xf.origin)
	var p_e = ScreenMath.project(camera, size, board_xf * end)
	var dir := Vector2.DOWN if lp.z > 0.0 else Vector2.UP
	if p_c != null and p_e != null and p_c.distance_to(p_e) > 2.0:
		dir = (p_e - p_c).normalized()
	f.press_speed = f.screen_vel.dot(dir) / size.y


## Measure a push finger: its velocity across the ground plane (units/s).
func _update_pusher(f: Finger, size: Vector2, dt: float) -> void:
	var a = ScreenMath.ray_plane(ScreenMath.ray(camera, size, f.window_start()), Vector3.ZERO, Vector3.UP)
	var b = ScreenMath.ray_plane(ScreenMath.ray(camera, size, f.screen_pos), Vector3.ZERO, Vector3.UP)
	var wt := f.window_time(dt)
	f.ground_vel = (b - a) / wt if a != null and b != null and wt > 0.0 else Vector3.ZERO


## Where a screen ray meets the plane of the flat deck (top surface), in board local space.
func _deck_point(r: Array, board_xf: Transform3D) -> Variant:
	var up := board_xf.basis.y
	var hit = ScreenMath.ray_plane(r, board_xf * Vector3(0.0, geo.deck_top(), 0.0), up)
	return null if hit == null else board_xf.affine_inverse() * hit


func _within_deck(lp: Vector3) -> bool:
	return absf(lp.x) <= geo.half_width + tuning.mm(tuning.foot_catch_margin_mm) \
			and absf(lp.z) <= geo.half_length + tuning.mm(tuning.foot_end_margin_mm)
