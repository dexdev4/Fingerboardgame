## Catching and adjusting the board in the air.
##
## A finger that lands on the board WHILE THE BOARD IS AIRBORNE is a catch (a foot coming back
## down onto the deck). Catch fingers act through torques (they turn the board, they don't push
## it around), shared between the catching fingers:
##
##   1. Hold / adjust. The finger has a velocity over the deck (board space, from FingerInput).
##      The board rotation that moves the finger's point at that velocity is
##          ω_target = (r × v_finger) / |r|²         (r = lever from the centre of mass)
##      and the catch drives the board's spin toward it:
##          τ = I · (ω_target − ω) / catch_hold_time
##      A still finger → ω_target = 0 → the spin stops (the catch). A dragging finger rotates the
##      board under it — adjust a late flip, square up a shove-it, straighten before landing.
##   2. Level. A foot is flat, so it presses the deck parallel to the ground. Error axis =
##      deck_up × world_up (its length = sin of the tilt); we drive the board to rotate about it
##      as a critically damped spring with time constant catch_level_time:
##          α = axis · (1/T²)  →  τ = I · α        (damping comes from term 1)
##      Only while the grip faces up enough (catch_min_up) — you can't catch a board by its bottom.
##
## Applies only while the board is airborne. Once it lands the finger is a normal foot again.
## No trick logic: it's what a foot touching a spinning board does.
class_name CatchPhysics
extends RefCounted


static func apply(state: PhysicsDirectBodyState3D, catchers: Array[Finger], t: BoardTuning) -> void:
	if catchers.is_empty():
		return
	var basis := state.transform.basis
	var inertia := state.inverse_inertia_tensor.inverse()     # world-space inertia tensor
	var share := 1.0 / catchers.size()
	var torque := Vector3.ZERO
	for f in catchers:
		var r := basis * f.local_pos - state.center_of_mass
		var v_finger := basis * Vector3(f.local_vel.x, 0.0, f.local_vel.z).limit_length(t.foot_max_speed)
		var w_target := r.cross(v_finger) / maxf(r.length_squared(), 1e-4)
		torque += inertia * (w_target - state.angular_velocity) * (share / t.catch_hold_time)
	var up := basis.y
	if up.dot(Vector3.UP) > t.catch_min_up:
		var axis := up.cross(Vector3.UP)
		torque += inertia * axis / (t.catch_level_time * t.catch_level_time)
	state.apply_torque(torque)
