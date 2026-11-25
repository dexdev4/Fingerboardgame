## The crashed ship (your base) at tile x = 0. Inside its range you're "at base": it refills your
## air and power (slowly until the scrubber / solar array are repaired) and shelters you from the
## night cold. Repairs change how it looks. Drawn in code; animation is visual only.
class_name Ship
extends Node2D

## id → [name, what it does]. Costs are in GameTuning.repairs / crafts (rule 4).
const REPAIRS := {
	"scrubber": ["O2 Scrubber", "Refills oxygen fast at the ship"],
	"solar": ["Solar Array", "Refills suit power fast at the ship"],
	"tank": ["Suit Tank", "More oxygen capacity"],
	"antenna": ["Long-range Antenna", "Send a signal across Tessaris"],
}
const CRAFTS := {
	"canister": ["O2 Canister", "Oxygen anywhere"],
	"cell": ["Power Cell", "Suit power anywhere"],
}

var t: GameTuning
var repaired := {}
var _t := 0.0


func setup(tuning: GameTuning) -> void:
	t = tuning
	# Centre of tile 0, standing on the flat crash-site surface.
	position = Vector2(0.5 * t.tile_size, t.surface_base * t.tile_size)


## True when `p` (px) is within the ship's range.
func in_range(p: Vector2) -> bool:
	return p.distance_to(position + Vector2(0, -40)) <= t.base_radius * t.tile_size


func _process(dt: float) -> void:
	_t += dt
	queue_redraw()


func _draw() -> void:
	var hull := Color("c9ccd8")
	var dark := Color("6c7083")
	# Hull: a long capsule, tilted, its nose dug into the ground on the right.
	draw_set_transform(Vector2(0, -34), deg_to_rad(6.0))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-120, -26), Vector2(60, -34), Vector2(110, -14), Vector2(118, 18),
		Vector2(-110, 30), Vector2(-132, 4)]), hull)
	draw_colored_polygon(PackedVector2Array([Vector2(-110, 30), Vector2(118, 18), Vector2(110, 30), Vector2(-100, 38)]), dark)
	# Cockpit window and the hatch.
	draw_colored_polygon(PackedVector2Array([Vector2(62, -26), Vector2(100, -12), Vector2(96, 0), Vector2(60, -8)]), Color("2b3a55"))
	draw_rect(Rect2(-30, -10, 26, 34), Color("8d92a6"))
	draw_rect(Rect2(-26, -6, 18, 26), Color(1.0, 0.85, 0.5, 0.55 + 0.1 * sin(_t * 3.0)))
	# Hull seams and a scorch mark.
	draw_line(Vector2(-60, -28), Vector2(-56, 32), dark, 2.0)
	draw_line(Vector2(20, -32), Vector2(24, 26), dark, 2.0)
	draw_circle(Vector2(-95, 0), 14.0, Color(0.15, 0.12, 0.12, 0.5))
	# Engine block at the back, smoking while the scrubber is broken.
	draw_rect(Rect2(-150, -16, 22, 32), dark)
	if not repaired.has("scrubber"):
		for i in 5:
			var k := fmod(_t * 0.35 + i * 0.2, 1.0)
			draw_circle(Vector2(-150 - k * 40.0, -20 - k * 110.0), 6.0 + k * 16.0, Color(0.35, 0.33, 0.38, 0.45 * (1.0 - k)))
	else:   # scrubber vent glowing green
		draw_rect(Rect2(-80, -40, 30, 8), Color(0.4, 1.0, 0.6, 0.7 + 0.3 * sin(_t * 2.0)))
	if repaired.has("solar"):
		for i in 3:
			draw_set_transform(Vector2(-20 + i * 46, -82), deg_to_rad(-8.0))
			draw_rect(Rect2(-20, -6, 40, 12), Color("2c4f8c"))
			draw_rect(Rect2(-20, -6, 40, 12), Color("9fb8e6"), false, 1.5)
			draw_line(Vector2(0, 6), Vector2(0, 18), dark, 2.0)
		draw_set_transform(Vector2(0, -34), deg_to_rad(6.0))
	if repaired.has("antenna"):
		draw_line(Vector2(40, -34), Vector2(44, -110), dark, 3.0)
		draw_arc(Vector2(44, -110), 18.0, PI * 0.15, PI * 0.85, 12, hull, 4.0)
		draw_circle(Vector2(44, -114), 3.0 + sin(_t * 6.0) * 1.5, Color(1.0, 0.3, 0.3))
	else:   # a bent stub where the antenna was
		draw_line(Vector2(40, -34), Vector2(54, -58), dark, 3.0)
	# Blinking beacon on top.
	draw_circle(Vector2(-10, -30), 4.0, Color(1.0, 0.2, 0.15, 0.3 + 0.7 * float(fmod(_t, 1.2) < 0.15)))
	draw_set_transform(Vector2.ZERO)
