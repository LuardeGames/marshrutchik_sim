extends Node3D
class_name Passenger
## Lightweight visual-only NPC. No navmesh: it walks in a straight line
## between two points and reports back via signal when it arrives.

signal arrived

var archetype: PassengerArchetype
var destination_stop_id: int = -1
var fare: int = 0
var mood: String = "neutral" # neutral, happy, annoyed, tired
var walk_speed: float = 1.6

var _target: Vector3
var _walking: bool = false

func setup(a: PassengerArchetype) -> void:
	archetype = a
	fare = a.base_fare + randi_range(-a.fare_variance, a.fare_variance)
	_build_visual()

func walk_to(target_pos: Vector3, speed: float = 1.6) -> void:
	_target = target_pos
	walk_speed = speed
	_walking = true
	var dir := (target_pos - global_position)
	dir.y = 0
	if dir.length() > 0.01:
		look_at(global_position + dir, Vector3.UP)

func _process(delta: float) -> void:
	if not _walking:
		return
	var to_target := _target - global_position
	to_target.y = 0
	if to_target.length() < 0.15:
		_walking = false
		global_position.x = _target.x
		global_position.z = _target.z
		arrived.emit()
		return
	var step := to_target.normalized() * walk_speed * delta
	if step.length() > to_target.length():
		step = to_target
	global_position += step
	# subtle bob while walking
	rotation.y = lerp_angle(rotation.y, atan2(to_target.x, to_target.z), 8.0 * delta)

func react_to_jolt() -> void:
	# small comedic reaction to harsh braking/turns - visual bump
	var tw := create_tween()
	tw.tween_property(self, "rotation:z", 0.25, 0.08)
	tw.tween_property(self, "rotation:z", 0.0, 0.25)

func _build_visual() -> void:
	var color: Color = archetype.color if archetype else Color.WHITE

	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.28
	body_mesh.height = 1.15
	body.mesh = body_mesh
	body.position = Vector3(0, 0.75, 0)
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = color
	body.material_override = body_mat
	add_child(body)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.2
	head_mesh.height = 0.4
	head.mesh = head_mesh
	head.position = Vector3(0, 1.5, 0)
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.9, 0.75, 0.6)
	head.material_override = head_mat
	add_child(head)
