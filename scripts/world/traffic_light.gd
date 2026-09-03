extends Node3D
class_name TrafficLightProp
## Purely decorative traffic light imitation - cycles red/yellow/green.
## Not wired into gameplay logic (arcade game, not a rules simulator).

var _red: StandardMaterial3D
var _yellow: StandardMaterial3D
var _green: StandardMaterial3D
var _timer: float = 0.0
var _phase: int = 0
const PHASE_DURATION := 4.0

func _ready() -> void:
	_build()
	_timer = randf_range(0.0, PHASE_DURATION)

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= PHASE_DURATION:
		_timer = 0.0
		_phase = (_phase + 1) % 3
		_update_lights()

func _update_lights() -> void:
	_red.emission_energy_multiplier = 2.5 if _phase == 0 else 0.15
	_yellow.emission_energy_multiplier = 2.5 if _phase == 1 else 0.15
	_green.emission_energy_multiplier = 2.5 if _phase == 2 else 0.15

func _build() -> void:
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.09
	pole_mesh.bottom_radius = 0.11
	pole_mesh.height = 3.4
	pole.mesh = pole_mesh
	pole.position = Vector3(0, 1.7, 0)
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.15, 0.15, 0.15)
	pole.material_override = pole_mat
	add_child(pole)

	var box := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.4, 1.0, 0.35)
	box.mesh = box_mesh
	box.position = Vector3(0, 3.6, 0)
	var box_mat := StandardMaterial3D.new()
	box_mat.albedo_color = Color(0.08, 0.08, 0.08)
	box.material_override = box_mat
	add_child(box)

	_red = _light_dot(Vector3(0, 3.95, 0.19), Color(1, 0.15, 0.1))
	_yellow = _light_dot(Vector3(0, 3.6, 0.19), Color(1, 0.85, 0.1))
	_green = _light_dot(Vector3(0, 3.25, 0.19), Color(0.15, 0.9, 0.2))
	_update_lights()

func _light_dot(pos: Vector3, color: Color) -> StandardMaterial3D:
	var m := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.13
	mesh.height = 0.26
	m.mesh = mesh
	m.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.15
	m.material_override = mat
	add_child(m)
	return mat
