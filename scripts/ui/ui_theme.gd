extends RefCounted
class_name UITheme
## Shared style helpers so every screen looks like one coherent game, not
## default Godot controls. Visual language: a provincial transit operator's
## route board - dark asphalt panels, an amber route-number accent, crisp
## corners instead of bubbly ones, and a digital-display font for numbers.

## Manrope (OFL, full Cyrillic) for every label/button; JetBrains Mono (OFL,
## full Cyrillic + tabular digits) for the HUD readouts that should feel like
## a dashboard display rather than body text. Both are variable fonts, so a
## single file covers the whole weight range via FontVariation.
const _FONT_UI: FontFile = preload("res://assets/fonts/Manrope-Variable.ttf")
const _FONT_MONO: FontFile = preload("res://assets/fonts/JetBrainsMono-Bold.ttf")

const COLOR_BG := Color(0.067, 0.078, 0.098, 0.94)
const COLOR_PANEL := Color(0.106, 0.125, 0.153, 0.93)
const COLOR_PANEL_DEEP := Color(0.055, 0.067, 0.086, 0.95)
const COLOR_ACCENT := Color("ffb020") # route-board amber
const COLOR_ACCENT_2 := Color("39a0d1") # cool signal blue
const COLOR_GOOD := Color("4fc26b")
const COLOR_BAD := Color("e2544a")
const COLOR_TEXT := Color(0.95, 0.96, 0.97)
const COLOR_TEXT_DIM := Color(0.68, 0.72, 0.78)
const COLOR_BORDER := Color(1, 1, 1, 0.07)

static var _font_cache: Dictionary = {}

## Variable-font weight lookup, cached per (family, weight) pair - avoids
## rebuilding a FontVariation resource for every label on every screen.
static func _weighted_font(base: FontFile, weight: int) -> FontVariation:
	var key := "%s_%d" % [base.resource_path, weight]
	if _font_cache.has(key):
		return _font_cache[key]
	var variation := FontVariation.new()
	variation.base_font = base
	variation.variation_opentype = {"wght": weight}
	_font_cache[key] = variation
	return variation

static func font_ui(weight: int = 500) -> FontVariation:
	return _weighted_font(_FONT_UI, weight)

static func font_mono(weight: int = 700) -> FontVariation:
	return _weighted_font(_FONT_MONO, weight)

static func panel_style(bg: Color = COLOR_PANEL, radius: int = 8, border: Color = COLOR_BORDER) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.set_content_margin_all(14)
	sb.shadow_size = 8
	sb.shadow_color = Color(0, 0, 0, 0.3)
	return sb

## A panel with a route-board accent strip along the top edge - the one
## recurring motif that ties HUD, menu and garage panels to the same object
## (a marshrutka's route sign) without needing any bitmap art.
static func accent_panel_style(bg: Color = COLOR_PANEL, accent: Color = COLOR_ACCENT, radius: int = 8) -> StyleBoxFlat:
	var sb := panel_style(bg, radius)
	sb.border_width_top = 3
	sb.border_color = accent
	return sb

static func button_style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(16)
	return sb

static func style_button(btn: Button, bg: Color = COLOR_ACCENT, text_color: Color = Color(0.08, 0.08, 0.09), font_size: int = 22) -> void:
	btn.add_theme_stylebox_override("normal", button_style(bg))
	btn.add_theme_stylebox_override("hover", button_style(bg.lightened(0.15)))
	btn.add_theme_stylebox_override("pressed", button_style(bg.darkened(0.15)))
	btn.add_theme_stylebox_override("disabled", button_style(bg.darkened(0.4)))
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", text_color)
	btn.add_theme_color_override("font_disabled_color", COLOR_TEXT_DIM)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_font_override("font", font_ui(700))
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
	l.add_theme_font_override("font", font_ui(800 if bold else 500))
	return l

## For readouts that should look like a dashboard/route-board display -
## speed, timer, money ticker - rather than body copy.
static func make_mono_label(text: String, size: int, color: Color = COLOR_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", font_mono(700))
	return l
