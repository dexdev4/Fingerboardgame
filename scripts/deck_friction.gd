## Friction for the deck itself (grip tape, edges) touching the ground — e.g. after landing
## upside down or on its side. The board's collision material is frictionless (so wheels can be
## modelled separately), so without this a bailed board would slide and spin like on ice.
##
## Which contacts get friction: those where the board's TOP or SIDE faces the ground, judged by
## the contact normal n (pointing from the ground into the board) against the deck's up axis:
##     n · up < side_threshold   →  grip / edge contact  →  friction
##     n · up ≥ side_threshold   →  underside contact (e.g. the tail striking during a pop) → none
## So ollies (tail underside on the ground) behave exactly as before.
##
## Coulomb friction per contact, with the normal force approximated by the board's weight shared
## between the touching contacts (the board is lying on them):
##     v_t   = sliding velocity of the board at the contact, along the ground (v − (v·n)n)
##     F     = −m_share · stick_rate · v_t,   limited to |F| ≤ μ · W_share
## The stick_rate term brings sliding to a stop within a few ticks (like static friction);
## the μ cap means a fast-moving board still skids a little before it grabs.
class_name DeckFriction
extends RefCounted

## Above this n·up the contact is on the underside (cos 70°: anything flatter is a side/top).
const SIDE_THRESHOLD := 0.34


## `contacts`: [offset from body origin (global orientation), normal] pairs for non-wheel contacts.
static func apply(state: PhysicsDirectBodyState3D, contacts: Array, t: BoardTuning) -> void:
	var up := state.transform.basis.y
	var touching: Array = []
	for c in contacts:
		if (c[1] as Vector3).dot(up) < SIDE_THRESHOLD:
			touching.append(c)
	if touching.is_empty():
		return
	var m_share := t.mass_kg() / touching.size()
	var max_force := t.deck_friction_mu * t.board_weight() / touching.size()
	for c in touching:
		var r: Vector3 = c[0]
		var n: Vector3 = c[1]
		var v := state.linear_velocity + state.angular_velocity.cross(r - state.center_of_mass)
		var v_t := v - n * v.dot(n)
		var f := (-v_t * m_share * t.deck_stick_rate).limit_length(max_force)
		state.apply_force(f, r)
