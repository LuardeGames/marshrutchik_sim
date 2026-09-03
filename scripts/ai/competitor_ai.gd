extends Node3D
class_name CompetitorAI
## A rival marshrutka that drives the same loop. If it reaches a stop before
## the player picks it up, it "steals" some of the waiting passengers -
## creating a soft race without forcing the player to speed constantly.

var waypoints: Array[Vector3] = []
var stops_by_waypoint: Dictionary = {} # waypoint_index -> stop_id
var passenger_manager: PassengerManager

var _current_index: int = 1
var _speed: float = 10.0
var _visited_stops: Dictionary = {}
var _body: Node3D

const ARRIVE_RADIUS := 6.0

func setup(wps: Array[Vector3], stop_map: Dictionary, pm: PassengerManager) -> void:
	waypoints = wps
	stops_by_waypoint = stop_map
	passenger_manager = pm
	global_position = wps[0] + Vector3(3.5, 0, 0) # offset so it doesn't overlap player spawn
	_speed = randf_range(8.5, 11.5)
	_build_visual()

func _process(delta: float) -> void:
	if waypoints.is_empty():
		return
	var target: Vector3 = waypoints[_current_index] + Vector3(3.5, 0, 0)
	var to_target := target - global_position
	to_target.y = 0
	if to_target.length() < ARRIVE_RADIUS:
		if stops_by_waypoint.has(_current_index) and not _visited_stops.has(_current_index):
			_visited_stops[_current_index] = true
			var stop_id: int = stops_by_waypoint[_current_index]
			var taken := passenger_manager.competitor_take_passengers(stop_id)
			if taken > 0:
				EventBus.notification.emit("Конкурент забрал %d пассажиров на остановке!" % taken, 2.2)
		_current_index = (_current_index + 1) % waypoints.size()
		target = waypoints[_current_index] + Vector3(3.5, 0, 0)
		to_target = target - global_position
		to_target.y = 0
	if to_target.length() > 0.01:
		var dir := to_target.normalized()
		global_position += dir * _speed * delta
		var look_target := global_position + dir
		if _body:
			_body.look_at(look_target, Vector3.UP)

func _build_visual() -> void:
	_body = Node3D.new()
	add_child(_body)
	var body := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.1, 2.1, 5.6)
	body.mesh = mesh
	body.position = Vector3(0, 1.1, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.2, 0.2)
	body.material_override = mat
	_body.add_child(body)

	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(2.0, 0.8, 4.8)
	roof.mesh = roof_mesh
	roof.position = Vector3(0, 2.0, -0.1)
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.85, 0.35, 0.35)
	roof.material_override = roof_mat
	_body.add_child(roof)

	for side in [-1, 1]:
		for z in [-2.0, 1.8]:
			var wheel := MeshInstance3D.new()
			var wm := CylinderMesh.new()
			wm.top_radius = 0.4
			wm.bottom_radius = 0.4
			wm.height = 0.3
			wheel.mesh = wm
			wheel.rotation.z = PI / 2.0
			wheel.position = Vector3(side * 1.1, 0.4, z)
			var wmat := StandardMaterial3D.new()
			wmat.albedo_color = Color(0.05, 0.05, 0.05)
			wheel.material_override = wmat
			_body.add_child(wheel)
