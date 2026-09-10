extends RefCounted
class_name BusVisual
## Original mesh-built GAZelle 3221 / PAZ 3205 silhouettes. Front is -Z.
## All views (player, rival, garage) use this same visual, without physics.
static func material(color: Color, metallic: float = 0.0, roughness: float = 0.68) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat

static func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, part_name: String = "") -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	if not part_name.is_empty():
		node.name = part_name
	parent.add_child(node)
	return node

static func label(parent: Node3D, text: String, pos: Vector3, angle: float, scale_px: float = 0.004) -> void:
	var node := Label3D.new()
	node.text = text
	node.position = pos
	node.rotation.y = angle
	node.font_size = 48
	node.pixel_size = scale_px
	node.modulate = Color("252a29")
	node.outline_size = 0
	parent.add_child(node)

static func build(parent: Node3D, d: VehicleDefinition) -> Dictionary:
	var paz := d.modern
	var w := d.width
	var h := d.height
	var l := d.length
	var paint := ShaderMaterial.new()
	paint.shader=preload("res://assets/materials/coachwork.gdshader")
	paint.set_shader_parameter("paint",d.body_color)
	var cream := material(d.body_color.lightened(0.12), 0.1)
	# Was a flat roughness=0.68 across the board regardless of metallic, so
	# "chrome" (high metallic) still looked like dull grey plastic instead of
	# shiny metal, and "glass" (metallic on top of that) looked like tinted
	# plastic instead of glazing. Roughness now actually varies per material:
	# chrome reads as shiny metal, glass as smooth and reflective but
	# non-metallic, rubber stays flat matte, trim a semi-gloss plastic.
	var dark := material(Color("252c2e"), 0.0, 0.55)
	var glass := material(Color("36535f"), 0.0, 0.12)
	var trim := material(d.accent_color, 0.0, 0.5)
	var chrome := material(Color("9babad"), 0.85, 0.22)
	var rubber := material(Color("171c20"), 0.0, 0.92)
	var front := -l/2.0
	var rear := l/2.0
	# Rounded cross sections with a narrower roof; avoids a scaled generic van.
	var cabin_front := front + (0.13 if paz else 0.95)
	var roof_front := cabin_front + (0.15 if paz else 0.5)
	_shell(parent, w, h, cabin_front, roof_front, rear, paint)
	box(parent, Vector3(0,0.63,0), Vector3(w*0.94,0.32,l*0.93), dark, "Chassis")
	if not paz:
		var hood := box(parent, Vector3(0,1.05,front+0.52), Vector3(w*0.94,0.64,1.02), paint, "GazelleHood")
		hood.rotation.x = -0.10
	# Sill stripe, roof gutter and separated side windows.
	var window_y := h*0.68
	var window_h := h*0.29
	var count := 6 if paz else 4
	var span := rear-cabin_front-0.40
	var spacing := span/float(count)
	for side in [-1.0,1.0]:
		box(parent,Vector3(side*(w/2.0+0.006),h*0.46,(cabin_front+rear)/2.0),Vector3(0.025,0.17,span+0.2),trim)
		box(parent,Vector3(side*w*0.474,h*0.94,(roof_front+rear)/2.0),Vector3(0.045,0.045,rear-roof_front),chrome)
		for i in range(count):
			var z := cabin_front+0.22+spacing*(i+0.5)
			box(parent,Vector3(side*(w*0.49+0.012),window_y,z),Vector3(0.045,window_h+0.08,spacing*0.87),dark)
			box(parent,Vector3(side*(w*0.49+0.037),window_y,z),Vector3(0.01,window_h,spacing*0.80),glass)
			box(parent,Vector3(side*(w*0.49+0.044),window_y+window_h*0.23,z),Vector3(0.012,0.026,spacing*0.80),chrome)
			if i>0:
				box(parent,Vector3(side*(w*0.49+0.045),window_y,z+spacing*0.30),Vector3(0.014,window_h*0.92,0.10),material(Color("ac9a77")))
		# Mirrors on stems at the cab, wheel arches and hubcaps.
		box(parent,Vector3(side*(w/2.0+0.17),window_y,cabin_front+0.1),Vector3(0.36,0.045,0.055),dark)
		box(parent,Vector3(side*(w/2.0+0.33),window_y,cabin_front+0.1),Vector3(0.11,0.3,0.19),dark,"Mirror")
	# Raked front glass, separate rear glass, bumper and grille.
	var wind := box(parent,Vector3(0,window_y,cabin_front+(roof_front-cabin_front)*0.61-0.045),Vector3(w*0.88,window_h,0.045),glass,"Windscreen")
	wind.rotation.x = atan((roof_front-cabin_front)*0.85/(h*0.84-0.64))
	box(parent,Vector3(0,window_y,rear+0.012),Vector3(w*0.80,window_h*0.83,0.04),glass)
	for z in [front-0.02,rear+0.04]:
		box(parent,Vector3(0,0.63,z),Vector3(w*0.99,0.20,0.16),dark,"Bumper")
	box(parent,Vector3(0,1.02,front-0.045),Vector3(w*0.45,0.32,0.035),dark)
	for i in range(4):
		box(parent,Vector3(0,0.91+i*0.07,front-0.07),Vector3(w*0.43,0.024,0.02),chrome)
	if not paz:
		for side in [-1.0,1.0]:
			box(parent,Vector3(side*w*0.35,1.06,front-0.07),Vector3(0.38,0.19,0.04),material(Color("f3ead0")))
	if paz:
		for side in [-1.0,1.0]:
			var lamp := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius=0.15
			cylinder.bottom_radius=0.15
			cylinder.height=0.06
			lamp.mesh=cylinder
			lamp.rotation.x=PI/2.0
			lamp.position=Vector3(side*w*0.34,1.07,front-0.04)
			lamp.material_override=material(Color("fff1ca"))
			parent.add_child(lamp)
	# Route cards face forward and backward and remain legible at close range.
	for z in [roof_front-0.12,rear+0.05]:
		var angle := PI if z<0 else 0.0
		box(parent,Vector3(0,h*0.88,z),Vector3(w*0.67,0.29,0.025),material(Color("efe9c9")))
		label(parent,"47  ВОКЗАЛ",Vector3(0,h*0.88,z+(-0.02 if z<0 else 0.02)),angle,0.0026)
	box(parent,Vector3(0,0.65,rear+0.14),Vector3(0.62,0.15,0.025),cream)
	label(parent,"М 047 РТ",Vector3(0,0.65,rear+0.16),0.0,0.0014)
	# Door panel pivots for PAZ and slides for GAZelle.
	var door := Node3D.new()
	door.name="PassengerDoor"
	var door_z := cabin_front+0.65 if paz else 0.1
	door.position=Vector3(w/2.0+0.05,0,door_z)
	parent.add_child(door)
	box(door,Vector3(0,h*0.47,0),Vector3(0.05,h*0.66,0.82),trim)
	box(door,Vector3(0.03,window_y,0),Vector3(0.025,window_h*0.83,0.65),glass)
	box(door,Vector3(0.05,h*0.40,0.25),Vector3(0.04,0.035,0.16),chrome)
	var wheels: Array[MeshInstance3D]=[]
	var radius := 0.48 if paz else 0.37
	for side in [-1.0,1.0]:
		for z in [-l*0.31,l*0.30]:
			var wheel:=MeshInstance3D.new()
			var mesh:=CylinderMesh.new()
			mesh.top_radius=radius
			mesh.bottom_radius=radius
			mesh.height=0.25
			mesh.radial_segments=16
			wheel.mesh=mesh
			wheel.position=Vector3(side*w*0.49,radius,z)
			wheel.rotation.z=PI/2.0
			wheel.material_override=rubber
			parent.add_child(wheel)
			wheels.append(wheel)
			var hub:=MeshInstance3D.new()
			var hub_mesh:=CylinderMesh.new()
			hub_mesh.top_radius=radius*0.53
			hub_mesh.bottom_radius=radius*0.53
			hub_mesh.height=0.27
			hub_mesh.radial_segments=12
			hub.mesh=hub_mesh
			hub.material_override=chrome
			wheel.add_child(hub)
	# Door outlines, wipers, fuel flap, rear seams and roof vents.
	for side in [-1.0,1.0]:
		box(parent,Vector3(side*(w/2.0+0.016),0.90,rear-0.65),Vector3(0.025,0.25,0.3),trim)
		box(parent,Vector3(side*(w/2.0+0.025),1.12,cabin_front+0.70),Vector3(0.04,0.035,0.2),dark)
		box(parent,Vector3(side*(w/2.0+0.01),1.0,cabin_front+0.87),Vector3(0.02,0.65,0.015),dark)
		box(parent,Vector3(side*w*0.34,0.63,rear-0.9),Vector3(0.35,0.25,0.06),rubber)
		var wiper:=box(parent,Vector3(side*w*0.21,window_y-window_h*0.26,cabin_front+(roof_front-cabin_front)*0.61-0.09),Vector3(w*0.30,0.028,0.03),dark)
		wiper.rotation.z=0.16
		box(parent,Vector3(side*w*0.40,1.15,rear+0.045),Vector3(0.18,0.23,0.035),material(Color("9a2b20")))
		box(parent,Vector3(side*w*0.40,1.31,rear+0.045),Vector3(0.18,0.08,0.035),material(Color("dc963a")))
	if paz:
		for z in [-0.7,1.25]:
			box(parent,Vector3(0,h+0.015,z),Vector3(0.8,0.055,0.75),cream)
		box(parent,Vector3(0,window_y,cabin_front+(roof_front-cabin_front)*0.61-0.075),Vector3(0.055,window_h,0.03),dark)
	else:
		box(parent,Vector3(0,1.12,rear+0.035),Vector3(0.018,0.8,0.015),dark)
	box(parent,Vector3(0,0.67,front-0.12),Vector3(0.61,0.14,0.025),cream)
	label(parent,"М 047 РТ",Vector3(0,0.67,front-0.14),PI,0.0014)
	return {"wheels":wheels,"door":door,"door_origin":door.position}

static func _shell(parent: Node3D,w: float,h: float,front: float,roof_front: float,rear: float,mat: Material) -> void:
	# Chamfered roof shoulders and sloped cab, authored as indexed triangles.
	var points: Array[Vector3]=[]
	for z in [front,rear]:
		var roof_z := roof_front if z==front else rear-0.08
		points.append_array([Vector3(-w/2.0,0.64,z),Vector3(w/2.0,0.64,z),Vector3(w/2.0,h*0.84,z+(roof_front-front)*0.85 if z==front else z),Vector3(w*0.44,h,roof_z),Vector3(-w*0.44,h,roof_z),Vector3(-w/2.0,h*0.84,z+(roof_front-front)*0.85 if z==front else z)])
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(6):
		var j: int=(i+1)%6
		for index in [i,j,j+6,i,j+6,i+6]:
			st.add_vertex(points[index])
	for i in range(1,5):
		for index in [0,i+1,i,6,6+i,6+i+1]:
			st.add_vertex(points[index])
	st.generate_normals()
	var body:=MeshInstance3D.new()
	body.name="Coachwork"
	body.mesh=st.commit()
	# Authored shell is visible from either winding; windows sit on its exterior.
	body.material_override=mat
	parent.add_child(body)
