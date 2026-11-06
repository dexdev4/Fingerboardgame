## Adds grind spots to the EXISTING park scene (keeps anything you've edited in the editor):
##   godot --headless --path . -s res://tools/add_grind_spots.gd
## Safe to run more than once: spots that already exist are left alone.
##
## 1. Tags every obstacle with "slide_friction_scale" — how slick its surface is for grinds and
##    slides (multiplies grind_mu / slide_mu in board_tuning.tres): steel 0.6, painted 0.8,
##    concrete 1.0.
## 2. The board can't steer yet and rolls straight down x = 0, so two spots go ON that line:
##    - LineRail: a flat bar along the line (50-50 / 5-0 / nosegrind, or boardslide if sideways)
##    - LineLedge: a ledge whose steel-coped edge runs along the line, so trucks lock onto the
##      edge with one pair of wheels on top and the other hanging off (ledge 50-50).
extends SceneTree

const PARK := "res://scenes/skatepark.tscn"
const STEEL := 0.6
const PAINTED := 0.8
const CONCRETE := 1.0
## The ledge's grind edge sits a little LEFT of the line (x = 0). A real ledge 50-50 is stable
## only with the board's centre over the ledge side of the edge (hanger on the edge, inside
## wheels on top, board tilted), so a board rolling straight down x = 0 locks in.
const LEDGE_EDGE_X := -0.07

var root_node: Node3D


func _initialize() -> void:
	root_node = load(PARK).instantiate()
	_tag_surfaces()
	var metal := _material_of("FlatBar")
	var concrete := _material_of("ManualPad")
	if not root_node.has_node("LineRail"):
		_add_rail(metal)
	if not root_node.has_node("LineLedge"):
		_add_ledge(concrete, metal)
	var packed := PackedScene.new()
	packed.pack(root_node)
	print("saved skatepark.tscn: ", error_string(ResourceSaver.save(packed, PARK)))
	root_node.free()
	quit()


## Every StaticBody3D gets a slickness. Names decide it: rails/bars/posts are steel, the yellow
## ledge is painted (with steel coping), everything else is concrete.
func _tag_surfaces() -> void:
	for n in root_node.find_children("*", "StaticBody3D", true, false):
		if n.has_meta("slide_friction_scale"):
			continue
		var name := String(n.name).to_lower()
		var scale := CONCRETE
		if "rail" in name or "bar" in name or "post" in name or "leg" in name and "bench" not in name:
			scale = STEEL
		elif name == "ledge":
			scale = PAINTED
		n.set_meta("slide_friction_scale", scale)
	# Unnamed duplicates of the flat bar's legs (auto-named by Godot) are steel too.
	for n in root_node.get_children():
		if n is StaticBody3D and String(n.name).begins_with("@") and _is_thin_bar(n):
			n.set_meta("slide_friction_scale", STEEL)


func _is_thin_bar(n: Node) -> bool:
	for c in n.get_children():
		if c is CollisionShape3D and c.shape is CylinderShape3D:
			return true
	return false


func _material_of(node_name: String) -> Material:
	var n := root_node.get_node_or_null(node_name)
	if n:
		for c in n.get_children():
			if c is MeshInstance3D:
				return c.material_override
	return MeshUtil.material(Color(0.6, 0.6, 0.62), 0.4, 0.8)


## Flat bar along the line (x = 0), between the manual pad and the kicker.
## Bar Ø 4 mm (Ø 32 mm real-park bar at 1:8), top 12 mm off the ground: an easy ollie-on.
func _add_rail(metal: Material) -> void:
	var r := 0.02
	var y := 0.1
	var z0 := -8.9
	var z1 := -11.9
	var rail := _bar("LineRail", Vector3(0, y, z0), Vector3(0, y, z1), r, metal, STEEL)
	for z in [z0 - 0.15, z1 + 0.15]:                  # legs just inside each end
		_bar("LineRailLeg", Vector3(0, 0, z), Vector3(0, y, z), r * 0.8, metal, STEEL)
	rail.set_meta("note", "In line with the run-up: ollie on for a 50-50 or a boardslide.")


## Ledge whose LEFT top edge (x = LEDGE_EDGE_X) runs along the line, with steel coping on it.
func _add_ledge(concrete: Material, metal: Material) -> void:
	var size := Vector3(0.8, 0.15, 5.0)
	var body := StaticBody3D.new()
	body.name = "LineLedge"
	body.position = Vector3(LEDGE_EDGE_X + size.x * 0.5, size.y * 0.5, -21.9)
	body.set_meta("slide_friction_scale", STEEL)    # you grind its steel-coped edge
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = concrete
	body.add_child(mi)
	_own(body)
	# Visible steel angle along the grindable edge.
	var coping := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.008
	cm.bottom_radius = 0.008
	cm.height = size.z
	coping.mesh = cm
	coping.material_override = metal
	coping.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-size.x * 0.5, size.y * 0.5, 0))
	body.add_child(coping)
	_own(body)


func _bar(name: String, a: Vector3, b: Vector3, r: float, mat: Material, slick: float) -> StaticBody3D:
	var len := a.distance_to(b)
	var dir := (b - a) / len
	var basis := Basis.IDENTITY
	var axis := Vector3.UP.cross(dir)
	if axis.length() > 1e-5:
		basis = Basis(axis.normalized(), Vector3.UP.angle_to(dir))
	var body := StaticBody3D.new()
	body.name = name
	body.transform = Transform3D(basis, (a + b) * 0.5)
	body.set_meta("slide_friction_scale", slick)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = len
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = r
	mesh.bottom_radius = r
	mesh.height = len
	mesh.radial_segments = 16
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	_own(body)
	return body


func _own(n: Node) -> void:
	if n.get_parent() == null:
		root_node.add_child(n)
	n.owner = root_node
	for c in n.get_children():
		_own_child(c)


func _own_child(n: Node) -> void:
	n.owner = root_node
	for c in n.get_children():
		_own_child(c)
