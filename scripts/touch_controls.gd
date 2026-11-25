## On-screen buttons for portrait play: ◀ ▶ (bottom left, left thumb) and JUMP (bottom right,
## right thumb). Multitouch: each finger is tracked by its touch index, so you can run and jump at
## the same time. The buttons press the same input actions as the keyboard (move_left, ...).
##
## A full-width bar under the buttons swallows the emulated mouse events, so touching a button
## never also counts as tapping the world (mining happens on world taps — see Main).
class_name TouchControls
extends CanvasLayer

const ACTIONS := ["move_left", "move_right", "jump"]
const LABELS := ["left", "right", "JUMP"]

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


## Screen rectangles of the three buttons (in this canvas layer's coordinates).
func _rects() -> Array[Rect2]:
	var size := get_viewport().get_visible_rect().size
	var h := t.touch_bar_height
	var pad := 18.0
	var bw := (size.x * 0.5 - pad * 3.0) * 0.5
	var y := size.y - h + pad
	var bh := h - pad * 2.0
	return [Rect2(pad, y, bw, bh), Rect2(pad * 2.0 + bw, y, bw, bh),
			Rect2(size.x * 0.58, y, size.x * 0.42 - pad, bh)]


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			var a := _action_at(event.position)
			if a != "":
				_hold(event.index, a)
		else:
			_release(event.index)
	elif event is InputEventScreenDrag and _held.has(event.index):
		# Sliding a thumb from ◀ to ▶ switches direction without lifting it.
		var a := _action_at(event.position)
		if a != _held[event.index]:
			_release(event.index)
			if a != "":
				_hold(event.index, a)


func _action_at(p: Vector2) -> String:
	var r := _rects()
	for i in r.size():
		if r[i].grow(10.0).has_point(p):
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


## Let go of everything (pause menus, story panels).
func release_all() -> void:
	for i in _held.keys():
		_release(i)


func _draw_bar() -> void:
	var r := _rects()
	var font := ThemeDB.fallback_font
	_bar.draw_rect(Rect2(Vector2.ZERO, _bar.size), Color(0.04, 0.03, 0.08, 0.55))
	for i in r.size():
		var rect := Rect2(r[i].position - _bar.position, r[i].size)
		var on := _pressed.has(ACTIONS[i])
		_bar.draw_rect(rect, Color(1, 1, 1, 0.28 if on else 0.12))
		_bar.draw_rect(rect, Color(1, 1, 1, 0.5), false, 3.0)
		var c := rect.get_center()
		if i < 2:   # arrows drawn as triangles (the default font has no arrow glyphs)
			var d := -1.0 if i == 0 else 1.0
			_bar.draw_colored_polygon(PackedVector2Array([c + Vector2(d * 26, 0),
					c + Vector2(-d * 18, -28), c + Vector2(-d * 18, 28)]), Color(1, 1, 1, 0.9))
		else:
			var fs := 44
			var tw := font.get_string_size(LABELS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			_bar.draw_string(font, c + Vector2(-tw * 0.5, fs * 0.35), LABELS[i],
					HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.9))
