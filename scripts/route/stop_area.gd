extends Node3D
class_name StopArea
## A single bus-stop zone: detection area + simple visual marker (pole,
## sign board, pad). Built entirely from primitives at runtime.

signal vehicle_entered(stop: StopArea)
signal vehicle_exited(stop: StopArea)

var stop_id: int = 0
var stop_name: String = ""
var required: bool = true
var waypoint_index: int = 0

var _area: Area3D
var vehicle_inside: Node3D = null
var _sign_mesh: MeshInstance3D

func setup(id: int, name_: String, req: bool, wp_index: int) -> void:
	stop_id = id
	stop_name = name_
	required = req
	waypoint_index = wp_index
	name = "Stop_%d_%s" % [id, name_]
	_build_visual()
	_build_area()

func _build_visual() -> void:
	# ground pad (light color to stand out from asphalt)
	var pad := MeshInstance3D.new()
	var pad_mesh := BoxMesh.new()
	pad_mesh.size = Vector3(6.0, 0.05, 10.0)
	pad.mesh = pad_mesh
	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = Color(0.85, 0.8, 0.55)
	pad.material_override = pad_mat
	pad.position = Vector3(0, 0.03, 0)
	add_child(pad)

	# pole
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.08
	pole_mesh.bottom_radius = 0.1
	pole_mesh.height = 2.6
	pole.mesh = pole_mesh
	pole.position = Vector3(3.2, 1.3, 0)
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.7, 0.7, 0.75)
	pole.material_override = pole_mat
	add_child(pole)

	# sign board
	_sign_mesh = MeshInstance3D.new()
	var sign_mesh := BoxMesh.new()
	sign_mesh.size = Vector3(1.4, 0.9, 0.06)
	_sign_mesh.mesh = sign_mesh
	_sign_mesh.position = Vector3(3.2, 2.5, 0)
	var sign_mat := StandardMaterial3D.new()
	sign_mat.albedo_color = Color(0.15, 0.45, 0.85)
	sign_mat.emission_enabled = true
	sign_mat.emission = Color(0.1, 0.3, 0.6)
	sign_mat.emission_energy_multiplier = 0.5
	_sign_mesh.material_override = sign_mat
	add_child(_sign_mesh)

	# small shelter roof for flavor
	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(4.0, 0.15, 2.2)
	roof.mesh = roof_mesh
	roof.position = Vector3(4.6, 2.3, 0)
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.4, 0.42, 0.46)
	roof.material_override = roof_mat
	add_child(roof)
	for side in [-0.9, 0.9]:
		var leg := MeshInstance3D.new()
		var leg_mesh := CylinderMesh.new()
		leg_mesh.top_radius = 0.06
		leg_mesh.bottom_radius = 0.06
		leg_mesh.height = 2.2
		leg.mesh = leg_mesh
		leg.position = Vector3(3.0, 1.1, side)
		leg.material_override = pole_mat
		add_child(leg)

func _build_area() -> void:
	_area = Area3D.new()
	_area.name = "DetectionArea"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(9.0, 4.0, 14.0)
	shape.shape = box
	shape.position = Vector3(0, 2.0, 0)
	_area.add_child(shape)
	_area.collision_layer = 0
	_area.collision_mask = 2 # vehicle layer
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	add_child(_area)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("vehicle"):
		vehicle_inside = body
		vehicle_entered.emit(self)

func _on_body_exited(body: Node3D) -> void:
	if body == vehicle_inside:
		vehicle_inside = null
		vehicle_exited.emit(self)

## Distance from the stop's pad center to a global position, used to judge
## parking quality.
func distance_to_pad(global_pos: Vector3) -> float:
	return global_position.distance_to(Vector3(global_pos.x, global_position.y, global_pos.z))
