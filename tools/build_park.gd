## Generates res://scenes/skatepark.tscn — the outdoor street plaza.
##   godot --headless --path . -s res://tools/build_park.gd
## After generating, the scene is a normal Godot scene: move/duplicate obstacles in the editor.
## (Re-running this tool overwrites those edits.)
##
## Scale: a 1:8 model of a real street plaza, the same ratio as a fingerboard to a skateboard.
## World units: 1 unit = 10 cm real (fingerboard world). E.g. a real 15 cm stair → 1.9 cm → 0.15 u.
## The board rolls toward −Z from the spawn on the stair platform. It can't turn yet, so the
## stairs, manual pad and kicker are in line; ledges, flat bar etc. sit beside the line.
extends SceneTree

const H := 0.45            # platform height = 3 stairs of 0.15
const STEP_RISE := 0.15
const STEP_RUN := 0.3
const STAIRS_TOP_Z := -1.0 # front edge of the platform; stairs descend toward −Z from here
const RAIL_HEIGHT := 0.12  # handrail above the stair nosings
const RAIL_R := 0.02

var root_node: Node3D
var concrete: ShaderMaterial
var metal: StandardMaterial3D
var paint: StandardMaterial3D
var wood: StandardMaterial3D


func _initialize() -> void:
	concrete = MeshUtil.shader_material("res://shaders/concrete.gdshader")
	metal = MeshUtil.material(Color(0.62, 0.64, 0.68), 0.3, 0.9)
	paint = MeshUtil.material(Color(0.95, 0.72, 0.12), 0.55)     # yellow painted ledge
	wood = MeshUtil.material(Color(0.55, 0.36, 0.2), 0.8)
	root_node = Node3D.new()
	root_node.name = "Skatepark"

	_environment()
	_ground()
	_stairs()
	_line_obstacles()
	_side_obstacles()
	_scenery()

	var spawn := Marker3D.new()
	spawn.name = "Spawn"               # ground point the board starts on, nose toward −Z
	spawn.position = Vector3(0, H, 4.2)
	_add(spawn)

	var packed := PackedScene.new()
	packed.pack(root_node)
	var err := ResourceSaver.save(packed, "res://scenes/skatepark.tscn")
	print("saved skatepark.tscn: ", error_string(err))
	root_node.free()
	quit()


# ---- Building blocks --------------------------------------------------------------------

func _add(n: Node, parent: Node = null) -> Node:
	(parent if parent else root_node).add_child(n)
	_own(n)
	return n


func _own(n: Node) -> void:
	n.owner = root_node
	for c in n.get_children():
		_own(c)


## Solid box obstacle: collision + mesh. `pos` = centre of the bottom face.
func box(name: String, size: Vector3, pos: Vector3, mat: Material, parent: Node = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = pos + Vector3(0, size.y * 0.5, 0)
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
	_add(body, parent)
	return body


## Wedge: rises from 0 to `height` along local −Z over `length`, `width` wide (local X).
func wedge(name: String, width: float, length: float, height: float, xf: Transform3D) -> void:
	var outline := PackedVector2Array([Vector2(0, length * 0.5), Vector2(0, -length * 0.5),
			Vector2(height, -length * 0.5)])
	var body := StaticBody3D.new()
	body.name = name
	body.transform = xf
	var cs := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	for p in outline:
		for x in [-width * 0.5, width * 0.5]:
			pts.append(Vector3(x, p.x, p.y))
	shape.points = pts
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = MeshUtil.prism_yz(outline, width * 0.5)
	mi.material_override = concrete
	body.add_child(mi)
	_add(body)


## Round bar from a to b (rails, posts). With collision unless `solid` is false.
func bar(name: String, a: Vector3, b: Vector3, r: float, mat: Material, solid := true, parent: Node = null) -> Node3D:
	var len := a.distance_to(b)
	var dir := (b - a) / len
	# Cylinders are built along Y: rotate Y onto the bar direction.
	var basis := Basis.IDENTITY
	var axis := Vector3.UP.cross(dir)
	if axis.length() > 1e-5:
		basis = Basis(axis.normalized(), Vector3.UP.angle_to(dir))
	var xf := Transform3D(basis, (a + b) * 0.5)
	var node: Node3D = StaticBody3D.new() if solid else Node3D.new()
	node.name = name
	node.transform = xf
	if solid:
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
	mesh.radial_segments = 16
	mi.mesh = mesh
	mi.material_override = mat
	node.add_child(mi)
	_add(node, parent)
	return node


## Thin steel angle along the top edge of an obstacle (visual "coping"; collision is the box).
func coping(name: String, from: Vector3, to: Vector3) -> void:
	bar(name, from, to, 0.008, metal, false)


# ---- The park ---------------------------------------------------------------------------

func _environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.3, 0.5, 0.85)
	sky_mat.sky_horizon_color = Color(0.72, 0.8, 0.9)
	sky_mat.ground_horizon_color = Color(0.72, 0.8, 0.9)
	sky_mat.ground_bottom_color = Color(0.3, 0.35, 0.3)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Neutral fill light: sky-coloured ambient turned every shadow blue.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.66, 0.68, 0.72)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_AGX    # natural, film-like highlights
	env.tonemap_exposure = 1.25                        # AgX is a little dark by default
	env.fog_enabled = true                 # soft haze so the far scenery sits back
	env.fog_light_color = Color(0.75, 0.82, 0.9)
	env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	_add(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-50), deg_to_rad(35), 0)), Vector3(0, 10, 0))
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.shadow_bias = 0.01
	sun.shadow_normal_bias = 0.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 4.0   # tight range = crisp shadow under the board
	_add(sun)


func _ground() -> void:
	# One big collision slab for plaza + lawn (top at y = 0).
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(400, 2, 400)
	cs.shape = shape
	cs.position = Vector3(0, -1, 0)
	ground.add_child(cs)
	var plaza := MeshInstance3D.new()
	plaza.name = "Plaza"
	var pm := PlaneMesh.new()
	pm.size = Vector2(16, 34)
	plaza.mesh = pm
	plaza.material_override = concrete
	plaza.position = Vector3(0, 0, -9)
	ground.add_child(plaza)
	var lawn := MeshInstance3D.new()
	lawn.name = "Lawn"
	var lm := PlaneMesh.new()
	lm.size = Vector2(400, 400)
	lawn.mesh = lm
	lawn.material_override = MeshUtil.shader_material("res://shaders/grass.gdshader")
	lawn.position = Vector3(0, -0.004, 0)    # just under the concrete: no z-fighting
	ground.add_child(lawn)
	_add(ground)


## Raised platform (the run-up), 3 stairs down toward −Z, a handrail, and a bank on the side
## to roll back up.
func _stairs() -> void:
	var group := Node3D.new()
	group.name = "StairSet"
	_add(group)
	box("Platform", Vector3(5, H, 6), Vector3(0, 0, STAIRS_TOP_Z + 3.0), concrete, group)
	coping("PlatformLip", Vector3(-2.5, H, STAIRS_TOP_Z), Vector3(2.5, H, STAIRS_TOP_Z))
	var steps := int(round(H / STEP_RISE))
	for i in range(1, steps):
		var top := H - STEP_RISE * i
		var z := STAIRS_TOP_Z - STEP_RUN * (i - 0.5)
		box("Step%d" % i, Vector3(5, top, STEP_RUN), Vector3(0, 0, z), concrete, group)
		coping("StepLip%d" % i, Vector3(-2.5, top, z - STEP_RUN * 0.5), Vector3(2.5, top, z - STEP_RUN * 0.5))
	# Handrail parallel to the line through the stair nosings (slope = rise / run).
	var slope := STEP_RISE / STEP_RUN
	var z0 := STAIRS_TOP_Z + 0.1
	var z1 := STAIRS_TOP_Z - STEP_RUN * steps + 0.1
	var nose_y := func(z: float) -> float: return clampf(H + slope * (z - STAIRS_TOP_Z), 0.0, H)
	var x := 1.8
	var a := Vector3(x, nose_y.call(z0) + RAIL_HEIGHT, z0)
	var b := Vector3(x, nose_y.call(z1) + RAIL_HEIGHT, z1)
	bar("Handrail", a, b, RAIL_R, metal, true, group)
	bar("RailPostTop", Vector3(x, H, z0), a, RAIL_R * 0.8, metal, true, group)
	bar("RailPostBottom", Vector3(x, 0, z1), b, RAIL_R * 0.8, metal, true, group)
	# Bank from the plaza up to the platform's west side (rise toward +X).
	wedge("Bank", 6.0, 2.5, H, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-3.75, 0, STAIRS_TOP_Z + 3.0)))


## In line with the run-up: manual pad, then a kicker.
func _line_obstacles() -> void:
	box("ManualPad", Vector3(1.6, 0.07, 2.4), Vector3(0, 0, -6.5), concrete)
	for z in [-5.3, -7.7]:
		coping("ManualPadLip", Vector3(-0.8, 0.07, z), Vector3(0.8, 0.07, z))
	wedge("Kicker", 1.6, 0.8, 0.12, Transform3D(Basis.IDENTITY, Vector3(0, 0, -13.0)))


## Beside the line: a painted ledge with coping, a flat bar, benches, planters, a hubba-ish
## low wall.
func _side_obstacles() -> void:
	box("Ledge", Vector3(0.45, 0.2, 5.0), Vector3(2.4, 0, -8.0), paint)
	coping("LedgeCoping", Vector3(2.175, 0.2, -10.5), Vector3(2.175, 0.2, -5.5))
	var bar_y := 0.12
	bar("FlatBar", Vector3(-2.2, bar_y, -6.0), Vector3(-2.2, bar_y, -11.0), RAIL_R, metal)
	for z in [-6.2, -10.8]:
		bar("FlatBarLeg", Vector3(-2.2, 0, z), Vector3(-2.2, bar_y, z), RAIL_R * 0.8, metal)
	box("LowWall", Vector3(4.0, 0.14, 0.4), Vector3(0, 0, -18.0), concrete)
	coping("LowWallCoping", Vector3(-2.0, 0.14, -17.8), Vector3(2.0, 0.14, -17.8))
	for z in [-14.0, -20.0]:
		_bench(Vector3(4.6, 0, z))
		_planter(Vector3(-4.8, 0, z))


func _bench(at: Vector3) -> void:
	var b := box("Bench", Vector3(0.5, 0.06, 1.6), at + Vector3(0, 0.18, 0), wood)
	for dz in [-0.65, 0.65]:
		box("BenchLeg", Vector3(0.4, 0.18, 0.08), at + Vector3(0, 0, dz), concrete)
	b.name = "Bench"


func _planter(at: Vector3) -> void:
	box("Planter", Vector3(1.2, 0.25, 1.2), at, concrete)
	var soil := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.05, 1.05)
	soil.mesh = pm
	soil.material_override = MeshUtil.shader_material("res://shaders/grass.gdshader")
	soil.position = at + Vector3(0, 0.252, 0)
	_add(soil)
	_tree(at + Vector3(0, 0.25, 0), 0.6)


## Scenery outside the plaza: trees and lamp posts (no collision — you can't reach them).
func _scenery() -> void:
	for z in range(-24, 8, 6):
		for x in [-10.5, 10.5]:
			_tree(Vector3(x + (z % 4) * 0.3, 0, z), 1.0)
	for z in [-20.0, -8.0, 4.0]:
		for x in [-8.6, 8.6]:
			bar("LampPost", Vector3(x, 0, z), Vector3(x, 6, z), 0.07, metal, false)
			var head := MeshInstance3D.new()
			var hb := BoxMesh.new()
			hb.size = Vector3(0.6, 0.15, 0.3)
			head.mesh = hb
			head.material_override = metal
			head.position = Vector3(x - signf(x) * 0.3, 6.0, z)
			_add(head)


func _tree(at: Vector3, s: float) -> void:
	var bark := MeshUtil.material(Color(0.35, 0.25, 0.16), 0.9)
	var leaves := MeshUtil.material(Color(0.2, 0.42, 0.16), 0.9)
	bar("Trunk", at, at + Vector3(0, 5.0 * s, 0), 0.22 * s, bark, false)
	for k in 3:
		var c := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = (1.9 - k * 0.35) * s
		sm.height = sm.radius * 1.7
		c.mesh = sm
		c.material_override = leaves
		c.position = at + Vector3((k - 1) * 0.5 * s, (5.0 + k * 1.0) * s, (k % 2) * 0.4 * s)
		_add(c)
