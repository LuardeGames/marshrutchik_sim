extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	print("[PASS] " if ok else "[FAIL] ",message)
	if not ok: failures+=1
func touch(control: Control,index: int,pressed: bool) -> void:
	var event:=InputEventScreenTouch.new()
	event.index=index
	event.pressed=pressed
	event.position=control.get_global_rect().get_center()
	root.push_input(event,true)
func run() -> void:
	await process_frame
	var gm:=root.get_node("GameManager")
	var input:=root.get_node("InputState")
	gm.start_trip()
	for i in range(8): await process_frame
	var game:=current_scene
	var throttle: Control=null
	var steer: Control=null
	var controls: Array[Node]=game.hud.find_children("*","Control",true,false)
	for control in controls:
		if control.get_script() and control.get_script().resource_path.ends_with("touch_control.gd"):
			if control.caption=="▲": throttle=control
			if control.caption=="◀": steer=control
	check(throttle!=null and steer!=null,"touch controls exist")
	if throttle and steer:
		touch(throttle,0,true)
		touch(steer,1,true)
		await process_frame
		check(input.throttle_touch and input.steer_left_touch,"two independent fingers hold throttle and steering")
		touch(steer,1,false)
		await process_frame
		check(input.throttle_touch and not input.steer_left_touch,"releasing steering preserves throttle")
		game.hud._set_paused(true)
		await process_frame
		check(not input.throttle_touch and not input.steer_left_touch,"pause releases all held controls")
		game.hud._set_paused(false)
		game.hud._on_trip_completed({"rating":3,"passengers":12,"fares":600,"stop_bonus":150,"comfort_bonus":60,"penalties":0,"time":400,"total":810})
		for i in range(4): await process_frame
		# Native simulated touches must not pass through a result modal.
		gm.trip_running=false
		touch(throttle,0,true)
		await process_frame
		check(not input.throttle_touch,"results reject touch driving")
	gm.go_to_menu()
	for i in range(3): await process_frame
	print("TOUCH: ",failures," failures")
	quit(0 if failures==0 else 1)
