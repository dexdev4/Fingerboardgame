## The 8-bit UI look: pixel font, flat dark panels with a 1-pixel tan border, chunky buttons.
## Every menu and panel uses this theme.
class_name UiTheme
extends RefCounted

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var th := Theme.new()
	th.default_font = PixelFont.get_font()
	th.default_font_size = PixelFont.SIZE
	th.set_color("font_color", "Label", Pal.UI_TEXT)
	th.set_constant("line_spacing", "Label", 2)
	th.set_stylebox("panel", "PanelContainer", box(Pal.UI_BG, Pal.UI_EDGE, 4))
	th.set_stylebox("panel", "Panel", box(Pal.UI_BG, Pal.UI_EDGE, 4))
	for state in ["normal", "focus"]:
		th.set_stylebox(state, "Button", box(Pal.BARK_DARK, Pal.TAN, 3))
	th.set_stylebox("hover", "Button", box(Pal.BARK, Pal.CREAM, 3))
	th.set_stylebox("pressed", "Button", box(Pal.WOOD, Pal.CREAM, 3))
	th.set_stylebox("disabled", "Button", box(Color("2a2018"), Pal.UI_DIM, 3))
	th.set_color("font_color", "Button", Pal.UI_TEXT)
	th.set_color("font_hover_color", "Button", Pal.WHITE)
	th.set_color("font_pressed_color", "Button", Pal.WHITE)
	th.set_color("font_focus_color", "Button", Pal.UI_TEXT)
	th.set_color("font_disabled_color", "Button", Pal.UI_DIM)
	th.set_constant("line_spacing", "Button", 2)
	th.set_stylebox("normal", "LineEdit", box(Pal.INK, Pal.TAN, 3))
	th.set_stylebox("focus", "LineEdit", box(Pal.INK, Pal.CREAM, 3))
	th.set_color("font_color", "LineEdit", Pal.WHITE)
	th.set_color("caret_color", "LineEdit", Pal.YELLOW)
	# Thin scrollbar.
	var grab := StyleBoxFlat.new()
	grab.bg_color = Pal.TAN
	grab.content_margin_left = 2
	grab.content_margin_right = 2
	th.set_stylebox("grabber", "VScrollBar", grab)
	th.set_stylebox("grabber_highlight", "VScrollBar", grab)
	th.set_stylebox("grabber_pressed", "VScrollBar", grab)
	var track := StyleBoxFlat.new()
	track.bg_color = Pal.INK
	track.content_margin_left = 2
	track.content_margin_right = 2
	th.set_stylebox("scroll", "VScrollBar", track)
	_theme = th
	return th


## A flat box with a 1 px border (no rounded corners, no anti-aliasing: pixel-crisp).
static func box(bg: Color, edge: Color, pad: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = edge
	b.set_border_width_all(1)
	b.set_content_margin_all(pad)
	b.anti_aliasing = false
	return b
