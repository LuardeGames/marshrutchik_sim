extends Control
class_name TouchControl
## Each control owns a finger ID, so throttle + steering work simultaneously.
signal held_changed(held: bool)
var caption: String=""
var _finger: int=-1
var _held:=false
var _label: Label

func _ready() -> void:
	custom_minimum_size=Vector2(78,78)
	process_mode=Node.PROCESS_MODE_ALWAYS
	mouse_filter=Control.MOUSE_FILTER_STOP
	_label=UITheme.make_label(caption,16,UITheme.COLOR_TEXT)
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(_label)

func _draw() -> void:
	draw_style_box(UITheme.button_style(UITheme.COLOR_ACCENT.darkened(0.2) if _held else UITheme.COLOR_PANEL),Rect2(Vector2.ZERO,size))

func _set_held(value: bool) -> void:
	if _held==value: return
	_held=value
	held_changed.emit(value)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or get_tree().paused or not get_node("/root/GameManager").trip_running:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _finger==-1 and get_global_rect().has_point(event.position):
			_finger=event.index
			_set_held(true)
		elif not event.pressed and event.index==_finger:
			_finger=-1
			_set_held(false)
	elif event is InputEventScreenDrag and event.index==_finger:
		if not get_global_rect().grow(18).has_point(event.position):
			_finger=-1
			_set_held(false)

func _gui_input(event: InputEvent) -> void:
	if _finger!=-1 or get_tree().paused: return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		_set_held(event.pressed)
		accept_event()

func _process(_delta: float) -> void:
	if get_tree().paused or not is_visible_in_tree() or not get_node("/root/GameManager").trip_running:
		_finger=-1
		_set_held(false)

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		_finger=-1
		_set_held(false)
