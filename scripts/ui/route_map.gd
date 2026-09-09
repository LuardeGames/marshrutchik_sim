extends Control
class_name RouteMap
## Heading and road topology stay readable when the destination is offscreen.
var vehicle: VehicleController
var route_manager: RouteManager
var points: Array[Vector3] = []

func _ready() -> void:
	points = RouteDefinition.waypoints()
	custom_minimum_size=Vector2(220,180)
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _map(pos: Vector3) -> Vector2:
	return Vector2(18,18)+Vector2((pos.x+170)/960.0,(pos.z+630)/940.0)*Vector2(184,142)

func _draw() -> void:
	draw_style_box(UITheme.panel_style(Color(0.06,0.09,0.11,0.90)),Rect2(Vector2.ZERO,size))
	if vehicle and is_instance_valid(vehicle):
		var world := vehicle.get_parent()
		for street in world.get_meta("city_streets",[]):
			draw_line(_map(street[0]),_map(street[1]),Color("465955"),1.0,true)
	for i in range(points.size()):
		draw_line(_map(points[i]),_map(points[(i+1)%points.size()]),Color("7b8988"),3.0,true)
		var midpoint:=_map(points[i].lerp(points[(i+1)%points.size()],0.5))
		var direction:=(_map(points[(i+1)%points.size()])-_map(points[i])).normalized()
		var side:=Vector2(-direction.y,direction.x)
		draw_line(midpoint-direction*3+side*2,midpoint+direction*2,Color("a3ada4"),1.0,true)
		draw_line(midpoint-direction*3-side*2,midpoint+direction*2,Color("a3ada4"),1.0,true)
	if route_manager:
		for i in range(route_manager.stops.size()):
			var stop:=route_manager.stops[i]
			var color:=Color("6a7976")
			if i<route_manager.current_stop_index:
				color=Color("7dba8a")
			elif i==route_manager.current_stop_index:
				color=Color("f2ce77")
			draw_circle(_map(stop.global_position),4.0,color)
	if vehicle:
		var pos:=_map(vehicle.global_position)
		var direction:=-vehicle.global_transform.basis.z
		var forward:=Vector2(direction.x,direction.z).normalized()
		var side:=Vector2(-forward.y,forward.x)
		draw_colored_polygon(PackedVector2Array([pos+forward*8,pos-forward*5+side*5,pos-forward*5-side*5]),Color("f7f4e5"))
