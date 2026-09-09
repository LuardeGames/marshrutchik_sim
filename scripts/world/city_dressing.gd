extends RefCounted
class_name CityDressing
## Local street vocabulary, placed relative to road tangents, outside lanes.
static func build(parent: Node3D, waypoints: Array[Vector3]) -> void:
	var root := Node3D.new()
	root.name = "CISStreetDetails"
	parent.add_child(root)
	var metal := BusVisual.material(Color("626960"))
	var wood := BusVisual.material(Color("735442"))
	var poles: Array = []
	var arms: Array = []
	var crossings: Array=[]
	for i in range(waypoints.size()):
		var a := waypoints[i]
		var b := waypoints[(i+1)%waypoints.size()]
		var dir := (b-a).normalized()
		var side := Vector3(-dir.z,0,dir.x)
		var angle := atan2(dir.x,dir.z)
		for k in range(1,int(a.distance_to(b)/40.0)):
			var pos := a+dir*float(k)*40.0+side*7.0
			poles.append({"size":Vector3(0.15,7.0,0.15),"position":pos+Vector3(0,3.5,0),"y_rot":0.0})
			arms.append({"size":Vector3(2.1,0.10,0.10),"position":pos-side+Vector3(0,6.9,0),"y_rot":angle})
		# Both approaches have a crossing, matching the roadside signs.
		for distance in [12.0,a.distance_to(b)-12.0]:
			for stripe in range(7):
				var crossing_pos: Vector3=a+dir*distance+side*(float(stripe)-3.0)*1.1+Vector3(0,0.145,0)
				crossings.append({"size":Vector3(0.5,0.015,3.2),"position":crossing_pos,"y_rot":angle})
		# A patch and manhole on each straight, above the road surface.
		var patch := BusVisual.box(root,a.lerp(b,0.6)+Vector3(0,0.132,0)+side*1.8,Vector3(2.5,0.01,4),BusVisual.material(Color("373d3f")))
		patch.rotation.y=angle
		var manhole:=MeshInstance3D.new()
		var disc:=CylinderMesh.new()
		disc.top_radius=0.42
		disc.bottom_radius=0.42
		disc.height=0.016
		disc.radial_segments=12
		manhole.mesh=disc
		manhole.position=a.lerp(b,0.38)+side*2.4+Vector3(0,0.139,0)
		manhole.material_override=metal
		root.add_child(manhole)
	WorldBuilder._multimesh_boxes(root,"LampPoles",metal,poles)
	WorldBuilder._multimesh_boxes(root,"LampArms",metal,arms)
	WorldBuilder._multimesh_boxes(root,"Crosswalks",BusVisual.material(Color("bdbbaa")),crossings)
	var names := ["ПРОДУКТЫ  24", "РЫНОК", "АПТЕКА", "ДОМ БЫТА", "ВОКЗАЛ", "АВТОПАРК № 4"]
	var subtitles := ["ХЛЕБ • МОЛОКО", "ОВОЩИ • ФРУКТЫ", "8:00 — 21:00", "КЛЮЧИ • РЕМОНТ", "ПРИГОРОДНЫЕ КАССЫ", "МОЙКА • ШИНОМОНТАЖ"]
	var defs := RouteDefinition.stops()
	for i in range(defs.size()):
		var idx: int=defs[i].waypoint_index
		var tangent:=RouteDefinition.stop_forward(idx)
		var side:=Vector3(-tangent.z,0,tangent.x)
		var plaza:=Node3D.new()
		plaza.name="District_%d" % i
		plaza.position=RouteDefinition.stop_position(idx)+side*12.0-tangent*16.0
		plaza.rotation.y=atan2(side.x,side.z)
		root.add_child(plaza)
		# Shop facing the road (-Z), corrugated fascia, deep window and canopy.
		BusVisual.box(plaza,Vector3(0,1.6,0),Vector3(5.5,3.2,3.4),BusVisual.material(Color("d2c8af")))
		WorldBuilder._invisible_collider(plaza,Vector3(0,1.6,0),Vector3(5.5,3.2,3.4))
		BusVisual.box(plaza,Vector3(0,2.85,-1.78),Vector3(5.8,0.70,0.16),BusVisual.material(Color("46645c")))
		_sign(plaza,names[i],Vector3(0,2.9,-1.88),0.0055)
		_sign(plaza,subtitles[i],Vector3(0,2.6,-1.89),0.0023)
		BusVisual.box(plaza,Vector3(-0.8,1.55,-1.73),Vector3(2.7,1.65,0.07),BusVisual.material(Color("42606a")))
		BusVisual.box(plaza,Vector3(1.5,1.10,-1.76),Vector3(0.95,2.20,0.11),metal)
		BusVisual.box(plaza,Vector3(1.5,1.55,-1.84),Vector3(0.68,0.96,0.02),BusVisual.material(Color("729095")))
		BusVisual.box(plaza,Vector3(0,3.28,-0.15),Vector3(5.95,0.14,4.1),metal)
		# Bench and litter bin beside the shop; no props inside the stop pad.
		BusVisual.box(plaza,Vector3(-4,0.52,0),Vector3(2.1,0.12,0.5),wood)
		BusVisual.box(plaza,Vector3(-4,0.95,0.23),Vector3(2.1,0.65,0.1),wood)
		for x in [-4.8,-3.2]:
			BusVisual.box(plaza,Vector3(x,0.25,0),Vector3(0.09,0.5,0.48),metal)
		BusVisual.box(plaza,Vector3(-5.7,0.38,0),Vector3(0.5,0.76,0.5),metal)
		# District street plate.
		BusVisual.box(plaza,Vector3(-1.7,2.24,-1.79),Vector3(1.8,0.26,0.03),BusVisual.material(Color("294a6b")))
		_sign(plaza,"ул. МИРА, %d" % (i*8+3),Vector3(-1.7,2.24,-1.82),0.0018)
	_build_ambient_life(parent, waypoints)

static func _build_ambient_life(parent: Node3D, waypoints: Array[Vector3]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 55129
	var parked_colors := [Color("536a72"), Color("8b5148"), Color("b18d53"), Color("65745b")]
	for i in range(waypoints.size()):
		var a: Vector3 = waypoints[i]
		var b: Vector3 = waypoints[(i + 1) % waypoints.size()]
		var dir: Vector3 = (b - a).normalized()
		var side: Vector3 = Vector3(-dir.z, 0, dir.x)
		var length: float = a.distance_to(b)
		var side_signs: Array[float] = [-1.0, 1.0]
		for side_sign: float in side_signs:
			var t := 0.24 + float((i + int(side_sign > 0.0)) % 3) * 0.17
			var start: Vector3 = a.lerp(b, t) + side * side_sign * (RouteDefinition.ROAD_WIDTH * 0.5 + 3.0)
			var finish: Vector3 = a.lerp(b, minf(t + 0.22, 0.90)) + side * side_sign * (RouteDefinition.ROAD_WIDTH * 0.5 + 3.0)
			if _near_stop(start) or start.distance_to(finish) < 8.0:
				continue
			var pedestrian := AmbientPedestrian.new()
			pedestrian.start_point = start + Vector3(0, 0.04, 0)
			pedestrian.end_point = finish + Vector3(0, 0.04, 0)
			pedestrian.variant = rng.randi_range(0, 3)
			pedestrian.walk_speed = rng.randf_range(0.8, 1.25)
			parent.add_child(pedestrian)
		if length > 110.0 and i % 2 == 0:
			var parked_pos: Vector3 = a.lerp(b, 0.67) + side * (RouteDefinition.ROAD_WIDTH * 0.5 + 2.7)
			if not _near_stop(parked_pos):
				_parked_car(parent, parked_pos, dir, parked_colors[i % parked_colors.size()])

static func _near_stop(pos: Vector3) -> bool:
	for stop in RouteDefinition.stops():
		if pos.distance_to(RouteDefinition.stop_position(int(stop.waypoint_index))) < 18.0:
			return true
	return false

static func _parked_car(parent: Node3D, pos: Vector3, direction: Vector3, color: Color) -> void:
	var car := Node3D.new()
	car.name = "ParkedCar"
	car.position = pos
	car.rotation.y = atan2(direction.x, direction.z)
	parent.add_child(car)
	BusVisual.box(car, Vector3(0, 0.42, 0), Vector3(1.55, 0.55, 3.1), BusVisual.material(color))
	BusVisual.box(car, Vector3(0, 0.82, -0.10), Vector3(1.25, 0.35, 1.45), BusVisual.material(Color("36484d"), 0.1))
	BusVisual.box(car, Vector3(0, 0.36, -1.58), Vector3(1.62, 0.13, 0.08), BusVisual.material(Color("e0bf69")))

static func _sign(parent: Node3D,text: String,pos: Vector3,pixel: float) -> void:
	var label:=Label3D.new()
	label.text=text
	label.font_size=48
	label.pixel_size=pixel
	label.position=pos
	label.rotation.y=PI
	label.modulate=Color("f2eddb")
	label.outline_size=0
	parent.add_child(label)
