## The sky and distant forest behind the world: a banded 8-bit sky that follows the time of day,
## sun and moon, stars at night, and three layers of hills and tree-line silhouettes that scroll
## slower than the world (parallax). Inside the cabin it's just darkness. Visual only.
class_name Background
extends CanvasLayer

var world_seed := 0
## Set every frame by Main.
var camera_pos := Vector2.ZERO
var daylight := 1.0
var time := 0.0
## Share of the day that is daytime (1 − night_fraction), set by Main.
var day_fraction := 0.65
var inside := false
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
	if inside:
		_canvas.draw_rect(Rect2(Vector2.ZERO, size), Pal.INK)
		return
	var d := daylight
	# Banded sky: 8 flat bands (no smooth gradient — it's 8-bit).
	var top := Pal.NIGHT.lerp(Color("4f86b8"), d)
	var bottom := Color("2a2440").lerp(Color("bfe0e8"), d)
	var dusk := clampf(1.0 - absf(d - 0.5) * 2.0, 0.0, 1.0)   # warm tint at dawn and dusk
	bottom = bottom.lerp(Pal.ORANGE, dusk * 0.5)
	var bands := 8
	for i in bands:
		var y0 := floorf(size.y * 0.7 * i / bands)
		_canvas.draw_rect(Rect2(0, y0, size.x, size.y), top.lerp(bottom, float(i) / (bands - 1)))
	# Stars.
	if d < 0.8:
		for i in 40:
			var p := Vector2(floorf(HashNoise.hash_f(3, i, 0, 1) * size.x), floorf(HashNoise.hash_f(3, i, 1, 1) * size.y * 0.5))
			if HashNoise.hash_f(3, i, 2, 1) < 1.0 - d:
				_canvas.draw_rect(Rect2(p, Vector2.ONE), Pal.WHITE)
	# Sun by day, moon by night, arcing across the sky.
	var arc_t := clampf(time / maxf(day_fraction, 0.01), 0.0, 1.0)
	if d > 0.05:
		var sp := Vector2(size.x * (0.1 + 0.8 * arc_t), size.y * 0.5 - sin(arc_t * PI) * size.y * 0.24).floor()
		_canvas.draw_rect(Rect2(sp - Vector2(4, 4), Vector2(9, 9)), Pal.YELLOW)
		_canvas.draw_rect(Rect2(sp - Vector2(3, 5), Vector2(7, 11)), Pal.YELLOW)
		_canvas.draw_rect(Rect2(sp - Vector2(5, 3), Vector2(11, 7)), Pal.YELLOW)
	else:
		var mp := Vector2(size.x * 0.72, size.y * 0.3).floor()
		_canvas.draw_rect(Rect2(mp - Vector2(3, 3), Vector2(7, 7)), Pal.CREAM)
		_canvas.draw_rect(Rect2(mp + Vector2(-1, -3), Vector2(4, 4)), top)       # crescent bite
	# Distant hills, then two tree lines (darker = nearer).
	var fog := Color("6f8fa8").lerp(Pal.NIGHT, 1.0 - d)
	_hills(size, 0.06, size.y * 0.55, 34.0, Color("5d7a8a").lerp(Color("1d2236"), 1.0 - d), 3)
	_treeline(size, 0.14, size.y * 0.62, 22.0, Pal.LEAF_DARK.lerp(fog, 0.55), 5, 10.0)
	_treeline(size, 0.28, size.y * 0.7, 26.0, Pal.LEAF_DARK.lerp(Pal.INK, 0.3 + (1.0 - d) * 0.5), 9, 8.0)


## Rolling hills from 1D noise (pixel-stepped).
func _hills(size: Vector2, parallax: float, base_y: float, height: float, col: Color, salt: int) -> void:
	var off := camera_pos.x * parallax
	for x in range(0, int(size.x), 2):
		var n := HashNoise.fbm1(world_seed, salt, (x + off) / 90.0, 2)
		var y := floorf(base_y - n * height)
		_canvas.draw_rect(Rect2(x, y, 2, size.y - y), col)


## A tree line: a band with pointed pine tops every `spacing` px (pixel triangles).
func _treeline(size: Vector2, parallax: float, base_y: float, height: float, col: Color, salt: int, spacing: float) -> void:
	var off := camera_pos.x * parallax
	_canvas.draw_rect(Rect2(0, base_y, size.x, size.y - base_y), col)
	var first := floori(off / spacing) - 1
	for k in range(first, first + int(size.x / spacing) + 3):
		var x := floorf(k * spacing - off)
		var h := floorf(height * (0.5 + HashNoise.hash_f(world_seed, k, 0, salt) * 0.6))
		for row in int(h):
			var half := floorf(row * 0.35) + 1
			_canvas.draw_rect(Rect2(x - half, base_y - h + row, half * 2 + 1, 1), col)
