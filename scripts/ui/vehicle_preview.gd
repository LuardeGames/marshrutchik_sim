extends SubViewportContainer
class_name VehiclePreview
## Actual game model in the garage: a static viewport, rendered once.
func setup(definition: VehicleDefinition) -> void:
	custom_minimum_size = Vector2(230,120)
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.size = Vector2i(460,240)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	BusVisual.build(world,definition)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-35,0)
	light.light_energy = 1.5
	world.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("a3b7c5")
	environment.environment.ambient_light_energy = 0.7
	world.add_child(environment)
	var camera := Camera3D.new()
	camera.position = Vector3(7,4.2,-8)
	world.add_child(camera)
	camera.look_at(Vector3(0,definition.height*0.48,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.5
	camera.current = true
