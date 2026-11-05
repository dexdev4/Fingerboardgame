## Pushing: a finger swiped backward across the ground beside the board, like a skater's push.
##
## The camera follows the board, so a push finger's measured ground velocity is relative to
## the board. A real pushing foot only drives the board while it moves backward faster than
## the board moves forward (otherwise it just drags along the ground). So:
##     s      = backward swipe speed (units/s) × push_speed_scale
##     v_fwd  = board speed toward its nose
##     F      = m · push_gain · max(s − v_fwd, 0),   capped at m · push_max_accel
## Consequence: you can never push faster than you swipe — swipe faster to go faster.
## Only works with at least two wheels on the ground (you can't push in the air).
class_name PushPhysics
extends RefCounted


static func apply(state: PhysicsDirectBodyState3D, pushers: Array[Finger], wheels_down: int, t: BoardTuning) -> void:
	for f in pushers:
		f.press_force = 0.0
	if wheels_down < 2:
		return
	var fwd := -state.transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.1:
		return
	fwd = fwd.normalized()
	var v_fwd := state.linear_velocity.dot(fwd)
	for f in pushers:
		var s := -f.ground_vel.dot(fwd) * t.push_speed_scale
		var force := t.mass_kg() * minf(t.push_gain * maxf(s - v_fwd, 0.0), t.push_max_accel)
		# Applied through the centre of mass so a push never tips the board.
		state.apply_force(fwd * force, state.center_of_mass)
		f.press_force = force
