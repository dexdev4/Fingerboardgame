## The fingerboard: one RigidBody3D. Every physics tick it asks FingerInput what the fingers
## are doing, then applies forces from feet, push fingers and wheels. That's all — every
## trick must come out of these forces plus the physics engine's collisions.
class_name Board
extends RigidBody3D

## A kick (tail or nose) struck the ground. strength = closing speed (units/s).
signal popped(strength: float)
## Wheels touched down after being airborne. speed = downward speed at impact (units/s).
signal landed(speed: float)
## The board was put back at the start.
signal reset_done

var tuning: BoardTuning
var geo: BoardGeometry
var input: FingerInput
var parts := {}             # physics shape index → "deck" | "tail" | "nose" | "wheel"
var spawn_xf: Transform3D

# Read by the debug overlay.
var wheels_down := 0

var _reset_requested := false
var _prev_lin := Vector3.ZERO
var _prev_ang := Vector3.ZERO
var _kicks_touching := {}   # part name → bool, last tick
var _air_time := 0.0


func setup(t: BoardTuning, finger_input: FingerInput) -> void:
	tuning = t
	input = finger_input
	geo = BoardGeometry.new(t)
	parts = BoardBuilder.build_collision(self, geo)
	BoardBuilder.build_visuals(self, geo)

	mass = t.mass_kg()
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, -t.mm(t.com_drop_mm), 0.0)
	inertia = _box_inertia()
	# Frictionless and dead: wheel grip comes from WheelPhysics, tail bounce from _pop().
	var mat := PhysicsMaterial.new()
	mat.friction = 0.0
	mat.bounce = 0.0
	physics_material_override = mat
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = t.linear_damp
	angular_damp = t.angular_damp
	can_sleep = false            # a sleeping body would ignore fingers
	continuous_cd = true         # a snapped tail moves fast; don't let it tunnel the ground
	contact_monitor = true
	max_contacts_reported = 16
	spawn_xf = Transform3D(Basis.IDENTITY, Vector3(0.0, geo.rest_height + 0.002, 0.0))
	global_transform = spawn_xf


## Solid-box inertia, m/12·(a² + b²) about each axis, using the deck's length and width and
## an effective height (trucks + wheels hang below the deck).
##   X (pitch, nose up/down):  m/12·(H² + L²)
##   Y (yaw, turning):         m/12·(W² + L²)
##   Z (roll, along the deck): m/12·(W² + H²)
func _box_inertia() -> Vector3:
	var m := tuning.mass_kg()
	var l := geo.half_length * 2.0
	var w := geo.half_width * 2.0
	var h := tuning.mm(tuning.inertia_height_mm)
	return Vector3(h * h + l * l, w * w + l * l, w * w + h * h) * (m / 12.0)


func request_reset() -> void:
	_reset_requested = true


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _reset_requested:
		_do_reset(state)
		return
	var dt := state.step

	# --- Read contacts: which wheels are down, which kicks are touching the ground. ---
	var wheel_contacts: Array[Vector3] = []
	var seen_wheels := {}
	var kick_hits := {}
	for i in state.get_contact_count():
		var shape := state.get_contact_local_shape(i)
		var part: String = parts.get(shape, "deck")
		# Contact position is global; convert to an offset from the body origin.
		var r := state.get_contact_local_position(i) - state.transform.origin
		if part == "wheel" and not seen_wheels.has(shape):
			seen_wheels[shape] = true
			wheel_contacts.append(r)
		elif part == "tail" or part == "nose":
			# A kick usually touches at several corner points; accumulate them so the bounce is
			# applied at their average (one corner alone would twist the board).
			var n := state.get_contact_local_normal(i)
			var hit: Array = kick_hits.get(part, [Vector3.ZERO, Vector3.ZERO, 0])
			kick_hits[part] = [hit[0] + r, hit[1] + (n if n.y >= 0.0 else -n), hit[2] + 1]
	wheels_down = wheel_contacts.size()

	# --- Forces. ---
	input.physics_update(state.transform, state.get_space_state(), dt)
	for f in input.feet():
		FootPhysics.apply(state, f, geo, tuning, wheels_down > 0)
	PushPhysics.apply(state, input.pushers(), wheels_down, tuning)
	WheelPhysics.apply(state, wheel_contacts, tuning)

	# --- Events. ---
	for part in ["tail", "nose"]:
		var touching := kick_hits.has(part)
		if touching and not _kicks_touching.get(part, false):
			var hit: Array = kick_hits[part]
			_pop(state, hit[0] / hit[2], (hit[1] as Vector3).normalized())
		_kicks_touching[part] = touching
	_track_landing(dt)

	_prev_lin = state.linear_velocity
	_prev_ang = state.angular_velocity


## A kick just hit the ground. The engine's contact is perfectly dead (it already zeroed the
## closing speed), so we add the bounce: an impulse that gives the contact point an outgoing
## speed of e·v_in along the normal (e = tail_restitution).
## Impulse needed for a velocity change Δv at offset r' (from the centre of mass) along n:
##     J = Δv · m_eff,    m_eff = 1 / ( 1/m + n · ((I⁻¹ (r' × n)) × r') )
## m_eff is the "effective mass" felt at that point — lower than m because the board can also
## rotate. Velocities from the previous tick are used because that's the pre-impact motion.
func _pop(state: PhysicsDirectBodyState3D, r: Vector3, n: Vector3) -> void:
	var rc := r - state.center_of_mass
	var v_in := -(_prev_lin + _prev_ang.cross(rc)).dot(n)   # closing speed, positive = into ground
	if v_in < tuning.pop_min_speed:
		return
	var ang_term := (state.inverse_inertia_tensor * rc.cross(n)).cross(rc).dot(n)
	var m_eff := 1.0 / (state.inverse_mass + ang_term)
	state.apply_impulse(n * tuning.tail_restitution * v_in * m_eff, r)
	popped.emit(v_in)


## Detects touchdown after being airborne (for haptics / overlay only, no forces).
func _track_landing(dt: float) -> void:
	if wheels_down == 0 and _kicks_touching.values().count(true) == 0:
		_air_time += dt
		return
	if wheels_down > 0 and _air_time >= tuning.landing_min_air_time:
		landed.emit(maxf(-_prev_lin.y, 0.0))
	_air_time = 0.0


func _do_reset(state: PhysicsDirectBodyState3D) -> void:
	_reset_requested = false
	state.transform = spawn_xf
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO
	_prev_lin = Vector3.ZERO
	_prev_ang = Vector3.ZERO
	_kicks_touching.clear()
	_air_time = 0.0
	input.clear()
	reset_done.emit()


# ---- Read-outs for the debug overlay (world units → real units) -------------------------

func speed_cm_s() -> float:
	return linear_velocity.length() / tuning.world_scale * 100.0


## Height of the board above its resting height, in real mm.
func height_mm() -> float:
	return (global_position.y - geo.rest_height) / tuning.world_scale * 1000.0


## [pitch (nose up +), roll (right side down +), yaw] in degrees.
func angles_deg() -> Vector3:
	var b := global_transform.basis
	var nose := -b.z
	return Vector3(rad_to_deg(asin(clampf(nose.y, -1, 1))),
			rad_to_deg(asin(clampf(-b.x.y, -1, 1))),
			rad_to_deg(atan2(-nose.x, -nose.z)))
