class_name UiKit
extends RefCounted
## Shared theme and widget helpers for the placeholder UI.

const SCREEN := Vector2(720, 1280)

static var _theme: Theme


static func theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	_theme.default_font_size = 24
	var normal := _box(Palette.BARK, Palette.INK)
	var hover := _box(Palette.BARK.lightened(0.15), Palette.INK)
	var pressed := _box(Palette.BARK.darkened(0.2), Palette.PARCHMENT)
	var disabled := _box(Palette.BARK.darkened(0.45), Palette.INK)
	for state in [["normal", normal], ["hover", hover], ["pressed", pressed], ["disabled", disabled], ["focus", StyleBoxEmpty.new()]]:
		_theme.set_stylebox(state[0], "Button", state[1])
	_theme.set_color("font_color", "Button", Palette.PARCHMENT)
	_theme.set_color("font_hover_color", "Button", Palette.PARCHMENT)
	_theme.set_color("font_pressed_color", "Button", Palette.PARCHMENT)
	_theme.set_color("font_disabled_color", "Button", Palette.BIRCH.darkened(0.4))
	_theme.set_color("font_color", "Label", Palette.PARCHMENT)
	_theme.set_stylebox("panel", "PanelContainer", _box(Palette.NIGHT.lightened(0.08), Palette.INK))
	return _theme


static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(3)
	b.set_corner_radius_all(10)
	b.content_margin_left = 16
	b.content_margin_right = 16
	b.content_margin_top = 10
	b.content_margin_bottom = 10
	return b


static func button(text: String, on_press: Callable, min_size := Vector2(0, 64)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.pressed.connect(on_press)
	return b


static func label(text: String, size := 24, color := Palette.PARCHMENT, wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func background(parent: Control, color := Palette.NIGHT) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = color
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	return bg
