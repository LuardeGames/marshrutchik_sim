extends Node3D
class_name TrafficDummy
## Purely decorative background traffic - moves back and forth on a short
## stretch, no collision with the player (keeps physics cheap).

@export var travel_distance: float = 40.0
@export var speed: float = 6.0
var _start_z: float = 0.0
var _dir: float = 1.0

func _ready() -> void:
	_start_z = position.z
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(randf_range(0.2, 0.9), randf_range(0.2, 0.9), randf_range(0.2, 0.9))
	var body := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.9, 1.6, 4.2)
	body.mesh = mesh
	body.position.y = 0.9
	body.material_override = mat
	add_child(body)

func _process(delta: float) -> void:
	position.z += _dir * speed * delta
	if abs(position.z - _start_z) > travel_distance:
		_dir *= -1.0
		rotate_y(PI)
