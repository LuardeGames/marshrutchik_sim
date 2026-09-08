extends CharacterBody3D
class_name TrafficDummy
## Simple oncoming cars follow their own lane around the whole road network.
@export var start_index: int = 0
@export var speed: float = 7.0
var _points: Array[Vector3] = []
var _index := 0
var _wheels: Array[MeshInstance3D] = []

func _ready() -> void:
	collision_layer=4
	collision_mask=1|2|4
	var road:=RouteDefinition.waypoints()
	road.reverse()
	for i in range(road.size()):
		var incoming:=(road[i]-road[(i-1+road.size())%road.size()]).normalized()
		var outgoing:=(road[(i+1)%road.size()]-road[i]).normalized()
		var offset:=Vector3(-incoming.z-outgoing.z,0,incoming.x+outgoing.x)*2.5
		_points.append(road[i]+offset)
	_index=start_index%_points.size()
	position=_points[_index]+Vector3(0,0.3,0)
	_index=(_index+1)%_points.size()
	var palette:=[Color("c9c7b7"),Color("5b756d"),Color("8b4032"),Color("596574")]
	var paint:=BusVisual.material(palette[start_index%palette.size()],0.2)
	var dark:=BusVisual.material(Color("24282a"))
	var glass:=BusVisual.material(Color("354b53"),0.25)
	BusVisual.box(self,Vector3(0,0.70,0),Vector3(1.75,0.65,4.0),paint)
	BusVisual.box(self,Vector3(0,1.19,0.15),Vector3(1.55,0.65,2.0),paint)
	for side in [-1.0,1.0]:
		BusVisual.box(self,Vector3(side*0.783,1.25,0.15),Vector3(0.025,0.40,1.7),glass)
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
	BusVisual.box(self,Vector3(0,1.25,-0.87),Vector3(1.35,0.4,0.03),glass)
	BusVisual.box(self,Vector3(0,1.25,1.17),Vector3(1.35,0.4,0.03),glass)
	for z in [-2.03,2.03]:
		BusVisual.box(self,Vector3(0,0.5,z),Vector3(1.75,0.16,0.1),dark)
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(1.8,1.5,4.1)
	shape.shape=box
	shape.position.y=0.62
	add_child(shape)

func _physics_process(delta: float) -> void:
	if _points.is_empty() or not GameManager.trip_running:
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
	velocity.x=forward.x*speed
	velocity.z=forward.z*speed
	velocity.y=-0.5 if is_on_floor() else velocity.y-18*delta
	move_and_slide()
	for wheel in _wheels:
		wheel.rotate_object_local(Vector3.UP,-get_real_velocity().length()*delta/0.32)
