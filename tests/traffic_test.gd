extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, description: String) -> void:
	print("[PASS] " if ok else "[FAIL] ",description)
	if not ok:
		failures+=1
func run() -> void:
	root.get_node("GameManager").start_trip()
	for i in range(4):
		await physics_frame
	var game = current_scene
	game.event_manager.stop()
	game.vehicle.set_physics_process(false)
	game.vehicle.position=Vector3(-270,1,350)
	game.competitor.set_process(false)
	game.competitor.set_physics_process(false)
	game.competitor.position=Vector3(-270,1,330)
	var cars: Array[TrafficDummy] = []
	for child in game.world.get_children():
		if child is TrafficDummy:
			cars.append(child)
	check(cars.size()==40,"40 ambient cars spawn")
	var signals := get_nodes_in_group("traffic_signals")
	check(signals.size()==6,"six signal heads control three junctions")
	var conflict := false
	for t in range(240):
		for i in range(0,signals.size(),2):
			if signals[i].phase_at(t*0.1)==2 and signals[i+1].phase_at(t*0.1)==2:
				conflict=true
	check(not conflict,"crossing approaches never receive simultaneous green")
	var travelled: Dictionary = {}
	var last: Dictionary = {}
	var stopped: Dictionary = {}
	var resumed: Dictionary = {}
	var violations := 0
	for car in cars:
		travelled[car]=0.0
		last[car]=car.position
	for frame in range(9000):
		await physics_frame
		for car in cars:
			travelled[car]+=car.position.distance_to(last[car])
			last[car]=car.position
			if car.waiting_for_signal and car.current_speed<0.15:
				stopped[car]=true
			if stopped.has(car) and not car.waiting_for_signal and car.current_speed>3.0:
				resumed[car]=true
			for light in signals:
				var forward := -car.global_transform.basis.z
				var relative: Vector3 = light.stop_point-car.global_position
				if light._phase==0 and forward.dot(light.approach)>0.95 and absf(relative.dot(Vector3(-light.approach.z,0,light.approach.x)))<1.0:
					var along: float = relative.dot(light.approach)
					if along>0.0 and along<1.5 and car.current_speed>1.0:
						violations+=1
	var minimum := INF
	for distance in travelled.values():
		minimum=minf(minimum,distance)
	print("TRAFFIC min travel=",minimum," stopped=",stopped.size()," resumed=",resumed.size()," violations=",violations)
	check(cars.size()>0 and minimum>100.0,"every car makes progress during 150 seconds")
	check(stopped.size()>0,"cars stop at red signals")
	check(resumed.size()>0,"stopped cars resume on green")
	check(violations==0,"cars do not drive across red stop lines")
	# Isolated lane with a stationary bus-sized obstacle: check the following
	# gap independently of incidental meetings in the ambient simulation.
	WorldBuilder._box(game.world,Vector3(2100,-0.5,-100),Vector3(250,1,250),Color.GRAY)
	var follower := TrafficDummy.new()
	follower.road_path.assign([Vector3(2000,0,0),Vector3(2000,0,-200),Vector3(2200,0,-200),Vector3(2200,0,0)])
	follower.reverse_direction=false
	follower.spawn_fraction=0.02
	game.world.add_child(follower)
	var forward := -follower.global_basis.z
	var obstacle := StaticBody3D.new()
	obstacle.collision_layer=2
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size=Vector3(2.4,3.0,6.0)
	col.shape=box
	col.position.y=1.5
	obstacle.add_child(col)
	game.world.add_child(obstacle)
	obstacle.position=follower.position+forward*18.0
	for i in range(600):
		await physics_frame
	check(follower.current_speed<0.15 and follower.position.distance_to(obstacle.position)>5.0,"car stops with a gap behind a stationary bus")
	var before := follower.position
	obstacle.queue_free()
	for i in range(300):
		await physics_frame
	check(follower.position.distance_to(before)>12.0,"car resumes when the lane clears")
	quit(1 if failures else 0)
