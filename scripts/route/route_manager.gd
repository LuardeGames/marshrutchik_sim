extends Node
class_name RouteManager
## Tracks progress along the single closed-loop route: which stop is next,
## whether the player is currently within a stop zone, and when the trip is
## complete (arrival + proper handling of the final stop).

signal next_stop_changed(stop: StopArea)
signal stop_arrived(stop: StopArea, quality: String)
signal route_completed

var stops: Array[StopArea] = []
var current_stop_index: int = 0
var vehicle: VehicleController
var player_in_zone: StopArea = null
var _stopped_properly: bool = false
var _handled_current_stop: bool = false
var _route_finished: bool = false
var _reported_misses: Dictionary = {}

const GOOD_STOP_DISTANCE := 3.0
const FAR_STOP_DISTANCE := 7.0

func setup(stop_list: Array[StopArea], vehicle_ref: VehicleController) -> void:
	stops = stop_list
	vehicle = vehicle_ref
	for s in stops:
		s.vehicle_entered.connect(_on_vehicle_entered)
		s.vehicle_exited.connect(_on_vehicle_exited)
	current_stop_index = 0
	_reported_misses.clear()
	_refresh_markers()
	next_stop_changed.emit(get_next_stop())

func get_next_stop() -> StopArea:
	if stops.is_empty():
		return null
	return stops[current_stop_index]

func is_final_stop(stop: StopArea) -> bool:
	return current_stop_index == stops.size() - 1 and stop == stops[current_stop_index]

func _on_vehicle_entered(stop: StopArea) -> void:
	player_in_zone = stop

func _on_vehicle_exited(stop: StopArea) -> void:
	if player_in_zone == stop:
		player_in_zone = null
	if stop == get_next_stop() and not _handled_current_stop:
		if stop.required and not _reported_misses.has(stop.stop_id):
			_reported_misses[stop.stop_id] = true
			GameManager.register_missed_stop()
			GameManager.register_rule_violation("missed_stop", 45, 5.0, "Пропустили остановку «%s» · вернитесь и заберите пассажиров" % stop.stop_name)
			EventBus.stop_reached.emit(stop.stop_id, "missed")

func _process(_delta: float) -> void:
	if _route_finished or vehicle == null or player_in_zone == null:
		return
	var stop := player_in_zone
	if stop != get_next_stop():
		return
	if _handled_current_stop:
		return
	if abs(vehicle.speed) < VehicleController.DOOR_SPEED_LIMIT:
		var dist := stop.distance_to_pad(vehicle.global_position)
		if dist > FAR_STOP_DISTANCE:
			return
		var quality := "good"
		if dist > GOOD_STOP_DISTANCE:
			quality = "far"
		_handled_current_stop = true
		stop_arrived.emit(stop, quality)

func can_service_stop(stop: StopArea) -> bool:
	if stop == null or stop != get_next_stop() or vehicle == null:
		return false
	return abs(vehicle.speed) < VehicleController.DOOR_SPEED_LIMIT and stop.distance_to_pad(vehicle.global_position) <= FAR_STOP_DISTANCE

## Called by PassengerManager once boarding/alighting is finished at the
## current stop and doors close (or a short delay elapses), to advance route.
func advance_to_next_stop() -> void:
	if _route_finished or stops.is_empty():
		return
	var finishing_stop := stops[current_stop_index]
	_handled_current_stop = false
	if current_stop_index >= stops.size() - 1:
		_route_finished = true
		_refresh_markers()
		route_completed.emit()
		return
	current_stop_index += 1
	_refresh_markers()
	next_stop_changed.emit(get_next_stop())

func _refresh_markers() -> void:
	for stop in stops:
		stop.set_active(not _route_finished and stop == get_next_stop())

## Distance follows the road, so a nearby stop across the block isn't misleading.
func distance_to_next_stop() -> float:
	if vehicle == null or stops.is_empty():
		return 0.0
	var points := RouteDefinition.waypoints()
	var best := INF
	var segment := 0
	var projected := Vector3.ZERO
	for i in range(points.size()):
		var p := Geometry3D.get_closest_point_to_segment(vehicle.global_position,points[i],points[(i+1)%points.size()])
		var d := vehicle.global_position.distance_squared_to(p)
		if d < best:
			best=d
			segment=i
			projected=p
	var stop := get_next_stop()
	var end_segment := (stop.waypoint_index-1+points.size())%points.size()
	var end := points[stop.waypoint_index]-RouteDefinition.stop_forward(stop.waypoint_index)*30.0
	if segment == end_segment and (end-projected).dot(RouteDefinition.stop_forward(stop.waypoint_index)) >= -12.0:
		return projected.distance_to(end)
	var distance := projected.distance_to(points[(segment+1)%points.size()])
	segment=(segment+1)%points.size()
	for i in range(points.size()):
		if segment == end_segment:
			return distance+points[segment].distance_to(end)
		distance+=points[segment].distance_to(points[(segment+1)%points.size()])
		segment=(segment+1)%points.size()
	return distance
