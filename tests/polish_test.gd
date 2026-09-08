extends SceneTree
var failed:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	print("[PASS] " if ok else "[FAIL] ",message)
	if not ok: failed+=1
func run() -> void:
	await process_frame
	var save:=root.get_node("SaveManager")
	var gm:=root.get_node("GameManager")
	var original: Dictionary=save.data.duplicate(true)
	save.data=save.DEFAULT_DATA.duplicate(true)
	save.data.money=987
	save.save_game()
	save.data.money=123
	save.save_game()
	var f:=FileAccess.open(save.SAVE_PATH,FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	save.load_game()
	check(save.get_money()==987,"corrupted save recovers previous valid snapshot")
	save.data=save.DEFAULT_DATA.duplicate(true)
	save._merge_defaults(save.data,{"money":"oops","sound":{"master":9,"sfx":[]},"upgrades":{"engine":999},"selected_vehicle":"unknown"})
	save._validate_data()
	check(save.get_money()==300 and save.get_sound_setting("master")==1.0,"invalid save values keep safe defaults and bounds")
	check(save.get_selected_vehicle()=="old_marshrutka","invalid vehicle selection recovers")
	check(not save.spend_money(-100),"negative purchase rejected")
	gm.start_trip()
	for i in range(10): await physics_frame
	var game:=current_scene
	game.event_manager.stop()
	game.hud._set_paused(true)
	var time_before: float=gm.trip_time
	for i in range(20): await process_frame
	check(is_equal_approx(time_before,gm.trip_time),"pause freezes trip clock")
	game.hud._set_paused(false)
	game.hud._on_change_requested(45,100,[55,45,65])
	check(game.hud.change_label.text.contains("100") and game.hud.change_label.text.contains("45"),"change popup retains fare and payment")
	var money_before: int=save.get_money()
	game.hud._on_change_option_picked(55,55)
	game.hud._on_change_option_picked(55,55)
	check(save.get_money()==money_before+15,"change reward cannot be double clicked")
	var shapes_ok:=true
	for stop in game.route_manager.stops:
		var expected:=RouteDefinition.stop_forward(stop.waypoint_index)
		shapes_ok=shapes_ok and (-stop.global_basis.z).dot(expected)>0.999
	check(shapes_ok,"every stop is aligned with approach lane")
	game.vehicle.global_position=Vector3(10000,2,10000)
	game.hud._recover_vehicle()
	check(game.vehicle.global_position.length()<1000,"recovery brings an off-map vehicle back to road")
	gm.go_to_garage()
	for i in range(3): await process_frame
	check(not gm.trip_running,"garage stops trip clock")
	save.data=original
	save.save_game()
	gm.go_to_menu()
	for i in range(3): await process_frame
	print("POLISH: ",failed," failures")
	quit(0 if failed==0 else 1)
