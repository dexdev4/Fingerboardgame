## Converts one finger ("foot") into forces on the board, applied at the finger's contact point.
##
## A real foot doesn't "apply N newtons": it MOVES the part of the deck under it. So each foot
## drives its contact point toward a target speed, using just enough force (capped):
##
##   1. PRESS (along board −Y, into the deck)
##      press_speed = finger speed on screen toward the board end nearest it (screen units/s; 1 unit = the screen's short side).
##                    Back foot: flick DOWN the screen onto the tail. Front foot: drag UP toward
##                    the nose. (Kicks rise toward the tips, so a foot driven toward a tip runs
##                    into the kick and pushes it down.)
##      v_target    = min(gain · end_push, foot_max_speed) + min(gain · side_push, side_max_speed)
##                    (units/s; the caps keep reactions smooth however hard you flick)
##      end_push    = max(press_speed − deadzone, 0) · zone
##      zone        = 0 → 1 from press_zone_start to the kick bend: a foot only converts sliding
##                    into pressing where the deck rises under it. In the middle it just slides.
##      side_push   = max(press_speed_side − deadzone, 0) · zone_side · press_side_gain
##      zone_side   = 0 → 1 from press_side_zone_start to the rail: the concave rises toward the
##                    rails, so a finger driven off the side presses that edge. Pressing an edge
##                    off the centre line makes roll torque — in the air that flips the board;
##                    on the ground the wheels hold it, like a real board.
##      v_point     = how fast that deck point is already moving down
##      F_drive     = m_eff · (v_target − v_point) / τ + F_hold, clamped ≥ 0
##                    τ = press_response_time for end presses (smooth), press_side_response_time
##                    for side flicks (quick: they only touch the rail briefly), blended by share
##      F_press     = W·rest_weight (only while supported) + min(F_drive, W·press_max_weights)
##      A resting finger has weight on a board standing on its wheels. In the air a still finger
##      rises with the board (like a skater lifting their feet) — it must not keep pushing, or
##      a finger resting on the tail would keep spinning the 14 g board.
##      Once the point moves as fast as the finger, F_drive drops to ~0: the foot never
##      over-drives the board. A front foot sliding toward the nose while the nose swings up
##      meets it head-on, stops the rotation and levels the board, then stops pushing.
##
##      m_eff (the "effective mass" felt at the foot) depends on what the board can do:
##      • In the air, or foot between the axles: the board turns about its centre of mass.
##        m_eff = 1 / (n · ((I⁻¹ (r × n)) × r)),  r = lever arm from the centre of mass.
##        Only the rotational part of the point's motion counts (ω × r): a foot works by
##        tipping the board, so it must not fight the whole board rising.
##      • On the ground with the foot past an axle (on a kick): the board tips about that axle.
##        Parallel-axis theorem: I_axle = I_x + m·d²  (d = centre of mass ↔ axle distance)
##        m_eff = I_axle / L²   (L = foot ↔ axle lever),  F_hold = W·d_z / L
##        F_hold is the force that just balances the board's weight about the axle — the foot
##        has to lift the rest of the board before the tail can go down.
##
##   2. DRAG (grip-tape friction, along the deck surface)
##      F_t = m · grip_rate · v_slip,  limited to |F_t| ≤ grip_mu · F_press   (Coulomb friction)
##      v_slip = finger velocity over the deck, capped at foot_max_speed (a fast flick can't
##      whip the grip tape harder than a deliberate one). You can only drag as hard as you press.
##
## Forces act at the contact point, not the centre: pressing the tail behind the rear axle
## rotates the board nose-up around the rear wheels until the tail hits the ground — the pop.
## No ollie code exists anywhere: lift the finger (or stop moving it) and these forces stop.
class_name FootPhysics
extends RefCounted


## `grounded`: wheels on the ground (the board can tip about an axle).
## `supported`: the board is resting on something — wheels, or trucks/deck on a rail or ledge —
## so a resting finger has weight on it (it doesn't in mid-air).
## `end_down`: the kick at this foot's end (tail for the back foot) is touching the ground.
## `popped_end`: which kick popped last (+1 tail, −1 nose, 0 none) — the one a foot can scoop.
static func apply(state: PhysicsDirectBodyState3D, f: Finger, g: BoardGeometry,
		t: BoardTuning, grounded: bool, supported: bool, end_down: bool, popped_end: float = 0.0) -> void:
	f.press_force = 0.0
	f.drag_force = 0.0
	if not f.on_board:
		return
	var basis := state.transform.basis
	var up := basis.y
	var weight := t.board_weight()
	# apply_force wants the point as an offset from the body origin, in global orientation.
	var offset := basis * f.local_pos

	# 1. Press.
	var f_n := weight * t.foot_rest_weight if supported else 0.0
	var zone := clampf((absf(f.local_pos.z) - t.mm(t.press_zone_start_mm))
			/ maxf(g.flat_half - t.mm(t.press_zone_start_mm), 1e-4), 0.0, 1.0)
	var side_start := t.mm(t.press_side_zone_start_mm)
	var zone_side := clampf((absf(f.local_pos.x) - side_start) / maxf(g.half_width - side_start, 1e-4), 0.0, 1.0)
	# Once the kick under this foot is on the ground it can't go any lower: the extra press goes
	# straight into the ground. Without this a foot still "following through" pins the tail
	# down and levers the board up onto its tail instead of letting it pop off.
	var push_end := 0.0 if end_down else maxf(f.press_speed - t.press_deadzone, 0.0) * zone
	var push_side := maxf(f.press_speed_side - t.press_side_deadzone, 0.0) * zone_side * t.press_side_gain
	# Predictable flips: once the board is already rolling toward this rail at press_side_max_roll,
	# the flick adds no more. However hard you flick, the roll tops out at the same rate, so a
	# kickflip is about one rotation in a normal hang time instead of "harder = more spins".
	# (Right rail (x > 0) going down = negative spin about the board's long +Z axis.)
	var roll_toward := -state.angular_velocity.dot(basis.z) * signf(f.local_pos.x)
	if roll_toward >= t.press_side_max_roll:
		push_side = 0.0
	# A finger that caught the board in the air is catching/adjusting it (CatchPhysics), not
	# flicking: dragging it sideways turns the board under it instead of flipping it.
	if f.caught_in_air:
		push_side = 0.0
	# A side press also needs the finger to really cross the deck toward that rail (board space,
	# units/s). On screen alone, a finger sliding straight toward the nose can pick up a small
	# sideways component from the camera angle, and a little roll makes that worse — a feedback
	# loop that rolled straight ollies.
	if f.local_vel.x * signf(f.local_pos.x) < t.press_side_min_cross_speed:
		push_side = 0.0
	# Each direction has its own speed cap: end presses stay slow and smooth (foot_max_speed),
	# side presses may go faster (press_side_max_speed) so a flip can come round in the air.
	var v_end := minf(t.press_speed_gain * push_end, t.foot_max_speed)
	var v_side := minf(t.press_speed_gain * push_side, t.press_side_max_speed)
	var v_target := v_end + v_side
	# Response time blends from the smooth end-press value to the quick side-press value by how
	# much of the target comes from the side flick.
	var tau := lerpf(t.press_response_time, t.press_side_response_time, v_side / maxf(v_target, 1e-6))
	if v_target > 0.0:
		var drive: float
		if grounded and absf(f.local_pos.z) > g.axle_z:
			drive = _drive_about_axle(state, f, g, t, v_target, tau)
		else:
			drive = _drive_free(state, offset, up, v_target, tau)
		f_n += clampf(drive, 0.0, weight * t.press_max_weights)
	state.apply_force(-up * f_n, offset)

	# 2. Drag (grip friction), in the plane of the deck.
	var slip := basis * Vector3(f.local_vel.x, 0.0, f.local_vel.z).limit_length(t.foot_max_speed)
	var drag := (slip * t.mass_kg() * t.grip_rate).limit_length(t.grip_mu * f_n)
	state.apply_force(drag, offset)

	f.press_force = f_n
	f.drag_force = drag.length()

	# 3. Scoop (shove-it spin) — wheels off the ground, not a catching finger, and only on the
	# kick that just POPPED (the tail for an ollie / 360 flip, the nose for nollie tricks): the
	# foot that snapped that kick is the one that scoops it. A front foot flicking off the nose
	# for a kickflip therefore doesn't add a shove-it.
	if not grounded and not f.caught_in_air and zone > 0.0 and signf(f.local_pos.z) == popped_end:
		_scoop_spin(state, f, t)


## Board free to turn about its centre of mass (airborne, or foot between the axles).
static func _drive_free(state: PhysicsDirectBodyState3D, offset: Vector3, up: Vector3,
		v_target: float, tau: float) -> float:
	var r := offset - state.center_of_mass
	var v_point := -state.angular_velocity.cross(r).dot(up)
	var rot_term := (state.inverse_inertia_tensor * r.cross(up)).cross(r).dot(up)
	var m_eff := 1.0 / maxf(rot_term, 1e-6)
	return m_eff * (v_target - v_point) / tau


## Board on its wheels, foot outside the wheelbase: it tips about the nearest axle.
## Worked in board-local 2D (z along the board, y up) — the tipping is a pitch rotation.
static func _drive_about_axle(state: PhysicsDirectBodyState3D, f: Finger, g: BoardGeometry,
		t: BoardTuning, v_target: float, tau: float) -> float:
	var side := signf(f.local_pos.z)                         # +1 tail, −1 nose
	var axle := Vector2(side * g.axle_z, g.wheel_y)          # (z, y) of the axle
	var com := Vector2(0.0, -t.mm(t.com_drop_mm))
	var lever := absf(f.local_pos.z - axle.x)                # foot ↔ axle, along the board
	var d := com - axle
	var i_axle := state.inverse_inertia.x                    # principal inverse inertia (pitch)
	i_axle = (1.0 / maxf(i_axle, 1e-9)) + t.mass_kg() * d.length_squared()
	var m_eff := i_axle / (lever * lever)
	var hold := t.board_weight() * absf(d.x) / lever
	# Downward speed of the deck point from tipping about the axle: ω × (lever from the axle).
	# Not the board's full velocity — once the board tilts, plain forward rolling has a
	# component along the tilted deck normal and would read as "the tail is already going
	# down", making the foot let go early (fast rolling would kill the pop).
	var basis := state.transform.basis
	var lever_arm := basis * (f.local_pos - Vector3(0.0, axle.y, axle.x))
	var v_point := -state.angular_velocity.cross(lever_arm).dot(basis.y)
	return m_eff * (v_target - v_point) / tau + hold


## A foot sweeping SIDEWAYS along a kick scoops it: the kick rises, so instead of slipping the foot
## catches on it and pushes that end of the board round — a shove-it spin about the vertical.
##   target spin  ω* = clamp(press_scoop_gain · v_side / |z|,  ±press_scoop_max_spin)   (rad/s)
##     (v_side = the foot's sideways speed over the deck, z = how far along the board it is:
##      the spin that moves that end of the board sideways at the foot's speed, × gain)
##   torque       τ  = I_spin · (ω* − ω_spin) / press_side_response_time   about the vertical
## Like flips, the spin tops out at press_scoop_max_spin however hard you scoop, so a 360 shove
## (or the shove in a 360 flip) comes round about once in a normal pop — predictable.
static func _scoop_spin(state: PhysicsDirectBodyState3D, f: Finger, t: BoardTuning) -> void:
	var v_side := f.local_vel.x
	if absf(v_side) < t.press_scoop_min_speed:
		return
	# Spin about the VERTICAL: the foot pushes the kick sideways across the ground. (About the
	# deck's own up axis it would tumble the board whenever it's pitched up steeply.)
	var axis := Vector3.UP
	# Foot at +z (tail) moving +x swings the tail right: spin about +Y is negative there
	# (ω × r: (0, ω, 0) × (0, 0, z) = (ω·z, 0, 0), so ω = v_side / z).
	var w_target := clampf(t.press_scoop_gain * v_side / maxf(absf(f.local_pos.z), 0.05) * signf(f.local_pos.z),
			-t.press_scoop_max_spin, t.press_scoop_max_spin)
	var w_now := state.angular_velocity.dot(axis)
	if (w_target - w_now) * w_target <= 0.0:
		return                                   # already spinning at least that fast that way
	var i_spin := 1.0 / maxf((state.inverse_inertia_tensor * axis).dot(axis), 1e-9)
	state.apply_torque(axis * i_spin * (w_target - w_now) / t.press_side_response_time)
