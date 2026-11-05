## Builds the board's collision shapes and visual meshes from BoardGeometry.
## Built in code (not in the scene) so changing the mm values in board_tuning.tres
## reshapes the board without touching the scene.
class_name BoardBuilder
extends RefCounted

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


## Adds the visible board (see BoardVisuals).
static func build_visuals(body: Node3D, g: BoardGeometry, t: BoardTuning) -> void:
	BoardVisuals.build(body, g, t)
