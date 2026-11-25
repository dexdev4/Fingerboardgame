## On-screen buttons for portrait play: ◀ ▶ (bottom left, left thumb) and JUMP (bottom right,
## right thumb). Multitouch: each finger is tracked by its touch index, so you can walk and jump
## at once. The buttons press the same input actions as the keyboard (move_left, ...).
## A bar under the buttons swallows the emulated mouse events, so pressing a button never also
## counts as tapping the world (taps chop, dig and pick things up — see Main).
class_name TouchControls
extends CanvasLayer

const ACTIONS := ["move_left", "move_right", "jump"]

var t: GameTuning
var _bar: Control
var _held := {}            # touch index → action
var _pressed := {}         # action → number of fingers on it


func setup(tuning: GameTuning) -> void:
	t = tuning
	layer = 5
	_bar = Control.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_bar.draw.connect(_draw_bar)
	add_child(_bar)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	_bar.position = Vector2(0, size.y - t.touch_bar_height)
	_bar.size = Vector2(size.x, t.touch_bar_height)
	_bar.queue_redraw()


## Screen rectangles of the three buttons.
func _rects() -> Array[Rect2]:
	var size := get_viewport().get_visible_rect().size
	var h := t.touch_bar_height
	var pad := 4.0
	var y := size.y - h + pad
	var bh := h - pad * 2.0
	var bw := floorf((size.x * 0.5 - pad * 3.0) * 0.5)
	return [Rect2(pad, y, bw, bh), Rect2(pad * 2.0 + bw, y, bw, bh),
			Rect2(floorf(size.x * 0.56), y, size.x - floorf(size.x * 0.56) - pad, bh)]


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			var a := _action_at(event.position)
			if a != "":
				_hold(event.index, a)
		else:
			_release(event.index)
	elif event is InputEventScreenDrag and _held.has(event.index):
		var a := _action_at(event.position)   # slide a thumb from ◀ to ▶ without lifting it
		if a != _held[event.index]:
			_release(event.index)
			if a != "":
				_hold(event.index, a)


func _action_at(p: Vector2) -> String:
	var r := _rects()
	for i in r.size():
		if r[i].grow(3.0).has_point(p):
			return ACTIONS[i]
	return ""


func _hold(index: int, action: String) -> void:
	_held[index] = action
	_pressed[action] = _pressed.get(action, 0) + 1
	Input.action_press(action)
	_bar.queue_redraw()


func _release(index: int) -> void:
	if not _held.has(index):
		return
	var action: String = _held[index]
	_held.erase(index)
	_pressed[action] = _pressed.get(action, 1) - 1
	if _pressed[action] <= 0:
		_pressed.erase(action)
		Input.action_release(action)
	_bar.queue_redraw()


func release_all() -> void:
	for i in _held.keys():
		_release(i)


func _draw_bar() -> void:
	_bar.draw_rect(Rect2(Vector2.ZERO, _bar.size), Color(Pal.INK, 0.85))
	_bar.draw_rect(Rect2(0, 0, _bar.size.x, 1), Pal.BARK)
	var r := _rects()
	for i in r.size():
		var rect := Rect2(r[i].position - _bar.position, r[i].size)
		var on := _pressed.has(ACTIONS[i])
		_bar.draw_rect(rect, Pal.BARK if on else Pal.BARK_DARK)
		_bar.draw_rect(rect, Pal.TAN, false, 1.0)
		var c := rect.get_center().floor()
		if i < 2:   # chunky pixel arrows
			var d := -1 if i == 0 else 1
			for k in 6:
				var hgt := 6 - k
				_bar.draw_rect(Rect2(c.x - 3 * d + k * d - (1 if d < 0 else 0), c.y - hgt, 1, hgt * 2 + 1), Pal.CREAM)
		else:
			var font := PixelFont.get_font()
			var txt := "JUMP"
			_bar.draw_string(font, Vector2(c.x - txt.length() * 3, c.y + 4), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, PixelFont.SIZE, Pal.CREAM)
