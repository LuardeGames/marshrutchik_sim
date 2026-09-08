extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,720)
	var gm:=root.get_node("GameManager")
	gm.start_trip()
	for i in range(8): await process_frame
	var game:=current_scene
	game.vehicle.set_physics_process(false)
	game.camera_rig.set_process(false)
	game.vehicle.global_position=Vector3(2.5,0.13,-55)
	game.camera_rig.camera.global_position=Vector3(3.5,4.7,-44)
	game.camera_rig.camera.look_at(game.vehicle.global_position+Vector3(0,1,-3))
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/review/mobile.png")
	gm.go_to_menu()
	for i in range(2): await process_frame
	quit()
