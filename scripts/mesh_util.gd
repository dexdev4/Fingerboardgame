## Small mesh-building helpers shared by the board visuals and the skatepark builder.
## Meshes only: no physics in here.
class_name MeshUtil
extends RefCounted


## A lathe: spins a 2D profile around the X axis. Profile points are (x, radius).
## Normals come from the profile's tangent: in the profile plane the outward normal of a
## segment (dx, dr) is (−dr, dx) normalised, then rotated around X with the vertex.
static func lathe(profile: PackedVector2Array, segments: int, st: SurfaceTool) -> void:
	var n := profile.size()
	var normals := PackedVector2Array()
	for i in n:
		var a := profile[maxi(i - 1, 0)]
		var b := profile[mini(i + 1, n - 1)]
		var t := (b - a).normalized()
		normals.append(Vector2(-t.y, t.x))
	for s in segments:
		var a0 := TAU * s / segments
		var a1 := TAU * (s + 1) / segments
		for i in n - 1:
			var quad := [
				_lathe_v(profile[i], normals[i], a0), _lathe_v(profile[i + 1], normals[i + 1], a0),
				_lathe_v(profile[i + 1], normals[i + 1], a1), _lathe_v(profile[i], normals[i], a1)]
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_normal(quad[k][1])
				st.add_vertex(quad[k][0])


static func _lathe_v(p: Vector2, nrm: Vector2, ang: float) -> Array:
	var c := cos(ang)
	var s := sin(ang)
	return [Vector3(p.x, p.y * c, p.y * s), Vector3(nrm.x, nrm.y * c, nrm.y * s).normalized()]


## A closed prism: a 2D outline of (y, z) points extruded along X from -half_x to +half_x.
## Used for wedges (banks, kickers) and the truck hangers. Either winding works: the signed
## area (shoelace formula, ½Σ(aᵧb_z − b_ᵧa_z)) tells us which way round it goes.
static func prism_yz(outline: PackedVector2Array, half_x: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := outline.size()
	var area := 0.0
	for i in n:
		var a := outline[i]
		var b := outline[(i + 1) % n]
		area += a.x * b.y - b.x * a.y
	var wind := 1.0 if area > 0.0 else -1.0
	for side in [-1.0, 1.0]:                     # end caps (fan)
		for i in range(1, n - 1):
			for p in [outline[0], outline[i], outline[i + 1]]:
				st.set_normal(Vector3(side, 0, 0))
				st.add_vertex(Vector3(side * half_x, p.x, p.y))
	for i in n:                                  # sides
		var a := outline[i]
		var b := outline[(i + 1) % n]
		var e := (b - a).normalized()
		var nrm := Vector3(0, e.y, -e.x) * wind  # (e_z, −e_y) is outward for counter-clockwise
		for v in [Vector3(-half_x, a.x, a.y), Vector3(half_x, a.x, a.y), Vector3(half_x, b.x, b.y),
				Vector3(-half_x, a.x, a.y), Vector3(half_x, b.x, b.y), Vector3(-half_x, b.x, b.y)]:
			st.set_normal(nrm)
			st.add_vertex(v)
	return st.commit()


static func material(c: Color, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	m.cull_mode = BaseMaterial3D.CULL_DISABLED   # helpers don't care about triangle winding
	return m


static func shader_material(path: String, params: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m
