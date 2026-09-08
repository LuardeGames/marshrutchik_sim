extends RefCounted
class_name UITheme
## Shared style helpers so every screen looks like one coherent game, not
## default Godot controls.

const COLOR_BG := Color(0.09, 0.11, 0.16, 0.92)
const COLOR_PANEL := Color(0.13, 0.16, 0.22, 0.92)
const COLOR_ACCENT := Color(0.98, 0.78, 0.2)
const COLOR_ACCENT_2 := Color(0.25, 0.65, 0.95)
const COLOR_GOOD := Color(0.35, 0.85, 0.4)
const COLOR_BAD := Color(0.9, 0.35, 0.3)
const COLOR_TEXT := Color(0.96, 0.96, 0.98)
const COLOR_TEXT_DIM := Color(0.72, 0.75, 0.8)

static func panel_style(bg: Color = COLOR_PANEL, radius: int = 14, border: Color = Color(1, 1, 1, 0.08)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.set_content_margin_all(14)
	sb.shadow_size = 3
	sb.shadow_color = Color(0, 0, 0, 0.25)
	return sb

static func button_style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(16)
	return sb

static func style_button(btn: Button, bg: Color = COLOR_ACCENT, text_color: Color = Color(0.1, 0.1, 0.1), font_size: int = 22) -> void:
	btn.add_theme_stylebox_override("normal", button_style(bg))
	btn.add_theme_stylebox_override("hover", button_style(bg.lightened(0.15)))
	btn.add_theme_stylebox_override("pressed", button_style(bg.darkened(0.15)))
	btn.add_theme_stylebox_override("disabled", button_style(bg.darkened(0.4)))
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", text_color)
	btn.add_theme_color_override("font_disabled_color", COLOR_TEXT_DIM)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.custom_minimum_size = Vector2(0, 52)
	btn.focus_mode = Control.FOCUS_ALL
	var focus:=button_style(Color(0,0,0,0))
	focus.set_border_width_all(2)
	focus.border_color=COLOR_TEXT
	btn.add_theme_stylebox_override("focus",focus)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

static func make_label(text: String, size: int, color: Color = COLOR_TEXT, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
