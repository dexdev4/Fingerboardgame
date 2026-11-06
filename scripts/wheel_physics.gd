## Wheel behaviour for wheels touching the ground. The board's collision is frictionless, so
## these forces are the ONLY grip the wheels have:
##   - Sideways grip: a rolling wheel resists sliding along its axle. We remove a fraction of
##     the sideways velocity each second:  F_lat = −m_share · lateral_grip · v_lat
##     (m_share = board mass ÷ wheels down). Stable while lateral_grip < physics ticks/s.
##   - Rolling resistance: constant deceleration along the rolling direction,
##     F_roll = −sign(v_roll) · m_share · rolling_resistance, never strong enough to reverse.
## Forces act at the contact patch (below the centre of mass), so hard sideways grip also
## produces a little roll torque, like a real board.
##   - Bushing damping (3+ wheels down): trucks' rubber bushings and the wheels' urethane
##     absorb landings. Spin about the deck's long/cross axes (pitch, roll) is damped with
##     torque τ = −c · I·ω⊥ (ω⊥ = ω minus its yaw part; I·ω⊥ = angular momentum, so this removes
##     a fraction c of that spin per second), and rebound along the deck's up axis with
##     F = −m · c · v_up (only while moving away from the ground: bushings don't pull down).
##     Needs 3+ wheels so it never fights an ollie, which pivots on the 2 rear wheels.
class_name WheelPhysics
extends RefCounted


##   - Steering: `lean` (−1 … 1, + = leaning right) turns the trucks. A skateboard's trucks turn
##     into the lean, the front and rear in opposite directions, so the board carves:
##         steer δ = lean · max_steer · sensitivity
##         front wheels roll toward  nose + right·tan δ,   rear wheels toward  nose − right·tan δ
##     The sideways grip above then works along each wheel's new axle, which turns the board.
##
## `wheel_contacts`: offsets (global orientation, from body origin) of grounded wheel contacts.
static func apply(state: PhysicsDirectBodyState3D, wheel_contacts: Array[Vector3], t: BoardTuning,
		lean: float = 0.0) -> void:
	if wheel_contacts.is_empty():
		return
	var basis := state.transform.basis
	var to_local := basis.inverse()
	var tan_steer := tan(deg_to_rad(t.max_steer_deg * t.steer_sensitivity) * clampf(lean, -1.0, 1.0))
	var m_share := t.mass_kg() / wheel_contacts.size()
	var dt := state.step
	# Only the yaw part of the spin moves a wheel across the ground. On a real board the deck
	# rocks (pitch/roll) on the trucks' bushings while the wheels stay planted, so that rocking
	# must not count as the wheel skidding — otherwise a one-wheel-first landing kicks the
	# board sideways.
	var up := basis.y
	var w_yaw := up * state.angular_velocity.dot(up)
	for r in wheel_contacts:
		# This wheel's truck: front (−Z, nose side) or rear. They steer opposite ways.
		var front := (to_local * r).z < 0.0
		var roll_dir := (-basis.z + basis.x * (tan_steer if front else -tan_steer)).normalized()
		var axle_dir := roll_dir.cross(basis.y)          # sideways for this wheel
		# Ground velocity of the wheel: v = v_cm + ω_yaw × (r − r_cm).
		var v := state.linear_velocity + w_yaw.cross(r - state.center_of_mass)
		var v_lat := v.dot(axle_dir)
		state.apply_force(-axle_dir * v_lat * t.wheel_lateral_grip * m_share, r)

		var v_roll := v.dot(roll_dir)
		# Largest force that would just stop this wheel's share this tick: m·v/dt.
		var stop := absf(v_roll) * m_share / dt
		var f_roll := minf(t.rolling_resistance * m_share, stop)
		state.apply_force(-roll_dir * signf(v_roll) * f_roll, r)

	if wheel_contacts.size() >= 3 and t.bushing_damping > 0.0:
		var w := state.angular_velocity
		var w_perp := w - up * w.dot(up)
		var inertia_world := state.inverse_inertia_tensor.inverse()
		state.apply_torque(-(inertia_world * w_perp) * t.bushing_damping)
		var v_up := state.linear_velocity.dot(up)
		if v_up > 0.0:
			state.apply_central_force(-up * v_up * t.mass_kg() * t.bushing_damping)
