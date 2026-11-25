## The sky behind the world: a gradient that follows the time of day, stars at night, a ringed gas
## giant and two moons, and two layers of distant alien mountains that scroll slower than the
## world (parallax). Drawn in code on a background canvas layer. Visual only.
class_name Background
extends CanvasLayer

var world_seed := 0
## Set every frame by Main: camera centre (px) and daylight (0 night … 1 day).
var camera_pos := Vector2.ZERO
var daylight := 1.0
var _canvas: Control


func setup(seed_value: int) -> void:
	world_seed = seed_value
	layer = -10
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_sky)
	add_child(_canvas)


func _process(_dt: float) -> void:
	_canvas.queue_redraw()


func _draw_sky() -> void:
	var size := _canvas.get_viewport_rect().size
	var d := daylight
	# Sky: violet-pink by day, deep indigo at night.
	var top := Color("1b1440").lerp(Color("6d4fa3"), d)
	var bottom := Color("2a1838").lerp(Color("e39b8a"), d)
	var bands := 24
	for i in bands:
		var y0 := size.y * i / bands
		_canvas.draw_rect(Rect2(0, y0, size.x, size.y / bands + 1), top.lerp(bottom, float(i) / bands))
	# Stars fade in at night (fixed positions from a hash).
	if d < 0.9:
		for i in 90:
			var p := Vector2(HashNoise.hash_f(3, i, 0, 1) * size.x, HashNoise.hash_f(3, i, 1, 1) * size.y * 0.7)
			_canvas.draw_circle(p, 1.0 + HashNoise.hash_f(3, i, 2, 1) * 1.2, Color(1, 1, 1, (1.0 - d) * 0.9))
	# Ringed gas giant, drifting very slowly with the camera.
	var gp := Vector2(size.x * 0.72 - camera_pos.x * 0.004, size.y * 0.18)
	_canvas.draw_circle(gp, 70.0, Color("c2553a").lerp(Color("7a3a3a"), 1.0 - d))
	_canvas.draw_circle(gp + Vector2(18, 14), 54.0, Color(0, 0, 0, 0.18))
	_draw_ring(gp, Color(0.5, 0.88, 0.82, 0.55))
	# Two small moons.
	_canvas.draw_circle(Vector2(size.x * 0.2, size.y * 0.1), 14.0, Color("d8d4e8"))
	_canvas.draw_circle(Vector2(size.x * 0.32, size.y * 0.16), 8.0, Color("b5c7d6"))
	# Distant mountains (two layers, slower = farther).
	_mountains(size, 0.12, size.y * 0.55, 160.0, Color("3b2a5a").lerp(Color("8a5f8f"), d * 0.6), 5)
	_mountains(size, 0.25, size.y * 0.64, 120.0, Color("2a1d40").lerp(Color("5e3f6e"), d * 0.6), 9)


func _draw_ring(c: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		pts.append(c + Vector2(cos(a) * 118.0, sin(a) * 20.0).rotated(-0.25))
	_canvas.draw_polyline(pts, col, 4.0)


## A mountain silhouette whose height comes from 1D noise of (screen x + camera x × parallax).
func _mountains(size: Vector2, parallax: float, base_y: float, height: float, col: Color, salt: int) -> void:
	var pts := PackedVector2Array([Vector2(0, size.y)])
	var step := 16.0
	var off := camera_pos.x * parallax
	var x := 0.0
	while x <= size.x + step:
		var n := HashNoise.fbm1(world_seed, salt, (x + off) / 220.0, 3)
		pts.append(Vector2(x, base_y - n * height))
		x += step
	pts.append(Vector2(size.x + step, size.y))
	_canvas.draw_colored_polygon(pts, col)
