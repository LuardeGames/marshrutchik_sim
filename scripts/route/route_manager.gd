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

const GOOD_STOP_DISTANCE := 3.0
const FAR_STOP_DISTANCE := 7.0

func setup(stop_list: Array[StopArea], vehicle_ref: VehicleController) -> void:
	stops = stop_list
	vehicle = vehicle_ref
	for s in stops:
		s.vehicle_entered.connect(_on_vehicle_entered)
		s.vehicle_exited.connect(_on_vehicle_exited)
	current_stop_index = 0
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
		# left the zone without stopping properly -> only penalize required stops
		if stop.required:
			pass # PassengerManager / HUD already nudges player; no hard fail in MVP

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
		var quality := "good"
		if dist > GOOD_STOP_DISTANCE:
			quality = "far"
		_handled_current_stop = true
		stop_arrived.emit(stop, quality)

## Called by PassengerManager once boarding/alighting is finished at the
## current stop and doors close (or a short delay elapses), to advance route.
func advance_to_next_stop() -> void:
	if _route_finished or stops.is_empty():
		return
	var finishing_stop := stops[current_stop_index]
	_handled_current_stop = false
	if current_stop_index >= stops.size() - 1:
		_route_finished = true
		route_completed.emit()
		return
	current_stop_index += 1
	next_stop_changed.emit(get_next_stop())
