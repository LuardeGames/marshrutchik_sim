extends Node3D
class_name AmbientPedestrian
## Cheap looping sidewalk pedestrians. They are scenery, but their movement
## gives the districts a readable sense of scale and life.

var start_point := Vector3.ZERO
var end_point := Vector3.ZERO
var walk_speed := 1.1
var variant := 0
var _progress := 0.0
var _body: Node3D

func _ready() -> void:
	_build()

func _process(delta: float) -> void:
	var length := start_point.distance_to(end_point)
	if length < 0.1:
		return
	_progress = fposmod(_progress + delta * walk_speed / length, 1.0)
	global_position = start_point.lerp(end_point, _progress)
	var direction := (end_point - start_point).normalized()
	if direction.length() > 0.1:
		look_at(global_position + direction, Vector3.UP)
	if _body:
		_body.position.y = 0.05 + sin(Time.get_ticks_msec() * 0.008 + variant) * 0.04

func _build() -> void:
	_body = Node3D.new()
	add_child(_body)
	var palette := [Color("405c70"), Color("8b5147"), Color("5c7355"), Color("b17d47")]
	var clothes := BusVisual.material(palette[variant % palette.size()])
	var skin := BusVisual.material(Color("c58d68"))
	BusVisual.box(_body, Vector3(0, 0.72, 0), Vector3(0.34, 0.72, 0.22), clothes)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.16
	head_mesh.height = 0.32
	head.mesh = head_mesh
	head.position = Vector3(0, 1.22, 0)
	head.material_override = skin
	_body.add_child(head)
	for side in [-1.0, 1.0]:
		BusVisual.box(_body, Vector3(side * 0.12, 0.30, 0), Vector3(0.09, 0.52, 0.10), clothes)
