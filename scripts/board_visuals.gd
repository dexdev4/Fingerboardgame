## The board's looks: concave deck with rounded edges (grip tape with a filed, worn edge; maple
## plies; bottom graphic). Trucks, hardware and wheels are in TruckVisuals.
## Visual only — collision shapes are in BoardBuilder and stay simple boxes/spheres.
## Sizes are fractions of the board's real dimensions so they follow the tuning values.
class_name BoardVisuals
extends RefCounted

const ALONG_STEPS := 64     # deck profile resolution, nose → tail
const ACROSS_STEPS := 10    # deck resolution across the width (for the concave)
const EDGE_STEPS := 6       # segments in the rounded edge (half circle across the thickness)


static func build(body: Node3D, g: BoardGeometry, t: BoardTuning) -> void:
	var deck := MeshInstance3D.new()
	deck.name = "DeckMesh"
	deck.mesh = _deck_mesh(g, t)
	body.add_child(deck)

	TruckVisuals.build(body, g, t)


# ---- Deck ------------------------------------------------------------------------------

## The side profile (flat middle + two kicks) swept across the width. Each across-the-width
## position x is lifted by the concave: c(x) = concave · (x / half_width)², so the rails sit
## higher than the centre line, like a real deck.
static func _deck_mesh(g: BoardGeometry, t: BoardTuning) -> ArrayMesh:
	var grip := SurfaceTool.new()
	var wood := SurfaceTool.new()
	grip.begin(Mesh.PRIMITIVE_TRIANGLES)
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	var concave := t.mm(t.concave_mm)
	var span := g.flat_half + g.kick_length          # half the profile length, along the deck
	var h := g.thickness * 0.5
	var prev: Array = []
	for i in ALONG_STEPS + 1:
		var u := float(i) / ALONG_STEPS              # 0 nose … 1 tail
		var s := lerpf(-span, span, u)
		var d := maxf(absf(s) - g.flat_half, 0.0)    # distance travelled along a kick
		var z := signf(s) * (minf(absf(s), g.flat_half) + d * cos(g.kick_angle))
		var centre := Vector3(0.0, d * sin(g.kick_angle), z)
		var n := g.surface_normal(z)
		var w := _half_width_at(g, z)
		var row := []                                # [top, bottom, top normal] per column
		for j in ACROSS_STEPS + 1:
			var x := lerpf(-w, w, float(j) / ACROSS_STEPS)
			var lift := concave * pow(x / g.half_width, 2.0)
			var slope := 2.0 * concave * x / (g.half_width * g.half_width)   # d(lift)/dx
			var base := centre + Vector3(x, 0, 0) + n * lift
			row.append([base + n * h, base - n * h, (n - Vector3(slope, 0, 0)).normalized()])
		if not prev.is_empty():
			var u0 := float(i - 1) / ALONG_STEPS
			for j in ACROSS_STEPS:
				var a: Array = prev[j]
				var b: Array = prev[j + 1]
				var c: Array = row[j + 1]
				var e: Array = row[j]
				# Grip UV.y = position across the width (0..1): the shader wears the edges.
				var g0 := float(j) / ACROSS_STEPS
				var g1 := float(j + 1) / ACROSS_STEPS
				_quad(grip, [a[0], b[0], c[0], e[0]], [a[2], b[2], c[2], e[2]],
						[Vector2(u0, g0), Vector2(u0, g1), Vector2(u, g1), Vector2(u, g0)])
				var v0 := 2.0 + float(j) / ACROSS_STEPS
				var v1 := 2.0 + float(j + 1) / ACROSS_STEPS
				_quad(wood, [a[1], b[1], c[1], e[1]], [-a[2], -b[2], -c[2], -e[2]],
						[Vector2(u0, v0), Vector2(u0, v1), Vector2(u, v1), Vector2(u, v0)])
			# Rounded edges: a half circle from the bottom face round to the grip, bulging out
			# by half the thickness. UV.y runs 0 (bottom) → 1 (top) so the plies wrap round it.
			for j in [0, ACROSS_STEPS]:
				var out := Vector3(-1, 0, 0) if j == 0 else Vector3(1, 0, 0)
				var p0 := _edge_arc(prev[j], out)
				var q0 := _edge_arc(row[j], out)
				for k in EDGE_STEPS:
					var v0 := float(k) / EDGE_STEPS
					var v1 := float(k + 1) / EDGE_STEPS
					_quad(wood, [p0[k][0], p0[k + 1][0], q0[k + 1][0], q0[k][0]],
							[p0[k][1], p0[k + 1][1], q0[k + 1][1], q0[k][1]],
							[Vector2(u0, v0), Vector2(u0, v1), Vector2(u, v1), Vector2(u, v0)])
		prev = row
	var mesh := grip.commit()
	mesh.surface_set_material(0, MeshUtil.shader_material("res://shaders/grip_tape.gdshader",
			{"grip_color": t.grip_color}))
	wood.commit(mesh)
	mesh.surface_set_material(1, MeshUtil.shader_material("res://shaders/deck_wood.gdshader",
			{"graphic_a": t.graphic_color_a, "graphic_b": t.graphic_color_b}))
	return mesh


## Points [position, normal] round one edge of the deck, bottom (θ = 0) to top (θ = π):
## P(θ) = centre − up·h·cos θ + out·h·sin θ, a half circle of radius h (half the thickness).
static func _edge_arc(edge: Array, out: Vector3) -> Array:
	var top: Vector3 = edge[0]
	var bottom: Vector3 = edge[1]
	var centre := (top + bottom) * 0.5
	var h := top.distance_to(bottom) * 0.5
	var up := (top - bottom).normalized()
	var pts := []
	for k in EDGE_STEPS + 1:
		var a := PI * k / EDGE_STEPS
		var n := (-up * cos(a) + out * sin(a)).normalized()
		pts.append([centre + n * h, n])
	return pts


## Top-view outline: full width, rounding off into a semicircle at each tip.
static func _half_width_at(g: BoardGeometry, z: float) -> float:
	var r := g.half_width
	var into_round := absf(z) - (g.half_length - r)
	if into_round <= 0.0:
		return r
	return sqrt(maxf(r * r - into_round * into_round, 0.0)) + 0.0005


static func _quad(st: SurfaceTool, v: Array, n: Array, uv: Array) -> void:
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_normal(n[k])
		if not uv.is_empty():
			st.set_uv(uv[k])
		st.add_vertex(v[k])
