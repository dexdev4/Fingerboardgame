## Everything on screen except the world and the touch buttons:
##  - top: oxygen / food / power / health bars, clock, place, objective
##  - inventory (metal, ice, crystal, alloy) and usable items (tap to eat / use)
##  - short messages ("+1 metal", warnings)
##  - panels: story pages (chapters, logs), the ship (repairs + crafting), pause menu
## UI only: it emits signals; Main does the game logic.
class_name Hud
extends CanvasLayer

signal use_item(item: String)
signal repair(id: String)
signal craft(item: String)
signal panel_closed
signal new_world
signal paused(on: bool)

const BAR_COLORS := {"oxygen": Color("57c7ff"), "food": Color("f2a65a"), "power": Color("f5e663"), "health": Color("ff5d6c")}
const BAR_NAMES := {"oxygen": "O2", "food": "FOOD", "power": "POWER", "health": "HEALTH"}
const ITEM_NAMES := {"metal": "Metal", "ice": "Ice", "crystal": "Crystal", "alloy": "Alloy",
		"glowcap": "Glowcap", "canister": "O2 Canister", "cell": "Power Cell"}
const ITEM_COLORS := {"metal": Color("e0b36a"), "ice": Color("a8e2f0"), "crystal": Color("ff5fd2"), "alloy": Color("66f0ff")}
const USE_LABELS := {"glowcap": "Eat glowcap", "canister": "O2 canister", "cell": "Power cell"}

var t: GameTuning
var _theme := Theme.new()
var _root: Control
var _bars := {}             # stat → [ProgressBar, Label]
var _clock: Label
var _place: Label
var _objective: Label
var _inv: Label
var _use_buttons := {}      # item → Button
var _toast_box: VBoxContainer
var _panel: PanelContainer
var _panel_title: Label
var _panel_text: Label
var _panel_body: VBoxContainer
var _panel_queue: Array = []   # pending [title, text] story pages
var _ship_mode := false
var _pause_btn: Button
## Shown in the pause panel (set by Main).
var world_seed := 0


func setup(tuning: GameTuning) -> void:
	t = tuning
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS      # panels work while the game is paused
	_theme.default_font_size = 24
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _theme
	add_child(_root)
	_build_top()
	_build_items()
	_build_toasts()
	_build_panel()
	get_viewport().size_changed.connect(_layout)
	_layout()


# ---- Layout -----------------------------------------------------------------------------

func _build_top() -> void:
	var box := VBoxContainer.new()
	box.name = "Top"
	box.position = Vector2(16, 14)
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(grid)
	for stat in ["oxygen", "food", "power", "health"]:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := Label.new()
		label.text = BAR_NAMES[stat]
		label.custom_minimum_size.x = 92
		label.add_theme_font_size_override("font_size", 20)
		row.add_child(label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(190, 22)
		bar.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = BAR_COLORS[stat]
		fill.set_corner_radius_all(4)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0, 0, 0, 0.5)
		bg.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", bg)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(bar)
		grid.add_child(row)
		_bars[stat] = [bar, label]
	_clock = _label(box, 22)
	_place = _label(box, 22)
	_objective = _label(box, 22)
	_objective.add_theme_color_override("font_color", Color("ffe08a"))
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inv = _label(box, 22)
	_pause_btn = Button.new()
	_pause_btn.text = " II "
	_pause_btn.add_theme_font_size_override("font_size", 30)
	_pause_btn.pressed.connect(func(): show_pause())
	_root.add_child(_pause_btn)


func _build_items() -> void:
	var row := HBoxContainer.new()
	row.name = "Items"
	row.add_theme_constant_override("separation", 10)
	_root.add_child(row)
	for item in Inventory.USABLES:
		var b := Button.new()
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(func(): use_item.emit(item))
		row.add_child(b)
		_use_buttons[item] = b


func _build_toasts() -> void:
	_toast_box = VBoxContainer.new()
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.alignment = BoxContainer.ALIGNMENT_END
	_root.add_child(_toast_box)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.12, 0.95)
	style.border_color = Color("7fe0d0")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(22)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.visible = false
	_root.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_panel.add_child(col)
	_panel_title = Label.new()
	_panel_title.add_theme_font_size_override("font_size", 34)
	_panel_title.add_theme_color_override("font_color", Color("7fe0d0"))
	_panel_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_panel_title)
	_panel_text = Label.new()
	_panel_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_text.add_theme_font_size_override("font_size", 25)
	col.add_child(_panel_text)
	_panel_body = VBoxContainer.new()
	_panel_body.add_theme_constant_override("separation", 10)
	col.add_child(_panel_body)


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	(_root.get_node("Top") as Control).size.x = size.x - 120
	_objective.custom_minimum_size.x = size.x - 140
	_pause_btn.position = Vector2(size.x - 86, 14)
	var items := _root.get_node("Items") as Control
	items.position = Vector2(16, size.y - t.touch_bar_height - 70)
	_toast_box.position = Vector2(16, size.y - t.touch_bar_height - 330)
	_toast_box.size = Vector2(size.x - 32, 250)
	_panel.position = Vector2(30, size.y * 0.12)
	_fit_panel()


func _label(parent: Control, fs: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


# ---- Updates from Main -------------------------------------------------------------------

func update_stats(s: Survival) -> void:
	for stat in _bars:
		var bar: ProgressBar = _bars[stat][0]
		bar.max_value = s.oxygen_cap if stat == "oxygen" else t.get(stat + "_max")
		bar.value = s.get(stat)
		# Flash the label red when a stat runs low.
		var low := bar.value < bar.max_value * 0.2
		var flash := low and fmod(Time.get_ticks_msec() / 400.0, 2.0) < 1.0
		(_bars[stat][1] as Label).add_theme_color_override("font_color", Color("ff5d6c") if flash else Color.WHITE)


func update_info(clock: String, place: String, objective: String) -> void:
	_clock.text = clock
	_place.text = place
	_objective.text = "Goal: " + objective


func update_inventory(inv: Inventory) -> void:
	var parts: Array[String] = []
	for item in Inventory.RESOURCES:
		parts.append("%s %d" % [ITEM_NAMES[item], inv.count(item)])
	_inv.text = "   ".join(parts)
	for item in _use_buttons:
		var n := inv.count(item)
		var b: Button = _use_buttons[item]
		b.visible = n > 0
		b.text = " %s ×%d " % [USE_LABELS[item], n]


## A short message that fades out after a few seconds.
func toast(text: String, color: Color = Color.WHITE) -> void:
	var l := _label(_toast_box, 24)
	l.text = text
	l.add_theme_color_override("font_color", color)
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)
	while _toast_box.get_child_count() > 6:
		_toast_box.get_child(0).free()


# ---- Panels ------------------------------------------------------------------------------

func panel_open() -> bool:
	return _panel.visible


## Queue a story page (chapter start, crew log, ...). Pages show one at a time; the game is
## paused while one is open so you can read in peace.
func show_story(title: String, text: String) -> void:
	_panel_queue.append([title, text])
	if not _panel.visible:
		_next_page()


func _next_page() -> void:
	if _panel_queue.is_empty():
		_close_panel()
		return
	var page: Array = _panel_queue.pop_front()
	_open(page[0], page[1])
	_button("Continue", _next_page)


func _open(title: String, text: String) -> void:
	_ship_mode = false
	for c in _panel_body.get_children():
		_panel_body.remove_child(c)   # out of the layout now; freed at the end of the frame
		c.queue_free()
	_panel_title.text = title
	_panel_text.text = text
	_panel_text.visible = text != ""
	_panel.visible = true
	_fit_panel()
	paused.emit(true)


## Shrink the panel to its content (wrapped text only knows its height once its width is set).
func _fit_panel() -> void:
	var w := get_viewport().get_visible_rect().size.x - 60.0
	_panel_title.custom_minimum_size.x = w - 44.0
	_panel_text.custom_minimum_size.x = w - 44.0
	_panel.size = Vector2(w, 0)
	_panel.reset_size.call_deferred()


func _close_panel() -> void:
	if not _panel_queue.is_empty():   # story pages that arrived while another panel was open
		_next_page()
		return
	_panel.visible = false
	_ship_mode = false
	paused.emit(false)
	panel_closed.emit()


func _button(text: String, action: Callable, enabled: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.add_theme_font_size_override("font_size", 26)
	b.custom_minimum_size.y = 64
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # long recipes wrap instead of widening the panel
	b.pressed.connect(action)
	_panel_body.add_child(b)
	_fit_panel()
	return b


## The ship panel: one row per repair and per craft, enabled when you can afford it.
func show_ship(inv: Inventory, repaired: Dictionary) -> void:
	_open("The Meridian", "Ship systems. Bring resources to repair them.")
	_ship_mode = true
	for id in Ship.REPAIRS:
		var cost: Dictionary = t.repairs[id]
		var info: Array = Ship.REPAIRS[id]
		if repaired.has(id):
			_button("%s: repaired" % info[0], func(): pass, false)
		else:
			_button("Repair %s (%s)\n%s" % [info[0], _cost_text(cost), info[1]],
					func(): repair.emit(id), inv.can_afford(cost))
	for item in Ship.CRAFTS:
		var cost: Dictionary = t.crafts[item]
		var info: Array = Ship.CRAFTS[item]
		_button("Make %s (%s): %s" % [info[0], _cost_text(cost), info[1]],
				func(): craft.emit(item), inv.can_afford(cost))
	_button("Close", _close_panel)


## Re-open the ship panel with fresh numbers (after a repair or craft).
func refresh_ship(inv: Inventory, repaired: Dictionary) -> void:
	if _ship_mode and _panel.visible:
		show_ship(inv, repaired)


func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for item in cost:
		parts.append("%d %s" % [int(cost[item]), ITEM_NAMES.get(item, item)])
	return ", ".join(parts)


func show_pause() -> void:
	_open("Paused", "World seed: %d\n\nMove with the buttons at the bottom. Tap a tile near you to mine it (hold to keep digging). Tap plants, wreckage, pods and stones to pick them up or read them. Tap the ship to repair it and make supplies." % world_seed)
	_button("Resume", _close_panel)
	_button("New world (new seed)", func():
		_close_panel()
		new_world.emit())
