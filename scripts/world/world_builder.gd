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
		stop.position = pos + perp * (ROAD_WIDTH / 2.0 + 3.5)
		stop.look_at(pos, Vector3.UP)
		stop.setup(def.id, def.name, def.required, wp_index)
		stops.append(stop)
		stop_by_waypoint[wp_index] = def.id

	_build_districts(parent, waypoints, stop_defs)
	_build_trees(parent, waypoints)

	return {
		"stops": stops,
		"waypoints": waypoints,
		"stop_by_waypoint": stop_by_waypoint,
		"spawn_position": waypoints[0] + _perp_at(waypoints, 0) * -8.0,
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
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.fog_enabled = true
	env.fog_light_color = Color(0.75, 0.8, 0.82)
	env.fog_density = 0.0035
	env.fog_aerial_perspective = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.ssao_enabled = true
	env.ssao_radius = 2.0
	env.ssao_intensity = 1.4
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.02
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12
	env_node.environment = env
	parent.add_child(env_node)

	# Lower, warmer sun angle for long shadows that actually read as shadows
	# (the previous near-overhead angle left the ground almost flat/shadowless).
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -50, 0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.directional_shadow_max_distance = 220.0
	sun.light_color = Color(1.0, 0.95, 0.85)
	parent.add_child(sun)

	# Cool, dim fill light from the opposite side so shadow-side faces of
	# buildings aren't pure black - cheap and very cheap on a single mesh pass.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 130, 0)
	fill.light_energy = 0.35
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
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.5, 0.28)
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)
	parent.add_child(body)

static func _build_road(parent: Node3D, waypoints: Array[Vector3]) -> void:
	var road_root := Node3D.new()
	road_root.name = "Road"
	parent.add_child(road_root)
	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_color = Color(0.16, 0.16, 0.17)
	asphalt.roughness = 0.85
	var curb_mat := StandardMaterial3D.new()
	curb_mat.albedo_color = Color(0.82, 0.82, 0.78)
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color(0.9, 0.85, 0.2)
	var sidewalk_mat := StandardMaterial3D.new()
	sidewalk_mat.albedo_color = Color(0.68, 0.66, 0.62)
	sidewalk_mat.roughness = 0.95

	var n := waypoints.size()
	for i in range(n):
		var a: Vector3 = waypoints[i]
		var b: Vector3 = waypoints[(i + 1) % n]
		var mid := (a + b) / 2.0
		var length := a.distance_to(b) + ROAD_WIDTH
		var dir := (b - a).normalized()
		var angle := atan2(dir.x, dir.z)

		var seg := MeshInstance3D.new()
		var seg_mesh := BoxMesh.new()
		seg_mesh.size = Vector3(ROAD_WIDTH, 0.12, length)
		seg.mesh = seg_mesh
		seg.material_override = asphalt
		seg.position = Vector3(mid.x, 0.06, mid.z)
		seg.rotation.y = angle
		road_root.add_child(seg)

		# center dashed line (few short boxes)
		var dash_count: int = max(2, int(length / 8.0))
		for d in range(dash_count):
			if d % 2 != 0:
				continue
			var t: float = float(d) / float(dash_count)
			var dash_pos: Vector3 = a.lerp(b, t)
			var dash := MeshInstance3D.new()
			var dash_mesh := BoxMesh.new()
			dash_mesh.size = Vector3(0.25, 0.02, 3.0)
			dash.mesh = dash_mesh
			dash.material_override = line_mat
			dash.position = Vector3(dash_pos.x, 0.13, dash_pos.z)
			dash.rotation.y = angle
			road_root.add_child(dash)

		# curbs both sides
		var perp := Vector3(-dir.z, 0, dir.x)
		for side in [-1.0, 1.0]:
			var curb := MeshInstance3D.new()
			var curb_mesh := BoxMesh.new()
			curb_mesh.size = Vector3(0.35, 0.22, length)
			curb.mesh = curb_mesh
			curb.material_override = curb_mat
			curb.position = mid + perp * side * (ROAD_WIDTH / 2.0 + 0.2)
			curb.position.y = 0.11
			curb.rotation.y = angle
			road_root.add_child(curb)

			var sidewalk := MeshInstance3D.new()
			var sidewalk_mesh := BoxMesh.new()
			sidewalk_mesh.size = Vector3(3.2, 0.1, length)
			sidewalk.mesh = sidewalk_mesh
			sidewalk.material_override = sidewalk_mat
			sidewalk.position = mid + perp * side * (ROAD_WIDTH / 2.0 + 1.9)
			sidewalk.position.y = 0.05
			sidewalk.rotation.y = angle
			road_root.add_child(sidewalk)

static func _build_traffic_lights(parent: Node3D, waypoints: Array[Vector3]) -> void:
	var corner_indices := [2, 7, 10]
	for idx in corner_indices:
		if idx >= waypoints.size():
			continue
		var light := TrafficLightProp.new()
		var perp := _perp_at(waypoints, idx)
		light.position = waypoints[idx] + perp * (ROAD_WIDTH / 2.0 + 1.0)
		parent.add_child(light)

static func _build_traffic_dummies(parent: Node3D, waypoints: Array[Vector3]) -> void:
	# a couple of decorative vehicles idling/moving on straight stretches
	var spots := [
		{"pos": Vector3(120, 0, -220), "dist": 60.0},
		{"pos": Vector3(460, 0, -70), "dist": 50.0},
	]
	for s in spots:
		var dummy := TrafficDummy.new()
		dummy.position = s.pos
		dummy.travel_distance = s.dist
		dummy.speed = randf_range(4.0, 7.0)
		parent.add_child(dummy)

# ---------------------------------------------------------------------------
# District dressing
# ---------------------------------------------------------------------------

static func _build_districts(parent: Node3D, waypoints: Array[Vector3], stop_defs: Array[Dictionary]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337

	for def in stop_defs:
		var wp_index: int = def.waypoint_index
		var center: Vector3 = waypoints[wp_index]
		var perp := _perp_at(waypoints, wp_index)
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
	var band := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x * 0.92, size.y * 0.5, size.z * 0.92)
	band.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.75, 0.85, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.7, 0.5)
	mat.emission_energy_multiplier = 0.15
	band.material_override = mat
	building.add_child(band)

static func _build_filler(parent: Node3D, waypoints: Array[Vector3], rng: RandomNumberGenerator) -> void:
	var colors := [Color(0.7, 0.65, 0.6), Color(0.6, 0.62, 0.68), Color(0.68, 0.58, 0.5), Color(0.5, 0.55, 0.5)]
	var n := waypoints.size()
	for i in range(n):
		var a: Vector3 = waypoints[i]
		var b: Vector3 = waypoints[(i + 1) % n]
		var segments := int(a.distance_to(b) / 40.0)
		var dir := (b - a).normalized()
		var perp := Vector3(-dir.z, 0, dir.x)
		for s in range(segments):
			if rng.randf() > 0.6:
				continue
			var t: float = (s + 0.5) / float(max(segments, 1))
			var base_pos: Vector3 = a.lerp(b, t)
			var sides: Array[float] = [-1.0, 1.0]
			for side in sides:
				if rng.randf() > 0.55:
					continue
				var dist: float = rng.randf_range(20.0, 36.0)
				var pos: Vector3 = base_pos + perp * side * dist
				var height: float = rng.randf_range(6.0, 16.0)
				var w: float = rng.randf_range(8.0, 13.0)
				var d: float = rng.randf_range(8.0, 13.0)
				var bldg: Node3D = _box(parent, pos + Vector3(0, height / 2.0, 0), Vector3(w, height, d), _jitter(colors[rng.randi() % colors.size()], rng))
				_add_window_band(bldg, Vector3(w, height, d))
			# small shop/kiosk near the road on one side - real low-poly model
			if rng.randf() > 0.5:
				var kiosk_side: float = -1.0 if rng.randf() > 0.5 else 1.0
				var kiosk_pos: Vector3 = base_pos + perp * kiosk_side * 11.0
				var model: String = SHOP_MODELS[rng.randi() % SHOP_MODELS.size()]
				_model_prop(parent, model, kiosk_pos, rng.randf_range(4.0, 6.0), rng.randf() * TAU)

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
	foliage_mesh.height = 3.0
	foliage_mm.mesh = foliage_mesh
	foliage_mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		var base: Transform3D = transforms[i]
		foliage_mm.set_instance_transform(i, Transform3D(Basis(), base.origin + Vector3(0, 1.8, 0)))
	var foliage_inst := MultiMeshInstance3D.new()
	foliage_inst.multimesh = foliage_mm
	var foliage_mat := StandardMaterial3D.new()
	foliage_mat.albedo_color = Color(0.22, 0.5, 0.24)
	foliage_inst.material_override = foliage_mat
	parent.add_child(foliage_inst)
