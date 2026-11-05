## Converts one finger ("foot") into forces on the board, applied at the finger's contact point.
##
## A real foot doesn't "apply N newtons": it MOVES the part of the deck under it. So each foot
## drives its contact point toward a target speed, using just enough force (capped):
##
##   1. PRESS (along board −Y, into the deck)
##      press_speed = finger speed on screen toward the board end nearest it (screen heights/s).
##                    Back foot: flick DOWN the screen onto the tail. Front foot: drag UP toward
##                    the nose. (Kicks rise toward the tips, so a foot driven toward a tip runs
##                    into the kick and pushes it down.)
##      v_target    = press_speed_gain · max(press_speed − deadzone, 0) · zone       (units/s)
##      zone        = 0 → 1 from press_zone_start to the kick bend: a foot only converts sliding
##                    into pressing where the deck rises under it. In the middle it just slides.
##      v_point     = how fast that deck point is already moving down
##      F_drive     = m_eff · (v_target − v_point) / press_response_time + F_hold, clamped ≥ 0
##      F_press     = W·rest_weight (only while grounded) + min(F_drive, W·press_max_weights)
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
##      v_slip = finger velocity over the deck. You can only drag the board as hard as you press.
##
## Forces act at the contact point, not the centre: pressing the tail behind the rear axle
## rotates the board nose-up around the rear wheels until the tail hits the ground — the pop.
## No ollie code exists anywhere: lift the finger (or stop moving it) and these forces stop.
class_name FootPhysics
extends RefCounted


static func apply(state: PhysicsDirectBodyState3D, f: Finger, g: BoardGeometry,
		t: BoardTuning, grounded: bool) -> void:
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
	var f_n := weight * t.foot_rest_weight if grounded else 0.0
	var zone := clampf((absf(f.local_pos.z) - t.mm(t.press_zone_start_mm))
			/ maxf(g.flat_half - t.mm(t.press_zone_start_mm), 1e-4), 0.0, 1.0)
	var v_target := t.press_speed_gain * maxf(f.press_speed - t.press_deadzone, 0.0) * zone
	if v_target > 0.0:
		var drive: float
		if grounded and absf(f.local_pos.z) > g.axle_z:
			drive = _drive_about_axle(state, f, g, t, v_target)
		else:
			drive = _drive_free(state, offset, up, v_target, t)
		f_n += clampf(drive, 0.0, weight * t.press_max_weights)
	state.apply_force(-up * f_n, offset)

	# 2. Drag (grip friction), in the plane of the deck.
	var slip := basis * Vector3(f.local_vel.x, 0.0, f.local_vel.z)
	var drag := (slip * t.mass_kg() * t.grip_rate).limit_length(t.grip_mu * f_n)
	state.apply_force(drag, offset)

	f.press_force = f_n
	f.drag_force = drag.length()


## Board free to turn about its centre of mass (airborne, or foot between the axles).
static func _drive_free(state: PhysicsDirectBodyState3D, offset: Vector3, up: Vector3,
		v_target: float, t: BoardTuning) -> float:
	var r := offset - state.center_of_mass
	var v_point := -state.angular_velocity.cross(r).dot(up)
	var rot_term := (state.inverse_inertia_tensor * r.cross(up)).cross(r).dot(up)
	var m_eff := 1.0 / maxf(rot_term, 1e-6)
	return m_eff * (v_target - v_point) / t.press_response_time


## Board on its wheels, foot outside the wheelbase: it tips about the nearest axle.
## Worked in board-local 2D (z along the board, y up) — the tipping is a pitch rotation.
static func _drive_about_axle(state: PhysicsDirectBodyState3D, f: Finger, g: BoardGeometry,
		t: BoardTuning, v_target: float) -> float:
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
	return m_eff * (v_target - v_point) / t.press_response_time + hold
