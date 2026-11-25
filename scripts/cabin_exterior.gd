## Your cabin seen from the forest, at tile x = 0. It grows with extensions; its roof is thatch or
## shingles; a chimney smokes once there's a hearth; windows glow at night when a light is
## inside. Not solid: walk past it, tap it (when close) to go in. Visual only.
class_name CabinExterior
extends Node2D

var t: GameTuning
var cabin: Cabin
var _t := 0.0


func setup(tuning: GameTuning, c: Cabin) -> void:
	t = tuning
	cabin = c
	position = Vector2(0.5 * t.tile_size, t.surface_base * t.tile_size)   # on the clearing's ground
	z_index = -1


## Outside width (px): 6 tiles plus 2 per extension.
func outer_width() -> float:
	return (6 + cabin.extensions * 2) * t.tile_size


## Tap target (global).
func rect() -> Rect2:
	var w := outer_width()
	return Rect2(global_position + Vector2(-w * 0.5, -46), Vector2(w, 46))


func door_x() -> float:
	return global_position.x + outer_width() * 0.5 - 12


func in_range(p: Vector2) -> bool:
	return absf(p.x - global_position.x) <= outer_width() * 0.5 + 12 and absf(p.y - global_position.y) < 40


func _process(dt: float) -> void:
	_t += dt
	queue_redraw()


func _draw() -> void:
	var w := outer_width()
	var x0 := -w * 0.5
	var wall_h := 22.0
	# Stone footing and log walls.
	draw_rect(Rect2(x0 - 1, -3, w + 2, 3), Pal.STONE)
	for i in range(int(wall_h / 4)):
		var y := -3 - (i + 1) * 4
		draw_rect(Rect2(x0, y, w, 4), Pal.BARK if i % 2 == 0 else Pal.WOOD)
		draw_rect(Rect2(x0, y, w, 1), Pal.BARK_DARK)
		draw_rect(Rect2(x0 - 2, y + 1, 3, 3), Pal.TAN)            # log ends at the corners
		draw_rect(Rect2(x0 + w - 1, y + 1, 3, 3), Pal.TAN)
	var top := -3 - wall_h
	# Door (right side) and windows.
	var dx := w * 0.5 - 14
	draw_rect(Rect2(dx, -17, 8, 14), Pal.BARK_DARK)
	draw_rect(Rect2(dx + 1, -16, 6, 13), Pal.WOOD)
	draw_rect(Rect2(dx + 5, -10, 1, 1), Pal.YELLOW)
	var lit := cabin.light(0.0) > t.cabin_base_light + 0.05
	var night_glow := Color(Pal.YELLOW, 0.9) if lit else Pal.NIGHT
	var n_windows := 1 + cabin.extensions
	for i in n_windows:
		var wx := x0 + 6 + i * 16
		draw_rect(Rect2(wx - 1, -18, 9, 8), Pal.BARK_DARK)
		draw_rect(Rect2(wx, -17, 7, 6), night_glow if lit else Pal.SKY.darkened(0.3))
		draw_rect(Rect2(wx + 3, -17, 1, 6), Pal.BARK_DARK)
	# Roof: thatch (straw, ragged edge) or shingles (rows of dark tiles).
	var roof_h := 18.0
	var eave := 5.0
	var pts := PackedVector2Array([Vector2(x0 - eave, top + 1), Vector2(0, top - roof_h), Vector2(x0 + w + eave, top + 1)])
	if cabin.roof_type == "thatch":
		draw_colored_polygon(pts, Color("b8913f"))
		for i in range(int(roof_h / 3)):
			var y := top - i * 3
			var half := (w * 0.5 + eave) * (1.0 - float(i * 3) / roof_h)
			draw_line(Vector2(-half, y), Vector2(half, y), Color("8a6a2a"))
		for x in range(int(x0 - eave), int(x0 + w + eave), 2):
			draw_rect(Rect2(x, top + 1, 1, 1 + (x % 3)), Color("8a6a2a"))   # ragged straw eave
	else:
		draw_colored_polygon(pts, Pal.RED.darkened(0.3))
		for i in range(int(roof_h / 3)):
			var y := top - i * 3
			var half := (w * 0.5 + eave) * (1.0 - float(i * 3) / roof_h)
			draw_line(Vector2(-half, y), Vector2(half, y), Pal.BARK_DARK)
			for x in range(int(-half), int(half), 4):
				draw_rect(Rect2(x + (i % 2) * 2, y - 2, 1, 2), Pal.BARK_DARK)
	# Chimney and smoke once there's a hearth inside.
	if cabin.has_function("hearth"):
		var cx := x0 + w * 0.25
		draw_rect(Rect2(cx, top - 16, 5, 14), Pal.STONE)
		draw_rect(Rect2(cx, top - 16, 5, 1), Pal.STONE_LIGHT)
		for i in 4:
			var k := fmod(_t * 0.25 + i * 0.25, 1.0)
			var r := 1.5 + k * 3.0
			draw_circle(Vector2(cx + 2 + sin(k * 6.0 + i) * 3.0, top - 18 - k * 26.0), r, Color(Pal.STONE_LIGHT, 0.5 * (1.0 - k)))
