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
	global_position = _lane_point(0) # offset so it doesn't overlap player spawn
	_speed = randf_range(8.5, 11.5)
	_build_visual()

func _process(delta: float) -> void:
	if waypoints.is_empty() or GameManager.state == GameManager.State.RESULTS:
		return
	var target: Vector3 = _lane_point(_current_index)
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
		target = _lane_point(_current_index)
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
	var definition := VehicleCatalog.build()[0]
	definition.body_color = Color("a95439")
	BusVisual.build(_body, definition)

func _lane_point(i: int) -> Vector3:
	var incoming:=(waypoints[i]-waypoints[(i-1+waypoints.size())%waypoints.size()]).normalized()
	var outgoing:=(waypoints[(i+1)%waypoints.size()]-waypoints[i]).normalized()
	return waypoints[i]+Vector3(-incoming.z-outgoing.z,0,incoming.x+outgoing.x)*2.5+Vector3(0,0.15,0)
