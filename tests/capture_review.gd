extends SceneTree
## Render real game scenes using an X11 display; screenshots are not mockups.
## DISPLAY=:99 godot --path . --rendering-method gl_compatibility --script res://tests/capture_review.gd
var output := "res://docs/review"
func _initialize() -> void:
	call_deferred("run")

func capture(filename: String) -> void:
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+filename+".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,720)
	var save:=root.get_node("SaveManager")
	var original: Dictionary=save.data.duplicate(true)
	save.data=save.DEFAULT_DATA.duplicate(true)
	var gm:=root.get_node("GameManager")
	gm.go_to_menu()
	await capture("menu")
	gm.go_to_garage()
	await capture("garage")
	gm.start_trip()
	for i in range(5):
		await process_frame
	var game:=current_scene
	game.competitor.set_process(false)
	game.vehicle.set_physics_process(false)
	game.camera_rig.set_process(false)
	game.camera_rig.set_physics_process(false)
	game.vehicle.global_position=Vector3(2.5,0.13,-55)
	game.vehicle.rotation=Vector3.ZERO
	game.camera_rig.camera.global_position=Vector3(3.5,4.7,-44)
	game.camera_rig.camera.look_at(game.vehicle.global_position+Vector3(0,1,-3))
	await capture("city")
	var stop: StopArea=game.route_manager.stops[0]
	game.vehicle.global_position=stop.global_position+Vector3(0,0.15,0)
	game.vehicle.look_at(game.vehicle.global_position+RouteDefinition.stop_forward(stop.waypoint_index))
	game.camera_rig.camera.global_position=stop.to_global(Vector3(-6,5,9))
	game.camera_rig.camera.look_at(stop.to_global(Vector3(2,1,0)))
	await capture("stop")
	game.hud._set_paused(true)
	await capture("pause")
	game.hud.settings.show()
	await capture("settings")
	game.hud.settings.hide()
	game.hud._set_paused(false)
	gm.complete_trip()
	await capture("results")
	game.vehicle.global_position=Vector3(2.5,0.13,-55)
	game.hud.visible=false
	game.vehicle.queue_free()
	var vehicles:=VehicleCatalog.build()
	for i in range(vehicles.size()):
		var bus:=Node3D.new()
		game.world.add_child(bus)
		bus.position=Vector3(2.5,0.13,-55)
		BusVisual.build(bus,vehicles[i])
		game.camera_rig.camera.global_position=Vector3(7,3.4,-62)
		game.camera_rig.camera.look_at(bus.global_position+Vector3(0,1,0))
		await capture("gazelle" if i==0 else "paz")
		bus.queue_free()
	save.data=original
	save.save_game()
	quit()
