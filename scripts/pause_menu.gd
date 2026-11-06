## Pause button + pause menu with the player's settings (GameSettings).
##
## Pausing stops the whole game (SceneTree.paused: the physics world freezes) and lifts every
## finger, so nothing pushes the board while you're in the menu. This node keeps running while
## paused (PROCESS_MODE_ALWAYS). Settings apply live; camera changes snap the camera so you can
## see the new view behind the menu. They're saved when you resume.
## UI only: it never touches physics except through GameSettings.apply (input like any other).
class_name PauseMenu
extends CanvasLayer

var settings: GameSettings
var tuning: BoardTuning
var board: Board
var camera: ChaseCamera
var input: FingerInput
var _apply: Callable
var _persist := true

var _pause_btn: Button
var _root: Control          # the whole menu (hidden while playing)
var _theme := Theme.new()
var _rows := {}             # setting key → [slider, value label, spec]
var _quiet := false         # true while refreshing sliders from code (don't re-apply)


## Slider specs: [key, label, min, max, step, value format, is camera]. Ranges come from the
## tuning resource (menu_* fields), not from here.
func _specs() -> Array:
	var t := tuning
	var o := t.menu_camera_orbit_max_deg
	return [
		["#", "GAME"],
		["game_speed", "Game speed (time)", t.menu_game_speed_min, t.menu_game_speed_max, 0.05, "%.2f×", false],
		["gravity", "Gravity (× real)", t.menu_gravity_min, t.menu_gravity_max, 0.05, "%.2f", false],
		["#", "BOARD & INPUT"],
		["flip_speed", "Board flip speed", t.menu_flip_speed_min, t.menu_flip_speed_max, 0.05, "%.2f×", false],
		["flick_sensitivity", "Flick sensitivity", t.menu_flick_sensitivity_min, t.menu_flick_sensitivity_max, 0.05, "%.2f×", false],
		["#", "CAMERA"],
		["camera_distance", "Distance behind", t.menu_camera_distance_min, t.menu_camera_distance_max, 0.05, "%.2f", true],
		["camera_height", "Height", t.menu_camera_height_min, t.menu_camera_height_max, 0.05, "%.2f", true],
		["camera_orbit_deg", "Orbit (left / right)", -o, o, 1.0, "%+.0f°", true],
		["camera_aim_height", "Tilt (aim up / down)", t.menu_camera_aim_min, t.menu_camera_aim_max, 0.02, "%+.2f", true],
		["camera_fov_deg", "Field of view (zoom)", t.menu_camera_fov_min, t.menu_camera_fov_max, 1.0, "%.0f°", true],
	]


func setup(s: GameSettings, t: BoardTuning, b: Board, cam: ChaseCamera, i: FingerInput,
		apply_settings: Callable, persist: bool) -> void:
	settings = s
	tuning = t
	board = b
	camera = cam
	input = i
	_apply = apply_settings
	_persist = persist
	layer = 10                                  # above the debug overlay
	process_mode = Node.PROCESS_MODE_ALWAYS     # keeps working while the game is paused
	_build()
	_layout()
	get_viewport().size_changed.connect(_layout)
	# The pause button is UI: a touch on it must not become a finger on the board.
	var prev := input.ui_blockers
	input.ui_blockers = func(p: Vector2) -> bool:
		return prev.call(p) or (_pause_btn.visible and _pause_btn.get_global_rect().has_point(p))
	# Android back button pauses / resumes instead of quitting the app.
	get_tree().quit_on_go_back = false


func _build() -> void:
	_pause_btn = Button.new()
	_pause_btn.text = "  II  PAUSE  "
	_pause_btn.theme = _theme
	_pause_btn.pressed.connect(set_paused.bind(true))
	add_child(_pause_btn)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = _theme
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()                  # light dim: the board stays visible below
	dim.color = Color(0, 0, 0, 0.3)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.09, 0.11, 0.92)
	box.set_corner_radius_all(18)
	box.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", box)
	_root.add_child(panel)
	var col := VBoxContainer.new()
	col.name = "Col"
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.name = "Title"
	col.add_child(title)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	col.add_child(buttons)
	_add_button(buttons, "RESUME", set_paused.bind(false))
	_add_button(buttons, "RESET BOARD", func():
		board.request_reset()
		set_paused(false))
	_add_button(buttons, "DEFAULTS", _defaults)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for spec in _specs():
		if spec[0] == "#":
			var h := Label.new()
			h.text = spec[1]
			h.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
			list.add_child(h)
			continue
		_add_slider(list, spec)

	var quit := Button.new()
	quit.text = "QUIT GAME"
	quit.pressed.connect(func(): get_tree().quit())
	col.add_child(quit)
	_refresh()


func _add_button(parent: Control, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(action)
	parent.add_child(b)


func _add_slider(parent: Control, spec: Array) -> void:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = spec[1]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value_label := Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	parent.add_child(row)
	var slider := HSlider.new()
	slider.min_value = spec[2]
	slider.max_value = spec[3]
	slider.step = spec[4]
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_slider.bind(spec[0]))
	parent.add_child(slider)
	_rows[spec[0]] = [slider, value_label, spec]


func _on_slider(value: float, key: String) -> void:
	_rows[key][1].text = _rows[key][2][5] % value
	if _quiet:
		return
	settings.set(key, value)
	_apply.call()
	if _rows[key][2][6]:
		camera.snap()     # show the new camera view right away (the game is paused)


## Sliders ← settings (without re-applying).
func _refresh() -> void:
	_quiet = true
	for key in _rows:
		var slider: HSlider = _rows[key][0]
		slider.value = settings.get(key)
		_rows[key][1].text = _rows[key][2][5] % slider.value
	_quiet = false


func _defaults() -> void:
	settings.reset_to_defaults()
	_apply.call()
	camera.snap()
	_refresh()


func set_paused(on: bool) -> void:
	get_tree().paused = on
	_root.visible = on
	_pause_btn.visible = not on
	# Lift every finger: nothing should press the board during or straight after the menu (a
	# finger held through the menu never sends its lift event to the paused input).
	input.clear()
	if not on and _persist:
		settings.save()


## Sizes scale with the screen's short side (like the debug overlay). The panel covers the top
## part of the screen so the board (lower middle) stays visible for camera changes.
func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var ui := maxf(minf(size.x, size.y) / 720.0, 0.5)
	_theme.default_font_size = int(28 * ui)
	var grab := StyleBoxFlat.new()             # thick, touch-friendly slider track
	grab.bg_color = Color(0.35, 0.37, 0.42)
	grab.set_corner_radius_all(int(6 * ui))
	grab.content_margin_top = 7 * ui
	grab.content_margin_bottom = 7 * ui
	_theme.set_stylebox("slider", "HSlider", grab)
	var fill := grab.duplicate() as StyleBoxFlat
	fill.bg_color = Color(1.0, 0.6, 0.15)
	_theme.set_stylebox("grabber_area", "HSlider", fill)
	_theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
	for key in _rows:
		(_rows[key][0] as HSlider).custom_minimum_size.y = 52 * ui
	_pause_btn.add_theme_font_size_override("font_size", int(24 * ui))
	_pause_btn.position = Vector2(size.x - _pause_btn.get_combined_minimum_size().x - 16 * ui, 86 * ui)
	var panel := _root.get_node("Panel") as PanelContainer
	var m := 20 * ui
	panel.position = Vector2(m, m)
	panel.size = Vector2(size.x - 2 * m, size.y * 0.6)
	(panel.get_node("Col/Title") as Label).add_theme_font_size_override("font_size", int(40 * ui))


func _notification(what: int) -> void:
	if settings == null:
		return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		set_paused(not get_tree().paused)
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and OS.has_feature("mobile") and _persist \
			and not get_tree().paused:
		set_paused(true)      # leaving the app (call, home button) pauses the game


## Escape on desktop toggles the menu.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
