extends SceneTree

func _init() -> void:
	var world := Node3D.new()
	WorldBuilder._register_road_surface(world, Vector3.ZERO, Vector3(0, 0, 100), 12.0, 6.0)
	WorldBuilder._register_road_surface(world, Vector3(0, 0, 50), Vector3(100, 0, 50), 6.2, 4.0)
	var surfaces: Array = world.get_meta("road_surfaces")
	assert(WorldBuilder.is_road_surface(Vector3(0, 2, 20), surfaces))
	assert(WorldBuilder.is_road_surface(Vector3(5.9, 0, -5.9), surfaces))
	assert(WorldBuilder.is_road_surface(Vector3(70, 0, 50), surfaces))
	assert(not WorldBuilder.is_road_surface(Vector3(70, 0, 54), surfaces))
	assert(not WorldBuilder.is_road_surface(Vector3(9, 0, 20), surfaces))
	assert(not WorldBuilder.is_road_surface(Vector3(0, 0, 107), surfaces))
	world.free()
	print("Road surface geometry: PASS")
	quit()
