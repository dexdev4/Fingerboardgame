## Something on the ground you can tap to collect or read: an air-bladder plant (oxygen), a
## glowcap fungus (food), ship wreckage (metal / power cell), a crew-log pod or a monolith (story).
## Drawn in code; the gentle bob/glow runs in _process and is purely visual.
class_name Pickup
extends Node2D

var id: String
var kind: String
var cell: Vector2i
var _t := 0.0


func setup(data: Dictionary, t: GameTuning) -> void:
	id = data.id
	kind = data.kind
	cell = data.cell
	# Stand on the floor of the cell (bottom edge), centred.
	position = Vector2((cell.x + 0.5) * t.tile_size, (cell.y + 1) * t.tile_size)
	_t = float(abs(id.hash()) % 1000) / 100.0   # desync the animations (visual only)


func _process(dt: float) -> void:
	_t += dt
	queue_redraw()


func _draw() -> void:
	var glow := 0.5 + 0.5 * sin(_t * 2.0)
	match kind:
		"bladder":
			# A translucent green air sac on a stalk.
			draw_line(Vector2(0, 0), Vector2(0, -14), Color("4f7a3a"), 3.0)
			draw_circle(Vector2(0, -22 - glow * 2.0), 10.0 + glow, Color(0.55, 0.95, 0.6, 0.75))
			draw_circle(Vector2(-3, -25 - glow * 2.0), 3.0, Color(1, 1, 1, 0.6))
		"glowcap":
			# Three glowing mushrooms.
			for i in 3:
				var x := (i - 1) * 9.0
				var h := 10.0 + i % 2 * 6.0
				draw_line(Vector2(x, 0), Vector2(x, -h), Color("d9c9a6"), 3.0)
				draw_circle(Vector2(x, -h), 6.0, Color(0.55, 0.95, 0.85).lerp(Color.WHITE, glow * 0.3))
		"wreck":
			# Bent hull plate with a blinking light.
			draw_colored_polygon(PackedVector2Array([Vector2(-14, 0), Vector2(-10, -14), Vector2(8, -18), Vector2(14, 0)]), Color("9aa3b5"))
			draw_line(Vector2(-10, -7), Vector2(10, -10), Color("5c6578"), 2.0)
			draw_circle(Vector2(6, -12), 2.5, Color(1.0, 0.4, 0.2, 0.4 + glow * 0.6))
		"crew_log":
			# An escape-pod data beacon: white capsule, pulsing blue light.
			draw_rect(Rect2(-9, -26, 18, 26), Color("e8e8f0"))
			draw_rect(Rect2(-6, -22, 12, 6), Color("57c7ff"))
			draw_circle(Vector2(0, -32), 3.0 + glow * 2.0, Color(0.35, 0.8, 1.0, 0.5 + glow * 0.5))
		"monolith":
			# A tall dark stone with glowing glyphs.
			draw_colored_polygon(PackedVector2Array([Vector2(-12, 0), Vector2(-9, -64), Vector2(9, -70), Vector2(12, 0)]), Color("2b2838"))
			for i in 4:
				draw_line(Vector2(-4, -14 - i * 13), Vector2(4, -18 - i * 13), Color(0.4, 0.95, 1.0, 0.4 + glow * 0.6), 2.0)
