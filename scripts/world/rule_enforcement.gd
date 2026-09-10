extends Node
class_name RuleEnforcement
## Makes the route a driving job with consequences: speed limits, red lights,
## staying on the road and keeping the correct direction all affect the trip.

var vehicle: VehicleController
var route_manager: RouteManager
var speed_limit_kmh: int = 60
var _previous_position := Vector3.ZERO
var _cooldowns: Dictionary = {}
var _road_surfaces: Array = []
var _offroad_time: float = 0.0

const SPEED_TOLERANCE := 5.0
const SIDEWALK_LIMIT := RouteDefinition.ROAD_WIDTH * 0.5 + 1.4
## Standard RF speed limit inside a populated area (population sign)
## PDD 10.2 - this is the default everywhere on the route, not just on
## straights. Only actual hazards (a stop bay, a tight corner) slow it down.
const CITY_LIMIT_KMH := 60
## Corners on the route loop are sharp ~90 degree turns; a bus can't safely
## carry 60 km/h into one, so the limit steps down on the approach exactly
## like a real "turn ahead" sign would.
const CORNER_LIMIT_KMH := 40
const CORNER_SLOW_RADIUS := 22.0
const STOP_LIMIT_KMH := 20
const STOP_SLOW_RADIUS := 16.0

func setup(vehicle_ref: VehicleController, route_ref: RouteManager, world: Node3D = null) -> void:
	vehicle = vehicle_ref
	route_manager = route_ref
	_previous_position = vehicle.global_position
	if world != null:
		_road_surfaces = world.get_meta("road_surfaces", [])

func _physics_process(delta: float) -> void:
	if vehicle == null or not GameManager.trip_running or GameManager.state != GameManager.State.DRIVING:
		return
	for key in _cooldowns.keys():
		_cooldowns[key] = maxf(0.0, float(_cooldowns[key]) - delta)
	_check_speed()
	_check_surface(delta)
	_check_red_lights()
	_previous_position = vehicle.global_position

func get_speed_limit_kmh() -> int:
	if vehicle == null:
		return CITY_LIMIT_KMH
	var limit := CITY_LIMIT_KMH
	if _near_corner(vehicle.global_position, CORNER_SLOW_RADIUS):
		limit = CORNER_LIMIT_KMH
	if _near_stop(vehicle.global_position, STOP_SLOW_RADIUS):
		limit = STOP_LIMIT_KMH
	speed_limit_kmh = limit
	return limit

func _near_corner(pos: Vector3, radius: float) -> bool:
	for point in RouteDefinition.waypoints():
		if pos.distance_to(point) < radius:
			return true
	return false

func _check_speed() -> void:
	var limit := get_speed_limit_kmh()
	if vehicle.get_speed_kmh() <= float(limit) + SPEED_TOLERANCE:
		return
	var fine: int = 28 if limit >= CORNER_LIMIT_KMH else 40
	_try_violation("speed", fine, 2.0, "Слишком быстро: лимит %d км/ч · штраф %d ₽" % [limit, fine], 4.0)

func _check_surface(delta: float) -> void:
	var data := _nearest_route_data(vehicle.global_position)
	var distance := float(data.get("distance", 0.0))
	if _near_stop(vehicle.global_position, 18.0):
		_offroad_time = 0.0
		return # the bus bay is deliberately outside the road centreline
	var on_road: bool = WorldBuilder.is_road_surface(vehicle.global_position, _road_surfaces, 0.35)
	if _road_surfaces.is_empty():
		on_road = distance <= SIDEWALK_LIMIT
	_offroad_time = _offroad_time + delta if not on_road and absf(vehicle.speed) > 1.5 else 0.0
	if _offroad_time >= 0.8:
		_try_violation("sidewalk", 35, 3.0, "Съехали с дороги на тротуар · штраф 35 ₽", 3.0)
	# Secondary streets are two-way; route direction cannot describe them.
	if distance > RouteDefinition.ROAD_WIDTH * 0.5:
		return
	var direction: Vector3 = data.get("direction", Vector3.ZERO)
	var forward := -vehicle.global_transform.basis.z
	if direction.length() > 0.1 and forward.dot(direction) < -0.45 and vehicle.get_speed_kmh() > 8.0:
		_try_violation("wrong_way", 50, 4.0, "Езда навстречу движению · штраф 50 ₽", 3.0)

func _check_red_lights() -> void:
	var forward := -vehicle.global_transform.basis.z
	for node in get_tree().get_nodes_in_group("traffic_signals"):
		var light := node as TrafficLightProp
		if light == null or not light.is_red():
			continue
		var previous_relative: Vector3 = light.stop_point - _previous_position
		var current_relative: Vector3 = light.stop_point - vehicle.global_position
		var previous_along := previous_relative.dot(light.approach)
		var current_along := current_relative.dot(light.approach)
		var lateral := absf(current_relative.dot(Vector3(-light.approach.z, 0, light.approach.x)))
		if previous_along > 0.0 and current_along <= 0.0 and lateral < 2.6 and forward.dot(light.approach) > 0.65 and vehicle.get_speed_kmh() > 8.0:
			_try_violation("red_light", 60, 5.0, "Проехали на красный · штраф 60 ₽", 2.5)

func _try_violation(kind: String, fine: int, comfort_loss: float, message: String, cooldown: float) -> void:
	if float(_cooldowns.get(kind, 0.0)) > 0.0:
		return
	_cooldowns[kind] = cooldown
	GameManager.register_rule_violation(kind, fine, comfort_loss, message)

func _near_stop(pos: Vector3, radius: float) -> bool:
	for stop in RouteDefinition.stops():
		if pos.distance_to(RouteDefinition.stop_position(int(stop.waypoint_index))) < radius:
			return true
	return false

func _nearest_route_data(pos: Vector3) -> Dictionary:
	var points := RouteDefinition.waypoints()
	var best := INF
	var nearest := Vector3.ZERO
	var direction := Vector3.ZERO
	for i in range(points.size()):
		var a: Vector3 = points[i]
		var b: Vector3 = points[(i + 1) % points.size()]
		var projected := Geometry3D.get_closest_point_to_segment(pos, a, b)
		var distance := pos.distance_to(projected)
		if distance < best:
			best = distance
			nearest = projected
			direction = (b - a).normalized()
	return {"distance": best, "point": nearest, "direction": direction}
