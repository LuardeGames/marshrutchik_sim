extends Node3D
## Root controller for the driving scene: builds the world, spawns the
## vehicle/competitor, and wires up route/passenger/event/camera systems.

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")

var world: Node3D
var vehicle: VehicleController
var competitor: CompetitorAI
var camera_rig: CameraRig
var route_manager: RouteManager
var passenger_manager: PassengerManager
var event_manager: RandomEventManager
var hud: CanvasLayer

func _ready() -> void:
	world = Node3D.new()
	world.name = "World"
	add_child(world)

	var build_result := WorldBuilder.build(world)
	var stops: Array[StopArea] = build_result.stops
	var waypoints: Array[Vector3] = build_result.waypoints

	_spawn_vehicle(build_result)
	_spawn_camera()
	_spawn_competitor(build_result)

	route_manager = RouteManager.new()
	route_manager.name = "RouteManager"
	add_child(route_manager)
	route_manager.setup(stops, vehicle)

	var stop_order: Array[int] = []
	for s in stops:
		stop_order.append(s.stop_id)

	passenger_manager = PassengerManager.new()
	passenger_manager.name = "PassengerManager"
	add_child(passenger_manager)
	passenger_manager.setup(vehicle, route_manager, world, stop_order)
	vehicle.boarding_manager = passenger_manager

	event_manager = RandomEventManager.new()
	event_manager.name = "RandomEventManager"
	add_child(event_manager)
	event_manager.start()

	vehicle.harsh_event.connect(_on_harsh_event)
	route_manager.route_completed.connect(_on_route_completed)

	hud = HUD_SCENE.instantiate()
	add_child(hud)
	if hud.has_method("bind"):
		hud.bind(vehicle, route_manager, passenger_manager)

	EventBus.trip_started.emit()
	_maybe_show_tutorial()

func _spawn_vehicle(build_result: Dictionary) -> void:
	vehicle = VehicleController.new()
	vehicle.name = "PlayerVehicle"
	vehicle.definition = VehicleCatalog.get_by_id(SaveManager.get_selected_vehicle())
	world.add_child(vehicle)
	vehicle.global_position = build_result.spawn_position + Vector3(0, 0.6, 0)
	var look_dir: Vector3 = build_result.spawn_forward_waypoint - build_result.spawn_position
	if look_dir.length() > 0.1:
		vehicle.look_at(vehicle.global_position + look_dir, Vector3.UP)

func _spawn_camera() -> void:
	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	camera_rig.target = vehicle
	add_child(camera_rig)
	camera_rig.camera.current = true
	EventBus.vehicle_collision.connect(func(strength): camera_rig.shake(strength))

func _spawn_competitor(build_result: Dictionary) -> void:
	competitor = CompetitorAI.new()
	competitor.name = "Competitor"
	world.add_child(competitor)
	# defer setup until passenger_manager exists
	call_deferred("_finish_competitor_setup", build_result)

func _finish_competitor_setup(build_result: Dictionary) -> void:
	await get_tree().process_frame
	competitor.setup(build_result.waypoints, build_result.stop_by_waypoint, passenger_manager)

func _on_harsh_event(kind: String, _strength: float) -> void:
	if passenger_manager:
		passenger_manager.jolt_passengers()

func _on_route_completed() -> void:
	event_manager.stop()
	GameManager.complete_trip()

func _maybe_show_tutorial() -> void:
	if int(SaveManager.data.get("trips_completed", 0)) == 0:
		EventBus.notification.emit("Ваш первый рейс. Держитесь правой стороны и следуйте мини-карте.",5.0)
