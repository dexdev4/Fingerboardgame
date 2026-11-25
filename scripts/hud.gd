## Everything on screen except the world and the touch buttons (all at 180×320, 8-bit style):
##  - top: health / hunger / warmth / stamina bars, clock, place, current goal
##  - buttons above the controls: CRAFT, BAG, BUILD (in the cabin), pause
##  - short messages ("+3 Log")
##  - one panel for: story pages, crafting, your bag, the chest, the pause menu
##  - the build palette (pick furniture to place, or remove)
## UI only: it emits signals; Main runs the game logic.
class_name Hud
extends CanvasLayer

signal craft(id: String)
signal use_item(id: String)
signal open_craft
signal open_bag
signal toggle_build
signal build_pick(id: String)
signal build_remove
signal chest_deposit
signal chest_take
signal paused(on: bool)
signal quit_to_title

const STATS := ["health", "hunger", "warmth", "stamina"]
const STAT_COLORS := {"health": Pal.RED, "hunger": Pal.ORANGE, "warmth": Pal.YELLOW, "stamina": Pal.LIME}

var t: GameTuning
var world_seed := 0
var _root: Control
var _stats: Control
var _stat_values := {}
var _clock: Label
var _place: Label
var _goal: Label
var _buttons: HBoxContainer
var _build_btn: Button
var _toasts: VBoxContainer
var _panel: PanelContainer
var _panel_title: Label
var _panel_text: Label
var _panel_body: VBoxContainer
var _scroll: ScrollContainer
var _queue: Array = []        # pending story pages [title, text]
var _mode := ""               # what the panel shows: story, craft, bag, chest, pause
var _palette: PanelContainer
var _palette_row: HBoxContainer
var _palette_hint: Label


func setup(tuning: GameTuning) -> void:
	t = tuning
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.get_theme()
	add_child(_root)
	_stats = Control.new()
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats.position = Vector2(3, 3)
	_stats.size = Vector2(174, 18)
	_stats.draw.connect(_draw_stats)
	_root.add_child(_stats)
	_clock = _label(Vector2(3, 23), Pal.CREAM)
	_place = _label(Vector2(3, 33), Pal.TAN)
	_goal = _label(Vector2(3, 43), Pal.YELLOW)
	_goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal.custom_minimum_size.x = 174
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 2)
	_root.add_child(_buttons)
	_hud_button("CRAFT", func(): open_craft.emit())
	_hud_button("BAG", func(): open_bag.emit())
	_build_btn = _hud_button("BUILD", func(): toggle_build.emit())
	_hud_button("II", func(): show_pause())
	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.add_theme_constant_override("separation", 1)
	_root.add_child(_toasts)
	_build_panel()
	_build_palette()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _label(pos: Vector2, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Pal.INK)
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	return l


func _hud_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 14)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(action)
	_buttons.add_child(b)
	return b


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.visible = false
	_root.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_panel.add_child(col)
	_panel_title = Label.new()
	_panel_title.add_theme_color_override("font_color", Pal.YELLOW)
	_panel_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_panel_title)
	_panel_text = Label.new()
	_panel_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_panel_text)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_panel_body = VBoxContainer.new()
	_panel_body.add_theme_constant_override("separation", 2)
	_panel_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_panel_body)


func _build_palette() -> void:
	_palette = PanelContainer.new()
	_palette.visible = false
	_root.add_child(_palette)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	_palette.add_child(col)
	_palette_hint = Label.new()
	_palette_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_palette_hint.add_theme_color_override("font_color", Pal.TAN)
	col.add_child(_palette_hint)
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size.y = 30
	col.add_child(sc)
	_palette_row = HBoxContainer.new()
	_palette_row.add_theme_constant_override("separation", 2)
	sc.add_child(_palette_row)


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var bar_top := size.y - t.touch_bar_height
	_buttons.position = Vector2(3, bar_top - 17)
	_buttons.size = Vector2(size.x - 6, 14)
	_toasts.position = Vector2(3, 64)   # under the goal line, clear of the ground and the cabin
	_toasts.size = Vector2(size.x - 6, 60)
	_palette.position = Vector2(2, 64)   # top of the screen: the cabin is drawn low, above the buttons
	_palette.size = Vector2(size.x - 4, 0)
	_palette.custom_minimum_size.x = size.x - 4
	_palette_hint.custom_minimum_size.x = size.x - 14
	_fit_panel()


# ---- Updates from Main -----------------------------------------------------------------------

func update_stats(s: Survival) -> void:
	for stat in STATS:
		_stat_values[stat] = s.get(stat) / t.get(stat + "_max")
	_stats.queue_redraw()


func _draw_stats() -> void:
	var blink := int(Time.get_ticks_msec() / 300) % 2 == 0
	for i in STATS.size():
		var stat: String = STATS[i]
		var pos := Vector2((i % 2) * 88, (i / 2) * 9)
		_stats.draw_texture(Sprites.icon("ui_" + stat), pos)
		var f: float = _stat_values.get(stat, 1.0)
		var bar := Rect2(pos + Vector2(10, 2), Vector2(74, 5))
		_stats.draw_rect(bar.grow(1), Pal.INK)
		_stats.draw_rect(bar, Color("2a2018"))
		var col: Color = STAT_COLORS[stat]
		if f < 0.2 and blink:
			col = Pal.WHITE
		_stats.draw_rect(Rect2(bar.position, Vector2(floorf(bar.size.x * f), bar.size.y)), col)
		_stats.draw_rect(Rect2(bar.position, Vector2(floorf(bar.size.x * f), 1)), col.lightened(0.3))


func update_info(clock: String, place: String, goal: String, at_home: bool) -> void:
	_clock.text = clock
	_place.text = place
	_goal.text = "Goal: " + goal
	_build_btn.disabled = not at_home


## A short message that fades away.
func toast(text: String, color: Color = Pal.CREAM) -> void:
	var l := Label.new()
	l.text = PixelFont.clean(text)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Pal.INK)
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = _toasts.size.x
	_toasts.add_child(l)
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)
	while _toasts.get_child_count() > 5:
		_toasts.get_child(0).free()


# ---- The panel ---------------------------------------------------------------------------------

func panel_open() -> bool:
	return _panel.visible


func panel_mode() -> String:
	return _mode if _panel.visible else ""


func _open(mode: String, title: String, text: String, scrolling: bool = false) -> void:
	_mode = mode
	for c in _panel_body.get_children():
		_panel_body.remove_child(c)
		c.queue_free()
	_panel_title.text = PixelFont.clean(title)
	_panel_text.text = PixelFont.clean(text)
	_panel_text.visible = text != ""
	_scroll.custom_minimum_size.y = 180 if scrolling else 0
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if scrolling else ScrollContainer.SCROLL_MODE_DISABLED
	_panel.visible = true
	_fit_panel()
	paused.emit(true)


func close_panel() -> void:
	if not _queue.is_empty():   # story pages that arrived while another panel was open
		_next_page()
		return
	_panel.visible = false
	_mode = ""
	paused.emit(false)


func _fit_panel() -> void:
	var size := get_viewport().get_visible_rect().size
	var w := size.x - 8
	_panel.position = Vector2(4, 30)
	_panel_title.custom_minimum_size.x = w - 10
	_panel_text.custom_minimum_size.x = w - 10
	_panel_body.custom_minimum_size.x = w - 14
	_panel.size = Vector2(w, 0)
	_panel.reset_size.call_deferred()


func _row_button(text: String, action: Callable, enabled: bool = true, icon: Texture2D = null) -> Button:
	var b := Button.new()
	b.text = PixelFont.clean(text)
	b.disabled = not enabled
	b.icon = icon
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0, 14)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(action)
	_panel_body.add_child(b)
	_fit_panel()
	return b


func _heading(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Pal.YELLOW)
	_panel_body.add_child(l)


## Queue a story page (chapters, journal pages...). Pages show one at a time and pause the game.
func show_story(title: String, text: String) -> void:
	_queue.append([title, text])
	if not _panel.visible:
		_next_page()


func _next_page() -> void:
	if _queue.is_empty():
		close_panel()
		return
	var page: Array = _queue.pop_front()
	_open("story", page[0], page[1])
	_row_button("Continue", _next_page)


## The craft list: every recipe, grouped; ones you can't make yet show why.
func show_craft(inv: Inventory, cabin: Cabin, at_home: bool) -> void:
	var where := "By hand"
	if at_home:
		var stations: Array[String] = []
		if cabin.has_function("workbench"):
			stations.append("workbench")
		if cabin.has_function("hearth"):
			stations.append("hearth")
		where = "At home: " + (", ".join(stations) if not stations.is_empty() else "no workbench yet")
	_open("craft", "Craft", where, true)
	for group in Catalog.GROUPS:
		_heading(group[0])
		for id in group[1]:
			var r: Dictionary = t.recipes[id]
			var why := Crafting.block(t, id, inv, cabin, at_home)
			var out := int(r.get("out", 1))
			var line := "%s%s\n%s" % [Catalog.item_name(id), (" x%d" % out) if out > 1 else "", Crafting.cost_text(r.cost)]
			if why != "" and why != "Not enough":
				line += "\n(" + why + ")"
			_row_button(line, func(): craft.emit(id), why == "", Catalog.icon(id) if Catalog.kind(id) != "upgrade" else null)
	_row_button("Close", close_panel)


func refresh_craft(inv: Inventory, cabin: Cabin, at_home: bool) -> void:
	if panel_mode() == "craft":
		var keep := _scroll.scroll_vertical
		show_craft(inv, cabin, at_home)
		_scroll.set_deferred("scroll_vertical", keep)


## Your bag: everything you carry; food and medicine can be used from here.
func show_bag(inv: Inventory) -> void:
	_open("bag", "Bag", "" if not inv.items.is_empty() else "Empty.", true)
	for id in inv.ids():
		var k := Catalog.kind(id)
		var n := inv.count(id)
		var label := "%s x%d" % [Catalog.item_name(id), n]
		match k:
			"food":
				_row_button(label + "  (eat: +%d food)" % int(t.food_values.get(id, 0)), func(): use_item.emit(id), true, Catalog.icon(id))
			"medicine":
				_row_button(label + "  (use: +%d health)" % int(t.heal_values.get(id, 0)), func(): use_item.emit(id), true, Catalog.icon(id))
			"furniture":
				_row_button(label + "  (place it with BUILD)", func(): pass, false, Catalog.icon(id))
			_:
				_row_button(label, func(): pass, false, Catalog.icon(id))
	_row_button("Close", close_panel)


func refresh_bag(inv: Inventory) -> void:
	if panel_mode() == "bag":
		show_bag(inv)


## The chest in your cabin: what's in it, and buttons to store or take.
func show_chest(chest: Inventory) -> void:
	var lines: Array[String] = []
	for id in chest.ids():
		lines.append("%s x%d" % [Catalog.item_name(id), chest.count(id)])
	_open("chest", "Chest", "Things in the chest are safe if you collapse in the woods.\n\n" +
			("\n".join(lines) if not lines.is_empty() else "(empty)"), false)
	_row_button("Put in materials and food", func(): chest_deposit.emit())
	_row_button("Take everything", func(): chest_take.emit())
	_row_button("Close", close_panel)


func refresh_chest(chest: Inventory) -> void:
	if panel_mode() == "chest":
		show_chest(chest)


func show_pause() -> void:
	_open("pause", "Paused", "World seed %d\n\nWalk with the buttons at the bottom. Tap a tree to chop it, the ground to dig, and plants, rocks, pages and stones to take or read them. Hold your finger down to keep working.\n\nIn your cabin, tap furniture to use it and press BUILD to arrange it." % world_seed)
	_row_button("Resume", close_panel)
	_row_button("Save and quit to title", func():
		_panel.visible = false
		_mode = ""
		quit_to_title.emit())


# ---- Build palette ----------------------------------------------------------------------------

func show_palette(inv: Inventory, selected: String, removing: bool) -> void:
	_palette.visible = true
	_toasts.position.y = 120   # messages move below the palette while building
	for c in _palette_row.get_children():
		_palette_row.remove_child(c)
		c.queue_free()
	var any := false
	for id in inv.ids():
		if not Catalog.is_furniture(id):
			continue
		any = true
		var b := Button.new()
		b.icon = Catalog.icon(id)
		b.text = "%d" % inv.count(id)
		b.toggle_mode = true
		b.button_pressed = id == selected
		b.tooltip_text = Catalog.item_name(id)
		b.pressed.connect(func(): build_pick.emit(id))
		_palette_row.add_child(b)
	var rm := Button.new()
	rm.text = "Take\nback"
	rm.toggle_mode = true
	rm.button_pressed = removing
	rm.pressed.connect(func(): build_remove.emit())
	_palette_row.add_child(rm)
	var done := Button.new()
	done.text = "Done"
	done.pressed.connect(func(): toggle_build.emit())
	_palette_row.add_child(done)
	if removing:
		_palette_hint.text = "Tap a piece to put it back in your bag."
	elif selected != "":
		_palette_hint.text = "Tap the room to place: %s" % Catalog.item_name(selected)
	elif any:
		_palette_hint.text = "Pick something to place."
	else:
		_palette_hint.text = "Nothing to place. Craft furniture at your workbench."


func hide_palette() -> void:
	_palette.visible = false
	_toasts.position.y = 64
