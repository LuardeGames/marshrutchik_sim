extends RefCounted
class_name WorldBuilder
## Procedurally assembles the whole map from primitives: ground, road,
## curbs, district buildings, props and MultiMesh-instanced trees.
## Nothing here needs an external 3D asset.

const ROAD_WIDTH := RouteDefinition.ROAD_WIDTH
const MAP_MARGIN := 120.0

static func build(parent: Node3D) -> Dictionary:
	var waypoints := RouteDefinition.waypoints()
	var stop_defs := RouteDefinition.stops()

	_build_environment(parent)
	_build_ground(parent, waypoints)
	_build_road(parent, waypoints)
	_build_traffic_lights(parent, waypoints)
	_build_traffic_dummies(parent, waypoints)

	var stops: Array[StopArea] = []
	var stop_by_waypoint: Dictionary = {}
	for def in stop_defs:
		var wp_index: int = def.waypoint_index
		var stop := StopArea.new()
		parent.add_child(stop)
		var pos: Vector3 = waypoints[wp_index]
		var perp := _perp_at(waypoints, wp_index)
		stop.position = RouteDefinition.stop_position(wp_index)
		stop.look_at(stop.position + RouteDefinition.stop_forward(wp_index), Vector3.UP)
		stop.setup(def.id, def.name, def.required, wp_index)
		stops.append(stop)
		stop_by_waypoint[wp_index] = def.id

	_build_districts(parent, waypoints, stop_defs)
	_build_trees(parent, waypoints)
	CityDressing.build(parent, waypoints)

	return {
		"stops": stops,
		"waypoints": waypoints,
		"stop_by_waypoint": stop_by_waypoint,
		"spawn_position": waypoints[0] + Vector3(2.5, 0, -14),
		"spawn_forward_waypoint": waypoints[1],
	}

static func _perp_at(waypoints: Array[Vector3], index: int) -> Vector3:
	var prev: Vector3 = waypoints[(index - 1 + waypoints.size()) % waypoints.size()]
	var next: Vector3 = waypoints[(index + 1) % waypoints.size()]
	var dir: Vector3 = (next - prev)
	dir.y = 0
	if dir.length() < 0.01:
		dir = Vector3(0, 0, 1)
	dir = dir.normalized()
	return Vector3(-dir.z, 0, dir.x)

static func _build_environment(parent: Node3D) -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.35, 0.55, 0.85)
	sky_mat.sky_horizon_color = Color(0.75, 0.82, 0.85)
	sky_mat.ground_bottom_color = Color(0.3, 0.3, 0.3)
	sky_mat.ground_horizon_color = Color(0.75, 0.82, 0.85)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b2bdc9")
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color(0.75, 0.8, 0.82)
	env.fog_density = 0.0035
	env.fog_aerial_perspective = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.90
	env.ssao_enabled = false
	env.ssao_radius = 2.0
	env.ssao_intensity = 1.4
	env.glow_enabled = false
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.02
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.92
	env_node.environment = env
	parent.add_child(env_node)

	# Lower, warmer sun angle for long shadows that actually read as shadows
	# (the previous near-overhead angle left the ground almost flat/shadowless).
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -50, 0)
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.directional_shadow_max_distance = 220.0
	sun.light_color = Color(1.0, 0.95, 0.85)
	parent.add_child(sun)

	# Cool, dim fill light from the opposite side so shadow-side faces of
	# buildings aren't pure black - cheap and very cheap on a single mesh pass.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 130, 0)
	fill.light_energy = 0.16
	fill.light_color = Color(0.7, 0.8, 1.0)
	fill.shadow_enabled = false
	parent.add_child(fill)

static func _bounds(waypoints: Array[Vector3]) -> Rect2:
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for p in waypoints:
		min_x = min(min_x, p.x)
		max_x = max(max_x, p.x)
		min_z = min(min_z, p.z)
		max_z = max(max_z, p.z)
	return Rect2(min_x - MAP_MARGIN, min_z - MAP_MARGIN, (max_x - min_x) + MAP_MARGIN * 2.0, (max_z - min_z) + MAP_MARGIN * 2.0)

static func _build_ground(parent: Node3D, waypoints: Array[Vector3]) -> void:
	var b := _bounds(waypoints)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.name = "GroundBody"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(b.size.x, 1.0, b.size.y)
	shape.shape = box
	shape.position = Vector3(b.position.x + b.size.x / 2.0, -0.5, b.position.y + b.size.y / 2.0)
	body.add_child(shape)

	var mesh_inst := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(b.size.x, 1.0, b.size.y)
	mesh_inst.mesh = plane
	mesh_inst.position = shape.position
	var mat := CityMaterials.surface("ground")
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)
	parent.add_child(body)

## Builds the whole road network (asphalt strips, lane dashes, curbs,
## sidewalks) as four MultiMeshInstance3D batches instead of one
## MeshInstance3D per piece. The naive version was ~260 separate draw calls
## just for road dressing (dashed lines alone were ~150, one box each) -
## everything here shares one unit BoxMesh per batch and gets its per-piece
## size/rotation/position baked into its MultiMesh instance transform, which
## collapses that down to 4 draw calls total. Matters a lot for a WebGL
## export where draw call count is usually the first thing to bite FPS.
static func _build_road(parent: Node3D, waypoints: Array[Vector3]) -> void:
	var road_root := Node3D.new()
	road_root.name = "Road"
	parent.add_child(road_root)
	var asphalt := CityMaterials.surface("asphalt")
	var curb_mat := CityMaterials.surface("concrete")
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color(0.85, 0.84, 0.76)
	var sidewalk_mat := CityMaterials.surface("paving")

	var road_entries: Array = []
	var dash_entries: Array = []
	var curb_entries: Array = []
	var sidewalk_entries: Array = []

	var n := waypoints.size()
	for i in range(n):
		var a: Vector3 = waypoints[i]
		var b: Vector3 = waypoints[(i + 1) % n]
		var mid := (a + b) / 2.0
		var length := a.distance_to(b) + ROAD_WIDTH
		var dir := (b - a).normalized()
		var angle := atan2(dir.x, dir.z)

		road_entries.append({"size": Vector3(ROAD_WIDTH, 0.12, length), "position": Vector3(mid.x, 0.06, mid.z), "y_rot": angle})

		# center dashed line
		var dash_count: int = max(2, int(length / 8.0))
		for d in range(dash_count):
			if d % 2 != 0:
				continue
			var t: float = float(d) / float(dash_count)
			var dash_pos: Vector3 = a.lerp(b, t)
			dash_entries.append({"size": Vector3(0.25, 0.02, 3.0), "position": Vector3(dash_pos.x, 0.13, dash_pos.z), "y_rot": angle})

		# curbs + sidewalks, both sides
		var perp := Vector3(-dir.z, 0, dir.x)
		var road_sides: Array[float] = [-1.0, 1.0]
		for side in road_sides:
			var curb_pos: Vector3 = mid + perp * side * (ROAD_WIDTH / 2.0 + 0.2)
			curb_pos.y = 0.11
			curb_entries.append({"size": Vector3(0.35, 0.22, maxf(1.0,a.distance_to(b)-ROAD_WIDTH)), "position": curb_pos, "y_rot": angle})

			var sidewalk_pos: Vector3 = mid + perp * side * (ROAD_WIDTH / 2.0 + 1.9)
			sidewalk_pos.y = 0.05
			sidewalk_entries.append({"size": Vector3(3.2, 0.1, maxf(1.0,a.distance_to(b)-ROAD_WIDTH)), "position": sidewalk_pos, "y_rot": angle})

	_multimesh_boxes(road_root, "RoadStrips", asphalt, road_entries)
	_multimesh_boxes(road_root, "LaneDashes", line_mat, dash_entries)
	_multimesh_boxes(road_root, "Curbs", curb_mat, curb_entries)
	_multimesh_boxes(road_root, "Sidewalks", sidewalk_mat, sidewalk_entries)

## Batches a list of {size, position, y_rot} box specs into a single
## MultiMeshInstance3D (one draw call) using a shared unit BoxMesh scaled
## per-instance via each entry's MultiMesh transform.
static func _multimesh_boxes(parent: Node3D, name: String, material: Material, entries: Array) -> void:
	if entries.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mm.mesh = mesh
	mm.instance_count = entries.size()
	for i in range(entries.size()):
		var e: Dictionary = entries[i]
		var basis := Basis.from_euler(Vector3(0, e.y_rot, 0)) * Basis.from_scale(e.size)
		mm.set_instance_transform(i, Transform3D(basis, e.position))
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = material
	inst.name = name
	parent.add_child(inst)

static func _build_traffic_lights(parent: Node3D, waypoints: Array[Vector3]) -> void:
	var corner_indices := [2, 7, 10]
	for idx in corner_indices:
		if idx >= waypoints.size():
			continue
		var light := TrafficLightProp.new()
		var perp := _perp_at(waypoints, idx)
		light.position = waypoints[idx] + perp * (ROAD_WIDTH / 2.0 + 1.0)
		parent.add_child(light)

static func _build_traffic_dummies(parent: Node3D, _waypoints: Array[Vector3]) -> void:
	for index in [2,5,8,11,14]:
		var car:=TrafficDummy.new()
		car.name="Oncoming_%d" % index
		car.start_index=index
		car.speed=6.0+float(index%3)
		parent.add_child(car)

# ---------------------------------------------------------------------------
# District dressing
# ---------------------------------------------------------------------------

static func _build_districts(parent: Node3D, waypoints: Array[Vector3], stop_defs: Array[Dictionary]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337

	for def in stop_defs:
		var wp_index: int = def.waypoint_index
		var forward := RouteDefinition.stop_forward(wp_index)
		var perp := Vector3(-forward.z,0,forward.x)
		var center := RouteDefinition.stop_position(wp_index)-perp*7.0
		match def.id:
			0: _build_residential(parent, center, perp, rng)
			1: _build_market(parent, center, perp, rng)
			2: _build_clinic(parent, center, perp, rng)
			3: _build_center(parent, center, perp, rng)
			4: _build_station(parent, center, perp, rng)
			5: _build_depot(parent, center, perp, rng)

	# generic filler buildings along the rest of the loop for a populated feel
	_build_filler(parent, waypoints, rng)

## Nudges a base color's value/saturation a little so repeated buildings
## from the same small palette don't look like identical copy-paste blocks.
static func _jitter(color: Color, rng: RandomNumberGenerator, amount: float = 0.06) -> Color:
	var d: float = rng.randf_range(-amount, amount)
	return Color(
		clamp(color.r + d, 0.0, 1.0),
		clamp(color.g + d, 0.0, 1.0),
		clamp(color.b + d, 0.0, 1.0),
		color.a
	)

static func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, collide: bool = true, y_rot: float = 0.0) -> Node3D:
	var root: Node3D
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)
		root = body
	else:
		root = Node3D.new()
	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_inst.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.9
	mat.albedo_color = color
	mesh_inst.material_override = mat
	root.add_child(mesh_inst)
	root.position = pos
	root.rotation.y = y_rot
	parent.add_child(root)
	return root

## Small real low-poly buildings (Kenney City Kit companion set, CC0) used
## for shops/kiosks/market stalls - not tall enough to stand in for the
## apartment blocks, which stay procedural boxes with window bands.
const SHOP_MODELS := [
	"res://assets/city/building-type-a.glb",
	"res://assets/city/building-type-b.glb",
	"res://assets/city/building-type-c.glb",
	"res://assets/city/building-type-d.glb",
	"res://assets/city/building-type-e.glb",
	"res://assets/city/building-type-f.glb",
	"res://assets/city/building-type-g.glb",
	"res://assets/city/building-type-h.glb",
]

## Instantiates a small building model, uniformly scaled to `target_width`
## (keeping its natural proportions), with a matching collision box, and
## returns the root node (position/rotation already applied).
static func _model_prop(parent: Node3D, model_path: String, pos: Vector3, target_width: float, y_rot: float = 0.0) -> Node3D:
	if not ResourceLoader.exists(model_path):
		return _box(parent, pos + Vector3(0, target_width * 0.4, 0), Vector3(target_width, target_width * 0.8, target_width), Color(0.6, 0.55, 0.5))
	var scene: PackedScene = load(model_path)
	var root := Node3D.new()
	parent.add_child(root)
	root.position = pos
	root.rotation.y = y_rot

	var inst: Node3D = scene.instantiate()
	root.add_child(inst)
	var raw_aabb = _collect_visual_aabb(inst, inst)
	if raw_aabb != null and raw_aabb.size.x > 0.01:
		var s: float = target_width / raw_aabb.size.x
		inst.scale = Vector3(s, s, s)
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = raw_aabb.size * s
		col.shape = shape
		col.position = (raw_aabb.position + raw_aabb.size / 2.0) * s
		body.add_child(col)
		root.add_child(body)
	return root

## Same AABB-merging trick used by the vehicle controller for its models -
## duplicated here since WorldBuilder and VehicleController don't share a
## common base class.
static func _collect_visual_aabb(node: Node, root_node: Node3D):
	var result = null
	if node is VisualInstance3D:
		var local_aabb: AABB = node.get_aabb()
		var rel_xform: Transform3D = root_node.global_transform.affine_inverse() * node.global_transform
		result = rel_xform * local_aabb
	for c in node.get_children():
		var child_aabb = _collect_visual_aabb(c, root_node)
		if child_aabb != null:
			result = child_aabb if result == null else result.merge(child_aabb)
	return result

static func _build_residential(parent: Node3D, center: Vector3, perp: Vector3, rng: RandomNumberGenerator) -> void:
	var colors := [Color(0.75, 0.72, 0.68), Color(0.68, 0.7, 0.75), Color(0.72, 0.65, 0.6)]
	var tangent := Vector3(perp.z, 0, -perp.x)
	for i in range(3):
		# jitter only along the road direction (tangent), never toward/away
		# from it, so buildings can never randomly drift back onto the road
		var offset := perp * (22.0 + i * 16.0) + tangent * rng.randf_range(-10.0, 10.0)
		var floors := rng.randi_range(5, 9)
		var height := floors * 3.0
		var b := _box(parent, center + offset, Vector3(14.0, height, 12.0), _jitter(colors[i % colors.size()], rng))
		b.position.y = height / 2.0
		_add_window_band(b, Vector3(14.0, height, 12.0))

static func _build_market(parent: Node3D, center: Vector3, perp: Vector3, rng: RandomNumberGenerator) -> void:
	var stall_colors := [Color(0.9, 0.3, 0.2), Color(0.2, 0.6, 0.3), Color(0.9, 0.75, 0.15), Color(0.25, 0.45, 0.8)]
	var tangent := Vector3(perp.z, 0, -perp.x)
	for i in range(5):
		var offset := perp * (16.0 + rng.randf_range(0, 6)) + tangent * (i - 2) * 5.5
		var b := _box(parent, center + offset, Vector3(3.5, 2.4, 3.0), stall_colors[i % stall_colors.size()])
		b.position.y = 1.2
		var roof := _box(parent, center + offset + Vector3(0, 2.5, 0), Vector3(4.0, 0.15, 3.4), Color(0.95, 0.95, 0.95), false)

	# row of small real shopfronts behind the market stalls
	for i in range(3):
		var shop_offset := perp * 28.0 + tangent * (i - 1) * 10.0
		var model: String = SHOP_MODELS[rng.randi() % SHOP_MODELS.size()]
		var face_road_angle: float = atan2(-perp.x, -perp.z)
		_model_prop(parent, model, center + shop_offset, rng.randf_range(5.0, 6.0), face_road_angle)

static func _build_clinic(parent: Node3D, center: Vector3, perp: Vector3, rng: RandomNumberGenerator) -> void:
	var offset := perp * 20.0
	var b := _box(parent, center + offset + Vector3(0, 9, 0), Vector3(18.0, 18.0, 14.0), Color(0.9, 0.92, 0.88))
	_add_window_band(b, Vector3(18.0, 18.0, 14.0))
	var sign := _box(parent, center + offset + Vector3(0, 4.2, -7.2), Vector3(3.0, 3.0, 0.2), Color(0.9, 0.2, 0.2), false)

static func _build_center(parent: Node3D, center: Vector3, perp: Vector3, rng: RandomNumberGenerator) -> void:
	var b := _box(parent, center + perp * 22.0 + Vector3(0, 14, 0), Vector3(16.0, 28.0, 16.0), Color(0.55, 0.6, 0.65))
	_add_window_band(b, Vector3(16.0, 28.0, 16.0))
	# billboard
	var board := _box(parent, center - perp * 16.0 + Vector3(0, 6, 0), Vector3(8.0, 4.0, 0.3), Color(0.95, 0.8, 0.1), false)
	var legs := _box(parent, center - perp * 16.0 + Vector3(0, 2.0, 0), Vector3(0.4, 4.0, 0.4), Color(0.3, 0.3, 0.3), false)

static func _build_station(parent: Node3D, center: Vector3, perp: Vector3, rng: RandomNumberGenerator) -> void:
	var b := _box(parent, center + perp * 24.0 + Vector3(0, 7, 0), Vector3(26.0, 14.0, 12.0), Color(0.8, 0.75, 0.55))
	_add_window_band(b, Vector3(26.0, 14.0, 12.0))
	var tower := _box(parent, center + perp * 24.0 + Vector3(0, 17, -4), Vector3(4.0, 20.0, 4.0), Color(0.75, 0.68, 0.45))
	var spire := _box(parent, center + perp * 24.0 + Vector3(0, 28, -4), Vector3(1.0, 3.0, 1.0), Color(0.6, 0.55, 0.35), false)

static func _build_depot(parent: Node3D, center: Vector3, perp: Vector3, rng: RandomNumberGenerator) -> void:
	# tangent = road direction at this point, derived from perp so garages
	# line up parallel to the road instead of drifting back onto it.
	var tangent := Vector3(perp.z, 0, -perp.x)
	for i in range(3):
		var offset := perp * 22.0 + tangent * (i - 1) * 8.0
		_box(parent, center + offset + Vector3(0, 2.2, 0), Vector3(5.5, 4.4, 7.0), Color(0.4, 0.42, 0.4))
	_box(parent, center + perp * 22.0 + Vector3(0, 0.05, 0), Vector3(10.0, 0.05, 24.0), Color(0.3, 0.3, 0.3), false)

static func _add_window_band(building: Node3D, size: Vector3) -> void:
	for child in building.get_children():
		if child is MeshInstance3D:
			var old: StandardMaterial3D = child.material_override
			child.material_override = CityMaterials.facade(old.albedo_color)
	# Roof cap, entry canopy, balcony slabs give the facade real depth.
	_box(building, Vector3(0,size.y/2.0,0),Vector3(size.x+0.35,0.22,size.z+0.35),Color("77796f"),false)
	_box(building, Vector3(0,-size.y/2.0+1.1,-size.z/2.0-0.035),Vector3(1.3,2.2,0.09),Color("3f625c"),false)
	_box(building, Vector3(0,-size.y/2.0+2.5,-size.z/2.0-0.6),Vector3(2.4,0.16,1.4),Color("8c918b"),false)
	for floor_index in range(1,int(size.y/3.0)):
		_box(building,Vector3(size.x*0.25,-size.y/2.0+float(floor_index)*3.0,-size.z/2.0-0.45),Vector3(2.3,0.18,1.0),Color("aca796"),false)
		_box(building,Vector3(size.x*0.25,-size.y/2.0+float(floor_index)*3.0+0.52,-size.z/2.0-0.94),Vector3(2.3,0.9,0.10),Color("8b958b"),false)

## Fills the loop with a populated-feeling backdrop: a near row of full
## detail buildings (window bands) plus a second, cheaper back row (flat
## box, no extra mesh) for skyline depth, and roadside shops/kiosks.
## Segment spacing and spawn odds are tuned for "dense" while keeping the
## back row cheap (one draw call each) since this runs across the whole
## ~2.4km loop and total node/mesh count matters for web performance.
static func _build_filler(parent: Node3D, waypoints: Array[Vector3], rng: RandomNumberGenerator) -> void:
	var colors := [Color(0.7, 0.65, 0.6), Color(0.6, 0.62, 0.68), Color(0.68, 0.58, 0.5), Color(0.5, 0.55, 0.5)]
	var back_colors := [Color(0.62, 0.6, 0.58), Color(0.55, 0.58, 0.62), Color(0.6, 0.54, 0.5)]
	# Collected instead of built one-MeshInstance3D-at-a-time: with density
	# this high across the whole ~2.4km loop, that was 400+ draw calls on
	# its own. Bodies/back-row/windows each become a single MultiMesh batch
	# below; only a lightweight invisible collision box is still spawned
	# per near-building (buildings are the one thing you can actually drive
	# into, so they keep real collision - the back row and windows don't
	# need any).
	var front_entries: Array = []
	var back_entries: Array = []
	var n := waypoints.size()
	for i in range(n):
		var a: Vector3 = waypoints[i]
		var b: Vector3 = waypoints[(i + 1) % n]
		var segments := int(a.distance_to(b) / 26.0)
		var dir := (b - a).normalized()
		var perp := Vector3(-dir.z, 0, dir.x)
		for s in range(segments):
			var t: float = (s + 0.5) / float(max(segments, 1))
			var base_pos: Vector3 = a.lerp(b, t)
			var sides: Array[float] = [-1.0, 1.0]
			for side in sides:
				if rng.randf() > 0.8:
					continue
				var dist: float = rng.randf_range(19.0, 33.0)
				var pos: Vector3 = base_pos + perp * side * dist
				var height: float = float(rng.randi_range(3, 6)) * 3.0
				var w: float = rng.randf_range(8.0, 13.0)
				var d: float = rng.randf_range(8.0, 13.0)
				var size := Vector3(w, height, d)
				if not _clear_of_road(pos, size, waypoints):
					continue
				var center := pos + Vector3(0, height / 2.0, 0)
				front_entries.append({"size": size, "position": center, "y_rot": 0.0, "color": _jitter(colors[rng.randi() % colors.size()], rng)})
				_invisible_collider(parent, center, size)
				# second, cheaper row further back for a denser skyline
				if rng.randf() < 0.6:
					var back_dist: float = dist + rng.randf_range(14.0, 22.0)
					var back_pos: Vector3 = base_pos + perp * side * back_dist
					var back_height: float = float(rng.randi_range(5, 9)) * 3.0
					var back_w: float = rng.randf_range(9.0, 15.0)
					var back_d: float = rng.randf_range(9.0, 15.0)
					var back_size := Vector3(back_w, back_height, back_d)
					if not _clear_of_road(back_pos, back_size, waypoints):
						continue
					var back_center := back_pos + Vector3(0, back_height / 2.0, 0)
					back_entries.append({"size": back_size, "position": back_center, "y_rot": 0.0, "color": _jitter(back_colors[rng.randi() % back_colors.size()], rng, 0.04)})
					_invisible_collider(parent, back_center, back_size)
			# small shop/kiosk near the road on one side - real low-poly model
			if rng.randf() > 0.35:
				var kiosk_side: float = -1.0 if rng.randf() > 0.5 else 1.0
				var kiosk_pos: Vector3 = base_pos + perp * kiosk_side * 11.0
				if not _clear_of_road(kiosk_pos, Vector3(6,3,6), waypoints):
					continue
				var model: String = SHOP_MODELS[rng.randi() % SHOP_MODELS.size()]
				_model_prop(parent, model, kiosk_pos, rng.randf_range(4.0, 6.0), rng.randf() * TAU)

	var body_mat := CityMaterials.facade(Color.WHITE, true)
	_multimesh_colored_boxes(parent, "FillerFront", body_mat, front_entries)
	_multimesh_colored_boxes(parent, "FillerBack", body_mat, back_entries)
	var roofs: Array=[]
	var balconies: Array=[]
	var doors: Array=[]
	for e in front_entries:
		roofs.append({"size":Vector3(e.size.x+0.25,0.18,e.size.z+0.25),"position":e.position+Vector3(0,e.size.y/2.0,0),"y_rot":0.0})
		var front_z: float=e.position.z-e.size.z/2.0
		doors.append({"size":Vector3(1.2,2.1,0.05),"position":Vector3(e.position.x,1.05,front_z-0.03),"y_rot":0.0})
		roofs.append({"size":Vector3(2.1,0.14,1.5),"position":Vector3(e.position.x,2.4,front_z-0.7),"y_rot":0.0})
		var balcony_x: float=roundf((e.position.x+e.size.x*0.23-1.5)/3.0)*3.0+1.5
		for floor_index in range(1,int(e.size.y/3.0)):
			var y:=float(floor_index)*3.0+0.3
			balconies.append({"size":Vector3(2.2,0.14,0.95),"position":Vector3(balcony_x,y,front_z-0.45),"y_rot":0.0})
			balconies.append({"size":Vector3(2.2,0.82,0.08),"position":Vector3(balcony_x,y+0.45,front_z-0.89),"y_rot":0.0})
	_multimesh_boxes(parent,"RoofCapsAndCanopies",BusVisual.material(Color("697167")),roofs)
	_multimesh_boxes(parent,"BalconyPanels",BusVisual.material(Color("899184")),balconies)
	_multimesh_boxes(parent,"EntranceDoors",BusVisual.material(Color("3d5851")),doors)


## An invisible StaticBody3D collision box - used where a building's visual
## comes from a MultiMesh batch (which can't carry per-instance collision)
## but the box should still stop the player from driving through it.
static func _invisible_collider(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	body.position = pos
	parent.add_child(body)

## Same idea as _multimesh_boxes but with a per-instance vertex color
## (material must have vertex_color_use_as_albedo enabled) so a batch of
## boxes can still look like a palette of different buildings.
static func _multimesh_colored_boxes(parent: Node3D, name: String, material: Material, entries: Array) -> void:
	if entries.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mm.mesh = mesh
	mm.instance_count = entries.size()
	for i in range(entries.size()):
		var e: Dictionary = entries[i]
		var basis := Basis.from_euler(Vector3(0, e.y_rot, 0)) * Basis.from_scale(e.size)
		mm.set_instance_transform(i, Transform3D(basis, e.position))
		mm.set_instance_color(i, e.color.srgb_to_linear())
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = material
	inst.name = name
	parent.add_child(inst)

static func _build_trees(parent: Node3D, waypoints: Array[Vector3]) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18
	trunk_mesh.bottom_radius = 0.22
	trunk_mesh.height = 1.6
	multimesh.mesh = trunk_mesh

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var transforms: Array[Transform3D] = []
	var n := waypoints.size()
	for i in range(n):
		var a: Vector3 = waypoints[i]
		var b: Vector3 = waypoints[(i + 1) % n]
		var dir := (b - a).normalized()
		var perp := Vector3(-dir.z, 0, dir.x)
		var count := int(a.distance_to(b) / 14.0)
		for c in range(count):
			var t: float = float(c) / float(max(count, 1))
			var base_pos: Vector3 = a.lerp(b, t)
			var sides: Array[float] = [-1.0, 1.0]
			for side in sides:
				if rng.randf() > 0.45:
					continue
				var dist: float = rng.randf_range(7.0, 12.0)
				var pos: Vector3 = base_pos + perp * side * dist
				if _clear_of_road(pos, Vector3(1,1,1), waypoints):
					transforms.append(Transform3D(Basis(), pos + Vector3(0, 0.8, 0)))

	multimesh.instance_count = transforms.size()
	for i in range(transforms.size()):
		multimesh.set_instance_transform(i, transforms[i])

	var mm_inst := MultiMeshInstance3D.new()
	mm_inst.multimesh = multimesh
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.4, 0.28, 0.18)
	mm_inst.material_override = trunk_mat
	parent.add_child(mm_inst)

	# foliage as a second multimesh (spheres) on top of trunks
	var foliage_mm := MultiMesh.new()
	foliage_mm.transform_format = MultiMesh.TRANSFORM_3D
	var foliage_mesh := SphereMesh.new()
	foliage_mesh.radius = 1.6
	foliage_mesh.height = 3.8
	foliage_mesh.radial_segments = 8
	foliage_mesh.rings = 4
	foliage_mm.mesh = foliage_mesh
	foliage_mm.use_colors = true
	foliage_mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		var base: Transform3D = transforms[i]
		foliage_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(rng.randf_range(0.8,1.3),rng.randf_range(1.1,1.6),rng.randf_range(0.8,1.3))), base.origin + Vector3(0, 2.3, 0)))
		foliage_mm.set_instance_color(i, Color("546742").lerp(Color("879064"),rng.randf()).srgb_to_linear())
	var foliage_inst := MultiMeshInstance3D.new()
	foliage_inst.multimesh = foliage_mm
	var foliage_mat := StandardMaterial3D.new()
	foliage_mat.vertex_color_use_as_albedo = true
	foliage_mat.roughness = 1.0
	foliage_inst.material_override = foliage_mat
	parent.add_child(foliage_inst)

static func _clear_of_road(pos: Vector3, size: Vector3, waypoints: Array[Vector3]) -> bool:
	for def in RouteDefinition.stops():
		if pos.distance_to(RouteDefinition.stop_position(def.waypoint_index)) < 15.0 + Vector2(size.x,size.z).length()*0.5:
			return false
	var radius := Vector2(size.x,size.z).length()*0.5 + ROAD_WIDTH*0.5 + 0.7
	for i in range(waypoints.size()):
		var nearest := Geometry3D.get_closest_point_to_segment(pos,waypoints[i],waypoints[(i+1)%waypoints.size()])
		if pos.distance_to(nearest) < radius:
			return false
	return true
