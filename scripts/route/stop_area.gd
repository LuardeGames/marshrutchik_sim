extends Node3D
class_name StopArea
## A single bus-stop zone: detection area + simple visual marker (pole,
## sign board, pad). Built entirely from primitives at runtime.

signal vehicle_entered(stop: StopArea)
signal vehicle_exited(stop: StopArea)

var stop_id: int = 0
var stop_name: String = ""
var required: bool = true
var waypoint_index: int = 0

var _area: Area3D
var vehicle_inside: Node3D = null
var _sign_mesh: MeshInstance3D

func setup(id: int, name_: String, req: bool, wp_index: int) -> void:
	stop_id = id
	stop_name = name_
	required = req
	waypoint_index = wp_index
	name = "Stop_%d_%s" % [id, name_]
	_build_visual()
	_build_area()

var _bay_material: StandardMaterial3D
var _marker: Node3D

func _build_visual() -> void:
	var concrete := CityMaterials.surface("paving")
	var metal := BusVisual.material(Color("3e5654"))
	var glass := BusVisual.material(Color("647a79"), 0.25)
	var wood := BusVisual.material(Color("775b43"))
	BusVisual.box(self, Vector3(-0.9,0.10,0),Vector3(8,0.12,24),CityMaterials.surface("asphalt"))
	BusVisual.box(self, Vector3(4.4,0.16,0),Vector3(3.3,0.18,23),concrete)
	_bay_material=BusVisual.material(Color("77786b"))
	for x in [-2.0,2.0]:
		BusVisual.box(self,Vector3(x,0.175,0),Vector3(0.12,0.02,10),_bay_material)
	for z in [-5.0,5.0]:
		BusVisual.box(self,Vector3(0,0.175,z),Vector3(4,0.02,0.12),_bay_material)
	# A familiar metal-and-glass shelter, parallel to the bus and outside its bay.
	BusVisual.box(self,Vector3(4.7,2.8,0),Vector3(2.5,0.18,6.2),metal)
	BusVisual.box(self,Vector3(5.7,1.55,0),Vector3(0.07,2.3,5.8),glass)
	for z in [-2.85,0.0,2.85]:
		BusVisual.box(self,Vector3(5.7,1.55,z),Vector3(0.09,2.4,0.09),metal)
	for z in [-2.85,2.85]:
		BusVisual.box(self,Vector3(3.6,1.55,z),Vector3(0.08,2.4,0.08),metal)
	BusVisual.box(self,Vector3(5.15,0.75,0),Vector3(0.65,0.1,4.5),wood)
	BusVisual.box(self,Vector3(5.48,1.1,0),Vector3(0.08,0.6,4.5),wood)
	for z in [-1.8,1.8]:
		BusVisual.box(self,Vector3(5.1,0.43,z),Vector3(0.08,0.65,0.12),metal)
	BusVisual.box(self,Vector3(3.5,1.8,-5.5),Vector3(0.09,3.3,0.09),metal)
	BusVisual.box(self,Vector3(3.5,3.1,-5.5),Vector3(0.07,0.75,0.7),BusVisual.material(Color("285b82")))
	var number := Label3D.new()
	number.text=RouteDefinition.route_number()
	number.font_size=64
	number.pixel_size=0.008
	number.position=Vector3(3.45,3.1,-5.5)
	number.rotation.y=-PI/2.0
	add_child(number)
	var title := Label3D.new()
	title.text=stop_name.to_upper()
	title.font_size=48
	title.pixel_size=0.006
	title.position=Vector3(3.4,2.72,0)
	title.rotation.y=-PI/2.0
	title.outline_size=2
	add_child(title)
	BusVisual.box(self,Vector3(5.6,1.8,-1.9),Vector3(0.035,0.7,0.6),BusVisual.material(Color("e6dcc1")))
	BusVisual.box(self,Vector3(4.5,0.6,4.0),Vector3(0.6,0.9,0.6),metal)
	_marker=Node3D.new()
	_marker.position=Vector3(0,4.7,0)
	add_child(_marker)
	var arrow := Label3D.new()
	arrow.text="↓"
	arrow.font_size=100
	arrow.pixel_size=0.018
	arrow.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	arrow.modulate=Color("f6cf66")
	_marker.add_child(arrow)
	set_active(false)

func set_active(active: bool) -> void:
	if _bay_material:
		_bay_material.albedo_color=Color("e6bd55") if active else Color("77786b")
	if _marker:
		_marker.visible=active

func _build_area() -> void:
	_area = Area3D.new()
	_area.name = "DetectionArea"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(9.0, 4.0, 14.0)
	shape.shape = box
	shape.position = Vector3(0, 2.0, 0)
	_area.add_child(shape)
	_area.collision_layer = 0
	_area.collision_mask = 2 # vehicle layer
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	add_child(_area)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("vehicle"):
		vehicle_inside = body
		vehicle_entered.emit(self)

func _on_body_exited(body: Node3D) -> void:
	if body == vehicle_inside:
		vehicle_inside = null
		vehicle_exited.emit(self)

## Distance from the stop's pad center to a global position, used to judge
## parking quality.
func distance_to_pad(global_pos: Vector3) -> float:
	return global_position.distance_to(Vector3(global_pos.x, global_position.y, global_pos.z))
