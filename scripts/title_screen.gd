## The title screen: the forest at dusk, the name ELDWOOD, and Continue / New game.
class_name TitleScreen
extends Control

signal continue_game
signal new_game

var has_save := false
var _t := 0.0


func setup(save_exists: bool) -> void:
	has_save = save_exists
	theme = UiTheme.get_theme()
	size = get_viewport().get_visible_rect().size
	var col := VBoxContainer.new()
	col.size = size
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 70
	col.add_child(spacer)
	var title := Label.new()
	title.text = "ELDWOOD"
	title.add_theme_font_size_override("font_size", PixelFont.SIZE * 3)
	title.add_theme_color_override("font_color", Pal.CREAM)
	title.add_theme_color_override("font_shadow_color", Pal.INK)
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := Label.new()
	sub.text = "A tale of the old forest"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Pal.TAN)
	col.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size.y = 40
	col.add_child(gap)
	if has_save:
		_button(col, "Continue", func(): continue_game.emit())
	_button(col, "New game", func(): new_game.emit())


func _button(parent: Control, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(100, 18)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(action)
	parent.add_child(b)


func _process(dt: float) -> void:
	_t += dt
	queue_redraw()


func _draw() -> void:
	# Dusk sky, distant hills and a dark pine line; a little cabin glowing at the edge.
	var s := get_viewport_rect().size
	var bands := [Color("2a2440"), Color("3d3150"), Color("5a3d55"), Color("8a4a4a"), Color("c26a3a"), Color("d9944a")]
	for i in bands.size():
		draw_rect(Rect2(0, floorf(s.y * 0.6 * i / bands.size()), s.x, s.y), bands[i])
	for x in range(0, int(s.x), 2):
		var h := floorf(HashNoise.fbm1(7, 3, x / 60.0, 2) * 30.0)
		draw_rect(Rect2(x, s.y * 0.6 - h, 2, s.y), Color("3b2d45"))
	var line_y := floorf(s.y * 0.7)
	draw_rect(Rect2(0, line_y, s.x, s.y), Pal.LEAF_DARK.darkened(0.5))
	for k in range(-1, int(s.x / 9.0) + 2):
		var h := floorf(16.0 + HashNoise.hash_f(7, k, 0, 9) * 18.0)
		for row in int(h):
			var half := floorf(row * 0.35) + 1
			draw_rect(Rect2(k * 9 - half, line_y - h + row, half * 2 + 1, 1), Pal.LEAF_DARK.darkened(0.5))
	# The cabin's lit window and chimney smoke.
	var cx := floorf(s.x * 0.22)
	draw_rect(Rect2(cx, line_y + 6, 14, 10), Pal.BARK_DARK)
	draw_rect(Rect2(cx + 4, line_y + 9, 4, 3), Pal.YELLOW if fmod(_t, 3.0) > 0.1 else Pal.ORANGE)
	for i in 3:
		var k := fmod(_t * 0.2 + i * 0.33, 1.0)
		draw_rect(Rect2(cx + 10 + int(sin(k * 5.0) * 2.0), line_y + 2 - k * 30.0, 2, 2), Color(Pal.STONE_LIGHT, 0.6 * (1.0 - k)))
	# Stars.
	for i in 30:
		var p := Vector2(floorf(HashNoise.hash_f(9, i, 0, 1) * s.x), floorf(HashNoise.hash_f(9, i, 1, 1) * s.y * 0.35))
		if int(_t * 2.0 + i) % 7 != 0:
			draw_rect(Rect2(p, Vector2.ONE), Pal.CREAM)
