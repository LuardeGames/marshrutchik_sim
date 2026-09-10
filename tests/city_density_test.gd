extends SceneTree
## Measures the generated city itself: route-side building coverage and the
## low-detail skyline that prevents the playable grid ending in open fields.

const SAMPLE_SPACING := 16.0
const FRONTAGE_OFFSET := 23.0
const MAX_FRONTAGE_GAP := 12.0

var failed := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	print("[PASS] " if ok else "[FAIL] ", message)
	if not ok:
		failed += 1

func run() -> void:
	root.get_node("GameManager").start_trip()
	for i in range(6):
		await physics_frame
	var world: Node3D = current_scene.world
	var front := world.get_node_or_null("FillerFront") as MultiMeshInstance3D
	var back := world.get_node_or_null("FillerBack") as MultiMeshInstance3D
	var front_count := 0 if front == null else front.multimesh.instance_count
	check(front_count >= 500, "city keeps a substantial playable building layer")
	var back_count := 0 if back == null else back.multimesh.instance_count
	check(back_count >= 100, "city has a continuous distant skyline")
	var parking := world.get_node_or_null("LotParking") as MultiMeshInstance3D
	var garages := world.get_node_or_null("GarageRows") as MultiMeshInstance3D
	var courtyards := world.get_node_or_null("CourtyardPaths") as MultiMeshInstance3D
	var entrances := world.get_node_or_null("EntranceDoors") as MultiMeshInstance3D
	var roof_details := world.get_node_or_null("RoofEquipment") as MultiMeshInstance3D
	check(parking != null and parking.multimesh.instance_count >= 6, "vacant lots include visible parking courts")
	check(garages != null and garages.multimesh.instance_count >= 6, "vacant lots include garage rows")
	check(courtyards != null and courtyards.multimesh.instance_count >= 6, "vacant lots include landscaped courtyards")
	check(entrances != null and entrances.multimesh.instance_count >= front_count * 2, "apartment blocks have entrances on both long facades")
	check(roof_details != null and roof_details.multimesh.instance_count >= front_count / 4, "apartment skyline includes rooftop equipment")

	var coverage := _frontage_coverage(world.get_world_3d().direct_space_state, RouteDefinition.waypoints()) if front != null else 0.0
	print("CITY DENSITY: frontage %.1f%%, playable %d, backdrop %d" % [coverage * 100.0, front_count, back_count])
	check(coverage >= 0.82, "route streets have continuous building frontage")
	quit(0 if failed == 0 else 1)

func _frontage_coverage(space: PhysicsDirectSpaceState3D, waypoints: Array[Vector3]) -> float:
	var shape := BoxShape3D.new()
	shape.size = Vector3(MAX_FRONTAGE_GAP * 2.0, 8.0, MAX_FRONTAGE_GAP * 2.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	var covered := 0
	var sampled := 0
	for segment_index in range(waypoints.size()):
		var start := waypoints[segment_index]
		var finish := waypoints[(segment_index + 1) % waypoints.size()]
		var direction := (finish - start).normalized()
		var side := Vector3(-direction.z, 0, direction.x)
		var sample_count := maxi(2, int(start.distance_to(finish) / SAMPLE_SPACING))
		for sample_index in range(1, sample_count):
			var road_position := start.lerp(finish, float(sample_index) / float(sample_count))
			if _near_stop(road_position) or _near_intersection(road_position, waypoints):
				continue
			for side_sign: float in [-1.0, 1.0]:
				var probe: Vector3 = road_position + side * side_sign * FRONTAGE_OFFSET
				sampled += 1
				query.transform = Transform3D(Basis(), probe + Vector3(0, 6.0, 0))
				if not space.intersect_shape(query, 1).is_empty():
					covered += 1
	return float(covered) / float(sampled)

func _near_stop(position: Vector3) -> bool:
	for stop in RouteDefinition.stops():
		if position.distance_to(RouteDefinition.stop_position(int(stop.waypoint_index))) < 24.0:
			return true
	return false

func _near_intersection(position: Vector3, waypoints: Array[Vector3]) -> bool:
	for waypoint in waypoints:
		if position.distance_to(waypoint) < 20.0:
			return true
	return false
