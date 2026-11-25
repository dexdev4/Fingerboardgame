## Inside your cabin: a walkable room (floor, walls and ceiling with collision), drawn for its
## upgrades (log / planed / plastered walls; dirt / plank / stone floor) with every placed piece
## of furniture and decor. In build mode it shows the grid and a ghost of the item being placed.
## The room lives far above the forest (ORIGIN) so its collision never touches the world.
class_name CabinInterior
extends Node2D

const ORIGIN := Vector2(0, -4000)

var t: GameTuning
var cabin: Cabin
## Build mode: the item being placed ("" = none) and where the ghost is (cell), and whether
## the remove tool is active.
var build_mode := false
var ghost_id := ""
var ghost_cell := Vector2i(-99, -99)
var remove_mode := false
var daylight := 1.0
var _body: StaticBody2D
var _t := 0.0


func setup(tuning: GameTuning, c: Cabin) -> void:
	t = tuning
	cabin = c
	position = ORIGIN
	_body = StaticBody2D.new()
	_body.collision_layer = 1
	add_child(_body)
	rebuild()


## Rebuild the room's collision (after an extension) and redraw.
func rebuild() -> void:
	for c in _body.get_children():
		c.free()
	var s := float(t.tile_size)
	var w := cabin.width() * s
	var h := cabin.height() * s
	_add_box(Rect2(-s * 2, h - s, w + s * 4, s * 2))     # floor (top at the floor row)
	_add_box(Rect2(-s * 2, -s * 2, s * 2, h + s * 2))     # left wall
	_add_box(Rect2(w, -s * 2, s * 2, h + s * 2))          # right wall (the door is drawn on it)
	_add_box(Rect2(-s * 2, -s * 2, w + s * 4, s * 2))     # ceiling
	queue_redraw()


func _add_box(r: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.position = r.position + r.size * 0.5
	_body.add_child(shape)


## Floor y (px, global) where the player stands, and the spot just inside the door.
func floor_y() -> float:
	return global_position.y + (cabin.height() - 1) * t.tile_size


func door_spot() -> Vector2:
	return global_position + Vector2((cabin.width() - 1.5) * t.tile_size, (cabin.height() - 1) * t.tile_size - 8)


## Spot beside the bed (where you wake up).
func bed_spot() -> Vector2:
	for p in cabin.placed:
		if Catalog.FUNCTIONS.get(p.id, "") == "bed":
			return global_position + Vector2((p.x + Cabin.size_of(p.id).x + 0.5) * t.tile_size, floor_y() - global_position.y - 8)
	return door_spot()


## Room cell (col, row) under a global point.
func cell_at(p: Vector2) -> Vector2i:
	var l := p - global_position
	return Vector2i(floori(l.x / t.tile_size), floori(l.y / t.tile_size))


func is_door(cell: Vector2i) -> bool:
	return cell.x == cabin.width() - 1 and cell.y >= cabin.height() - 4 and cell.y <= cabin.height() - 1


## Pixel rectangle (global) of the whole room.
func room_rect() -> Rect2:
	return Rect2(global_position, Vector2(cabin.width(), cabin.height()) * t.tile_size)


## Where to put item `id` for a tap at room cell `c` (floor items: on the floor at that column,
## centred on the finger; wall items: their top-left near the finger).
func placement_for(id: String, c: Vector2i) -> Vector2i:
	var sz := Cabin.size_of(id)
	var x := c.x - (sz.x - 1) / 2
	if Cabin.layer(id) == "wall":
		return Vector2i(x, clampi(c.y - (sz.y - 1) / 2, 1, cabin.wall_bottom() - sz.y + 1))
	return Vector2i(x, 0)


func _process(dt: float) -> void:
	_t += dt
	if visible:
		queue_redraw()


# ---- Drawing --------------------------------------------------------------------------------

func _draw() -> void:
	var s := float(t.tile_size)
	var w := cabin.width()
	var h := cabin.height()
	_draw_walls(w, h, s)
	_draw_floor(w, h, s)
	# Ceiling beam and corner posts.
	draw_rect(Rect2(0, 0, w * s, 4), Pal.BARK_DARK)
	draw_rect(Rect2(0, 4, w * s, 1), Pal.BARK)
	for x in range(0, w, 7):
		draw_rect(Rect2(x * s, 0, 3, (h - 1) * s), Pal.BARK_DARK)
	_draw_door(w, h, s)
	# Furniture: rugs, then wall decor, then floor furniture in front.
	for lay in ["rug", "wall", "floor"]:
		for p in cabin.placed:
			if Cabin.layer(p.id) == lay:
				_draw_item(p.id, p.x, p.y, Color.WHITE)
	if build_mode:
		_draw_build_overlay(w, h, s)


func _draw_walls(w: int, h: int, s: float) -> void:
	var rect := Rect2(0, 0, w * s, (h - 1) * s)
	match cabin.wall_type:
		"logs":     # rough horizontal logs with dark chinks between them
			draw_rect(rect, Pal.BARK)
			for y in range(0, int(rect.size.y), 6):
				draw_rect(Rect2(0, y, rect.size.x, 1), Pal.BARK_DARK)
				draw_rect(Rect2(0, y + 1, rect.size.x, 1), Pal.WOOD)
				for x in range(int(HashNoise.hash_f(3, y, 0, 1) * 9), int(rect.size.x), 23):
					draw_rect(Rect2(x, y + 3, 2, 1), Pal.BARK_DARK)    # knots
		"walls_planks":   # planed vertical boards
			draw_rect(rect, Pal.WOOD)
			for x in range(0, int(rect.size.x), 5):
				draw_rect(Rect2(x, 0, 1, rect.size.y), Pal.BARK)
		"walls_plaster":  # whitewash with timber framing
			draw_rect(rect, Pal.CREAM)
			draw_rect(Rect2(0, rect.size.y * 0.45, rect.size.x, 2), Pal.BARK_DARK)
			for x in range(0, int(rect.size.x), 28):
				draw_line(Vector2(x, 4), Vector2(x + 14, rect.size.y * 0.45), Pal.BARK_DARK)
	# Shadow along the bottom of the wall.
	draw_rect(Rect2(0, rect.size.y - 2, rect.size.x, 2), Color(0, 0, 0, 0.25))


func _draw_floor(w: int, h: int, s: float) -> void:
	var y := (h - 1) * s
	match cabin.floor_type:
		"dirt":
			draw_rect(Rect2(0, y, w * s, s), Pal.BARK_DARK)
			for x in range(0, w * int(s), 3):
				if HashNoise.hash_f(4, x, 0, 2) < 0.4:
					draw_rect(Rect2(x, y + 1 + int(HashNoise.hash_f(4, x, 1, 2) * 6), 1, 1), Pal.BARK)
		"floor_planks":
			draw_rect(Rect2(0, y, w * s, s), Pal.WOOD)
			draw_rect(Rect2(0, y, w * s, 1), Pal.TAN)
			for x in range(0, w * int(s), 12):
				draw_rect(Rect2(x, y + 1, 1, s - 1), Pal.BARK)
		"floor_stone":
			draw_rect(Rect2(0, y, w * s, s), Pal.STONE)
			draw_rect(Rect2(0, y, w * s, 1), Pal.STONE_LIGHT)
			for x in range(0, w * int(s), 8):
				draw_rect(Rect2(x, y + 1, 1, s - 1), Pal.STONE_DARK)


func _draw_door(w: int, h: int, s: float) -> void:
	var r := Rect2((w - 1) * s, (h - 4) * s, s, s * 3)
	draw_rect(r.grow(1), Pal.BARK_DARK)
	draw_rect(r, Pal.WOOD)
	draw_rect(Rect2(r.position + Vector2(3, 0), Vector2(1, r.size.y)), Pal.BARK)
	draw_rect(Rect2(r.position + Vector2(1, 11), Vector2(2, 2)), Pal.YELLOW)   # latch


## Draw one item at column x (row y for wall items), tinted (ghosts are green/red).
func _draw_item(id: String, x: int, y: int, tint: Color) -> void:
	var tex := Sprites.furniture(id)
	var s := float(t.tile_size)
	var pos: Vector2
	match Cabin.layer(id):
		"floor":
			pos = Vector2(x * s, (cabin.height() - 1) * s - tex.get_height())
		"rug":
			pos = Vector2(x * s, (cabin.height() - 1) * s - 1)
		"wall":
			pos = Vector2(x * s, y * s)
	draw_texture(tex, pos, tint)
	if id == "hearth" and tint == Color.WHITE:   # the fire flickers and glows
		var f := 0.5 + 0.5 * sin(_t * 9.0) * sin(_t * 5.3)
		draw_rect(Rect2(pos + Vector2(6, 13), Vector2(4, 4)), Color(Pal.YELLOW, 0.25 + 0.35 * f))
		draw_rect(Rect2(pos + Vector2(7, 12 + int(f * 2)), Vector2(1, 1)), Pal.YELLOW)
	elif (id == "candle_stand" or id == "sconce") and tint == Color.WHITE and int(_t * 6.0) % 3 == 0:
		draw_rect(Rect2(pos + Vector2(3, 0), Vector2(1, 1)), Pal.WHITE)


func _draw_build_overlay(w: int, h: int, s: float) -> void:
	var grid := Color(Pal.CREAM, 0.12)
	for x in range(w + 1):
		draw_rect(Rect2(x * s, s, 1, (h - 2) * s), grid)
	for y in range(1, h):
		draw_rect(Rect2(0, y * s, w * s, 1), grid)
	# Wall-hanging zone.
	draw_rect(Rect2(0, s, w * s, cabin.wall_bottom() * s), Color(Pal.SKY, 0.06))
	if ghost_id != "" and ghost_cell.x > -50:
		var at := placement_for(ghost_id, ghost_cell)
		var ok := cabin.can_place(ghost_id, at.x, at.y) == ""
		_draw_item(ghost_id, at.x, at.y, Color(0.6, 1.0, 0.6, 0.8) if ok else Color(1.0, 0.4, 0.4, 0.7))
