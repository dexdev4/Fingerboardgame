## Debug HUD (display only, runs in _process, never touches physics):
##  - a dot under each finger (orange = back foot, cyan = front foot, green = push,
##    hollow = foot currently off the board, grey = ignored) with an arrow for its velocity
##  - an inset top-down board map with each foot's board-space position, velocity and press force
##  - board speed, height and angles; a Reset button
class_name DebugOverlay
extends CanvasLayer

const COLORS := {
	Finger.Role.BACK_FOOT: Color(1.0, 0.55, 0.1),
	Finger.Role.FRONT_FOOT: Color(0.2, 0.8, 1.0),
	Finger.Role.PUSH: Color(0.3, 0.95, 0.4),
}
const ARROW_TIME := 0.1    # arrows show where the finger would be in 0.1 s

var board: Board
var input: FingerInput
var _canvas: Control
var _label: Label
var _reset: Button
var _last_pop := 0.0


func setup(b: Board, i: FingerInput) -> void:
	board = b
	input = i
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_canvas)
	add_child(_canvas)

	_label = Label.new()
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	add_child(_label)

	_reset = Button.new()
	_reset.text = "  RESET  "
	_reset.pressed.connect(func(): board.request_reset())
	add_child(_reset)

	input.ui_blockers = func(p: Vector2) -> bool: return _reset.get_global_rect().has_point(p)
	board.popped.connect(func(s: float): _last_pop = s)


func _process(_dt: float) -> void:
	var size := _canvas.get_viewport_rect().size
	var ui := maxf(size.y / 720.0, 0.5)      # scale UI with screen height
	_label.add_theme_font_size_override("font_size", int(18 * ui))
	_label.position = Vector2(150, 12) * ui
	_reset.add_theme_font_size_override("font_size", int(26 * ui))
	_reset.position = Vector2(size.x - _reset.size.x - 16 * ui, 16 * ui)

	var a := board.angles_deg()
	_label.text = "speed  %6.1f cm/s\nheight %6.1f mm\npitch  %6.1f°   roll %6.1f°   yaw %6.1f°\nwheels down %d   last pop %.1f u/s\n%d fps" % [
		board.speed_cm_s(), board.height_mm(), a.x, a.y, a.z,
		board.wheels_down, _last_pop, Engine.get_frames_per_second()]
	_canvas.queue_redraw()


func _draw_canvas() -> void:
	var ui := maxf(_canvas.get_viewport_rect().size.y / 720.0, 0.5)
	for f: Finger in input.fingers.values():
		_draw_finger(f, ui)
	_draw_inset(ui)


func _draw_finger(f: Finger, ui: float) -> void:
	var c: Color = COLORS.get(f.role, Color(0.6, 0.6, 0.6))
	var r := 26.0 * ui
	var is_foot := f.role == Finger.Role.BACK_FOOT or f.role == Finger.Role.FRONT_FOOT
	if is_foot and not f.on_board:
		_canvas.draw_arc(f.screen_pos, r, 0, TAU, 32, c, 3.0 * ui)
	else:
		_canvas.draw_circle(f.screen_pos, r, Color(c, 0.55))
	_arrow(f.screen_pos, f.screen_pos + f.screen_vel * ARROW_TIME, c, ui)


## Top-down board map: nose at the top. Shows board-space finger positions and velocities.
func _draw_inset(ui: float) -> void:
	var g := board.geo
	var h := 300.0 * ui
	var k := h / (g.half_length * 2.0)                 # pixels per world unit
	var centre := Vector2(70.0 * ui, 24.0 * ui + h * 0.5)
	var to_px := func(x: float, z: float) -> Vector2: return centre + Vector2(x, z) * k
	_canvas.draw_rect(Rect2(centre - Vector2(60, h * 0.5 / ui + 12) * ui, Vector2(120, h / ui + 24) * ui), Color(0, 0, 0, 0.35))
	var outline := Rect2(to_px.call(-g.half_width, -g.half_length), Vector2(g.half_width, g.half_length) * 2.0 * k)
	_canvas.draw_rect(outline, Color(0.85, 0.85, 0.85), false, 2.0 * ui)
	for z in [-g.flat_half, g.flat_half]:            # kick bends
		_canvas.draw_line(to_px.call(-g.half_width, z), to_px.call(g.half_width, z), Color(0.6, 0.6, 0.6), 1.0 * ui)
	for z in [-g.axle_z, g.axle_z]:                  # axles
		_canvas.draw_line(to_px.call(-g.wheel_x * 1.4, z), to_px.call(g.wheel_x * 1.4, z), Color(0.9, 0.9, 0.4), 2.0 * ui)
	_canvas.draw_line(to_px.call(-g.half_width, 0.0), to_px.call(g.half_width, 0.0), Color(1, 1, 1, 0.25), 1.0 * ui)
	var font := ThemeDB.fallback_font
	for f: Finger in input.feet():
		var c: Color = COLORS[f.role]
		var p: Vector2 = to_px.call(f.local_pos.x, f.local_pos.z)
		if f.on_board:
			_canvas.draw_circle(p, 8.0 * ui, c)
		else:
			_canvas.draw_arc(p, 8.0 * ui, 0, TAU, 16, c, 2.0 * ui)
		_arrow(p, p + Vector2(f.local_vel.x, f.local_vel.z) * ARROW_TIME * k, c, ui)
		var press := f.press_force / board.tuning.board_weight()
		_canvas.draw_string(font, p + Vector2(12, 5) * ui, "%.1fW" % press, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * ui), c)


func _arrow(from: Vector2, to: Vector2, c: Color, ui: float) -> void:
	if from.distance_to(to) < 4.0:
		return
	_canvas.draw_line(from, to, c, 3.0 * ui)
	var d := (to - from).normalized() * 12.0 * ui
	_canvas.draw_line(to, to - d.rotated(0.5), c, 3.0 * ui)
	_canvas.draw_line(to, to - d.rotated(-0.5), c, 3.0 * ui)
