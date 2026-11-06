## Friction for the deck itself (grip tape, edges) touching the ground — e.g. after landing
## upside down or on its side. The board's collision material is frictionless (so wheels can be
## modelled separately), so without this a bailed board would slide and spin like on ice.
##
## Which contacts get friction: those ON the grip-tape side or the edges, judged by where the
## contact point sits on the deck (board-local):
##     y above the deck's mid-plane at that z (grip side)   →  friction
##     |x| out at the rail (edge)                           →  friction
##     anything else (underside, e.g. the tail striking during a pop)  →  none
## A position test, not a normal-angle test: during a steep pop the tail's underside meets the
## ground at a shallow angle and must still slide freely.
##
## Coulomb friction per contact, with the normal force approximated by the board's weight shared
## between the touching contacts (the board is lying on them):
##     v_t   = sliding velocity of the board at the contact, along the ground (v − (v·n)n)
##     F     = −m_share · stick_rate · v_t,   limited to |F| ≤ μ · W_share
## The stick_rate term brings sliding to a stop within a few ticks (like static friction);
## the μ cap means a fast-moving board still skids a little before it grabs.
class_name DeckFriction
extends RefCounted

## A contact this close to the rail (fraction of the half width) counts as the edge.
const EDGE_FRACTION := 0.85


## `contacts`: [offset from body origin (global orientation), normal] pairs for non-wheel contacts.
static func apply(state: PhysicsDirectBodyState3D, contacts: Array, g: BoardGeometry, t: BoardTuning) -> void:
	var to_local := state.transform.basis.inverse()
	var touching: Array = []
	for c in contacts:
		var p: Vector3 = to_local * (c[0] as Vector3)
		var mid := g.surface_y(p.z) - g.thickness * 0.5     # deck mid-plane height at this z
		var on_grip := p.y > mid
		# Edge = out at the rail AND not on the bottom face (a kick's bottom corners are also
		# at the rail, and they must slide freely when the tail strikes).
		var on_edge := absf(p.x) > g.half_width * EDGE_FRACTION and p.y > mid - g.thickness * 0.25
		if on_grip or on_edge:
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
