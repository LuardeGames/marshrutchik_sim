extends RefCounted
class_name RoadSigns
## Code-native signs: clean silhouettes and readable labels at street scale.
static func build(parent: Node3D, points: Array[Vector3]) -> void:
	for i in range(points.size()):
		var dir := (points[(i+1)%points.size()]-points[i]).normalized()
		for reverse in [false,true]:
			var forward := -dir if reverse else dir
			var start := points[(i+1)%points.size()] if reverse else points[i]
			var right := Vector3(-forward.z,0,forward.x)
			_make(parent,start+forward*35.0+right*7.8,forward,"speed")
			_make(parent,start+forward*(points[i].distance_to(points[(i+1)%points.size()])-18.0)+right*7.8,forward,"crossing")

static func _disc(parent: Node3D, radius: float, color: Color, z: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=0.025
	mesh.radial_segments=32
	var node := MeshInstance3D.new()
	node.mesh=mesh
	node.material_override=BusVisual.material(color)
	node.rotation.x=PI/2
	node.position=Vector3(0,2.8,z)
	parent.add_child(node)

static func _make(parent: Node3D, pos: Vector3, forward: Vector3, kind: String) -> void:
	var root := Node3D.new()
	root.name="Sign_"+kind
	parent.add_child(root)
	root.position=pos
	root.look_at(pos+forward)
	BusVisual.box(root,Vector3(0,1.35,0),Vector3(0.065,2.7,0.065),BusVisual.material(Color("737b80")))
	if kind=="speed":
		_disc(root,0.48,Color("ad342d"),0)
		_disc(root,0.38,Color("e5e5dd"),0.025)
		var text := Label3D.new()
		text.text="40"
		text.font_size=96
		text.pixel_size=0.006
		text.modulate=Color("20282c")
		text.outline_size=0
		text.position=Vector3(0,2.8,0.05)
		root.add_child(text)
	else:
		BusVisual.box(root,Vector3(0,2.8,0),Vector3(0.95,0.95,0.045),BusVisual.material(Color("23588b")))
		var mesh := ImmediateMesh.new()
		var face := BusVisual.material(Color("ecece2"))
		face.cull_mode=BaseMaterial3D.CULL_DISABLED
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,face)
		for p in [Vector3(-0.39,2.46,0.03),Vector3(0.39,2.46,0.03),Vector3(0,3.17,0.03)]:
			mesh.surface_add_vertex(p)
		mesh.surface_end()
		var node := MeshInstance3D.new()
		node.mesh=mesh
		root.add_child(node)
		var dark := BusVisual.material(Color("25313a"))
		for x in [-0.24,-0.08,0.08,0.24]:
			BusVisual.box(root,Vector3(x,2.53,0.055),Vector3(0.08,0.045,0.01),dark)
		BusVisual.box(root,Vector3(0,2.79,0.055),Vector3(0.085,0.21,0.015),dark)
		BusVisual.box(root,Vector3(0,2.96,0.055),Vector3(0.10,0.10,0.015),dark)
		for side in [-1.0,1.0]:
			var limb := BusVisual.box(root,Vector3(side*0.065,2.65,0.055),Vector3(0.05,0.19,0.015),dark)
			limb.rotation.z=side*-0.5
