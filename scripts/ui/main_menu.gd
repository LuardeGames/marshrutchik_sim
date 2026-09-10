extends Control
## Main menu: title, navigation, money/best-rating readout, settings modal.

## Explicit preloads keep the menu bootable even while Godot is rebuilding
## its global class cache after a fresh clone/import.
const SettingsOverlayScript := preload("res://scripts/ui/settings_overlay.gd")
const MenuBackdropScript := preload("res://scripts/ui/menu_backdrop.gd")

var settings_panel: Control
var route_info_label: Label
var route_buttons: Array[Button] = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	PlatformService.mark_loading_ready()
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
	vbox.position = Vector2(42, -310)
	vbox.custom_minimum_size = Vector2(360, 0)
	vbox.add_theme_constant_override("separation", 16)
	add_child(vbox)

	var title := UITheme.make_label("МАРШРУТЧИК", 46, UITheme.COLOR_ACCENT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var selected_route := SaveManager.get_selected_route()
	var subtitle := UITheme.make_label("Маршрут № %s · %s" % [RouteDefinition.route_number(selected_route), RouteDefinition.route_name(selected_route)], 16, UITheme.COLOR_TEXT_DIM)
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
	stats_panel.add_theme_stylebox_override("panel", UITheme.accent_panel_style())
	vbox.add_child(stats_panel)
	var stats_box := HBoxContainer.new()
	stats_box.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_box.add_theme_constant_override("separation", 24)
	stats_panel.add_child(stats_box)
	stats_box.add_child(UITheme.make_label("%d ₽" % SaveManager.get_money(), 20, UITheme.COLOR_ACCENT))
	stats_box.add_child(UITheme.make_label("★ %d" % int(SaveManager.data.get("best_rating", 0)), 20, UITheme.COLOR_TEXT))
	stats_box.add_child(UITheme.make_label("Рейсов: %d" % int(SaveManager.data.get("trips_completed", 0)), 18, UITheme.COLOR_TEXT_DIM))
	_build_route_selector(vbox)

	vbox.add_child(_menu_button("НА ЛИНИЮ", UITheme.COLOR_GOOD, func():
		GameManager.start_trip()))
	vbox.add_child(_menu_button("ГАРАЖ", UITheme.COLOR_ACCENT, func():
		GameManager.go_to_garage()))
	vbox.add_child(_menu_button("НАСТРОЙКИ И УПРАВЛЕНИЕ", UITheme.COLOR_ACCENT_2, func():
		settings_panel.visible = true))

func _build_route_selector(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_style(Color(0.07, 0.10, 0.12, 0.94)))
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	var title := UITheme.make_label("ВЫБОР МАРШРУТА", 13, UITheme.COLOR_TEXT_DIM, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	route_info_label = UITheme.make_label("", 13, UITheme.COLOR_ACCENT)
	route_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(route_info_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	for route_id in RouteDefinition.route_ids():
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(112, 48)
		btn.add_theme_font_size_override("font_size", 13)
		row.add_child(btn)
		route_buttons.append(btn)
		btn.pressed.connect(_select_route.bind(route_id))
	_refresh_route_selector()

func _select_route(route_id: String) -> void:
	if SaveManager.set_selected_route(route_id):
		AudioManager.play_ui_click()
		_refresh_route_selector()

func _refresh_route_selector() -> void:
	var selected := SaveManager.get_selected_route()
	var trips := int(SaveManager.data.get("trips_completed", 0))
	var index := 0
	for route_id in RouteDefinition.route_ids():
		var btn := route_buttons[index]
		var unlocked := SaveManager.is_route_unlocked(route_id)
		var is_selected := route_id == selected
		btn.text = "№ %s\n%s" % [RouteDefinition.route_number(route_id), RouteDefinition.route_name(route_id)] if unlocked else "№ %s\nещё %d рейс" % [RouteDefinition.route_number(route_id), maxi(0, RouteDefinition.route_unlock_trips(route_id) - trips)]
		btn.disabled = not unlocked or is_selected
		UITheme.style_button(btn, UITheme.COLOR_GOOD if is_selected else UITheme.COLOR_ACCENT, Color(0.05, 0.05, 0.05), 13)
		btn.custom_minimum_size = Vector2(112, 48)
		index += 1
	if route_info_label:
		route_info_label.text = "%s · %s" % [RouteDefinition.route_name(selected), RouteDefinition.route_description(selected)]

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
