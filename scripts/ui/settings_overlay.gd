extends Control
class_name SettingsOverlay
## Shared, truly modal sound/help panel, available in the menu and during pause.
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode=Node.PROCESS_MODE_ALWAYS
	var dim:=ColorRect.new()
	dim.color=Color(0.025,0.035,0.04,0.92)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center:=CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel:=PanelContainer.new()
	panel.custom_minimum_size=Vector2(480,0)
	panel.add_theme_stylebox_override("panel",UITheme.panel_style())
	center.add_child(panel)
	var col:=VBoxContainer.new()
	col.add_theme_constant_override("separation",14)
	panel.add_child(col)
	col.add_child(UITheme.make_label("НАСТРОЙКИ И УПРАВЛЕНИЕ",24,UITheme.COLOR_ACCENT,true))
	for entry in [["Общая громкость","master"],["Радио","music"],["Двигатель и звуки","sfx"]]:
		var row:=HBoxContainer.new()
		var label:=UITheme.make_label(entry[0],17,UITheme.COLOR_TEXT_DIM)
		label.custom_minimum_size.x=210
		row.add_child(label)
		var slider:=HSlider.new()
		slider.custom_minimum_size=Vector2(170,28)
		slider.min_value=0
		slider.max_value=1
		slider.step=0.05
		slider.value=SaveManager.get_sound_setting(entry[1])
		slider.value_changed.connect(func(value): SaveManager.set_sound_setting(entry[1],value))
		row.add_child(slider)
		col.add_child(row)
	var mute:=CheckButton.new()
	mute.text="Без звука"
	mute.button_pressed=SaveManager.is_muted()
	mute.toggled.connect(func(value): SaveManager.set_muted(value))
	col.add_child(mute)
	col.add_child(HSeparator.new())
	col.add_child(UITheme.make_label("W / ↑   Газ        S / ↓   Тормоз, затем задний ход\nA D / ← →   Руль        Пробел   Ручник\nE   Двери        H   Сигнал        Esc   Пауза",16))
	var help:=UITheme.make_label("Подъезжайте в жёлтый карман. Остановитесь, откройте двери и дождитесь пассажиров. Закройте двери и продолжайте рейс. На конечной высадите всех.",16,UITheme.COLOR_TEXT_DIM)
	help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size.x=430
	col.add_child(help)
	var close:=Button.new()
	close.text="Понятно"
	UITheme.style_button(close)
	close.pressed.connect(func(): hide())
	col.add_child(close)
	visible=false

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		hide()
		get_viewport().set_input_as_handled()
