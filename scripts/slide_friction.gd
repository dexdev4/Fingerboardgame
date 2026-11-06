## Friction for grinds and slides: every contact that isn't a wheel (rolls: WheelPhysics) or the
## grip side (bails: DeckFriction) — i.e. the trucks' hangers and the deck's underside / kicks
## sliding on rails, ledges, boxes and the ground.
##
## Nothing here knows what a "grind" is. It's Coulomb friction between the touching materials:
##     μ = grind_mu (metal truck)  or  slide_mu (wood deck)   ×  the surface's slickness
##         (obstacle meta "slide_friction_scale": steel rail < painted ledge < concrete = 1)
##     N = the real normal force at the contact, from the physics engine's contact impulse:
##         N = |impulse · n| / dt     (n = contact normal; the impulse pushes into the board)
##     F = −μ·N along the sliding direction, but never more than the force that would stop that
##         contact's sliding this tick (m_share·|v_t|/dt) — friction can't reverse the slide.
## So a 50-50 on a slick rail carries speed a long way, a boardslide on a concrete ledge grinds
## to a halt quickly, and anything that isn't pressing on the obstacle (N = 0) gets no friction:
## a bad lock-in simply slides off.
class_name SlideFriction
extends RefCounted


## `contacts`: [offset, normal into board, impulse, part, surface scale] per non-wheel contact.
## Returns (truck contacts, deck contacts) — for the overlay/tests: grinding / sliding.
static func apply(state: PhysicsDirectBodyState3D, contacts: Array, g: BoardGeometry, t: BoardTuning) -> Vector2i:
	var to_local := state.transform.basis.inverse()
	var sliding: Array = []
	for c in contacts:
		if not DeckFriction.is_grip_side(to_local * (c[0] as Vector3), g):
			sliding.append(c)
	if sliding.is_empty():
		return Vector2i.ZERO
	var m_share := t.mass_kg() / sliding.size()
	var dt := state.step
	var trucks := 0
	for c in sliding:
		var r: Vector3 = c[0]
		var n: Vector3 = c[1]
		var part: String = c[3]
		if part == "truck":
			trucks += 1
		# The contact impulse always pushes INTO the board, so its size along the normal is the
		# pressing force whichever way the normal was reported (abs). Friction only needs the
		# normal's line, not its sign, to find the sliding direction.
		var normal_force := absf((c[2] as Vector3).dot(n)) / dt
		var mu := (t.grind_mu if part == "truck" else t.slide_mu) * float(c[4])
		var v := state.linear_velocity + state.angular_velocity.cross(r - state.center_of_mass)
		var v_t := v - n * v.dot(n)
		var speed := v_t.length()
		if speed < 1e-5:
			continue
		var f := minf(mu * normal_force, m_share * speed / dt)
		state.apply_force(-v_t / speed * f, r)
	return Vector2i(trucks, sliding.size() - trucks)
