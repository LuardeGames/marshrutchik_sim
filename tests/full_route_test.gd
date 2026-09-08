extends SceneTree
## Both vehicles: real stop triggers, walking/boarding, doors, progression,
## completion persistence and duplicate-completion protection. No SDK mocks.
var failures: Array[String]=[]
func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	print("[PASS] " if ok else "[FAIL] ",message)
	if not ok:
		failures.append(message)

func run() -> void:
	await process_frame
	var gm:=root.get_node("GameManager")
	var save:=root.get_node("SaveManager")
	var input:=root.get_node("InputState")
	var original: Dictionary=save.data.duplicate(true)
	Engine.time_scale=8.0
	for definition in VehicleCatalog.build():
		save.data=save.DEFAULT_DATA.duplicate(true)
		save.unlock_vehicle(definition.id)
		save.set_selected_vehicle(definition.id)
		gm.start_trip()
		for i in range(5):
			await process_frame
		var game:=current_scene
		game.competitor.set_process(false)
		check(game.vehicle.definition.id==definition.id,"selected vehicle spawns: "+definition.display_name)
		check(game.vehicle.get_node("BodyVisual/Coachwork")!=null,"authored coachwork exists")
		for stop in game.route_manager.stops:
			game.vehicle.global_position=stop.global_position+Vector3(0,0.6,0)
			game.vehicle.speed=0.0
			game.vehicle.velocity=Vector3.ZERO
			for i in range(12):
				await physics_frame
			check(game.route_manager.player_in_zone==stop,"stop area "+str(stop.stop_id))
			game.vehicle._toggle_doors()
			input.throttle_touch=true
			for i in range(8):
				await physics_frame
			check(absf(game.vehicle.speed)<0.01,"open doors prevent acceleration")
			input.reset_touch()
			if game.passenger_manager.boarding_pending>0:
				game.vehicle._toggle_doors()
				check(game.vehicle.doors_open,"cannot close during boarding")
			var frames:=0
			while game.passenger_manager.boarding_pending>0 and frames<600:
				frames+=1
				await physics_frame
			check(game.passenger_manager.boarding_pending==0,"boarding finishes")
			game.vehicle._toggle_doors()
			for i in range(12):
				await physics_frame
		check(gm.state==gm.State.RESULTS,"six stops complete the trip")
		check(game.vehicle.passengers_aboard==0,"terminus empties the bus")
		check(gm.passengers_delivered>0,"passengers delivered")
		var money: int=save.get_money()
		var trips: int=int(save.data.trips_completed)
		gm.complete_trip()
		check(save.get_money()==money and int(save.data.trips_completed)==trips,"completion is idempotent")
		input.throttle_touch=true
		for i in range(4):
			await physics_frame
		check(game.vehicle.speed==0.0,"results stop vehicle controls")
		check(save.get_money()==money,"results do not re-award final stop bonus")
		gm.go_to_garage()
		await process_frame
		await process_frame
		check(not input.throttle_touch,"scene change resets touch input")
		check(current_scene.get_script().resource_path.ends_with("garage.gd"),"garage loads after results")
	save.data=original
	save.save_game()
	Engine.time_scale=1.0
	print("FULL ROUTE: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
