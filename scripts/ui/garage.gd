extends Control
## Garage / upgrades screen: buy upgrade levels, pick between unlocked
## vehicles, purchase the second vehicle once affordable.

var money_label: Label
var upgrades_box: VBoxContainer
var vehicles_box: HBoxContainer
var condition_label: Label
var repair_button: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.1, 0.15)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_build_header()
	_build_vehicles()
	_build_upgrades()

func _build_header() -> void:
	var back_btn := Button.new()
	back_btn.text = "← Меню"
	UITheme.style_button(back_btn, UITheme.COLOR_PANEL.lightened(0.15), UITheme.COLOR_TEXT, 18)
	back_btn.custom_minimum_size = Vector2(120, 44)
	back_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back_btn.position = Vector2(24, 14)
	add_child(back_btn)
	back_btn.pressed.connect(func():
		AudioManager.play_ui_click()
		GameManager.go_to_menu())

	var title := UITheme.make_label("ГАРАЖ", 30, UITheme.COLOR_ACCENT, true)
	title.set_anchors_preset(Control.PRESET_TOP_LEFT)
	title.position = Vector2(164, 20)
	add_child(title)

	money_label = UITheme.make_label("%d ₽" % SaveManager.get_money(), 24, UITheme.COLOR_TEXT)
	money_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	money_label.position = Vector2(-390, 22)
	add_child(money_label)
	condition_label = UITheme.make_label("", 16, UITheme.COLOR_TEXT_DIM)
	condition_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	condition_label.position = Vector2(-390, 53)
	add_child(condition_label)
	repair_button = Button.new()
	repair_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	repair_button.position = Vector2(-195, 60)
	repair_button.custom_minimum_size = Vector2(170, 38)
	UITheme.style_button(repair_button, UITheme.COLOR_ACCENT, Color(0.05, 0.05, 0.05), 14)
	add_child(repair_button)
	repair_button.pressed.connect(func():
		if SaveManager.repair_vehicle():
			AudioManager.play_money()
			_refresh_money()
			_refresh_vehicles())
	_refresh_condition()
	var drive:=Button.new()
	drive.text="На линию →"
	UITheme.style_button(drive,UITheme.COLOR_GOOD,Color.BLACK,18)
	drive.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	drive.position=Vector2(-195,12)
	drive.custom_minimum_size=Vector2(170,48)
	add_child(drive)
	drive.pressed.connect(func(): GameManager.start_trip())

func _refresh_money() -> void:
	money_label.text = "%d ₽" % SaveManager.get_money()
	_refresh_condition()

func _refresh_condition() -> void:
	if condition_label == null or repair_button == null:
		return
	var condition := SaveManager.get_vehicle_condition()
	condition_label.text = "Состояние: %d%%" % int(round(condition))
	condition_label.modulate = UITheme.COLOR_GOOD if condition >= 70.0 else (UITheme.COLOR_ACCENT if condition >= 40.0 else UITheme.COLOR_BAD)
	var cost := SaveManager.get_repair_cost()
	repair_button.text = "Исправна" if cost <= 0 else "Ремонт: %d ₽" % cost
	repair_button.disabled = cost <= 0 or SaveManager.get_money() < cost

func _build_vehicles() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.accent_panel_style())
	panel.custom_minimum_size = Vector2(0, 300)
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 24)
	panel.position.y = 76
	panel.offset_top = 76
	panel.offset_bottom = 76 + 300

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	vbox.add_child(UITheme.make_label("Транспорт", 20, UITheme.COLOR_ACCENT_2, true))
	vehicles_box = HBoxContainer.new()
	vehicles_box.add_theme_constant_override("separation", 16)
	vbox.add_child(vehicles_box)
	_refresh_vehicles()

func _refresh_vehicles() -> void:
	for c in vehicles_box.get_children():
		vehicles_box.remove_child(c)
		c.queue_free()
	var selected := SaveManager.get_selected_vehicle()
	for def in VehicleCatalog.build():
		var card := PanelContainer.new()
		var selected_style := def.id == selected
		card.add_theme_stylebox_override("panel", UITheme.panel_style(def.body_color.darkened(0.75) if not selected_style else UITheme.COLOR_ACCENT.darkened(0.6), 12, UITheme.COLOR_ACCENT if selected_style else Color(1,1,1,0.08)))
		card.custom_minimum_size = Vector2(300, 130)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vehicles_box.add_child(card)

		var v := VBoxContainer.new()
		card.add_child(v)
		var preview := VehiclePreview.new()
		v.add_child(preview)
		preview.setup(def)
		v.add_child(UITheme.make_label(def.display_name, 18, UITheme.COLOR_TEXT, true))
		var desc := UITheme.make_label(def.description, 13, UITheme.COLOR_TEXT_DIM)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(desc)
		v.add_child(UITheme.make_label("%.0f км/ч · %d мест с улучшениями" % [def.base_max_speed * 3.6 * EconomyManager.get_upgrade_multiplier("engine"), def.base_capacity + EconomyManager.get_extra_capacity()], 13, UITheme.COLOR_TEXT_DIM))

		var unlocked := SaveManager.is_vehicle_unlocked(def.id)
		var btn := Button.new()
		if selected_style:
			btn.text = "Выбрано"
			btn.disabled = true
			UITheme.style_button(btn, UITheme.COLOR_GOOD, Color(0.05,0.05,0.05))
		elif unlocked:
			btn.text = "Выбрать"
			UITheme.style_button(btn, UITheme.COLOR_ACCENT_2, Color(1,1,1))
			btn.pressed.connect(func():
				AudioManager.play_ui_click()
				SaveManager.set_selected_vehicle(def.id)
				_refresh_vehicles())
		else:
			btn.text = "Купить за %d ₽" % def.price
			UITheme.style_button(btn, UITheme.COLOR_ACCENT, Color(0.05,0.05,0.05))
			btn.disabled = SaveManager.get_money() < def.price
			btn.pressed.connect(func():
				if SaveManager.spend_money(def.price):
					AudioManager.play_money()
					SaveManager.unlock_vehicle(def.id)
					SaveManager.set_selected_vehicle(def.id)
					_refresh_vehicles()
					_refresh_upgrades()
					_refresh_money())
		v.add_child(btn)

func _build_upgrades() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.accent_panel_style(UITheme.COLOR_PANEL, UITheme.COLOR_ACCENT_2))
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.position = Vector2(24, 426)
	panel.anchor_right = 1.0
	panel.offset_right = -24
	panel.anchor_bottom = 1.0
	panel.offset_bottom = -24
	add_child(panel)

	var scroll := ScrollContainer.new()
	panel.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	vbox.add_child(UITheme.make_label("Улучшения", 20, UITheme.COLOR_ACCENT_2, true))
	upgrades_box = VBoxContainer.new()
	upgrades_box.add_theme_constant_override("separation", 10)
	vbox.add_child(upgrades_box)
	_refresh_upgrades()

func _refresh_upgrades() -> void:
	for c in upgrades_box.get_children():
		upgrades_box.remove_child(c)
		c.queue_free()
	for u in EconomyManager.upgrades:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		upgrades_box.add_child(row)

		var name_l := UITheme.make_label(u.display_name, 18, UITheme.COLOR_TEXT, true)
		name_l.custom_minimum_size = Vector2(140, 0)
		row.add_child(name_l)

		var level := SaveManager.get_upgrade_level(u.id)
		var pips := HBoxContainer.new()
		pips.add_theme_constant_override("separation", 4)
		row.add_child(pips)
		for i in range(u.max_level):
			var pip := ColorRect.new()
			pip.custom_minimum_size = Vector2(20, 10)
			pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			pip.color = UITheme.COLOR_ACCENT if i < level else Color(1, 1, 1, 0.15)
			pips.add_child(pip)

		var desc_l := UITheme.make_label(u.description, 13, UITheme.COLOR_TEXT_DIM)
		desc_l.custom_minimum_size = Vector2(260, 0)
		desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(desc_l)

		var cost := u.cost_for_level(level + 1)
		var btn := Button.new()
		if level >= u.max_level:
			btn.text = "Макс. уровень"
			btn.disabled = true
			UITheme.style_button(btn, UITheme.COLOR_GOOD, Color(0.05,0.05,0.05), 18)
		else:
			btn.text = "Улучшить: %d ₽" % cost
			UITheme.style_button(btn, UITheme.COLOR_ACCENT, Color(0.05,0.05,0.05), 18)
			btn.disabled = SaveManager.get_money() < cost
			var uid := u.id
			btn.pressed.connect(func():
				if EconomyManager.purchase_upgrade(uid):
					_refresh_upgrades()
					_refresh_money()
					_refresh_vehicles()
					EventBus.notification.emit("Улучшение куплено!", 1.5))
		# fixed width so every row's button lines up regardless of label text
		# length ("Макс. уровень" vs "Улучшить: 1234 ₽") - set AFTER
		# style_button, which otherwise resets custom_minimum_size to (0,52)
		# and a varying width there previously shifted whole rows around.
		btn.custom_minimum_size = Vector2(190, 52)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_END
		row.add_child(btn)
