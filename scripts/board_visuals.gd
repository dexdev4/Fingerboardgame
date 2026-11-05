## The board's looks: concave deck (grip tape, maple plies, bottom graphic), bolts, trucks
## (baseplate, kingpin, bushings, hanger, axle) and rounded urethane wheels with bearings.
## Visual only — collision shapes are in BoardBuilder and stay simple boxes/spheres.
## Sizes are fractions of the board's real dimensions so they follow the tuning values.
class_name BoardVisuals
extends RefCounted

const ALONG_STEPS := 64     # deck profile resolution, nose → tail
const ACROSS_STEPS := 10    # deck resolution across the width (for the concave)
const WHEEL_SEGMENTS := 24


static func build(body: Node3D, g: BoardGeometry, t: BoardTuning) -> void:
	var deck := MeshInstance3D.new()
	deck.name = "DeckMesh"
	deck.mesh = _deck_mesh(g, t)
	body.add_child(deck)

	var metal := MeshUtil.material(t.truck_color, 0.35, 0.5)   # brushed aluminium
	var dark_metal := MeshUtil.material(Color(0.12, 0.12, 0.13), 0.4, 0.8)
	var bushing := MeshUtil.material(t.bushing_color, 0.7)
	var urethane := MeshUtil.material(t.wheel_color, 0.55)
	var bearing := MeshUtil.material(Color(0.75, 0.76, 0.8), 0.25, 1.0)
	var wheel_mesh := _wheel_mesh(g.wheel_radius, g.wheel_width)
	for side in [-1.0, 1.0]:                       # −1 front truck, +1 rear truck
		var axle_z: float = side * g.axle_z
		# The baseplate sits a little inboard of the axle (kingpin geometry).
		var plate_z: float = axle_z - side * g.wheel_radius
		_add_bolts(body, g, plate_z, dark_metal)
		_add_truck(body, g, axle_z, plate_z, metal, bushing)
		for x in [-g.wheel_x, g.wheel_x]:
			var w := MeshInstance3D.new()
			w.mesh = wheel_mesh
			w.set_surface_override_material(0, urethane)
			w.set_surface_override_material(1, bearing)
			w.position = Vector3(x, g.wheel_y, axle_z)
			body.add_child(w)


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
				_quad(grip, [a[0], b[0], c[0], e[0]], [a[2], b[2], c[2], e[2]], [])
				var v0 := 2.0 + float(j) / ACROSS_STEPS
				var v1 := 2.0 + float(j + 1) / ACROSS_STEPS
				_quad(wood, [a[1], b[1], c[1], e[1]], [-a[2], -b[2], -c[2], -e[2]],
						[Vector2(u0, v0), Vector2(u0, v1), Vector2(u, v1), Vector2(u, v0)])
			# Edges: UV.y runs 0 (bottom) → 1 (top) across the plies.
			for j in [0, ACROSS_STEPS]:
				var out := Vector3(-1, 0, 0) if j == 0 else Vector3(1, 0, 0)
				var p: Array = prev[j]
				var q: Array = row[j]
				_quad(wood, [p[1], p[0], q[0], q[1]], [out, out, out, out],
						[Vector2(u0, 0), Vector2(u0, 1), Vector2(u, 1), Vector2(u, 0)])
		prev = row
	var mesh := grip.commit()
	mesh.surface_set_material(0, MeshUtil.shader_material("res://shaders/grip_tape.gdshader",
			{"grip_color": t.grip_color}))
	wood.commit(mesh)
	mesh.surface_set_material(1, MeshUtil.shader_material("res://shaders/deck_wood.gdshader",
			{"graphic_a": t.graphic_color_a, "graphic_b": t.graphic_color_b}))
	return mesh


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


# ---- Hardware ----------------------------------------------------------------------------

## Four bolt heads poking through the grip over each baseplate (where your front finger goes).
static func _add_bolts(body: Node3D, g: BoardGeometry, plate_z: float, mat: Material) -> void:
	var head := CylinderMesh.new()
	head.top_radius = g.half_width * 0.07
	head.bottom_radius = head.top_radius
	head.height = g.thickness * 0.3
	head.radial_segments = 10
	for dx in [-0.3, 0.3]:
		for dz in [-0.22, 0.22]:
			var b := MeshInstance3D.new()
			b.mesh = head
			b.material_override = mat
			var z: float = plate_z + dz * g.half_width
			b.position = Vector3(dx * g.half_width, g.surface_y(z) + head.height * 0.3, z)
			body.add_child(b)


## Baseplate → kingpin + bushings → hanger → axle, sized from the board's own dimensions.
static func _add_truck(body: Node3D, g: BoardGeometry, axle_z: float, plate_z: float,
		metal: Material, bushing: Material) -> void:
	var under := -g.thickness * 0.5                 # underside of the deck
	var r := g.wheel_radius
	var plate_h := r * 0.25
	_box(body, Vector3(g.half_width * 1.0, plate_h, g.half_width * 0.75),
			Vector3(0, under - plate_h * 0.5, plate_z), metal)
	# Bushings (two stacked cylinders) around the kingpin, between baseplate and hanger.
	var hanger_top := g.wheel_y + r * 0.55
	var bush_top := under - plate_h
	var bush_h := (bush_top - hanger_top) * 0.5
	for k in 2:
		var c := CylinderMesh.new()
		c.top_radius = r * 0.42
		c.bottom_radius = r * 0.42
		c.height = bush_h * 0.9
		c.radial_segments = 14
		var m := MeshInstance3D.new()
		m.mesh = c
		m.material_override = bushing
		m.position = Vector3(0, bush_top - bush_h * (k + 0.5), (plate_z + axle_z) * 0.5)
		body.add_child(m)
	# Hanger: a tapered prism seen from the side, extruded across the axle width.
	var reach := g.wheel_x - g.wheel_width * 0.5
	var dz := axle_z - plate_z
	var outline := PackedVector2Array([            # (y, z) relative to the axle, CCW
		Vector2(-r * 0.35, -r * 0.45), Vector2(-r * 0.35, r * 0.45),
		Vector2(hanger_top - g.wheel_y, -dz * 0.2), Vector2(hanger_top - g.wheel_y, -dz * 1.1)])
	var hanger := MeshInstance3D.new()
	hanger.mesh = MeshUtil.prism_yz(outline, reach)
	hanger.material_override = metal
	hanger.position = Vector3(0, g.wheel_y, axle_z)
	body.add_child(hanger)
	# Axle through both wheels.
	var axle := CylinderMesh.new()
	axle.top_radius = r * 0.12
	axle.bottom_radius = r * 0.12
	axle.height = (g.wheel_x + g.wheel_width * 0.6) * 2.0
	var am := MeshInstance3D.new()
	am.mesh = axle
	am.material_override = metal
	am.transform = Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, g.wheel_y, axle_z))
	body.add_child(am)


## Wheel: rounded urethane tyre (surface 0) + a bearing shield on each face (surface 1).
## Profile is (x along the axle, radius), spun around the X axis by MeshUtil.lathe.
static func _wheel_mesh(r: float, w: float) -> ArrayMesh:
	var rc := minf(w, r) * 0.35                     # edge rounding radius
	var rb := r * 0.45                              # bearing radius
	var hw := w * 0.5
	var profile := PackedVector2Array([Vector2(-hw, rb)])
	for k in 5:                                     # inner rounded edge
		var a := PI * 0.5 * k / 4.0
		profile.append(Vector2(-hw + rc - rc * cos(a), r - rc + rc * sin(a)))
	for k in 5:                                     # outer rounded edge
		var a := PI * 0.5 * k / 4.0
		profile.append(Vector2(hw - rc + rc * sin(a), r - rc + rc * cos(a)))
	profile.append(Vector2(hw, rb))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	MeshUtil.lathe(profile, WHEEL_SEGMENTS, st)
	var mesh := st.commit()
	var shields := SurfaceTool.new()
	shields.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:                        # flat discs just inside each face
		var x: float = side * (hw - w * 0.08)
		MeshUtil.lathe(PackedVector2Array([Vector2(x, 0.0), Vector2(x, rb)]), WHEEL_SEGMENTS, shields)
	shields.commit(mesh)
	return mesh


static func _box(body: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = pos
	body.add_child(m)
