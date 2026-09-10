extends CanvasLayer
## In-run HUD: speed/comfort/money/passenger readouts, contextual
## notifications, mobile touch controls, change-giving mini-event, and the
## end-of-trip result screen. Built entirely in code for full control over
## the visual style.

var vehicle: VehicleController
var route_manager: RouteManager
var passenger_manager: PassengerManager

var comfort_bar: ProgressBar
var money_label: Label
var speed_label: Label
var passengers_label: Label
var rules_label: Label
var current_stop_label: Label
var next_stop_label: Label
var route_dots: HBoxContainer
var notification_label: Label
var notification_timer: float = 0.0
var fine_banner: PanelContainer
var fine_amount_label: Label
var fine_detail_label: Label
var fine_timer: float = 0.0

var change_popup: PanelContainer
var result_layer: Control
var is_touch_device: bool = false
var pause_layer: Control
var route_map: RouteMap
var context_label: Label
var time_label: Label
var change_label: Label
var settings: SettingsOverlay
var _notification_tween: Tween
var _change_pending := false
var double_reward_button: Button

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_touch_device = DisplayServer.is_touchscreen_available() or OS.get_cmdline_user_args().has("--touch-ui")
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	route_map = RouteMap.new()
	route_map.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	route_map.position = Vector2(-236, -335 if is_touch_device else -215)
	route_map.size = Vector2(220,180)
	root.add_child(route_map)
	_build_top_bar(root)
	_build_route_bar(root)
	_build_notification(root)
	_build_fine_banner(root)
	_build_change_popup(root)
	_build_menu_button(root)
	if is_touch_device:
		_build_mobile_controls(root)
	_build_pause(root)
	_build_result_screen(root)
	_build_context(root)
	settings=SettingsOverlay.new()
	root.add_child(settings)

	EventBus.notification.connect(_on_notification)
	EventBus.comfort_changed.connect(_on_comfort_changed)
	EventBus.money_earned.connect(_on_money_earned)
	EventBus.change_choice_requested.connect(_on_change_requested)
	EventBus.rule_violation.connect(_on_rule_violation)
	EventBus.trip_completed.connect(_on_trip_completed)
	EventBus.trip_failed.connect(_on_trip_failed)
	GameManager.double_reward_claimed.connect(_on_double_reward_claimed)
	if route_manager:
		route_manager.next_stop_changed.connect(_on_next_stop_changed)

func bind(v: VehicleController, rm: RouteManager, pm: PassengerManager) -> void:
	vehicle = v
	route_manager = rm
	passenger_manager = pm
	route_map.vehicle = v
	route_map.route_manager = rm
	rm.next_stop_changed.connect(_on_next_stop_changed)
	_on_next_stop_changed(rm.get_next_stop())
	_refresh_money()

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if vehicle:
		speed_label.text = "%d км/ч" % int(vehicle.get_speed_kmh())
		passengers_label.text = "В салоне: %d / %d" % [vehicle.passengers_aboard, vehicle.capacity]
	if rules_label:
		rules_label.text = "Штрафы: %d ₽ · Ошибки: %d" % [GameManager.fines_paid, GameManager.rule_violations]
	if fine_timer > 0.0:
		fine_timer -= delta
		if fine_timer <= 0.0 and fine_banner:
			var fine_tween := create_tween()
			fine_tween.tween_property(fine_banner, "modulate:a", 0.0, 0.35)
			fine_tween.tween_callback(fine_banner.hide)
	_refresh_context()
	if notification_timer > 0.0:
		notification_timer -= delta
		if notification_timer <= 0.0:
			_notification_tween = create_tween()
			_notification_tween.tween_property(notification_label, "modulate:a", 0.0, 0.4)

# ---------------------------------------------------------------------------
# Top bar: money / comfort / speed / passengers
# ---------------------------------------------------------------------------

func _build_top_bar(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.accent_panel_style())
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(16, 16)
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 18)
	vbox.add_child(row1)

	money_label = UITheme.make_mono_label(str(SaveManager.get_money()) + " ₽", 24, UITheme.COLOR_ACCENT)
	row1.add_child(money_label)
	speed_label = UITheme.make_mono_label("0 км/ч", 24, UITheme.COLOR_TEXT)
	row1.add_child(speed_label)
	passengers_label = UITheme.make_label("В салоне: 0 / 10", 20, UITheme.COLOR_ACCENT_2)
	row1.add_child(passengers_label)

	var comfort_row := HBoxContainer.new()
	comfort_row.add_theme_constant_override("separation", 8)
	vbox.add_child(comfort_row)
	comfort_row.add_child(UITheme.make_label("Комфорт", 16, UITheme.COLOR_TEXT_DIM))
	comfort_bar = ProgressBar.new()
	comfort_bar.custom_minimum_size = Vector2(180, 16)
	comfort_bar.max_value = 100
	comfort_bar.value = 100
	comfort_bar.show_percentage = false
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0, 0, 0, 0.4)
	bg_sb.set_corner_radius_all(8)
	comfort_bar.add_theme_stylebox_override("background", bg_sb)
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = UITheme.COLOR_GOOD
	fill_sb.set_corner_radius_all(8)
	comfort_bar.add_theme_stylebox_override("fill", fill_sb)
	comfort_row.add_child(comfort_bar)
	rules_label = UITheme.make_label("Штрафы: 0 ₽ · Ошибки: 0", 14, UITheme.COLOR_TEXT_DIM)
	vbox.add_child(rules_label)

func _on_comfort_changed(value: float) -> void:
	if comfort_bar == null:
		return
	comfort_bar.value = value
	var fill: StyleBoxFlat = comfort_bar.get_theme_stylebox("fill")
	if value > 60:
		fill.bg_color = UITheme.COLOR_GOOD
	elif value > 30:
		fill.bg_color = UITheme.COLOR_ACCENT
	else:
		fill.bg_color = UITheme.COLOR_BAD

func _on_money_earned(_amount: int, _reason: String) -> void:
	_refresh_money()

func _refresh_money() -> void:
	if money_label:
		money_label.text = "%d ₽" % SaveManager.get_money()

# ---------------------------------------------------------------------------
# Route bar: current/next stop + progress dots
# ---------------------------------------------------------------------------

func _build_route_bar(root: Control) -> void:
	# Wrapped in a full-width CenterContainer so the panel is reliably
	# centered without fighting anchors - and pushed below the top-left
	# money/speed/comfort panel so the two never overlap.
	var wrapper := CenterContainer.new()
	wrapper.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	wrapper.position = Vector2(-510, 16)
	wrapper.custom_minimum_size.x=430
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wrapper)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.accent_panel_style())
	wrapper.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var labels := VBoxContainer.new()
	labels.alignment = BoxContainer.ALIGNMENT_CENTER
	labels.add_theme_constant_override("separation", 2)
	vbox.add_child(labels)
	current_stop_label = UITheme.make_label("МАРШРУТ № %s" % RouteDefinition.route_number(), 14, UITheme.COLOR_TEXT_DIM)
	labels.add_child(current_stop_label)
	next_stop_label = UITheme.make_label("Следующая: —", 20, UITheme.COLOR_ACCENT, true)
	labels.add_child(next_stop_label)

	route_dots = HBoxContainer.new()
	route_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	route_dots.add_theme_constant_override("separation", 6)
	vbox.add_child(route_dots)
	var stop_defs := RouteDefinition.stops()
	for i in range(stop_defs.size()):
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(14, 14)
		dot.color = UITheme.COLOR_TEXT_DIM
		route_dots.add_child(dot)

func _on_next_stop_changed(stop: StopArea) -> void:
	if stop == null or next_stop_label == null:
		return
	next_stop_label.text = "%s" % stop.stop_name
	for i in range(route_dots.get_child_count()):
		var dot: ColorRect = route_dots.get_child(i)
		dot.color = UITheme.COLOR_ACCENT if i < stop.stop_id else (UITheme.COLOR_ACCENT_2 if i == stop.stop_id else UITheme.COLOR_TEXT_DIM)
	if stop.stop_id > 0:
		var stops := RouteDefinition.stops()
		current_stop_label.text = "МАРШРУТ № %s  ·  ОСТАНОВКА %d / %d" % [RouteDefinition.route_number(), stop.stop_id+1, route_manager.stops.size()]

# ---------------------------------------------------------------------------
# Notifications
# ---------------------------------------------------------------------------

func _build_notification(root: Control) -> void:
	notification_label = Label.new()
	notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification_label.add_theme_font_size_override("font_size", 22)
	notification_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT)
	notification_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	notification_label.add_theme_constant_override("shadow_offset_x", 2)
	notification_label.add_theme_constant_override("shadow_offset_y", 2)
	notification_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	notification_label.anchor_top = 0.20
	notification_label.anchor_bottom = 0.20
	notification_label.modulate.a = 0.0
	root.add_child(notification_label)

func _on_notification(text: String, duration: float) -> void:
	if _notification_tween and _notification_tween.is_valid():
		_notification_tween.kill()
	notification_label.text = text
	notification_label.modulate.a = 1.0
	notification_timer = duration

func _build_fine_banner(root: Control) -> void:
	var wrapper := CenterContainer.new()
	wrapper.set_anchors_preset(Control.PRESET_TOP_WIDE)
	wrapper.position = Vector2(0, 112)
	wrapper.custom_minimum_size = Vector2(0, 112)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wrapper)
	fine_banner = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.48, 0.055, 0.045, 0.96)
	style.border_color = Color("ffb04d")
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0.12, 0.0, 0.0, 0.75)
	style.shadow_size = 12
	fine_banner.add_theme_stylebox_override("panel", style)
	fine_banner.custom_minimum_size = Vector2(420, 96)
	fine_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(fine_banner)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	fine_banner.add_child(col)
	var title := UITheme.make_label("⚠  НАРУШЕНИЕ", 18, Color("ffe4a6"), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	fine_amount_label = UITheme.make_label("−0 ₽", 34, Color.WHITE, true)
	fine_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(fine_amount_label)
	fine_detail_label = UITheme.make_label("", 15, Color("ffe4d0"))
	fine_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(fine_detail_label)
	fine_banner.visible = false

func _on_rule_violation(kind: String, fine: int) -> void:
	if fine_banner == null:
		return
	var detail: String = "Нарушение правил"
	match kind:
		"speed": detail = "Превышение скорости"
		"red_light": detail = "Проезд на красный"
		"moving_doors": detail = "Двери открыты на ходу"
		"wrong_direction": detail = "Движение против потока"
		"sidewalk": detail = "Езда по тротуару"
		"off_route": detail = "Съезд с маршрута"
		"collision": detail = "Опасное столкновение"
		_: detail = kind
	fine_amount_label.text = "−%d ₽" % fine
	fine_detail_label.text = detail
	fine_banner.show()
	fine_banner.modulate.a = 1.0
	fine_timer = 3.2
	var flash := create_tween()
	flash.tween_property(fine_banner, "scale", Vector2(1.06, 1.06), 0.10)
	flash.tween_property(fine_banner, "scale", Vector2.ONE, 0.18)

# ---------------------------------------------------------------------------
# Change-giving mini event
# ---------------------------------------------------------------------------

func _build_change_popup(root: Control) -> void:
	change_popup = PanelContainer.new()
	change_popup.add_theme_stylebox_override("panel", UITheme.panel_style())
	change_popup.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	change_popup.position = Vector2(-205, -345 if is_touch_device else -250)
	change_popup.visible = false
	root.add_child(change_popup)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	change_popup.add_child(vbox)
	change_label=UITheme.make_label("",18,UITheme.COLOR_TEXT,true)
	vbox.add_child(change_label)
	var row := HBoxContainer.new()
	row.name = "OptionsRow"
	row.add_theme_constant_override("separation", 10)
	vbox.add_child(row)

func _on_change_requested(fare: int, given: int, options: Array) -> void:
	if _change_pending or GameManager.state != GameManager.State.DRIVING:
		return
	_change_pending=true
	change_label.text="Дали %d ₽ · Проезд %d ₽\nСколько сдачи вернуть?" % [given,fare]
	var row: HBoxContainer = change_popup.find_child("OptionsRow", true, false)
	for c in row.get_children():
		c.queue_free()
	var correct := given - fare
	for opt in options:
		var btn := Button.new()
		btn.text = "%d ₽" % opt
		UITheme.style_button(btn, UITheme.COLOR_ACCENT_2, Color(1, 1, 1))
		btn.custom_minimum_size = Vector2(100, 60)
		row.add_child(btn)
		btn.pressed.connect(_on_change_option_picked.bind(opt, correct))
	change_popup.visible = true

func _on_change_option_picked(chosen: int, correct: int) -> void:
	if not _change_pending or GameManager.state != GameManager.State.DRIVING:
		return
	_change_pending=false
	AudioManager.play_ui_click()
	change_popup.visible = false
	if chosen == correct:
		EconomyManager.add_comfort_bonus(15)
		EventBus.notification.emit("Точная сдача! +15 ₽ бонус", 2.0)
	else:
		EventBus.notification.emit("Ошиблись со сдачей... пассажир недоволен.", 2.0)
		GameManager.modify_comfort(-3.0)

# ---------------------------------------------------------------------------
# Menu / pause button
# ---------------------------------------------------------------------------

func _build_menu_button(root: Control) -> void:
	var btn := Button.new()
	btn.text = "☰"
	UITheme.style_button(btn, UITheme.COLOR_PANEL, UITheme.COLOR_TEXT, 22)
	btn.custom_minimum_size = Vector2(52, 52)
	btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn.position = Vector2(-68, 16)
	root.add_child(btn)
	btn.pressed.connect(func():
		AudioManager.play_ui_click()
		_set_paused(true))

# ---------------------------------------------------------------------------
# Mobile touch controls
# ---------------------------------------------------------------------------

func _build_mobile_controls(root: Control) -> void:
	var steer_box := HBoxContainer.new()
	steer_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	steer_box.position = Vector2(20, -110)
	steer_box.add_theme_constant_override("separation", 14)
	root.add_child(steer_box)
	steer_box.add_child(_touch_button("◀", func(p): InputState.steer_left_touch = p))
	steer_box.add_child(_touch_button("▶", func(p): InputState.steer_right_touch = p))

	var pedal_box := HBoxContainer.new()
	pedal_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	pedal_box.position = Vector2(-282, -110)
	pedal_box.add_theme_constant_override("separation", 14)
	root.add_child(pedal_box)
	pedal_box.add_child(_touch_button("Двери", func(p): if p: InputState.doors_touch_pressed = true))
	pedal_box.add_child(_touch_button("Тормоз", func(p): InputState.brake_touch = p))
	pedal_box.add_child(_touch_button("▲", func(p): InputState.throttle_touch = p))

func _touch_button(label: String, callback: Callable) -> TouchControl:
	var control:=TouchControl.new()
	control.caption=label
	control.held_changed.connect(callback)
	return control

# ---------------------------------------------------------------------------
# Result screen
# ---------------------------------------------------------------------------

func _build_result_screen(root: Control) -> void:
	result_layer = Control.new()
	result_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_layer.visible = false
	result_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(result_layer)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_layer.add_child(bg)

	var center:=CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_layer.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.COLOR_BG, 20))
	panel.custom_minimum_size = Vector2(500, 0)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "ResultVBox"
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	var title:=UITheme.make_label("Рейс завершён",28,UITheme.COLOR_ACCENT,true)
	title.name="Title"
	vbox.add_child(title)

func _on_trip_completed(summary: Dictionary) -> void:
	_change_pending=false
	change_popup.hide()
	pause_layer.hide()
	if fine_banner:
		fine_banner.hide()
	InputState.reset_touch()
	var title: Label = result_layer.find_child("Title", true, false)
	title.text = "Рейс завершён"
	title.add_theme_color_override("font_color", UITheme.COLOR_ACCENT)
	var vbox: VBoxContainer = result_layer.find_child("ResultVBox", true, false)
	for c in vbox.get_children():
		if c.name != "Title":
			c.queue_free()
	await get_tree().process_frame

	var stars := "★".repeat(summary.rating) + "☆".repeat(3 - summary.rating)
	vbox.add_child(UITheme.make_label(stars, 26, UITheme.COLOR_ACCENT))
	vbox.add_child(UITheme.make_label("Пассажиров: %d" % summary.passengers, 18))
	vbox.add_child(UITheme.make_label("Выручка: %d ₽" % summary.fares, 18))
	vbox.add_child(UITheme.make_label("Остановки и время: %d ₽" % summary.get("stop_bonus", 0), 18, UITheme.COLOR_GOOD))
	vbox.add_child(UITheme.make_label("Бонус за комфорт: %d ₽" % summary.comfort_bonus, 18, UITheme.COLOR_GOOD))
	vbox.add_child(UITheme.make_label("Штрафы: -%d ₽" % summary.penalties, 18, UITheme.COLOR_BAD))
	vbox.add_child(UITheme.make_label("Нарушения: %d · оплачено штрафов: %d ₽" % [int(summary.get("rule_violations", 0)), int(summary.get("fines_paid", 0))], 16, UITheme.COLOR_BAD))
	vbox.add_child(UITheme.make_label("Состояние машины: %d%% · столкновений: %d" % [int(round(summary.get("vehicle_condition",100.0))), int(summary.get("collisions",0))], 16, UITheme.COLOR_TEXT_DIM))
	if int(summary.get("daily_bonus", 0)) > 0:
		vbox.add_child(UITheme.make_label("Рейс дня «%s»: +%d ₽" % [summary.get("daily_title", ""), int(summary.daily_bonus)], 16, UITheme.COLOR_ACCENT_2))
	vbox.add_child(UITheme.make_label("Время: %s" % GameManager.format_time(summary.time), 18))
	vbox.add_child(UITheme.make_label("Итог: %d ₽" % summary.total, 24, UITheme.COLOR_ACCENT, true))

	double_reward_button = Button.new()
	double_reward_button.text = "Посмотреть рекламу · ×2 итог"
	double_reward_button.disabled = int(summary.total) <= 0
	UITheme.style_button(double_reward_button, UITheme.COLOR_ACCENT_2, Color(0.05, 0.05, 0.05), 16)
	double_reward_button.custom_minimum_size = Vector2(0, 48)
	vbox.add_child(double_reward_button)
	double_reward_button.pressed.connect(func():
		double_reward_button.disabled = true
		double_reward_button.text = "Загрузка рекламы…"
		if not GameManager.claim_double_reward():
			double_reward_button.disabled = false
			double_reward_button.text = "Посмотреть рекламу · ×2 итог")

	var milestone := "Маршрут освоен! ПАЗ, три звезды — вы свой в этом городе." if summary.get("mastered_now",false) else ("Следующая цель: рейс на ПАЗике на 3 звезды" if SaveManager.is_vehicle_unlocked("modern_microbus") else "До ПАЗика осталось %d ₽" % maxi(0,2500-SaveManager.get_money()))
	var goal:=UITheme.make_label(milestone,16,UITheme.COLOR_TEXT_DIM)
	goal.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	goal.custom_minimum_size.x=440
	vbox.add_child(goal)

	var next_btn := Button.new()
	next_btn.text = "Следующий рейс"
	UITheme.style_button(next_btn, UITheme.COLOR_GOOD, Color(0.05, 0.05, 0.05))
	vbox.add_child(next_btn)
	next_btn.pressed.connect(func():
		AudioManager.play_ui_click()
		GameManager.start_trip())

	var garage_btn := Button.new()
	garage_btn.text = "Гараж"
	UITheme.style_button(garage_btn, UITheme.COLOR_ACCENT, Color(0.05, 0.05, 0.05))
	vbox.add_child(garage_btn)
	garage_btn.pressed.connect(func():
		AudioManager.play_ui_click()
		GameManager.go_to_garage())

	var menu_btn := Button.new()
	menu_btn.text = "Главное меню"
	UITheme.style_button(menu_btn, UITheme.COLOR_PANEL.lightened(0.1), UITheme.COLOR_TEXT)
	vbox.add_child(menu_btn)
	menu_btn.pressed.connect(func():
		AudioManager.play_ui_click()
		GameManager.go_to_menu())

	result_layer.visible = true
	result_layer.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(result_layer, "modulate:a", 1.0, 0.35)

func _on_trip_failed(summary: Dictionary) -> void:
	_change_pending=false
	change_popup.hide()
	pause_layer.hide()
	if fine_banner:
		fine_banner.hide()
	InputState.reset_touch()
	var title: Label = result_layer.find_child("Title", true, false)
	title.text = "РЕЙС СОРВАН"
	title.add_theme_color_override("font_color", UITheme.COLOR_BAD)
	var vbox: VBoxContainer = result_layer.find_child("ResultVBox", true, false)
	for c in vbox.get_children():
		if c.name != "Title":
			c.queue_free()
	await get_tree().process_frame
	vbox.add_child(UITheme.make_label(String(summary.get("reason", "Плохое вождение")), 19, UITheme.COLOR_BAD, true))
	vbox.add_child(UITheme.make_label("Пассажиры не доехали: %d" % int(summary.get("passengers", 0)), 17))
	vbox.add_child(UITheme.make_label("Большой штраф: −%d ₽" % int(summary.get("penalties", 0)), 20, UITheme.COLOR_BAD, true))
	vbox.add_child(UITheme.make_label("Нарушения: %d · столкновений: %d" % [int(summary.get("rule_violations", 0)), int(summary.get("collisions", 0))], 16, UITheme.COLOR_TEXT_DIM))
	vbox.add_child(UITheme.make_label("Состояние машины: %d%%" % int(round(summary.get("vehicle_condition", 100.0))), 16, UITheme.COLOR_TEXT_DIM))
	vbox.add_child(UITheme.make_label("Так ездить нельзя — следующий рейс начнётся с новым счётом ошибок.", 15, UITheme.COLOR_TEXT_DIM))
	var retry := Button.new()
	retry.text = "Повторить рейс"
	UITheme.style_button(retry, UITheme.COLOR_ACCENT, Color("101416"))
	vbox.add_child(retry)
	retry.pressed.connect(func():
		AudioManager.play_ui_click()
		GameManager.start_trip())
	var garage_btn := Button.new()
	garage_btn.text = "В гараж"
	UITheme.style_button(garage_btn, UITheme.COLOR_PANEL.lightened(0.1), UITheme.COLOR_TEXT)
	vbox.add_child(garage_btn)
	garage_btn.pressed.connect(func():
		AudioManager.play_ui_click()
		GameManager.go_to_garage())
	var menu_btn := Button.new()
	menu_btn.text = "Главное меню"
	UITheme.style_button(menu_btn, UITheme.COLOR_PANEL.lightened(0.1), UITheme.COLOR_TEXT)
	vbox.add_child(menu_btn)
	menu_btn.pressed.connect(func():
		AudioManager.play_ui_click()
		GameManager.go_to_menu())
	result_layer.visible = true
	result_layer.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(result_layer, "modulate:a", 1.0, 0.35)

func _on_double_reward_claimed(amount: int) -> void:
	if double_reward_button == null:
		return
	double_reward_button.disabled = true
	double_reward_button.text = "Реклама просмотрена · +%d ₽" % amount


func _build_pause(root: Control) -> void:
	pause_layer = Control.new()
	pause_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(pause_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.03,0.05,0.07,0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_layer.add_child(dim)
	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-180,-145)
	panel.custom_minimum_size = Vector2(360,0)
	panel.add_theme_constant_override("separation",12)
	pause_layer.add_child(panel)
	panel.add_child(UITheme.make_label("ПАУЗА",30,UITheme.COLOR_ACCENT,true))
	var resume := Button.new()
	resume.text="Продолжить рейс"
	UITheme.style_button(resume,UITheme.COLOR_GOOD,Color.BLACK)
	panel.add_child(resume)
	resume.pressed.connect(func(): _set_paused(false))
	var recover := Button.new()
	recover.text="Вернуться на дорогу"
	UITheme.style_button(recover,UITheme.COLOR_PANEL,UITheme.COLOR_TEXT)
	panel.add_child(recover)
	recover.pressed.connect(func():
		_recover_vehicle()
		_set_paused(false))
	var menu := Button.new()
	menu.text="Выйти из рейса в меню"
	UITheme.style_button(menu,UITheme.COLOR_PANEL,UITheme.COLOR_TEXT)
	panel.add_child(menu)
	menu.pressed.connect(func(): GameManager.go_to_menu())
	panel.add_child(UITheme.make_label("Рейс не засчитается. Заработанное сохранится.",13,UITheme.COLOR_TEXT_DIM))
	var options:=Button.new()
	options.text="Настройки и управление"
	UITheme.style_button(options,UITheme.COLOR_PANEL,UITheme.COLOR_TEXT,18)
	panel.add_child(options)
	options.pressed.connect(func(): settings.show())
	pause_layer.visible=false

func _set_paused(value: bool) -> void:
	InputState.reset_touch()
	pause_layer.visible=value
	AudioManager.set_game_paused(value)
	get_tree().paused=value
	AudioManager.set_engine_running(not value)
	if value:
		PlatformService.stop_gameplay()
	else:
		PlatformService.start_gameplay()

func _recover_vehicle() -> void:
	if not vehicle:
		return
	if passenger_manager and passenger_manager.boarding_pending > 0:
		EventBus.notification.emit("Дождитесь окончания посадки и высадки",2.0)
		return
	var points:=RouteDefinition.waypoints()
	var nearest:=Vector3.ZERO
	var forward:=Vector3.FORWARD
	var distance:=INF
	for i in range(points.size()):
		var a:=points[i]
		var b:=points[(i+1)%points.size()]
		var projected:=Geometry3D.get_closest_point_to_segment(vehicle.global_position,a,b)
		var candidate:=vehicle.global_position.distance_squared_to(projected)
		if candidate<distance:
			distance=candidate
			nearest=projected
			forward=(b-a).normalized()
	vehicle.global_position=nearest+Vector3(-forward.z,0,forward.x)*2.5+Vector3(0,0.6,0)
	vehicle.look_at(vehicle.global_position+forward)
	vehicle.speed=0.0
	vehicle.velocity=Vector3.ZERO
	vehicle.steer_angle=0.0
	EventBus.notification.emit("Маршрутка снова на дороге",2.0)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if GameManager.state == GameManager.State.DRIVING:
			_set_paused(not get_tree().paused)
			get_viewport().set_input_as_handled()

func _build_context(root: Control) -> void:
	var panel:=PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position=Vector2(-260,-130 if is_touch_device else -115)
	panel.custom_minimum_size=Vector2(520,0)
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",UITheme.panel_style())
	root.add_child(panel)
	var col:=VBoxContainer.new()
	panel.add_child(col)
	context_label=UITheme.make_label("",18,UITheme.COLOR_ACCENT,true)
	context_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(context_label)
	time_label=UITheme.make_label("",14,UITheme.COLOR_TEXT_DIM)
	time_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(time_label)
	if not is_touch_device:
		var help:=UITheme.make_label("WASD · движение     E · двери     H · сигнал     Esc · пауза",13,UITheme.COLOR_TEXT_DIM)
		help.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(help)
	# Put results and pause above the context panel.
	root.move_child(pause_layer,-1)
	root.move_child(result_layer,-1)

func _refresh_context() -> void:
	if not vehicle or not route_manager or not context_label:
		return
	var limit := 60
	var scene := get_tree().current_scene
	var enforcement = scene.get("rule_enforcement") if scene else null
	if enforcement:
		limit = enforcement.get_speed_limit_kmh()
	if speed_label:
		speed_label.add_theme_color_override("font_color", UITheme.COLOR_BAD if vehicle.get_speed_kmh() > float(limit) + 5.0 else UITheme.COLOR_TEXT)
	time_label.text="Время %s  ·  За рейс %d ₽  ·  Лимит %d км/ч" % [GameManager.format_time(GameManager.trip_time),EconomyManager.get_trip_total(),limit]
	var key:="Двери" if is_touch_device else "E"
	if passenger_manager.boarding_pending>0:
		context_label.text="Посадка и высадка · Подождите: %d" % passenger_manager.boarding_pending
	elif vehicle.doors_open:
		context_label.text="%s · Закройте двери, можно ехать" % key
	elif route_manager.player_in_zone == route_manager.get_next_stop():
		context_label.text="%s · Откройте двери" % key if absf(vehicle.speed)<VehicleController.DOOR_SPEED_LIMIT else "Плавно остановитесь в жёлтом кармане"
	else:
		context_label.text="До остановки %d м · Двери закрыты" % int(route_manager.distance_to_next_stop())

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and pause_layer and GameManager.state == GameManager.State.DRIVING:
		_set_paused(true)
