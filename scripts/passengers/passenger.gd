extends Node3D
class_name Passenger
## Lightweight visual-only NPC. No navmesh: it walks in a straight line
## between two points and reports back via signal when it arrives.

signal arrived

var archetype: PassengerArchetype
var destination_stop_id: int = -1
var fare: int = 0
var mood: String = "neutral" # neutral, happy, annoyed, tired
var walk_speed: float = 1.6

var _target: Vector3
var _walking: bool = false
var _legs: Array[Node3D] = []
var _walk_phase := 0.0

func setup(a: PassengerArchetype) -> void:
	archetype = a
	fare = a.base_fare + randi_range(-a.fare_variance, a.fare_variance)
	_build_visual()

func walk_to(target_pos: Vector3, speed: float = 1.6) -> void:
	_target = target_pos
	walk_speed = speed
	_walking = true
	var dir := (target_pos - global_position)
	dir.y = 0
	if dir.length() > 0.01:
		look_at(global_position + dir, Vector3.UP)

func _process(delta: float) -> void:
	if not _walking:
		for leg in _legs:
			leg.rotation.x = 0.0
		return
	_walk_phase += delta * walk_speed * 5.0
	for i in range(_legs.size()):
		_legs[i].rotation.x = sin(_walk_phase + float(i)*PI)*0.35
	var to_target := _target - global_position
	to_target.y = 0
	if to_target.length() < 0.15:
		_walking = false
		global_position.x = _target.x
		global_position.z = _target.z
		arrived.emit()
		return
	var step := to_target.normalized() * walk_speed * delta
	if step.length() > to_target.length():
		step = to_target
	global_position += step
	# subtle bob while walking
	rotation.y = lerp_angle(rotation.y, atan2(-to_target.x, -to_target.z), 8.0 * delta)

func is_walking() -> bool:
	return _walking

func react_to_jolt() -> void:
	# small comedic reaction to harsh braking/turns - visual bump
	var tw := create_tween()
	tw.tween_property(self, "rotation:z", 0.25, 0.08)
	tw.tween_property(self, "rotation:z", 0.0, 0.25)

func _build_visual() -> void:
	var color: Color = archetype.color if archetype else Color.WHITE
	var coat := BusVisual.material(color)
	var trousers := BusVisual.material(Color("343c45"))
	var skin := BusVisual.material(Color("d8b28e"))
	BusVisual.box(self,Vector3(0,1.05,0),Vector3(0.47,0.64,0.29),coat)
	for side in [-1.0,1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side*0.13,0.74,0)
		add_child(leg)
		_legs.append(leg)
		BusVisual.box(leg,Vector3(0,-0.33,0),Vector3(0.17,0.64,0.19),trousers)
		BusVisual.box(leg,Vector3(0,-0.68,-0.07),Vector3(0.19,0.12,0.33),BusVisual.material(Color("23262a")))
		BusVisual.box(self,Vector3(side*0.31,0.96,0),Vector3(0.14,0.59,0.19),coat)
		BusVisual.box(self,Vector3(side*0.31,0.65,0),Vector3(0.12,0.13,0.14),skin)
	var head := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius=0.19
	mesh.height=0.40
	mesh.radial_segments=12
	mesh.rings=6
	head.mesh=mesh
	head.position=Vector3(0,1.55,0)
	head.material_override=skin
	add_child(head)
	BusVisual.box(self,Vector3(0,1.70,0.025),Vector3(0.35,0.12,0.30),BusVisual.material(Color("67584c")))
	BusVisual.box(self,Vector3(0.36,0.45,0),Vector3(0.28,0.35,0.20),BusVisual.material(Color("8a7c59")))
