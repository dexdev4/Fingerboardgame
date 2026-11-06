## Adds more street spots and city scenery to the EXISTING park (keeps your editor edits):
##   godot --headless --path . -s res://tools/add_plaza_details.gd
## Idempotent: anything already present (by name) is skipped. Every new solid gets a
## "slide_friction_scale" for grinds/slides (steel 0.6, painted 0.8, concrete 1.0).
## Scale 1:8 like the rest of the park (1 unit = 10 cm in fingerboard scale).
extends SceneTree

const PARK := "res://scenes/skatepark.tscn"
const STEEL := 0.6
const PAINTED := 0.8
const CONCRETE := 1.0

var root_node: Node3D
var concrete: Material
var metal: Material
var red_paint: StandardMaterial3D
var wood: StandardMaterial3D
var dark: StandardMaterial3D


func _initialize() -> void:
	root_node = load(PARK).instantiate()
	concrete = _material_of("ManualPad", MeshUtil.shader_material("res://shaders/concrete.gdshader"))
	metal = _material_of("FlatBar", MeshUtil.material(Color(0.62, 0.64, 0.68), 0.3, 0.9))
	red_paint = MeshUtil.material(Color(0.75, 0.16, 0.12), 0.6)
	wood = MeshUtil.material(Color(0.5, 0.34, 0.2), 0.8)
	dark = MeshUtil.material(Color(0.18, 0.19, 0.2), 0.5, 0.4)

	_spot("Hubba", _hubba)
	_spot("Funbox", _funbox)
	_spot("LongLedge", _long_ledge)
	_spot("RedCurb", _red_curb)
	_spot("RightBank", _right_bank)
	_spot("PicnicTable", _picnic_table)
	_spot("TrashCans", _trash_cans)
	_spot("Bollards", _bollards)
	_spot("City", _city)
	_spot("Fence", _fence)

	var packed := PackedScene.new()
	packed.pack(root_node)
	print("saved skatepark.tscn: ", error_string(ResourceSaver.save(packed, PARK)))
	root_node.free()
	quit()


## Builds a spot under a group node called `name`, unless one already exists.
func _spot(name: String, build: Callable) -> void:
	if root_node.has_node(name):
		return
	var group := Node3D.new()
	group.name = name
	root_node.add_child(group)
	group.owner = root_node
	build.call(group)
	_own(group)


func _material_of(node_name: String, fallback: Material) -> Material:
	var n := root_node.get_node_or_null(node_name)
	if n:
		for c in n.get_children():
			if c is MeshInstance3D and c.material_override:
				return c.material_override
	return fallback


# ---- Spots ------------------------------------------------------------------------------

## Hubba: a ledge running down beside the stair set (left side), top 0.15 above the nosings,
## with steel coping on its inner top edge. The stairs drop from y 0.45 at z −1.0 to 0 at z −1.9.
func _hubba(g: Node3D) -> void:
	var outline := PackedVector2Array([Vector2(0.0, -2.15), Vector2(0.0, -0.75),
			Vector2(0.62, -0.75), Vector2(0.62, -1.0), Vector2(0.12, -2.15)])
	_prism(g, "HubbaBody", outline, 0.2, Transform3D(Basis.IDENTITY, Vector3(-2.25, 0, 0)), concrete, PAINTED)
	_visual_bar(g, Vector3(-2.05, 0.62, -0.75), Vector3(-2.05, 0.62, -1.0), 0.008, metal)
	_visual_bar(g, Vector3(-2.05, 0.62, -1.0), Vector3(-2.05, 0.12, -2.15), 0.008, metal)


## Funbox: flat top with banks on the front and back, coped side edges — grind the edges,
## manual the top, ollie up the banks.
func _funbox(g: Node3D) -> void:
	var at := Vector3(3.6, 0, -15.5)
	var h := 0.18
	_box(g, "FunboxTop", Vector3(1.4, h, 1.6), at, concrete, CONCRETE)
	for side in [-1.0, 1.0]:
		# Banks rise toward the top from each end (along z).
		var outline := PackedVector2Array([Vector2(0, -side * 0.6), Vector2(0, side * 0.6), Vector2(h, -side * 0.6)])
		_prism(g, "FunboxBank", outline, 0.7, Transform3D(Basis.IDENTITY, at + Vector3(0, 0, side * 1.4)), concrete, CONCRETE)
		_visual_bar(g, at + Vector3(side * 0.7, h, -0.8), at + Vector3(side * 0.7, h, 0.8), 0.008, metal)


## A long concrete ledge with coping along the left of the plaza.
func _long_ledge(g: Node3D) -> void:
	_box(g, "LongLedgeBody", Vector3(0.45, 0.18, 7.0), Vector3(-4.6, 0, -16.0), concrete, STEEL)
	_visual_bar(g, Vector3(-4.375, 0.18, -19.5), Vector3(-4.375, 0.18, -12.5), 0.008, metal)


## Red-painted curb down the left edge of the plaza — the classic curb grind.
func _red_curb(g: Node3D) -> void:
	_box(g, "RedCurbBody", Vector3(0.3, 0.06, 24.0), Vector3(-6.8, 0, -10.0), red_paint, PAINTED)


## A bank on the right side, rising toward the edge of the plaza.
func _right_bank(g: Node3D) -> void:
	var outline := PackedVector2Array([Vector2(0, 0.9), Vector2(0, -0.9), Vector2(0.3, -0.9)])
	_prism(g, "RightBankBody", outline, 2.0, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(6.6, 0, -7.0)), concrete, CONCRETE)


## Picnic table: wooden top and benches on concrete feet — a real street-spot obstacle.
func _picnic_table(g: Node3D) -> void:
	var at := Vector3(5.6, 0, -22.0)
	_box(g, "TableTop", Vector3(0.7, 0.04, 1.8), at + Vector3(0, 0.36, 0), wood, CONCRETE)
	for dx in [-0.55, 0.55]:
		_box(g, "TableSeat", Vector3(0.25, 0.035, 1.8), at + Vector3(dx, 0.22, 0), wood, CONCRETE)
	for dz in [-0.7, 0.7]:
		_box(g, "TableFoot", Vector3(1.4, 0.22, 0.1), at + Vector3(0, 0, dz), concrete, CONCRETE)
		_box(g, "TableLeg", Vector3(0.1, 0.14, 0.1), at + Vector3(0, 0.22, dz), concrete, CONCRETE)


func _trash_cans(g: Node3D) -> void:
	for p in [Vector3(-6.0, 0, 2.5), Vector3(6.2, 0, -12.0), Vector3(-3.0, 0, -24.5)]:
		_cylinder(g, "TrashCan", p, 0.2, 0.42, dark, STEEL)


func _bollards(g: Node3D) -> void:
	for i in 6:
		_cylinder(g, "Bollard", Vector3(-2.5 + i, 0, 7.4), 0.06, 0.35, dark, STEEL)


## City blocks around the plaza (scenery, no collision): buildings with window grids.
func _city(g: Node3D) -> void:
	var mat := MeshUtil.shader_material("res://shaders/building.gdshader")
	var tint := [Color(0.62, 0.58, 0.52), Color(0.55, 0.52, 0.5), Color(0.66, 0.6, 0.5), Color(0.5, 0.5, 0.55)]
	var k := 0
	for z in range(-34, 14, 8):
		for x in [-17.0, 17.0]:
			var height := 8.0 + float((k * 7) % 9)
			var m := mat.duplicate() as ShaderMaterial
			m.set_shader_parameter("facade", tint[k % tint.size()])
			_visual_box(g, Vector3(7.0, height, 7.5), Vector3(x, height * 0.5, z), m)
			k += 1
	for x in range(-14, 16, 8):
		var height := 9.0 + float((k * 5) % 8)
		var m := mat.duplicate() as ShaderMaterial
		m.set_shader_parameter("facade", tint[k % tint.size()])
		_visual_box(g, Vector3(7.5, height, 7.0), Vector3(x, height * 0.5, -40.0), m)
		k += 1


## Low fence along the back of the plaza (scenery).
func _fence(g: Node3D) -> void:
	for i in 17:
		var x := -8.0 + i
		_visual_bar(g, Vector3(x, 0, -26.2), Vector3(x, 1.0, -26.2), 0.03, metal)
	for y in [0.45, 0.95]:
		_visual_bar(g, Vector3(-8, y, -26.2), Vector3(8, y, -26.2), 0.02, metal)


# ---- Building blocks ------------------------------------------------------------------------

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


## Solid prism from a (y, z) outline extruded ±half_x along X (wedges, hubbas).
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


func _cylinder(parent: Node3D, name: String, bottom: Vector3, r: float, h: float, mat: Material, slick: float) -> void:
	var body := StaticBody3D.new()
	body.name = name
	body.position = bottom + Vector3(0, h * 0.5, 0)
	body.set_meta("slide_friction_scale", slick)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = h
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = r
	mesh.bottom_radius = r
	mesh.height = h
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	parent.add_child(body)


func _visual_box(parent: Node3D, size: Vector3, centre: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = centre
	parent.add_child(mi)


## Round bar with no collision (coping lines, fence posts).
func _visual_bar(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material) -> void:
	var len := a.distance_to(b)
	var dir := (b - a) / len
	var basis := Basis.IDENTITY
	var axis := Vector3.UP.cross(dir)
	if axis.length() > 1e-5:
		basis = Basis(axis.normalized(), Vector3.UP.angle_to(dir))
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = r
	mesh.bottom_radius = r
	mesh.height = len
	mesh.radial_segments = 10
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = Transform3D(basis, (a + b) * 0.5)
	parent.add_child(mi)


func _own(n: Node) -> void:
	n.owner = root_node
	for c in n.get_children():
		_own(c)
