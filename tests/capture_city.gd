extends SceneTree
## Actual renderer views of the expanded city, without modifying save data.
func _initialize() -> void:
	call_deferred("run")
func shot(file: String) -> void:
	for i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/review/"+file+".png")
func run() -> void:
	root.size=Vector2i(1280,720)
	root.get_node("GameManager").start_trip()
	for i in range(5):
		await process_frame
	var game = current_scene
	game.vehicle.set_physics_process(false)
	game.camera_rig.set_process(false)
	game.camera_rig.set_physics_process(false)
	game.vehicle.global_position=Vector3(2.5,0.13,-55)
	game.camera_rig.camera.global_position=Vector3(3.5,4.7,-44)
	game.camera_rig.camera.look_at(game.vehicle.global_position+Vector3(0,1,-3))
	print("CITY_BUILDINGS ",game.world.get_meta("city_buildings"))
	await shot("dense_street")
	game.hud.visible=false
	game.camera_rig.camera.far=1800
	game.camera_rig.camera.global_position=Vector3(-80,125,80)
	game.camera_rig.camera.look_at(Vector3(150,0,-160))
	await shot("dense_quarters")
	quit()
