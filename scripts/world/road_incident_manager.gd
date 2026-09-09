extends Node
class_name RoadIncidentManager
## Small, readable road situations placed ahead of the bus. They occupy one
## lane, so the driver must slow down, merge and avoid blindly following the
## route line.

var vehicle: VehicleController
var world_parent: Node3D
var enabled := true
var _spawn_timer := 14.0
var _active: Array[Dictionary] = []
var _incident_index := 0

const MAX_ACTIVE := 2
const MIN_LIFETIME := 18.0
const MAX_LIFETIME := 30.0

func setup(vehicle_ref: VehicleController, world_ref: Node3D) -> void:
	vehicle = vehicle_ref
	world_parent = world_ref

func _process(delta: float) -> void:
	if not enabled or vehicle == null or not GameManager.trip_running or GameManager.state != GameManager.State.DRIVING:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and _active.size() < MAX_ACTIVE:
		_spawn_incident()
		_spawn_timer = randf_range(20.0, 34.0)
	for entry in _active.duplicate():
		entry.age = float(entry.age) + delta
		if entry.age >= float(entry.lifetime) or not is_instance_valid(entry.node):
			if is_instance_valid(entry.node):
				entry.node.queue_free()
			_active.erase(entry)

func clear_incidents() -> void:
	for entry in _active:
		if is_instance_valid(entry.node):
			entry.node.queue_free()
	_active.clear()

func _spawn_incident() -> void:
	var points := RouteDefinition.waypoints()
	if points.size() < 4:
		return
	var nearest_segment := _nearest_segment(vehicle.global_position, points)
	var segment: int = (nearest_segment + randi_range(1, 3)) % points.size()
	var a: Vector3 = points[segment]
	var b: Vector3 = points[(segment + 1) % points.size()]
	var dir: Vector3 = (b - a).normalized()
	var side: Vector3 = Vector3(-dir.z, 0, dir.x) * ([-1.0, 1.0].pick_random() * 2.5)
	var position: Vector3 = a.lerp(b, randf_range(0.35, 0.72)) + side
	if _too_close_to_stop(position) or position.distance_to(vehicle.global_position) < 35.0:
		return
	var kind: String = ["parked_car", "roadworks", "debris"].pick_random()
	var node: Node3D = _build_incident(kind, position, dir)
	if node == null:
		return
	node.name = "RoadIncident_%d" % _incident_index
	_incident_index += 1
	world_parent.add_child(node)
	_active.append({"node": node, "age": 0.0, "lifetime": randf_range(MIN_LIFETIME, MAX_LIFETIME)})
	EventBus.notification.emit(_incident_message(kind), 3.0)

func _build_incident(kind: String, position: Vector3, direction: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = position
	root.rotation.y = atan2(direction.x, direction.z)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.add_to_group("road_incident")
	root.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	if kind == "parked_car":
		box.size = Vector3(1.8, 1.2, 3.8)
		BusVisual.box(root, Vector3(0, 0.68, 0), Vector3(1.75, 0.75, 3.8), BusVisual.material(Color("8d4d3e")))
		BusVisual.box(root, Vector3(0, 1.15, -0.15), Vector3(1.35, 0.45, 1.6), BusVisual.material(Color("34464b"), 0.15))
		BusVisual.box(root, Vector3(0, 0.45, -1.95), Vector3(1.85, 0.18, 0.12), BusVisual.material(Color("e2be68")))
	else:
		box.size = Vector3(2.0, 1.0, 2.0) if kind == "roadworks" else Vector3(1.2, 0.6, 1.2)
		var color := Color("e27632") if kind == "roadworks" else Color("66615a")
		BusVisual.box(root, Vector3(0, box.size.y * 0.5, 0), box.size, BusVisual.material(color))
		if kind == "roadworks":
			for x in [-0.72, 0.72]:
				var cone := MeshInstance3D.new()
				var cone_mesh := CylinderMesh.new()
				cone_mesh.top_radius = 0.0
				cone_mesh.bottom_radius = 0.22
				cone_mesh.height = 0.65
				cone.mesh = cone_mesh
				cone.position = Vector3(x, 0.34, 0)
				cone.material_override = BusVisual.material(Color("e57a26"))
				root.add_child(cone)
	shape.shape = box
	shape.position.y = box.size.y * 0.5
	body.add_child(shape)
	return root

func _nearest_segment(pos: Vector3, points: Array[Vector3]) -> int:
	var best := INF
	var best_index := 0
	for i in range(points.size()):
		var projected := Geometry3D.get_closest_point_to_segment(pos, points[i], points[(i + 1) % points.size()])
		var distance := pos.distance_squared_to(projected)
		if distance < best:
			best = distance
			best_index = i
	return best_index

func _too_close_to_stop(pos: Vector3) -> bool:
	for stop in RouteDefinition.stops():
		if pos.distance_to(RouteDefinition.stop_position(int(stop.waypoint_index))) < 22.0:
			return true
	return false

func _incident_message(kind: String) -> String:
	match kind:
		"parked_car": return "Аварийка во втором ряду — перестройтесь аккуратно"
		"roadworks": return "Впереди ремонт дороги — сбросьте скорость и объезжайте"
		_: return "На дороге мусор — не влетите в препятствие"
