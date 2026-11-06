## Makes the park bigger and more polished — ADDS to the existing park (keeps your edits):
##   godot --headless --path . -s res://tools/expand_park.gd
## Idempotent: anything already present (by name) is skipped. Every solid gets a
## "slide_friction_scale" (steel 0.6, painted 0.8, concrete 1.0). Scale 1:8 like the rest.
##
## Adds: a plaza extension behind the start and wider side strips; a 5-stair with handrail and
## hubba; a quarter pipe with a real curved transition and coping; a kinked rail; two manual
## pads; a low bank; and polish — a raised concrete lip around the plaza, tree planters, lamp
## posts with glowing heads, benches.
extends SceneTree

const PARK := "res://scenes/skatepark.tscn"
const STEEL := 0.6
const PAINTED := 0.8
const CONCRETE := 1.0

var root_node: Node3D
var concrete: Material
var concrete_warm: ShaderMaterial
var metal: Material
var wood: StandardMaterial3D
var leaves: StandardMaterial3D
var bark: StandardMaterial3D
var glow: StandardMaterial3D


func _initialize() -> void:
	root_node = load(PARK).instantiate()
	concrete = _material_of("ManualPad", MeshUtil.shader_material("res://shaders/concrete.gdshader"))
	# The new section: same concrete, a touch warmer and with bigger slabs, so it reads as its own area.
	concrete_warm = MeshUtil.shader_material("res://shaders/concrete.gdshader", {
		"base_color": Color(0.7, 0.68, 0.64), "stain_color": Color(0.56, 0.54, 0.5), "joint_spacing": 1.5})
	metal = _material_of("FlatBar", MeshUtil.material(Color(0.62, 0.64, 0.68), 0.3, 0.9))
	wood = MeshUtil.material(Color(0.5, 0.34, 0.2), 0.8)
	leaves = MeshUtil.material(Color(0.22, 0.44, 0.18), 0.9)
	bark = MeshUtil.material(Color(0.35, 0.25, 0.16), 0.9)
	glow = MeshUtil.material(Color(1.0, 0.92, 0.75), 0.4)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.88, 0.6)
	glow.emission_energy_multiplier = 2.0

	_spot("PlazaExtension", _plaza_extension)
	_spot("PlazaLip", _plaza_lip)
	_spot("FiveStair", _five_stair)
	_spot("QuarterPipe", _quarter_pipe)
	_spot("KinkedRail", _kinked_rail)
	_spot("ManualPads", _manual_pads)
	_spot("LowBank", _low_bank)
	_spot("Planters", _planters)
	_spot("StreetLamps", _street_lamps)
	_spot("MoreBenches", _more_benches)

	var packed := PackedScene.new()
	packed.pack(root_node)
	print("saved skatepark.tscn: ", error_string(ResourceSaver.save(packed, PARK)))
	root_node.free()
	quit()


func _spot(name: String, build: Callable) -> void:
	if root_node.has_node(name):
		return
	var group := Node3D.new()
	group.name = name
	root_node.add_child(group)
	build.call(group)
	_own(group)


func _material_of(node_name: String, fallback: Material) -> Material:
	var n := root_node.get_node_or_null(node_name)
	if n:
		for c in n.get_children():
			if c is MeshInstance3D and c.material_override:
				return c.material_override
	return fallback


# ---- Ground --------------------------------------------------------------------------------

## New concrete behind the start (z 8 → 26) and side strips (x ±8 → ±12) along the old plaza.
## The ground's collision slab already covers everything, so these are surface only.
func _plaza_extension(g: Node3D) -> void:
	_slab(g, Vector2(24, 18), Vector3(0, 0.001, 17))
	for x in [-10.0, 10.0]:
		_slab(g, Vector2(4, 34), Vector3(x, 0.001, -9))


func _slab(g: Node3D, size: Vector2, centre: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = concrete_warm
	mi.position = centre
	g.add_child(mi)


## A low raised concrete lip around the whole plaza edge (skateable — a long curb), with gaps
## at the corners so you can roll out onto the lawn.
func _plaza_lip(g: Node3D) -> void:
	var h := 0.05
	for side in [-1.0, 1.0]:
		_box(g, "Lip", Vector3(0.25, h, 50.0), Vector3(side * 12.1, 0, -1.0), concrete, CONCRETE)
	_box(g, "Lip", Vector3(22.0, h, 0.25), Vector3(0, 0, 26.1), concrete, CONCRETE)


# ---- Spots ------------------------------------------------------------------------------

## 5-stair in the new section, dropping toward +z, with a handrail on its right and a hubba
## on its left. Rise 0.12 / run 0.3 per step (≈ real 1:8 stairs).
func _five_stair(g: Node3D) -> void:
	var rise := 0.12
	var run := 0.3
	var steps := 5
	var top_h := rise * steps
	var x0 := -5.0
	var z_edge := 12.0                # front edge of the top deck; steps run toward +z
	var width := 3.0
	_box(g, "Deck", Vector3(width + 1.0, top_h, 3.0), Vector3(x0, 0, z_edge - 1.5), concrete_warm, CONCRETE)
	# A bank up to the deck from the plaza side (−z), so you can roll up.
	_prism(g, "DeckBank", PackedVector2Array([Vector2(0, 1.25), Vector2(0, -1.25), Vector2(top_h, 1.25)]),
			(width + 1.0) * 0.5, Transform3D(Basis.IDENTITY, Vector3(x0, 0, z_edge - 4.25)), concrete_warm, CONCRETE)
	for i in range(1, steps):
		var top := top_h - rise * i
		var z := z_edge + run * (i - 0.5)
		_box(g, "Step", Vector3(width, top, run), Vector3(x0, 0, z), concrete_warm, CONCRETE)
		_bar(g, "StepLip", Vector3(x0 - width * 0.5, top, z - run * 0.5), Vector3(x0 + width * 0.5, top, z - run * 0.5), 0.006, metal, 0.0)
	var z_end := z_edge + run * steps
	# Handrail (right side), parallel to the nosing line, 0.14 above it.
	var slope := rise / run
	var nose_y := func(z: float) -> float: return clampf(top_h - slope * (z - z_edge), 0.0, top_h)
	var rx := x0 + width * 0.5 - 0.2
	var a := Vector3(rx, nose_y.call(z_edge - 0.1) + 0.14, z_edge - 0.1)
	var b := Vector3(rx, nose_y.call(z_end - 0.1) + 0.14, z_end - 0.1)
	_bar(g, "Handrail", a, b, 0.02, metal, STEEL)
	_bar(g, "RailPost", Vector3(rx, top_h, z_edge - 0.1), a, 0.016, metal, STEEL)
	_bar(g, "RailPost", Vector3(rx, 0, z_end - 0.1), b, 0.016, metal, STEEL)
	# Hubba (left side): a ledge running down the stairs, coped edge.
	var hx := x0 - width * 0.5 - 0.2
	_prism(g, "Hubba", PackedVector2Array([Vector2(0.0, z_edge - 0.3), Vector2(top_h + 0.14, z_edge - 0.3),
			Vector2(top_h + 0.14, z_edge), Vector2(0.14, z_end), Vector2(0.0, z_end)]),
			0.2, Transform3D(Basis.IDENTITY, Vector3(hx, 0, 0)), concrete_warm, PAINTED)
	_bar(g, "HubbaCoping", Vector3(hx + 0.2, top_h + 0.14, z_edge), Vector3(hx + 0.2, 0.14, z_end), 0.008, metal, 0.0)


## Quarter pipe: a real curved transition (radius R, 1:8 of a ~1.2 m quarter), a short deck on
## top and steel coping on the lip. Collision is a trimesh of the exact curve.
func _quarter_pipe(g: Node3D) -> void:
	var r := 1.5
	var deck := 0.8
	var half_w := 2.0
	var at := Vector3(5.0, 0, 23.0)       # bottom of the transition; it rises toward +z
	# Outline (y, z), starting at the BACK-BOTTOM corner: prism_yz fans its end caps from the first
	# point, and only that corner can "see" the whole solid (the curve only rises toward the back,
	# so a straight line from there to any point on the curve stays inside the solid).
	var outline := PackedVector2Array([Vector2(0.0, r + deck), Vector2(r, r + deck)])
	for k in range(12, -1, -1):              # transition: top (θ = 90°) down to the ground (θ = 0°)
		var th := PI * 0.5 * k / 12.0
		outline.append(Vector2(r - r * cos(th), r * sin(th)))
	var mesh := MeshUtil.prism_yz(outline, half_w)
	var body := StaticBody3D.new()
	body.name = "Quarter"
	body.position = at
	body.set_meta("slide_friction_scale", CONCRETE)
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = concrete_warm
	body.add_child(mi)
	g.add_child(body)
	_bar(g, "QuarterCoping", at + Vector3(-half_w, r, r), at + Vector3(half_w, r, r), 0.03, metal, STEEL)


## Kinked rail: flat, down, flat — for grinds on the way down the plaza's east side.
func _kinked_rail(g: Node3D) -> void:
	var x := 9.5
	var pts := [Vector3(x, 0.22, -2.0), Vector3(x, 0.22, -4.0), Vector3(x, 0.10, -6.5), Vector3(x, 0.10, -8.5)]
	for i in pts.size() - 1:
		_bar(g, "KinkSegment", pts[i], pts[i + 1], 0.02, metal, STEEL)
	for p in pts:
		_bar(g, "KinkPost", Vector3(p.x, 0, p.z), p, 0.016, metal, STEEL)


func _manual_pads(g: Node3D) -> void:
	_box(g, "ManualPadA", Vector3(1.4, 0.06, 2.8), Vector3(-9.5, 0, -14.0), concrete, CONCRETE)
	_box(g, "ManualPadB", Vector3(2.4, 0.08, 1.4), Vector3(2.0, 0, 18.0), concrete_warm, CONCRETE)
	for p in [[Vector3(-10.2, 0.06, -15.4), Vector3(-10.2, 0.06, -12.6)], [Vector3(0.8, 0.08, 17.3), Vector3(3.2, 0.08, 17.3)]]:
		_bar(g, "PadCoping", p[0], p[1], 0.006, metal, 0.0)


func _low_bank(g: Node3D) -> void:
	var outline := PackedVector2Array([Vector2(0, 0.9), Vector2(0, -0.9), Vector2(0.22, -0.9)])
	_prism(g, "LowBankBody", outline, 1.5, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-10.0, 0, 2.0)), concrete_warm, CONCRETE)


# ---- Polish -------------------------------------------------------------------------------

func _planters(g: Node3D) -> void:
	for p in [Vector3(-9, 0, 22), Vector3(-1, 0, 24), Vector3(9, 0, 13), Vector3(10, 0, -18), Vector3(-10, 0, -22)]:
		_box(g, "PlanterBox", Vector3(1.4, 0.24, 1.4), p, concrete_warm, CONCRETE)
		var soil := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(1.2, 1.2)
		soil.mesh = pm
		soil.material_override = MeshUtil.shader_material("res://shaders/grass.gdshader")
		soil.position = p + Vector3(0, 0.242, 0)
		g.add_child(soil)
		_bar(g, "Trunk", p + Vector3(0, 0.24, 0), p + Vector3(0, 3.4, 0), 0.14, bark, 0.0)
		for k in 3:
			var c := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 1.3 - k * 0.25
			sm.height = sm.radius * 1.7
			c.mesh = sm
			c.material_override = leaves
			c.position = p + Vector3((k - 1) * 0.35, 3.4 + k * 0.7, (k % 2) * 0.3)
			g.add_child(c)


## Lamp posts with glowing heads around the new section.
func _street_lamps(g: Node3D) -> void:
	for p in [Vector3(-11.4, 0, 10), Vector3(11.4, 0, 10), Vector3(-11.4, 0, 22), Vector3(11.4, 0, 22),
			Vector3(11.4, 0, -14), Vector3(-11.4, 0, -14)]:
		_bar(g, "LampPost", p, p + Vector3(0, 5.5, 0), 0.07, metal, 0.0)
		var head := MeshInstance3D.new()
		var hb := BoxMesh.new()
		hb.size = Vector3(0.7, 0.12, 0.32)
		head.mesh = hb
		head.material_override = glow
		head.position = p + Vector3(-signf(p.x) * 0.35, 5.5, 0)
		g.add_child(head)


func _more_benches(g: Node3D) -> void:
	for p in [Vector3(-3.0, 0, 25.0), Vector3(7.5, 0, 15.0), Vector3(-11.0, 0, -6.0)]:
		_box(g, "BenchSeat", Vector3(1.6, 0.05, 0.45), p + Vector3(0, 0.18, 0), wood, CONCRETE)
		for dx in [-0.65, 0.65]:
			_box(g, "BenchLeg", Vector3(0.08, 0.18, 0.4), p + Vector3(dx, 0, 0), concrete, CONCRETE)


# ---- Building blocks ---------------------------------------------------------------------

func _box(parent: Node3D, name: String, size: Vector3, bottom_centre: Vector3, mat: Material, slick: float) -> void:
	var body := StaticBody3D.new()
	body.name = name
	body.position = bottom_centre + Vector3(0, size.y * 0.5, 0)
	body.set_meta("slide_friction_scale", slick)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	parent.add_child(body)


func _prism(parent: Node3D, name: String, outline: PackedVector2Array, half_x: float, xf: Transform3D,
		mat: Material, slick: float) -> void:
	var body := StaticBody3D.new()
	body.name = name
	body.transform = xf
	body.set_meta("slide_friction_scale", slick)
	var cs := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	for p in outline:
		for x in [-half_x, half_x]:
			pts.append(Vector3(x, p.x, p.y))
	shape.points = pts
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = MeshUtil.prism_yz(outline, half_x)
	mi.material_override = mat
	body.add_child(mi)
	parent.add_child(body)


## Round bar a → b. slick > 0 = solid (grindable); slick 0 = visual only.
func _bar(parent: Node3D, name: String, a: Vector3, b: Vector3, r: float, mat: Material, slick: float) -> void:
	var len := a.distance_to(b)
	var dir := (b - a) / len
	var basis := Basis.IDENTITY
	var axis := Vector3.UP.cross(dir)
	if axis.length() > 1e-5:
		basis = Basis(axis.normalized(), Vector3.UP.angle_to(dir))
	var node: Node3D = StaticBody3D.new() if slick > 0.0 else Node3D.new()
	node.name = name
	node.transform = Transform3D(basis, (a + b) * 0.5)
	if slick > 0.0:
		node.set_meta("slide_friction_scale", slick)
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = r
		shape.height = len
		cs.shape = shape
		node.add_child(cs)
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = r
	mesh.bottom_radius = r
	mesh.height = len
	mesh.radial_segments = 12
	mi.mesh = mesh
	mi.material_override = mat
	node.add_child(mi)
	parent.add_child(node)


func _own(n: Node) -> void:
	n.owner = root_node
	for c in n.get_children():
		_own(c)
