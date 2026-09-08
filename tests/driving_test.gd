extends SceneTree
## Drives every road segment through the actual input/physics controller.
## No teleports after spawning. Stops for boarding and finishes both vehicles.
var failures: Array[String]=[]
func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	print("[PASS] " if value else "[FAIL] ",message)
	if not value: failures.append(message)

func lane_point(points: Array[Vector3],i: int) -> Vector3:
	var incoming:=(points[i]-points[(i-1+points.size())%points.size()]).normalized()
	var outgoing:=(points[(i+1)%points.size()]-points[i]).normalized()
	return points[i]+Vector3(-incoming.z-outgoing.z,0,incoming.x+outgoing.x)*2.5

func run() -> void:
	await process_frame
	var gm:=root.get_node("GameManager")
	var save:=root.get_node("SaveManager")
	var input:=root.get_node("InputState")
	var original: Dictionary=save.data.duplicate(true)
	for definition in VehicleCatalog.build():
		save.data=save.DEFAULT_DATA.duplicate(true)
		save.unlock_vehicle(definition.id)
		save.set_selected_vehicle(definition.id)
		gm.start_trip()
		for i in range(8): await physics_frame
		var game:=current_scene
		game.event_manager.stop()
		game.vehicle.harsh_event.connect(func(kind,strength):
			if kind=="collision":
				print("IMPACT ",definition.id," at ",game.vehicle.global_position," strength ",strength))
		# Keep city and collision geometry, isolate lane drivability from random traffic.
		game.competitor.set_process(false)
		for child in game.world.get_children():
			if child.name.begins_with("Oncoming_"): child.queue_free()
		var points:=RouteDefinition.waypoints()
		var targets: Array[Dictionary]=[]
		for step in range(1,points.size()+1):
			var i:=step%points.size()
			var stop: StopArea=null
			for candidate in game.route_manager.stops:
				if candidate.waypoint_index==i: stop=candidate
			if stop:
				var dir:=RouteDefinition.stop_forward(i)
				var right:=Vector3(-dir.z,0,dir.x)
				targets.append({"pos":stop.global_position-dir*18.0-right*4.5,"stop":null})
				targets.append({"pos":stop.global_position,"stop":stop})
			targets.append({"pos":lane_point(points,i),"stop":null})
		var frame_count:=0
		for target in targets:
			if gm.state==gm.State.RESULTS: break
			var arrived:=false
			for frame in range(6000):
				frame_count+=1
				var delta: Vector3=target.pos-game.vehicle.global_position
				delta.y=0
				var distance:=delta.length()
				if (target.stop==null and distance<3.0) or (target.stop!=null and distance<1.7 and absf(game.vehicle.speed)<0.2):
					arrived=true
					break
				var local: Vector3=game.vehicle.global_basis.inverse()*delta.normalized()
				var angle:=atan2(local.x,-local.z)
				input.steer_left_touch=angle < -0.04
				input.steer_right_touch=angle > 0.04
				var desired:=8.0
				if distance<16 or absf(angle)>0.35: desired=3.0
				if target.stop!=null and distance<8: desired=clampf((distance-1.0)*1.3,0.0,3.0)
				input.throttle_touch=game.vehicle.speed<desired-0.15
				input.brake_touch=game.vehicle.speed>desired+0.15
				await physics_frame
			input.reset_touch()
			if not arrived:
				for c in range(game.vehicle.get_slide_collision_count()):
					var collision: KinematicCollision3D=game.vehicle.get_slide_collision(c)
					print("OBSTACLE ",collision.get_collider().global_position," normal ",collision.get_normal())
				check(false,"driving stuck: "+definition.id+" target "+str(target.pos)+" at "+str(game.vehicle.global_position))
				break
			if target.stop:
				game.vehicle._toggle_doors()
				for i in range(1200):
					await physics_frame
					if game.passenger_manager.boarding_pending==0: break
				game.vehicle._toggle_doors()
				for i in range(30): await physics_frame
				print("DRIVEN STOP ",definition.id," ",target.stop.stop_id)
		check(gm.state==gm.State.RESULTS,"continuous driving finishes "+definition.display_name)
		check(gm.collisions==0,"no world collisions while driving "+definition.display_name)
		print("DRIVE FRAMES ",frame_count," comfort ",gm.comfort)
	save.data=original
	save.save_game()
	gm.go_to_menu()
	await process_frame
	quit(0 if failures.is_empty() else 1)
