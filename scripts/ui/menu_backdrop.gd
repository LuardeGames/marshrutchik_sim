extends SubViewportContainer
class_name MenuBackdrop
## Small in-engine diorama; actual vehicles and building materials, no mockup.
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stretch=true
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(1280,720)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	add_child(viewport)
	var world:=Node3D.new()
	viewport.add_child(world)
	WorldBuilder._build_environment(world)
	BusVisual.box(world,Vector3(0,-0.08,0),Vector3(90,0.1,90),CityMaterials.surface("ground"))
	BusVisual.box(world,Vector3(0,0,0),Vector3(70,0.1,11),CityMaterials.surface("asphalt"))
	BusVisual.box(world,Vector3(0,0.10,7),Vector3(70,0.15,3),CityMaterials.surface("paving"))
	for i in range(-6,7):
		BusVisual.box(world,Vector3(i*5,0.06,0),Vector3(2.4,0.01,0.12),BusVisual.material(Color("d1cec1")))
	for i in range(4):
		var height:=15.0+float(i%2)*9.0
		var building:=WorldBuilder._box(world,Vector3(float(i)*15.0-24.0,height/2.0,19),Vector3(12,height,12),Color("b7b09d"),false)
		WorldBuilder._add_window_band(building,Vector3(12,height,12))
	var buses:=VehicleCatalog.build()
	for i in range(buses.size()):
		var bus:=Node3D.new()
		bus.position=Vector3(float(i)*6.0-5.0,0.1,1.0)
		bus.rotation.y=-0.4
		world.add_child(bus)
		BusVisual.build(bus,buses[i])
	var camera:=Camera3D.new()
	world.add_child(camera)
	camera.position=Vector3(16,6.5,-14)
	camera.look_at(Vector3(2,2.0,2))
	camera.fov=55
	camera.current=true
