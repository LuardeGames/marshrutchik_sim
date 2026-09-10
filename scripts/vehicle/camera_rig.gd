extends Node3D
class_name CameraRig
## Smooth third-person follow camera with a subtle shake on collisions.
## Sits closer and lower than a generic chase cam so the bus's size and
## speed actually read, and reacts to speed/steering so cruising feels
## a little different from standing at a stop.

@export var target: Node3D
@export var follow_distance: float = 7.6
@export var follow_height: float = 3.0
@export var look_height: float = 1.55
@export var position_smooth: float = 5.5
@export var rotation_smooth: float = 6.5

const FOV_BASE := 64.0
const FOV_MAX_KICK := 10.0 # extra FOV at top speed - cheap sense of speed
const DISTANCE_SPEED_KICK := 1.6 # camera drifts back a little as speed rises
const LEAN_TILT_MAX := 0.045 # subtle roll into turns, radians

var camera: Camera3D
var _shake_time: float = 0.0
var _shake_strength: float = 0.0
var _rng := RandomNumberGenerator.new()
var _fov_current: float = FOV_BASE
var _roll_current: float = 0.0

func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = FOV_BASE
	add_child(camera)
	if target:
		var desired := _desired_transform(0.0)
		global_position = desired.origin
		look_at(target.global_position + Vector3.UP * look_height, Vector3.UP)

func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var vehicle := target as VehicleController
	var speed_ratio: float = vehicle.speed_ratio() if vehicle else 0.0
	var steer_signed: float = (vehicle.steer_angle / VehicleController.STEER_MAX) if vehicle else 0.0

	var desired := _desired_transform(speed_ratio)
	var focus := target.global_position + Vector3.UP * look_height
	var candidate := global_position.lerp(desired.origin, clamp(position_smooth * delta, 0.0, 1.0))
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(focus,candidate,1))
	global_position = hit.position + hit.normal * 0.55 if not hit.is_empty() else candidate
	var look_target := target.global_position + Vector3.UP * look_height
	if _shake_time > 0.0:
		_shake_time -= delta
		var offset := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0) * _shake_strength
		look_target += offset
		global_position += offset * 0.3
	var t := Transform3D().looking_at(look_target - global_position, Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(t.basis, clamp(rotation_smooth * delta, 0.0, 1.0))

	# Dynamism: FOV widens with speed for a cheap sense of pace, and the
	# camera rolls a touch into the turn the way a handheld chase shot would.
	var target_fov: float = FOV_BASE + FOV_MAX_KICK * speed_ratio
	_fov_current = lerp(_fov_current, target_fov, clamp(3.0 * delta, 0.0, 1.0))
	camera.fov = _fov_current
	var target_roll: float = clamp(-steer_signed * speed_ratio, -1.0, 1.0) * LEAN_TILT_MAX
	_roll_current = lerp(_roll_current, target_roll, clamp(4.0 * delta, 0.0, 1.0))
	camera.rotation.z = _roll_current

func _desired_transform(speed_ratio: float) -> Transform3D:
	var back := target.global_transform.basis.z.normalized()
	var distance := follow_distance + DISTANCE_SPEED_KICK * speed_ratio
	var pos := target.global_position + back * distance + Vector3.UP * follow_height
	var from := target.global_position + Vector3.UP * look_height
	var query := PhysicsRayQueryParameters3D.create(from, pos, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		pos = hit.position + hit.normal * 0.55
	return Transform3D(Basis(), pos)

func shake(strength: float) -> void:
	_shake_strength = clamp(strength * 0.6, 0.0, 0.6)
	_shake_time = 0.35
