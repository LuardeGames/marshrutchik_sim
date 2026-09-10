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
			WorldBuilder._invisible_collider(root,pos+Vector3(0,3.5,0),Vector3(0.28,7.0,0.28))
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
	_build_sidewalk_props(root, waypoints)
	_build_parks_and_courtyards(root, waypoints)
	_build_chain_stores(root)
	_build_neighborhood_life(root, waypoints)

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
			for pedestrian_index in range(2):
				var t: float = 0.14 + float((i * 2 + pedestrian_index + int(side_sign > 0.0)) % 5) * 0.13
				var start: Vector3 = a.lerp(b, t) + side * side_sign * (RouteDefinition.ROAD_WIDTH * 0.5 + 3.0)
				var finish: Vector3 = a.lerp(b, minf(t + 0.16 + float(pedestrian_index) * 0.03, 0.90)) + side * side_sign * (RouteDefinition.ROAD_WIDTH * 0.5 + 3.0)
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
	WorldBuilder._invisible_collider(car, Vector3(0, 0.65, 0), Vector3(1.65, 1.3, 3.2))

static func _build_sidewalk_props(root: Node3D, waypoints: Array[Vector3]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91741
	for i in range(waypoints.size()):
		var a: Vector3 = waypoints[i]
		var b: Vector3 = waypoints[(i + 1) % waypoints.size()]
		var dir: Vector3 = (b - a).normalized()
		var side: Vector3 = Vector3(-dir.z, 0, dir.x)
		var angle: float = atan2(dir.x, dir.z)
		for side_sign: float in [-1.0, 1.0]:
			for prop_index in range(3):
				var t: float = 0.18 + float(prop_index) * 0.25 + float((i + prop_index) % 2) * 0.04
				var pos: Vector3 = a.lerp(b, minf(t, 0.88)) + side * side_sign * (RouteDefinition.ROAD_WIDTH * 0.5 + 3.15)
				if _near_stop(pos):
					continue
				var kind: int = (i * 3 + prop_index + int(side_sign > 0.0)) % 5
				_street_prop(root, pos, angle, kind, rng)

static func _street_prop(root: Node3D, pos: Vector3, angle: float, kind: int, rng: RandomNumberGenerator) -> void:
	var prop := Node3D.new()
	prop.name = "SidewalkProp_%d" % kind
	prop.position = pos
	prop.rotation.y = angle
	root.add_child(prop)
	var metal := BusVisual.material(Color("596461"))
	var green_colors: Array[Color] = [Color("58724b"), Color("70865a"), Color("466a4f")]
	var green: Color = green_colors[rng.randi_range(0, 2)]
	match kind:
		0:
			BusVisual.box(prop, Vector3(0, 0.42, 0), Vector3(0.58, 0.84, 0.58), metal)
			BusVisual.box(prop, Vector3(0, 0.88, 0), Vector3(0.48, 0.08, 0.48), BusVisual.material(Color("252d2d")))
			WorldBuilder._invisible_collider(prop, Vector3(0, 0.42, 0), Vector3(0.62, 0.86, 0.62))
		1:
			BusVisual.box(prop, Vector3(0, 0.52, 0.08), Vector3(1.9, 0.12, 0.48), BusVisual.material(Color("77533d")))
			BusVisual.box(prop, Vector3(0, 0.87, -0.12), Vector3(1.9, 0.62, 0.10), BusVisual.material(Color("77533d")))
			for x in [-0.7, 0.7]:
				BusVisual.box(prop, Vector3(x, 0.27, 0.08), Vector3(0.10, 0.54, 0.10), metal)
			WorldBuilder._invisible_collider(prop, Vector3(0, 0.55, 0), Vector3(2.0, 1.2, 0.65))
		2:
			BusVisual.box(prop, Vector3(0, 0.18, 0), Vector3(1.55, 0.36, 0.85), BusVisual.material(Color("9b8970")))
			for x in [-0.48, 0.0, 0.48]:
				_shrub(prop, Vector3(x, 0.60, 0), green, rng.randf_range(0.72, 1.05))
			WorldBuilder._invisible_collider(prop, Vector3(0, 0.42, 0), Vector3(1.65, 0.70, 0.95))
		3:
			for x in [-0.9, 0.0, 0.9]:
				BusVisual.box(prop, Vector3(x, 0.62, 0), Vector3(0.12, 1.24, 0.12), metal)
			BusVisual.box(prop, Vector3(0, 0.82, 0), Vector3(1.9, 0.10, 0.10), metal)
			WorldBuilder._invisible_collider(prop, Vector3(0, 0.62, 0), Vector3(2.0, 1.25, 0.18))
		4:
			BusVisual.box(prop, Vector3(0, 0.55, 0), Vector3(0.90, 1.10, 0.72), BusVisual.material(Color("65706e")))
			BusVisual.box(prop, Vector3(0, 1.14, 0), Vector3(0.98, 0.08, 0.80), metal)
			BusVisual.box(prop, Vector3(0.46, 0.68, 0), Vector3(0.04, 0.26, 0.32), BusVisual.material(Color("d2b85e")))
			WorldBuilder._invisible_collider(prop, Vector3(0, 0.55, 0), Vector3(0.96, 1.14, 0.78))

static func _shrub(parent: Node3D, pos: Vector3, color: Color, scale_value: float) -> void:
	var shrub := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.42
	mesh.height = 0.78
	mesh.radial_segments = 8
	mesh.rings = 3
	shrub.mesh = mesh
	shrub.material_override = BusVisual.material(color)
	shrub.position = pos
	shrub.scale = Vector3(scale_value, scale_value, scale_value)
	parent.add_child(shrub)

static func _build_parks_and_courtyards(root: Node3D, waypoints: Array[Vector3]) -> void:
	var park_index := 0
	for i in range(waypoints.size()):
		if i % 3 != 0:
			continue
		var a: Vector3 = waypoints[i]
		var b: Vector3 = waypoints[(i + 1) % waypoints.size()]
		var dir: Vector3 = (b - a).normalized()
		var side: Vector3 = Vector3(-dir.z, 0, dir.x)
		var center: Vector3 = a.lerp(b, 0.52) + side * (18.0 if i % 2 == 0 else -18.0)
		var park := Node3D.new()
		park.name = "Park_%d" % park_index
		park.position = center
		park.rotation.y = atan2(dir.x, dir.z)
		root.add_child(park)
		WorldBuilder._box(park, Vector3(0, 0.04, 0), Vector3(18.0, 0.08, 30.0), Color("5e744e"), false)
		WorldBuilder._box(park, Vector3(0, 0.075, 0), Vector3(2.0, 0.035, 28.0), Color("b0a27f"), false)
		for x in [-6.0, 6.0]:
			for z in [-10.0, 0.0, 10.0]:
				var tree_pos := Vector3(x, 0, z)
				# Was a 2.8m sapling standing next to a 2.25m-tall bus - read as
				# a shrub, not a tree. A real street tree clears a minibus roof
				# by a wide margin; scaled up to ~4.6m overall.
				WorldBuilder._box(park, tree_pos + Vector3(0, 1.15, 0), Vector3(0.8, 2.3, 0.8), Color("76533e"), false)
				_shrub(park, tree_pos + Vector3(0, 3.1, 0), Color("4b704d"), 2.1)
				WorldBuilder._invisible_collider(park, tree_pos + Vector3(0, 1.7, 0), Vector3(1.3, 3.4, 1.3))
		WorldBuilder._box(park, Vector3(-5.0, 0.55, 4.0), Vector3(3.0, 0.12, 0.55), Color("735442"), false)
		WorldBuilder._box(park, Vector3(-5.0, 0.30, 4.0), Vector3(0.10, 0.6, 0.5), Color("596461"), false)
		WorldBuilder._box(park, Vector3(-3.8, 0.30, 4.0), Vector3(0.10, 0.6, 0.5), Color("596461"), false)
		park_index += 1

static func _build_chain_stores(root: Node3D) -> void:
	var stores: Array[Dictionary] = [
		{"pos": Vector3(-35, 0, -35), "name": "ПЯТЬ КРУГОВ", "color": Color("5d8b55")},
		{"pos": Vector3(335, 0, -150), "name": "WILD BOX", "color": Color("8a55a5")},
		{"pos": Vector3(540, 0, 85), "name": "ГИПЕРМАГ", "color": Color("a84c43")},
		{"pos": Vector3(115, 0, 215), "name": "OZONЬКА", "color": Color("3672a6")}
	]
	for store in stores:
		var store_pos: Vector3 = store["pos"]
		var store_name: String = String(store["name"])
		var store_color: Color = store["color"]
		_chain_store(root, store_pos, store_name, store_color)

static func _chain_store(root: Node3D, pos: Vector3, store_name: String, color: Color) -> void:
	var store := Node3D.new()
	store.name = "ChainStore_" + store_name
	store.position = pos
	root.add_child(store)
	WorldBuilder._box(store, Vector3(0, 2.0, 0), Vector3(9.0, 4.0, 7.0), Color("c1b89f"))
	WorldBuilder._invisible_collider(store, Vector3(0, 2.0, 0), Vector3(9.0, 4.0, 7.0))
	WorldBuilder._box(store, Vector3(0, 3.65, -3.65), Vector3(9.4, 0.8, 0.18), color, false)
	WorldBuilder._box(store, Vector3(0, 1.7, -3.63), Vector3(7.2, 1.7, 0.08), Color("42606a"), false)
	_sign(store, store_name, Vector3(0, 3.65, -3.78), 0.005)

static func _build_neighborhood_life(root: Node3D, waypoints: Array[Vector3]) -> void:
	var colors: Array[Color] = [Color("536a72"), Color("8b5148"), Color("b18d53"), Color("65745b")]
	var courtyard_index := 0
	for i in range(waypoints.size()):
		# These two route edges cross the civic and industrial loops; a yard
		# here would put its storage row directly on the secondary street.
		if i % 2 == 0 or i in [5, 13]:
			continue
		var a: Vector3 = waypoints[i]
		var b: Vector3 = waypoints[(i + 1) % waypoints.size()]
		var dir: Vector3 = (b - a).normalized()
		var side: Vector3 = Vector3(-dir.z, 0, dir.x)
		var center: Vector3 = a.lerp(b, 0.52) + side * (27.0 if i % 4 == 1 else -27.0)
		var yard := Node3D.new()
		yard.name = "Courtyard_%d" % courtyard_index
		yard.position = center
		yard.rotation.y = atan2(dir.x, dir.z)
		root.add_child(yard)
		WorldBuilder._box(yard, Vector3(0, 0.035, 0), Vector3(24.0, 0.07, 20.0), Color("536442"), false)
		WorldBuilder._box(yard, Vector3(0, 0.075, 0), Vector3(1.8, 0.035, 19.0), Color("a79b79"), false)
		for x in [-8.0, -2.7, 2.7, 8.0]:
			WorldBuilder._box(yard, Vector3(x, 1.35, -7.2), Vector3(4.5, 2.7, 4.0), Color("77706a"))
			WorldBuilder._box(yard, Vector3(x, 2.80, -7.2), Vector3(4.8, 0.25, 4.3), Color("4d5553"), false)
		for car_index in range(3):
			_parked_car(yard, Vector3(-8.0 + float(car_index) * 5.2, 0, 5.4), dir, colors[(i + car_index) % colors.size()])
		# A small Soviet-style playground gives empty courtyards a readable use.
		WorldBuilder._box(yard, Vector3(5.2, 0.20, -0.8), Vector3(4.5, 0.4, 3.8), Color("b99b62"), false)
		WorldBuilder._box(yard, Vector3(3.4, 1.15, -1.8), Vector3(0.14, 2.3, 0.14), Color("b24c3e"), false)
		WorldBuilder._box(yard, Vector3(5.2, 1.15, -1.8), Vector3(0.14, 2.3, 0.14), Color("b24c3e"), false)
		WorldBuilder._box(yard, Vector3(4.3, 2.05, -1.8), Vector3(1.2, 0.10, 0.10), Color("d0b25c"), false)
		WorldBuilder._box(yard, Vector3(-7.0, 1.0, -0.8), Vector3(0.10, 2.0, 0.10), Color("596461"), false)
		WorldBuilder._box(yard, Vector3(-3.0, 1.0, -0.8), Vector3(0.10, 2.0, 0.10), Color("596461"), false)
		WorldBuilder._box(yard, Vector3(-5.0, 1.6, -0.8), Vector3(4.0, 0.08, 0.08), Color("596461"), false)
		WorldBuilder._box(yard, Vector3(-8.0, 0.45, 0.5), Vector3(0.75, 0.9, 0.75), Color("596461"))
		WorldBuilder._box(yard, Vector3(-6.8, 0.45, 0.5), Vector3(0.75, 0.9, 0.75), Color("596461"))
		for x in [-9.0, 9.0]:
			# Was a bare floating shrub sphere doing duty as a "tree" - give it
			# a trunk and the same taller canopy as the park trees so yards
			# don't read as smaller/emptier than the parks next to them.
			WorldBuilder._box(yard, Vector3(x, 1.15, 6.8), Vector3(0.8, 2.3, 0.8), Color("76533e"), false)
			_shrub(yard, Vector3(x, 3.1, 6.8), Color("4f704d"), 2.1)
			WorldBuilder._invisible_collider(yard, Vector3(x, 1.7, 6.8), Vector3(1.3, 3.4, 1.3))
		courtyard_index += 1

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
