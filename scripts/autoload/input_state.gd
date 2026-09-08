extends Node
## Unified input source for keyboard/gamepad AND on-screen mobile buttons.
## VehicleController and UI read from here instead of Input directly,
## so touch controls and keyboard controls are fully interchangeable.

var throttle_touch: bool = false
var brake_touch: bool = false
var steer_left_touch: bool = false
var steer_right_touch: bool = false
var handbrake_touch: bool = false
var doors_touch_pressed: bool = false

func get_throttle() -> float:
	if throttle_touch:
		return 1.0
	return 1.0 if Input.is_action_pressed("accelerate") else 0.0

func get_brake() -> float:
	if brake_touch:
		return 1.0
	return 1.0 if Input.is_action_pressed("brake") else 0.0

func get_steer() -> float:
	var s := 0.0
	if Input.is_action_pressed("steer_left") or steer_left_touch:
		s -= 1.0
	if Input.is_action_pressed("steer_right") or steer_right_touch:
		s += 1.0
	return s

func get_handbrake() -> bool:
	return Input.is_action_pressed("handbrake") or handbrake_touch

func consume_doors_pressed() -> bool:
	var pressed := Input.is_action_just_pressed("doors") or doors_touch_pressed
	doors_touch_pressed = false
	return pressed

func reset_touch() -> void:
	throttle_touch = false
	brake_touch = false
	steer_left_touch = false
	steer_right_touch = false
	handbrake_touch = false
	doors_touch_pressed = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		reset_touch()
