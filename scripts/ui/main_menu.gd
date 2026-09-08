extends Control
## Main menu: title, navigation, money/best-rating readout, settings modal.

var settings_panel: PanelContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_content()
	_build_settings_modal()
	AudioManager.set_engine_running(false)

func _build_background() -> void:
	add_child(MenuBackdrop.new())
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
	var subtitle := UITheme.make_label("Маршрут № 47 · Обычный город", 16, UITheme.COLOR_TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)
	var mastered := SaveManager.is_vehicle_unlocked("modern_microbus") and int(SaveManager.data.get("best_rating",0)) >= 3
	var goal := UITheme.make_label("Маршрут освоен! Улучшайте рекорд." if mastered else "Цель: купить ПАЗ и получить 3 звезды",14,UITheme.COLOR_TEXT_DIM)
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(goal)

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
	vbox.add_child(_menu_button("НАСТРОЙКИ", UITheme.COLOR_ACCENT_2, func():
		settings_panel.visible = true))

func _menu_button(text: String, color: Color, action: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	UITheme.style_button(btn, color, Color(0.08, 0.08, 0.08), 24)
	btn.custom_minimum_size = Vector2(360, 64)
	btn.pressed.connect(func():
		AudioManager.play_ui_click()
		action.call())
	return btn

func _build_settings_modal() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.COLOR_BG, 20))
	settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	settings_panel.position = Vector2(-180, -160)
	settings_panel.custom_minimum_size = Vector2(360, 300)
	settings_panel.visible = false
	add_child(settings_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	settings_panel.add_child(vbox)
	vbox.add_child(UITheme.make_label("Настройки звука", 22, UITheme.COLOR_ACCENT, true))

	vbox.add_child(_sound_slider("Общая громкость", "master"))
	vbox.add_child(_sound_slider("Музыка", "music"))
	vbox.add_child(_sound_slider("Звуки", "sfx"))

	var mute_btn := CheckButton.new()
	mute_btn.text = "Без звука"
	mute_btn.button_pressed = SaveManager.is_muted()
	vbox.add_child(mute_btn)
	mute_btn.toggled.connect(func(pressed): SaveManager.set_muted(pressed))

	var close_btn := Button.new()
	close_btn.text = "Закрыть"
	UITheme.style_button(close_btn, UITheme.COLOR_PANEL.lightened(0.1), UITheme.COLOR_TEXT)
	vbox.add_child(close_btn)
	close_btn.pressed.connect(func():
		AudioManager.play_ui_click()
		settings_panel.visible = false)

func _sound_slider(label: String, key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := UITheme.make_label(label, 16, UITheme.COLOR_TEXT_DIM)
	l.custom_minimum_size = Vector2(140, 0)
	row.add_child(l)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = SaveManager.get_sound_setting(key)
	slider.custom_minimum_size = Vector2(160, 0)
	row.add_child(slider)
	slider.value_changed.connect(func(v): SaveManager.set_sound_setting(key, v))
	return row
