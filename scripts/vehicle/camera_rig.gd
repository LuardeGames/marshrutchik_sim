extends Node3D
class_name CameraRig
## Smooth third-person follow camera with a subtle shake on collisions.

@export var target: Node3D
@export var follow_distance: float = 10.5
@export var follow_height: float = 4.2
@export var look_height: float = 1.6
@export var position_smooth: float = 4.0
@export var rotation_smooth: float = 5.0

var camera: Camera3D
var _shake_time: float = 0.0
var _shake_strength: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 68.0
	add_child(camera)
	if target:
		var desired := _desired_transform()
		global_position = desired.origin
		look_at(target.global_position + Vector3.UP * look_height, Vector3.UP)

func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var desired := _desired_transform()
	global_position = global_position.lerp(desired.origin, clamp(position_smooth * delta, 0.0, 1.0))
	var look_target := target.global_position + Vector3.UP * look_height
	if _shake_time > 0.0:
		_shake_time -= delta
		var offset := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0) * _shake_strength
		look_target += offset
		global_position += offset * 0.3
	var t := Transform3D().looking_at(look_target - global_position, Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(t.basis, clamp(rotation_smooth * delta, 0.0, 1.0))

func _desired_transform() -> Transform3D:
	var back := target.global_transform.basis.z.normalized()
	var pos := target.global_position + back * follow_distance + Vector3.UP * follow_height
	return Transform3D(Basis(), pos)

func shake(strength: float) -> void:
	_shake_strength = clamp(strength * 0.6, 0.0, 0.6)
	_shake_time = 0.35
