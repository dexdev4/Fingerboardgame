## Wheel behaviour for wheels touching the ground. The board's collision is frictionless, so
## these forces are the ONLY grip the wheels have:
##   - Sideways grip: a rolling wheel resists sliding along its axle. We remove a fraction of
##     the sideways velocity each second:  F_lat = −m_share · lateral_grip · v_lat
##     (m_share = board mass ÷ wheels down). Stable while lateral_grip < physics ticks/s.
##   - Rolling resistance: constant deceleration along the rolling direction,
##     F_roll = −sign(v_roll) · m_share · rolling_resistance, never strong enough to reverse.
## Forces act at the contact patch (below the centre of mass), so hard sideways grip also
## produces a little roll torque, like a real board.
class_name WheelPhysics
extends RefCounted


## `wheel_contacts`: offsets (global orientation, from body origin) of grounded wheel contacts.
static func apply(state: PhysicsDirectBodyState3D, wheel_contacts: Array[Vector3], t: BoardTuning) -> void:
	if wheel_contacts.is_empty():
		return
	var basis := state.transform.basis
	var axle_dir := basis.x                 # sideways (along the axles)
	var roll_dir := -basis.z                # toward the nose
	var m_share := t.mass_kg() / wheel_contacts.size()
	var dt := state.step
	for r in wheel_contacts:
		# Velocity of the board material at the contact: v = v_cm + ω × (r − r_cm).
		var v := state.linear_velocity + state.angular_velocity.cross(r - state.center_of_mass)
		var v_lat := v.dot(axle_dir)
		state.apply_force(-axle_dir * v_lat * t.wheel_lateral_grip * m_share, r)

		var v_roll := v.dot(roll_dir)
		# Largest force that would just stop this wheel's share this tick: m·v/dt.
		var stop := absf(v_roll) * m_share / dt
		var f_roll := minf(t.rolling_resistance * m_share, stop)
		state.apply_force(-roll_dir * signf(v_roll) * f_roll, r)
