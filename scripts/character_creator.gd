## Character creation: design your medieval character before the game starts.
## A live (walking) preview; your name (type it, or roll a random one); skin, hair, beard, hat,
## tunic, trousers, cloak and boots; and a background that decides your starting kit.
class_name CharacterCreator
extends Control

signal finished(look: Dictionary)

const BACKGROUND_IDS := ["woodcutter", "mason", "herbalist", "wanderer"]

var look := CharacterLook.default_look()
var _preview: TextureRect
var _frames: Array[Texture2D] = []
var _values := {}        # option key → value Label
var _name_edit: LineEdit
var _bg_label: Label
var _bg_desc: Label
var _anim := 0.0


func setup() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Pal.INK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var col := VBoxContainer.new()
	col.position = Vector2(6, 4)
	col.custom_minimum_size = Vector2(168, 0)
	col.add_theme_constant_override("separation", 1)
	add_child(col)
	var title := Label.new()
	title.text = "Who are you?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Pal.YELLOW)
	col.add_child(title)
	# Preview: the sprite ×5 on a little patch of grass.
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(44, 64)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(frame)
	_preview = TextureRect.new()
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.custom_minimum_size = Vector2(32, 56)
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(_preview)
	# Name.
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 2)
	col.add_child(name_row)
	var nl := Label.new()
	nl.text = "Name"
	nl.custom_minimum_size.x = 60
	name_row.add_child(nl)
	_name_edit = LineEdit.new()
	_name_edit.text = look.name
	_name_edit.max_length = 12
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_changed.connect(func(tx: String): look.name = tx)
	name_row.add_child(_name_edit)
	var dice := Button.new()
	dice.text = "?"
	dice.tooltip_text = "Random name"
	dice.pressed.connect(func():
		look.name = CharacterLook.random_name()
		_name_edit.text = look.name)
	name_row.add_child(dice)
	# One row per appearance option.
	for opt in CharacterLook.OPTIONS:
		_option_row(col, opt[0], opt[1])
	# Background.
	var bg_row := _arrow_row(col, "Origin", func(d: int): _cycle_background(d))
	_bg_label = bg_row
	_bg_desc = Label.new()
	_bg_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bg_desc.custom_minimum_size = Vector2(168, 18)
	_bg_desc.add_theme_color_override("font_color", Pal.TAN)
	col.add_child(_bg_desc)
	var begin := Button.new()
	begin.text = "Begin"
	begin.custom_minimum_size = Vector2(80, 16)
	begin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	begin.pressed.connect(_finish)
	col.add_child(begin)
	_refresh()


func _option_row(parent: Control, key: String, label: String) -> void:
	_values[key] = _arrow_row(parent, label, func(d: int):
		var n := CharacterLook.choice_count(key)
		look[key] = posmod(int(look[key]) + d, n)
		_refresh())


## A row "Label  < value >"; returns the value label.
func _arrow_row(parent: Control, label: String, on_step: Callable) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	parent.add_child(row)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 60
	l.add_theme_color_override("font_color", Pal.TAN)
	row.add_child(l)
	var left := Button.new()
	left.text = "<"
	left.custom_minimum_size = Vector2(14, 12)
	left.pressed.connect(func(): on_step.call(-1))
	row.add_child(left)
	var v := Label.new()
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	var right := Button.new()
	right.text = ">"
	right.custom_minimum_size = Vector2(14, 12)
	right.pressed.connect(func(): on_step.call(1))
	row.add_child(right)
	return v


func _cycle_background(d: int) -> void:
	var i := BACKGROUND_IDS.find(look.background)
	look.background = BACKGROUND_IDS[posmod(i + d, BACKGROUND_IDS.size())]
	_refresh()


func _refresh() -> void:
	for key in _values:
		(_values[key] as Label).text = CharacterLook.choice_name(look, key)
	var info: Array = Catalog.BACKGROUNDS[look.background]
	_bg_label.text = info[0]
	_bg_desc.text = info[1]
	_frames = CharacterLook.frames(look)
	_preview.texture = _frames[0]


func _process(dt: float) -> void:
	_anim += dt
	if not _frames.is_empty():   # walk in place: idle, step, idle, step
		var f: int = [0, 1, 0, 2][int(_anim * 4.0) % 4]
		_preview.texture = _frames[f]


func _finish() -> void:
	look.name = look.name.strip_edges()
	if look.name == "":
		look.name = CharacterLook.random_name()
	finished.emit(look)
