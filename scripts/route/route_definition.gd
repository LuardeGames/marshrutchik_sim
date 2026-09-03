extends RefCounted
class_name RouteDefinition
## Static definition of the single closed-loop route used by the MVP map.
## Waypoints describe the road centerline; stops attach to specific
## waypoints. Kept in one place so a new route only needs a new array here.

const ROAD_WIDTH := 10.0

static func waypoints() -> Array[Vector3]:
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

## Each entry: id (int), name, waypoint_index (index into waypoints()), required (bool)
static func stops() -> Array[Dictionary]:
	return [
		{"id": 0, "name": "Спальный район", "waypoint_index": 3, "required": true},
		{"id": 1, "name": "Рынок", "waypoint_index": 5, "required": true},
		{"id": 2, "name": "Поликлиника", "waypoint_index": 8, "required": true},
		{"id": 3, "name": "Центр", "waypoint_index": 11, "required": true},
		{"id": 4, "name": "Вокзал", "waypoint_index": 13, "required": true},
		{"id": 5, "name": "Конечная", "waypoint_index": 0, "required": true},
	]

static func total_length() -> float:
	var pts := waypoints()
	var total := 0.0
	for i in range(pts.size()):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % pts.size()]
		total += a.distance_to(b)
	return total
