extends SceneTree
## Check both lanes of the newly drivable streets against world collisions.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.get_node("GameManager").start_trip()
	for i in range(4):
		await physics_frame
	var world: Node3D = current_scene.world
	var streets: Array = world.get_meta("city_streets")
	var blocked := 0
	var samples := 0
	for i in range(RouteDefinition.waypoints().size(),streets.size()):
		var a: Vector3 = streets[i][0]
		var b: Vector3 = streets[i][1]
		var dir := (b-a).normalized()
		var side := Vector3(-dir.z,0,dir.x)
		var count := int(a.distance_to(b)/4.0)
		for j in range(count+1):
			for lane in [-2.5,2.5]:
				var p: Vector3 = a.lerp(b,float(j)/count)+side*lane
				var query := PhysicsRayQueryParameters3D.create(p+Vector3(0,5,0),p-Vector3(0,1,0),1)
				var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
				samples += 1
				if hit.is_empty() or hit.position.y>0.5:
					blocked += 1
					print("BLOCKED STREET ",i," at ",p)
	print("[PASS] " if blocked==0 else "[FAIL] ",samples," lane samples on outer streets; obstructions: ",blocked)
	quit(0 if blocked==0 else 1)
