extends CharacterBody3D
class_name TrafficDummy
## Lane-following ambient traffic with signals, safe gaps and acceleration.
@export var start_index: int = 0
@export var speed: float = 7.0
var road_path: Array[Vector3] = []
var reverse_direction := true
var spawn_fraction := -1.0
var current_speed := 0.0
var waiting_for_signal := false
var _signals: Array[Node] = []
var _points: Array[Vector3] = []
var _index := 0
var _wheels: Array[MeshInstance3D] = []

func _ready() -> void:
	collision_layer=4
	collision_mask=1|2|4
	var road: Array[Vector3] = road_path.duplicate() if not road_path.is_empty() else RouteDefinition.waypoints()
	if reverse_direction:
		road.reverse()
	_signals=get_tree().get_nodes_in_group("traffic_signals")
	for i in range(road.size()):
		var incoming:=(road[i]-road[(i-1+road.size())%road.size()]).normalized()
		var outgoing:=(road[(i+1)%road.size()]-road[i]).normalized()
		var offset:=Vector3(-incoming.z-outgoing.z,0,incoming.x+outgoing.x)*2.5
		_points.append(road[i]+offset)
	_index=start_index%_points.size()
	position=_points[_index]+Vector3(0,0.3,0)
	_index=(_index+1)%_points.size()
	if spawn_fraction>=0.0:
		var perimeter := 0.0
		for i in range(_points.size()):
			perimeter += _points[i].distance_to(_points[(i+1)%_points.size()])
		var distance := spawn_fraction*perimeter
		for i in range(_points.size()):
			var length := _points[i].distance_to(_points[(i+1)%_points.size()])
			if distance<=length:
				position=_points[i].lerp(_points[(i+1)%_points.size()],distance/length)+Vector3(0,0.3,0)
				_index=(i+1)%_points.size()
				break
			distance-=length
	var heading := (_points[_index]-position).normalized()
	rotation.y=atan2(-heading.x,-heading.z)
	var palette:=[Color("c9c7b7"),Color("5b756d"),Color("8b4032"),Color("596574")]
	var paint:=BusVisual.material(palette[start_index%palette.size()],0.2)
	var dark:=BusVisual.material(Color("24282a"))
	var glass:=BusVisual.material(Color("354b53"),0.25)
	BusVisual.box(self,Vector3(0,0.70,0),Vector3(1.75,0.65,4.0),paint)
	var roof_length := 2.0 if start_index%3==0 else 2.6
	BusVisual.box(self,Vector3(0,1.19,0.15),Vector3(1.55,0.65,roof_length),paint)
	for side in [-1.0,1.0]:
		BusVisual.box(self,Vector3(side*0.783,1.25,0.15),Vector3(0.025,0.40,roof_length-0.3),glass)
		BusVisual.box(self,Vector3(side*0.79,1.25,0.05),Vector3(0.03,0.46,0.07),dark)
		BusVisual.box(self,Vector3(side*0.60,0.75,-2.03),Vector3(0.43,0.2,0.03),BusVisual.material(Color("dfd4b5")))
		BusVisual.box(self,Vector3(side*0.60,0.75,2.03),Vector3(0.40,0.2,0.03),BusVisual.material(Color("8f3428")))
		for z in [-1.25,1.25]:
			var wheel:=MeshInstance3D.new()
			var mesh:=CylinderMesh.new()
			mesh.top_radius=0.32
			mesh.bottom_radius=0.32
			mesh.height=0.20
			mesh.radial_segments=12
			wheel.mesh=mesh
			wheel.material_override=dark
			wheel.rotation.z=PI/2.0
			wheel.position=Vector3(side*0.85,0.32,z)
			add_child(wheel)
			_wheels.append(wheel)
	BusVisual.box(self,Vector3(0,1.25,0.15-roof_length*0.5-0.02),Vector3(1.35,0.4,0.03),glass)
	BusVisual.box(self,Vector3(0,1.25,0.15+roof_length*0.5+0.02),Vector3(1.35,0.4,0.03),glass)
	for z in [-2.03,2.03]:
		BusVisual.box(self,Vector3(0,0.5,z),Vector3(1.75,0.16,0.1),dark)
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(1.8,1.5,4.1)
	shape.shape=box
	shape.position.y=0.62
	add_child(shape)

func _physics_process(delta: float) -> void:
	if _points.is_empty() or not get_node("/root/GameManager").trip_running:
		return
	var target:=_points[_index]
	var direction:=target-global_position
	direction.y=0
	if direction.length()<2.0:
		_index=(_index+1)%_points.size()
		direction=_points[_index]-global_position
		direction.y=0
	var forward:=direction.normalized()
	rotation.y=lerp_angle(rotation.y,atan2(-forward.x,-forward.z),minf(delta*5.0,1.0))
	var desired := speed
	waiting_for_signal=false
	for signal_node in _signals:
		var light := signal_node as TrafficLightProp
		if not is_instance_valid(light) or light.allows_traffic() or forward.dot(light.approach)<0.85:
			continue
		var relative := light.stop_point-global_position
		var remaining := relative.dot(light.approach)-2.3
		var lateral := absf(relative.dot(Vector3(-light.approach.z,0,light.approach.x)))
		if remaining>=-0.6 and remaining<24.0 and lateral<2.0:
			desired=minf(desired,sqrt(maxf(remaining-0.6,0.0)*2.0*4.0))
			waiting_for_signal=true
	# Three feelers cover the car width and detect buses and queued cars.
	var right := Vector3(-forward.z,0,forward.x)
	var reach := 5.0+current_speed*1.5
	for side in [-0.65,0.0,0.65]:
		var origin: Vector3 = global_position+Vector3(0,0.8,0)+right*side
		var query := PhysicsRayQueryParameters3D.create(origin,origin+forward*reach,2|4,[get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var gap := origin.distance_to(hit.position)-3.8
			desired=minf(desired,maxf(gap,0.0)*0.7)
	current_speed=move_toward(current_speed,desired,(2.2 if desired>current_speed else 6.0)*delta)
	velocity.x=forward.x*current_speed
	velocity.z=forward.z*current_speed
	velocity.y=-0.5 if is_on_floor() else velocity.y-18*delta
	move_and_slide()
	for wheel in _wheels:
		wheel.rotate_object_local(Vector3.UP,-get_real_velocity().length()*delta/0.32)
