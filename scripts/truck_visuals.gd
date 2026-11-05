## Trucks, hardware and wheels (visual only — collision is simple spheres in BoardBuilder).
## Modelled on a real fingerboard truck, sized from the board's own dimensions:
##   bolt heads on the grip → riser pad → baseplate (with nuts underneath) → angled kingpin with
##   two bushings and a kingpin nut → hanger (centre body + axle housing) → axle with washers and
##   axle nuts → wheels (urethane tyre with a lip, recessed core, bearing shields).
class_name TruckVisuals
extends RefCounted

const WHEEL_SEGMENTS := 28
const KINGPIN_TILT := 0.45     # radians from vertical (~26°): bottom of the kingpin points inboard


static func build(body: Node3D, g: BoardGeometry, t: BoardTuning) -> void:
	var mats := {
		"metal": MeshUtil.material(t.truck_color, 0.35, 0.5),               # brushed aluminium
		"steel": MeshUtil.material(Color(0.55, 0.56, 0.6), 0.25, 0.9),
		"dark": MeshUtil.material(Color(0.1, 0.1, 0.11), 0.45, 0.6),       # bolts, nuts
		"riser": MeshUtil.material(Color(0.08, 0.08, 0.08), 0.8),
		"bushing": MeshUtil.material(t.bushing_color, 0.7),
		"urethane": MeshUtil.material(t.wheel_color, 0.5),
		"core": MeshUtil.material(t.wheel_color.darkened(0.18), 0.6),
		"bearing": MeshUtil.material(Color(0.78, 0.79, 0.82), 0.2, 1.0),
	}
	var wheel := _wheel_mesh(g.wheel_radius, g.wheel_width)
	for side in [-1.0, 1.0]:                       # −1 front truck, +1 rear truck
		var axle_z: float = side * g.axle_z
		# The baseplate sits a little inboard of the axle (kingpin geometry).
		var plate_z: float = axle_z - side * g.wheel_radius
		_bolts(body, g, plate_z, mats)
		_truck(body, g, side, axle_z, plate_z, mats)
		for x in [-g.wheel_x, g.wheel_x]:
			var w := MeshInstance3D.new()
			w.mesh = wheel
			w.set_surface_override_material(0, mats.urethane)
			w.set_surface_override_material(1, mats.core)
			w.set_surface_override_material(2, mats.bearing)
			# Mirror the left wheel so both wheels show their outer face outward.
			w.transform = Transform3D(Basis.IDENTITY.scaled(Vector3(signf(x), 1, 1)),
					Vector3(x, g.wheel_y, axle_z))
			body.add_child(w)


## Four bolt heads on the grip and their nuts under the baseplate.
static func _bolts(body: Node3D, g: BoardGeometry, plate_z: float, mats: Dictionary) -> void:
	var r := g.wheel_radius
	var plate_bottom := _plate_bottom(g)
	for dx in [-0.3, 0.3]:
		for dz in [-0.22, 0.22]:
			var x: float = dx * g.half_width
			var z: float = plate_z + dz * g.half_width
			var head_h := g.thickness * 0.3
			_cyl(body, g.half_width * 0.07, head_h, 12, Vector3(x, g.surface_y(z) + head_h * 0.3, z),
					Basis.IDENTITY, mats.dark)
			_cyl(body, g.half_width * 0.065, r * 0.18, 6, Vector3(x, plate_bottom - r * 0.09, z),
					Basis.IDENTITY, mats.dark)


static func _plate_bottom(g: BoardGeometry) -> float:
	var r := g.wheel_radius
	return -g.thickness * 0.5 - r * 0.15 - r * 0.25    # under the deck, riser and baseplate


static func _truck(body: Node3D, g: BoardGeometry, side: float, axle_z: float, plate_z: float,
		mats: Dictionary) -> void:
	var r := g.wheel_radius
	var under := -g.thickness * 0.5
	var riser_h := r * 0.15
	var plate_h := r * 0.25
	var foot := Vector3(g.half_width * 1.0, 0.0, g.half_width * 0.75)   # baseplate footprint
	_box(body, Vector3(foot.x * 1.04, riser_h, foot.z * 1.04), Vector3(0, under - riser_h * 0.5, plate_z), mats.riser)
	_box(body, Vector3(foot.x, plate_h, foot.z), Vector3(0, under - riser_h - plate_h * 0.5, plate_z), mats.metal)
	var plate_bottom := _plate_bottom(g)

	# Kingpin stack: tilted so its bottom points inboard, bushings around it, nut at the bottom.
	var hanger_top := g.wheel_y + r * 0.55
	var stack_len := (plate_bottom - hanger_top) / cos(KINGPIN_TILT)
	var tilt := Basis(Vector3.RIGHT, side * KINGPIN_TILT)
	var axis := tilt * Vector3.UP
	var centre := Vector3(0, (plate_bottom + hanger_top) * 0.5, (plate_z + axle_z) * 0.5)
	_cyl(body, r * 0.11, stack_len * 1.35, 10, centre, tilt, mats.steel)            # kingpin
	for k in [-0.25, 0.25]:
		_cyl(body, r * 0.4, stack_len * 0.42, 16, centre + axis * stack_len * k, tilt, mats.bushing)
	_cyl(body, r * 0.2, r * 0.22, 6, centre - axis * stack_len * 0.7, tilt, mats.dark)  # kingpin nut

	# Hanger: centre body (side profile, narrower) + a full-width axle housing.
	var reach := g.wheel_x - g.wheel_width * 0.5 - r * 0.12
	var dz := axle_z - plate_z
	var outline := PackedVector2Array([                  # (y, z) relative to the axle
		Vector2(-r * 0.35, -r * 0.4), Vector2(-r * 0.35, r * 0.4),
		Vector2(hanger_top - g.wheel_y, -dz * 0.15), Vector2(hanger_top - g.wheel_y, -dz * 1.05)])
	var body_mesh := MeshInstance3D.new()
	body_mesh.mesh = MeshUtil.prism_yz(outline, reach * 0.4)
	body_mesh.material_override = mats.metal
	body_mesh.position = Vector3(0, g.wheel_y, axle_z)
	body.add_child(body_mesh)
	var along_x := Basis(Vector3.FORWARD, PI * 0.5)          # cylinder Y axis → X axis
	_cyl(body, r * 0.3, reach * 2.0, 16, Vector3(0, g.wheel_y, axle_z), along_x, mats.metal)  # housing
	# Pivot cup where the hanger's pivot arm meets the baseplate.
	_cyl(body, r * 0.22, r * 0.3, 12, Vector3(0, plate_bottom - r * 0.1, plate_z - dz * 0.1),
			Basis.IDENTITY, mats.bushing)

	# Axle, washers either side of each wheel, axle nuts on the ends.
	var axle_len := (g.wheel_x + g.wheel_width * 0.5 + r * 0.45) * 2.0
	_cyl(body, r * 0.1, axle_len, 8, Vector3(0, g.wheel_y, axle_z), along_x, mats.steel)
	for sx in [-1.0, 1.0]:
		var wx: float = sx * g.wheel_x
		for face in [-1.0, 1.0]:
			var x: float = wx + face * (g.wheel_width * 0.5 + r * 0.04)
			_cyl(body, r * 0.32, r * 0.05, 14, Vector3(x, g.wheel_y, axle_z), along_x, mats.steel)
		var nut_x: float = wx + sx * (g.wheel_width * 0.5 + r * 0.22)
		_cyl(body, r * 0.24, r * 0.28, 6, Vector3(nut_x, g.wheel_y, axle_z), along_x, mats.dark)


## Wheel (outer face toward +X): surface 0 urethane tyre with a rounded lip on the outer edge and
## a gentler round on the inner edge; surface 1 recessed core ring on both faces; surface 2
## bearing shields. Profiles are (x along the axle, radius), spun round X by MeshUtil.lathe.
static func _wheel_mesh(r: float, w: float) -> ArrayMesh:
	var hw := w * 0.5
	var rb := r * 0.42          # bearing radius
	var rc := r * 0.64          # core radius (where the urethane face starts)
	var lip := minf(w, r) * 0.45
	var inner := minf(w, r) * 0.25
	var profile := PackedVector2Array([Vector2(-hw, rc)])
	for k in 5:                                     # inner rounded edge
		var a := PI * 0.5 * k / 4.0
		profile.append(Vector2(-hw + inner - inner * cos(a), r - inner + inner * sin(a)))
	for k in 7:                                     # outer lip (bigger radius)
		var a := PI * 0.5 * k / 6.0
		profile.append(Vector2(hw - lip + lip * sin(a), r - lip + lip * cos(a)))
	profile.append(Vector2(hw, rc))
	var tyre := SurfaceTool.new()
	var core := SurfaceTool.new()
	var shields := SurfaceTool.new()
	for st in [tyre, core, shields]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	MeshUtil.lathe(profile, WHEEL_SEGMENTS, tyre)
	for face in [-1.0, 1.0]:
		# Core: steps in from the tyre face to a recessed ring around the bearing.
		var x: float = face * (hw - w * 0.06)
		MeshUtil.lathe(PackedVector2Array([Vector2(face * hw, rc), Vector2(x, rc * 0.97), Vector2(x, rb)]),
				WHEEL_SEGMENTS, core)
		var xs: float = face * (hw - w * 0.1)
		MeshUtil.lathe(PackedVector2Array([Vector2(xs, r * 0.08), Vector2(xs, rb)]), WHEEL_SEGMENTS, shields)
	var mesh := tyre.commit()
	core.commit(mesh)
	shields.commit(mesh)
	return mesh


static func _cyl(body: Node3D, radius: float, height: float, segments: int, pos: Vector3,
		basis: Basis, mat: Material) -> void:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = segments
	c.rings = 1
	var m := MeshInstance3D.new()
	m.mesh = c
	m.material_override = mat
	m.transform = Transform3D(basis, pos)
	body.add_child(m)


static func _box(body: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = pos
	body.add_child(m)
