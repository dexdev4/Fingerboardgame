## Builds the board's collision shapes and visual meshes from BoardGeometry.
## Built in code (not in the scene) so changing the mm values in board_tuning.tres
## reshapes the board without touching the scene.
class_name BoardBuilder
extends RefCounted

const PROFILE_STEPS := 48   # resolution of the deck's side profile


## Adds CollisionShape3D children to `body`. Returns {shape_index: part_name} where
## part_name is "deck", "nose", "tail" or "wheel".
static func build_collision(body: RigidBody3D, g: BoardGeometry) -> Dictionary:
	var deck_size := Vector3(g.half_width * 2.0, g.thickness, g.flat_half * 2.0)
	_add_box(body, "deck", deck_size, Transform3D.IDENTITY)

	# Each kick is a box hinged at the end of the flat part and tilted up by kick_angle.
	# Rotating about X by -a tilts +Z upward (tail); +a tilts -Z upward (nose).
	var kick_size := Vector3(g.half_width * 2.0, g.thickness, g.kick_length)
	for side in [1.0, -1.0]:  # +1 = tail, -1 = nose
		var half := g.kick_length * 0.5
		var centre := Vector3(0.0, half * sin(g.kick_angle), side * (g.flat_half + half * cos(g.kick_angle)))
		var basis := Basis(Vector3.RIGHT, -side * g.kick_angle)
		_add_box(body, "tail" if side > 0.0 else "nose", kick_size, Transform3D(basis, centre))

	# Wheels are spheres: they roll smoothly in any direction. Sideways grip and rolling
	# resistance are applied as forces by WheelPhysics, so the board itself is frictionless.
	for z in [-g.axle_z, g.axle_z]:
		for x in [-g.wheel_x, g.wheel_x]:
			var cs := CollisionShape3D.new()
			cs.name = "WheelShape"
			var sphere := SphereShape3D.new()
			sphere.radius = g.wheel_radius
			cs.shape = sphere
			cs.position = Vector3(x, g.wheel_y, z)
			cs.set_meta("part", "wheel")
			body.add_child(cs)

	# Map the physics engine's shape indices to our part names (used to read contacts).
	var parts := {}
	for owner_id in body.get_shape_owners():
		var node: Node = body.shape_owner_get_owner(owner_id)
		for j in body.shape_owner_get_shape_count(owner_id):
			parts[body.shape_owner_get_shape_index(owner_id, j)] = node.get_meta("part", "deck")
	return parts


static func _add_box(body: RigidBody3D, part: String, size: Vector3, xf: Transform3D) -> void:
	var cs := CollisionShape3D.new()
	cs.name = part.capitalize() + "Shape"
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.transform = xf
	cs.set_meta("part", part)
	body.add_child(cs)


## Adds the visible board: deck (grip on top, wood below), trucks and wheels.
static func build_visuals(body: Node3D, g: BoardGeometry) -> void:
	var deck := MeshInstance3D.new()
	deck.name = "DeckMesh"
	deck.mesh = _deck_mesh(g)
	body.add_child(deck)

	var metal := _mat(Color(0.72, 0.74, 0.78), 0.35, 0.8)
	var urethane := _mat(Color(0.96, 0.94, 0.86), 0.6, 0.0)
	var under := -g.thickness * 0.5
	for z in [-g.axle_z, g.axle_z]:
		# Baseplate under the deck, and the hanger reaching out to the axle.
		_add_box_mesh(body, Vector3(g.half_width * 0.8, g.wheel_radius * 0.5, g.wheel_radius * 3.0),
				Vector3(0, under - g.wheel_radius * 0.25, z), metal)
		var hanger_top := under - g.wheel_radius * 0.5
		var hanger_h := hanger_top - g.wheel_y
		_add_box_mesh(body, Vector3(g.wheel_x * 2.0 - g.wheel_width, hanger_h, g.wheel_radius * 1.2),
				Vector3(0, g.wheel_y + hanger_h * 0.5, z), metal)
		for x in [-g.wheel_x, g.wheel_x]:
			var w := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = g.wheel_radius
			cyl.bottom_radius = g.wheel_radius
			cyl.height = g.wheel_width
			cyl.radial_segments = 20
			w.mesh = cyl
			w.material_override = urethane
			# Cylinder axis is Y; turn it to X so the wheel rolls along Z.
			w.transform = Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(x, g.wheel_y, z))
			body.add_child(w)


## Deck mesh: the side profile (flat middle + two kicks) extruded across the width,
## with the width rounded off near the tips so the outline looks like a real deck.
static func _deck_mesh(g: BoardGeometry) -> ArrayMesh:
	var top := SurfaceTool.new()
	var wood := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	var span := g.flat_half + g.kick_length       # half of the profile, measured along the deck
	var h := g.thickness * 0.5
	var prev: Array = []
	for i in PROFILE_STEPS + 1:
		var s := lerpf(-span, span, float(i) / PROFILE_STEPS)
		var d := maxf(absf(s) - g.flat_half, 0.0)   # distance travelled along a kick
		var z := signf(s) * (minf(absf(s), g.flat_half) + d * cos(g.kick_angle))
		var y := d * sin(g.kick_angle)
		var n := g.surface_normal(z)
		var w := _half_width_at(g, z)
		var cur := [Vector3(-w, y, z) + n * h, Vector3(w, y, z) + n * h,
				Vector3(-w, y, z) - n * h, Vector3(w, y, z) - n * h, n]
		if not prev.is_empty():
			_quad(top, prev[0], prev[1], cur[1], cur[0], n)          # grip tape
			_quad(wood, prev[2], prev[3], cur[3], cur[2], -n)        # underside
			_quad(wood, prev[0], prev[2], cur[2], cur[0], Vector3.LEFT)   # left edge
			_quad(wood, prev[1], prev[3], cur[3], cur[1], Vector3.RIGHT)  # right edge
		prev = cur
	var mesh := top.commit()
	mesh.surface_set_material(0, _mat(Color(0.13, 0.13, 0.14), 0.95, 0.0))
	wood.commit(mesh)
	mesh.surface_set_material(1, _mat(Color(0.78, 0.58, 0.38), 0.7, 0.0))
	return mesh


## Top-view outline: full width, then a semicircle of radius half_width at each tip.
static func _half_width_at(g: BoardGeometry, z: float) -> float:
	var r := g.half_width
	var into_round := absf(z) - (g.half_length - r)
	if into_round <= 0.0:
		return r
	return sqrt(maxf(r * r - into_round * into_round, 0.0)) + 0.0005


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	for v in [a, b, c, a, c, d]:
		st.set_normal(n)
		st.add_vertex(v)


static func _add_box_mesh(body: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	m.material_override = mat
	m.position = pos
	body.add_child(m)


static func _mat(c: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	m.cull_mode = BaseMaterial3D.CULL_DISABLED   # deck is built without caring about winding
	return m
