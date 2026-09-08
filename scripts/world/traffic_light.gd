extends Node3D
class_name TrafficLightProp
## Shared phase offset keeps opposing approaches of each junction coordinated.
var approach := Vector3.FORWARD
var stop_point := Vector3.ZERO
var phase_offset := 0.0
var _red: StandardMaterial3D
var _yellow: StandardMaterial3D
var _green: StandardMaterial3D
var _timer := 0.0
var _phase := 0
const CYCLE := 24.0

func _ready() -> void:
	add_to_group("traffic_signals")
	_build()
	_update_lights()

func phase_at(time: float) -> int:
	var time_in_cycle := fposmod(time+phase_offset+(12.0 if absf(approach.x)>0.5 else 0.0),CYCLE)
	if time_in_cycle<10.0:
		return 2
	if time_in_cycle<12.0:
		return 1
	return 0

func allows_traffic() -> bool:
	return _phase == 2

func _physics_process(delta: float) -> void:
	if not get_node("/root/GameManager").trip_running:
		return
	_timer += delta
	_update_lights()

func _update_lights() -> void:
	_phase = phase_at(_timer)
	var materials := [_red,_yellow,_green]
	var colors := [Color("ef4435"),Color("ffca4e"),Color("46d979")]
	for i in range(3):
		materials[i].albedo_color = colors[i] if i==_phase else colors[i]*0.14
		materials[i].emission_energy_multiplier = 1.4 if i==_phase else 0.0

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
	box_mesh.size = Vector3(0.55, 1.30, 0.35)
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
