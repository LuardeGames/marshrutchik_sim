extends RefCounted
class_name RouteDefinition
## Data-driven closed-loop route definitions. The world is rebuilt from the
## selected route, while route 47 keeps the original MVP geometry.

const ROAD_WIDTH := 10.0
const DEFAULT_ROUTE_ID := "route_47"

static var active_route_id: String = DEFAULT_ROUTE_ID

static func route_ids() -> Array[String]:
	return ["route_47", "route_12", "route_5"]

static func set_active_route(route_id: String) -> void:
	active_route_id = route_id if route_ids().has(route_id) else DEFAULT_ROUTE_ID

static func get_active_route_id() -> String:
	return active_route_id

static func _resolve_id(route_id: String = "") -> String:
	return active_route_id if route_id.is_empty() else route_id

static func route_name(route_id: String = "") -> String:
	match _resolve_id(route_id):
		"route_12": return "Вокзал → Центр"
		"route_5": return "Рынок → Промзона"
		_: return "Спальный район → Вокзал"

static func route_number(route_id: String = "") -> String:
	match _resolve_id(route_id):
		"route_12": return "12"
		"route_5": return "5"
		_: return "47"

static func route_description(route_id: String = "") -> String:
	match _resolve_id(route_id):
		"route_12": return "Вокзал, центр и плотный городской трафик"
		"route_5": return "Рынок, промзона и узкие улицы"
		_: return "Спальный район, рынок и вокзал"

static func route_unlock_trips(route_id: String) -> int:
	match route_id:
		"route_12": return 1
		"route_5": return 3
		_: return 0

static func waypoints(route_id: String = "") -> Array[Vector3]:
	match _resolve_id(route_id):
		"route_12":
			return [
				Vector3(0, 0, 0), Vector3(0, 0, -100), Vector3(160, 0, -100),
				Vector3(160, 0, -260), Vector3(340, 0, -260), Vector3(340, 0, -420),
				Vector3(520, 0, -420), Vector3(520, 0, -560), Vector3(740, 0, -560),
				Vector3(740, 0, -300), Vector3(620, 0, -300), Vector3(620, 0, -80),
				Vector3(460, 0, -80), Vector3(460, 0, 160), Vector3(200, 0, 160),
				Vector3(200, 0, 0),
			]
		"route_5":
			return [
				Vector3(0, 0, 0), Vector3(-120, 0, 0), Vector3(-120, 0, -160),
				Vector3(80, 0, -160), Vector3(80, 0, -340), Vector3(260, 0, -340),
				Vector3(260, 0, -520), Vector3(500, 0, -520), Vector3(700, 0, -360),
				Vector3(700, 0, -120), Vector3(520, 0, -120), Vector3(520, 0, 100),
				Vector3(300, 0, 100), Vector3(300, 0, 240), Vector3(0, 0, 240),
			]
		_: return _route_47_waypoints()

static func _route_47_waypoints() -> Array[Vector3]:
	var pts: Array[Vector3] = [
		Vector3(0, 0, 0),
		Vector3(0, 0, -140),
		Vector3(120, 0, -140),
		Vector3(120, 0, -300),
		Vector3(300, 0, -300),
		Vector3(300, 0, -460),
		Vector3(460, 0, -460),
		Vector3(460, 0, -300),
		Vector3(620, 0, -300),
		Vector3(620, 0, -140),
		Vector3(460, 0, -140),
		Vector3(460, 0, 0),
		Vector3(300, 0, 0),
		Vector3(300, 0, 140),
		Vector3(120, 0, 140),
		Vector3(120, 0, 0),
	]
	return pts

## Each entry: id (int), name, waypoint_index (index into waypoints()), required (bool).
static func stops(route_id: String = "") -> Array[Dictionary]:
	match _resolve_id(route_id):
		"route_12":
			return [
				{"id": 0, "name": "Вокзал", "waypoint_index": 3, "required": true},
				{"id": 1, "name": "Центр", "waypoint_index": 5, "required": true},
				{"id": 2, "name": "Университет", "waypoint_index": 8, "required": true},
				{"id": 3, "name": "Старый мост", "waypoint_index": 10, "required": true},
				{"id": 4, "name": "Парк", "waypoint_index": 13, "required": true},
				{"id": 5, "name": "Конечная", "waypoint_index": 0, "required": true},
			]
		"route_5":
			return [
				{"id": 0, "name": "Рынок", "waypoint_index": 3, "required": true},
				{"id": 1, "name": "Промзона", "waypoint_index": 6, "required": true},
				{"id": 2, "name": "Гаражи", "waypoint_index": 8, "required": true},
				{"id": 3, "name": "Старая слобода", "waypoint_index": 10, "required": true},
				{"id": 4, "name": "Речная улица", "waypoint_index": 13, "required": true},
				{"id": 5, "name": "Конечная", "waypoint_index": 0, "required": true},
			]
		_: return [
			{"id": 0, "name": "Спальный район", "waypoint_index": 3, "required": true},
			{"id": 1, "name": "Рынок", "waypoint_index": 5, "required": true},
			{"id": 2, "name": "Поликлиника", "waypoint_index": 8, "required": true},
			{"id": 3, "name": "Центр", "waypoint_index": 11, "required": true},
			{"id": 4, "name": "Вокзал", "waypoint_index": 13, "required": true},
			{"id": 5, "name": "Конечная", "waypoint_index": 0, "required": true},
		]

static func total_length(route_id: String = "") -> float:
	var pts := waypoints(route_id)
	var total := 0.0
	for i in range(pts.size()):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % pts.size()]
		total += a.distance_to(b)
	return total

## Stops sit 30 m before each corner on the incoming straight, in a right-side bay.
static func stop_forward(index: int) -> Vector3:
	var pts := waypoints()
	return (pts[index] - pts[(index - 1 + pts.size()) % pts.size()]).normalized()

static func stop_position(index: int) -> Vector3:
	var dir := stop_forward(index)
	return waypoints()[index] - dir * 30.0 + Vector3(-dir.z, 0, dir.x) * 7.0
