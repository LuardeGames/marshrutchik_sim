extends Control
## Main menu: title, navigation, money/best-rating readout, settings modal.

## Explicit preloads keep the menu bootable even while Godot is rebuilding
## its global class cache after a fresh clone/import.
const SettingsOverlayScript := preload("res://scripts/ui/settings_overlay.gd")
const MenuBackdropScript := preload("res://scripts/ui/menu_backdrop.gd")

var settings_panel: Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_content()
	_build_settings_modal()
	AudioManager.set_engine_running(false)

func _build_background() -> void:
	add_child(MenuBackdropScript.new())
	var shade := ColorRect.new()
	shade.color = Color(0.03,0.05,0.07,0.82)
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 460
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

func _build_content() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	vbox.position = Vector2(42, -225)
	vbox.custom_minimum_size = Vector2(360, 0)
	vbox.add_theme_constant_override("separation", 16)
	add_child(vbox)

	var title := UITheme.make_label("МАРШРУТЧИК", 46, UITheme.COLOR_ACCENT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var subtitle := UITheme.make_label("Маршрут № 47 · От спальника до вокзала", 16, UITheme.COLOR_TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)
	var mastered := bool(SaveManager.data.get("route_mastered",false))
	var goal := UITheme.make_label("Маршрут освоен! Улучшайте рекорд." if mastered else "Цель: купить ПАЗ и пройти на нём на 3 звезды",14,UITheme.COLOR_TEXT_DIM)
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(goal)
	var daily := DailyChallenge.today()
	var daily_label := UITheme.make_label("РЕЙС ДНЯ · %s\n%s" % [daily.title, daily.description], 14, UITheme.COLOR_ACCENT_2, true)
	daily_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	daily_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(daily_label)

	var stats_panel := PanelContainer.new()
	stats_panel.add_theme_stylebox_override("panel", UITheme.panel_style())
	vbox.add_child(stats_panel)
	var stats_box := HBoxContainer.new()
	stats_box.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_box.add_theme_constant_override("separation", 24)
	stats_panel.add_child(stats_box)
	stats_box.add_child(UITheme.make_label("%d ₽" % SaveManager.get_money(), 20, UITheme.COLOR_ACCENT))
	stats_box.add_child(UITheme.make_label("★ %d" % int(SaveManager.data.get("best_rating", 0)), 20, UITheme.COLOR_TEXT))
	stats_box.add_child(UITheme.make_label("Рейсов: %d" % int(SaveManager.data.get("trips_completed", 0)), 18, UITheme.COLOR_TEXT_DIM))

	vbox.add_child(_menu_button("НА ЛИНИЮ", UITheme.COLOR_GOOD, func():
		GameManager.start_trip()))
	vbox.add_child(_menu_button("ГАРАЖ", UITheme.COLOR_ACCENT, func():
		GameManager.go_to_garage()))
	vbox.add_child(_menu_button("НАСТРОЙКИ И УПРАВЛЕНИЕ", UITheme.COLOR_ACCENT_2, func():
		settings_panel.visible = true))

func _menu_button(text: String, color: Color, action: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	UITheme.style_button(btn, color, Color(0.08, 0.08, 0.08), 20)
	btn.custom_minimum_size = Vector2(360, 64)
	btn.pressed.connect(func():
		AudioManager.play_ui_click()
		action.call())
	return btn

func _build_settings_modal() -> void:
	settings_panel=SettingsOverlayScript.new()
	add_child(settings_panel)
