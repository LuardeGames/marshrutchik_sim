extends RefCounted
class_name WorldBuilder
## Procedurally assembles the whole map from primitives: ground, road,
## curbs, district buildings, props and MultiMesh-instanced trees.
## Nothing here needs an external 3D asset.

const ROAD_WIDTH := RouteDefinition.ROAD_WIDTH
## Ground/collision extends this far past the route's own waypoints. Must
## reach past the fixed-coordinate backdrop skyline in _build_backdrop_blocks
## (x up to ~1049, z from -849 to 549) on every route, or those buildings
## float over bare fog with a visible dead strip of nothing in front of them
## - this was the single biggest "empty city" complaint. 460 clears that on
## all three routes' waypoint bounds with room to spare.
const MAP_MARGIN := 460.0
## Was a flat 3.0 (a real panel-block storey), which is technically correct
## next to a ~2.25m-tall Gazelle but read as squat once the camera sat close
## and low to the car - the bus looked like it nearly filled a whole floor.
## Bumped for a heavier, more monumental skyline; the facade shader's window
## rows are re-tiled to this same height (see facade.gdshader) so the extra
## storey height doesn't stretch the window texture.
const FLOOR_HEIGHT := 3.35

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
	_build_city_variety(parent)
	CityDressing.build(parent, waypoints)
	_build_filler(parent, waypoints, RandomNumberGenerator.new())
	_build_trees(parent, waypoints)
	_build_pocket_gardens(parent)

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
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = preload("res://assets/materials/overcast_sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Flattened toward neutral grey (was a noticeably blue-ish "bac0c5") -
	# the mood is an overcast, drab CIS city, not a cool clear-sky bounce.
	env.ambient_light_color = Color("9a9a99")
	env.ambient_light_energy = 0.46
	env.fog_enabled = true
	env.fog_light_color = Color("999999")
	env.fog_density = 0.00085
	env.fog_sky_affect = 0.16
	env.fog_aerial_perspective = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.90
	# The Compatibility renderer doesn't support screen-space AO, so this
	# stays off - grime/contact shadow is baked into the facade/surface
	# shaders instead (see PS2Look/CityMaterials).
	env.ssao_enabled = false
	env.glow_enabled = false
	env.adjustment_enabled = true
	# Buildings/ground were still reading brighter than the grey sky behind
	# them - the ambient+sun stack was overpowering the overcast mood the
	# sky shader sets. Pulled the whole ground-level exposure down a notch.
	env.adjustment_brightness = 0.88
	# A gentler contrast/saturation than an earlier pass - "серость":
	# drab and hazy, not a punchy console crunch that fights the overcast
	# mood the sky/fog are already going for.
	env.adjustment_contrast = 1.04
	env.adjustment_saturation = 0.68
	env_node.environment = env
	parent.add_child(env_node)

	# Real shadow-casting sun, but soft: an overcast sky scatters sunlight
	# through cloud cover, so its shadow should be a soft, hazy smudge, not
	# a crisp hard-sun edge. A heavy shadow_blur plus lifting ambient back up
	# (vs. an earlier, punchier pass) keeps the shadow soft and never pure
	# black - matches how shadows actually look on a grey day.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -50, 0)
	sun.light_energy = 0.62
	sun.shadow_enabled = true
	sun.shadow_blur = 4.0
	sun.shadow_opacity = 0.6 # soft/hazy, never a stark black cutout
	sun.directional_shadow_max_distance = 150.0
	sun.light_color = Color("d4d9df")
	parent.add_child(sun)

	# Cool, dim fill light from the opposite side so shadow-side faces of
	# buildings aren't pure black - cheap and very cheap on a single mesh pass.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 130, 0)
	fill.light_energy = 0.06
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
		_register_road_surface(parent, a, b, ROAD_WIDTH, ROAD_WIDTH * 0.5)

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

	# Corner fill: each edge's curb/sidewalk above stops ROAD_WIDTH/2 short of
	# every vertex on purpose, so two edges meeting at an angle never need a
	# mitred join - but with nothing placed in that gap it read as a visibly
	# broken curb at every turn. Cap it with a box sized to the actual offset
	# between the incoming and outgoing edge's curb/sidewalk line on each
	# side; degenerates to a tiny corner dot where an edge runs straight
	# through (incoming and outgoing directions equal).
	var curb_offset := ROAD_WIDTH / 2.0 + 0.2
	var walk_offset := ROAD_WIDTH / 2.0 + 1.9
	for i in range(n):
		var prev_pt: Vector3 = waypoints[(i - 1 + n) % n]
		var cur_pt: Vector3 = waypoints[i]
		var next_pt: Vector3 = waypoints[(i + 1) % n]
		var in_dir := (cur_pt - prev_pt).normalized()
		var out_dir := (next_pt - cur_pt).normalized()
		var in_perp := Vector3(-in_dir.z, 0, in_dir.x)
		var out_perp := Vector3(-out_dir.z, 0, out_dir.x)
		for side in [-1.0, 1.0]:
			var p_in: Vector3 = cur_pt + in_perp * side * curb_offset
			var p_out: Vector3 = cur_pt + out_perp * side * curb_offset
			var corner := (p_in + p_out) * 0.5
			var gap := Vector3(absf(p_out.x - p_in.x) + 0.35, 0.0, absf(p_out.z - p_in.z) + 0.35)
			if gap.x > 0.4 and gap.z > 0.4:
				curb_entries.append({"size": Vector3(gap.x, 0.22, gap.z), "position": Vector3(corner.x, 0.11, corner.z), "y_rot": 0.0})
			var pw_in: Vector3 = cur_pt + in_perp * side * walk_offset
			var pw_out: Vector3 = cur_pt + out_perp * side * walk_offset
			var corner_w := (pw_in + pw_out) * 0.5
			var gap_w := Vector3(absf(pw_out.x - pw_in.x) + 3.2, 0.0, absf(pw_out.z - pw_in.z) + 3.2)
			if gap_w.x > 0.4 and gap_w.z > 0.4:
				sidewalk_entries.append({"size": Vector3(gap_w.x, 0.1, gap_w.z), "position": Vector3(corner_w.x, 0.05, corner_w.z), "y_rot": 0.0})

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

## Same idea as _multimesh_boxes but with a low-poly sphere instead of a
## cube - used for tree canopies, which read as jarringly artificial as flat
## cubes next to every round shrub/foliage sphere elsewhere in the city.
static func _multimesh_spheres(parent: Node3D, name: String, material: Material, entries: Array) -> void:
	if entries.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 7
	mesh.rings = 3
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
	for idx in [2,7,10]:
		for neighbor in [(idx-1+waypoints.size())%waypoints.size(),(idx+1)%waypoints.size()]:
			var dir: Vector3 = (waypoints[idx]-waypoints[neighbor]).normalized()
			var right := Vector3(-dir.z,0,dir.x)
			var light := TrafficLightProp.new()
			light.approach = dir
			light.stop_point = waypoints[idx]-dir*17.0+right*2.5
			light.phase_offset = float(idx)*1.3
			light.position = waypoints[idx]-dir*10.0+right*6.6
			parent.add_child(light)
			light.look_at(light.position+dir)
			_box(parent,light.stop_point+Vector3(0,0.14,0),Vector3(4.4,0.025,0.35),Color("d4d3ca"),false,atan2(dir.x,dir.z))
	RoadSigns.build(parent,waypoints)

static func _build_traffic_dummies(parent: Node3D, waypoints: Array[Vector3]) -> void:
	var outer: Array[Vector3] = [Vector3(-140,0,-600),Vector3(760,0,-600),Vector3(760,0,280),Vector3(-140,0,280)]
	var civic_loop: Array[Vector3] = [Vector3(-90,0,-80),Vector3(250,0,-80),Vector3(250,0,110),Vector3(-90,0,110)]
	var industrial_loop: Array[Vector3] = [Vector3(380,0,-430),Vector3(680,0,-430),Vector3(680,0,-170),Vector3(520,0,-110),Vector3(380,0,-190)]
	for circuit in [waypoints, outer, civic_loop, industrial_loop]:
		var is_route: bool = circuit == waypoints
		var is_outer: bool = circuit == outer
		var count: int = 20 if is_route else (12 if is_outer else 5)
		for reverse in [false,true]:
			for index in range(count):
				var car := TrafficDummy.new()
				car.name = "Oncoming_%s_%s_%d" % ["Route" if is_route else "Outer",reverse,index]
				car.road_path.assign(circuit)
				car.reverse_direction = reverse
				car.start_index = index
				# Four-car waves create queues at red lights while still leaving
				# gaps for the player to merge and overtake on wider sections.
				if is_route:
					var wave: int = index / 4
					var slot: int = index % 4
					car.spawn_fraction = fposmod(0.04 + float(wave) * 0.235 + float(slot) * 0.018, 1.0)
				else:
					car.spawn_fraction = (float(index)+0.35)/float(count)
				car.speed = 7.5+float(index%4)*0.7
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
		var height := floors * FLOOR_HEIGHT
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
	var b := _box(parent, center - perp * 24.0 + Vector3(0, 7, 0), Vector3(26.0, 14.0, 12.0), Color(0.8, 0.75, 0.55))
	_add_window_band(b, Vector3(26.0, 14.0, 12.0))
	var tower := _box(parent, center - perp * 24.0 + Vector3(0, 17, -4), Vector3(4.0, 20.0, 4.0), Color(0.75, 0.68, 0.45))
	var spire := _box(parent, center - perp * 24.0 + Vector3(0, 28, -4), Vector3(1.0, 3.0, 1.0), Color(0.6, 0.55, 0.35), false)

static func _build_depot(parent: Node3D, center: Vector3, perp: Vector3, rng: RandomNumberGenerator) -> void:
	# tangent = road direction at this point, derived from perp so garages
	# line up parallel to the road instead of drifting back onto it.
	var tangent := Vector3(perp.z, 0, -perp.x)
	for i in range(3):
		var offset := perp * 22.0 + tangent * (i - 1) * 8.0
		_box(parent, center + offset + Vector3(0, 2.2, 0), Vector3(5.5, 4.4, 7.0), Color(0.4, 0.42, 0.4))
	_box(parent, center + perp * 22.0 + Vector3(0, 0.05, 0), Vector3(10.0, 0.05, 24.0), Color(0.3, 0.3, 0.3), false)

static func _build_city_variety(parent: Node3D) -> void:
	# A few deliberately different silhouettes break the endless panel-block
	# rhythm: brick houses, Stalin-era frontage, a school, a fire station and
	# a small private-sector street typical of a provincial CIS city.
	_build_brick_house(parent, Vector3(-105, 0, -520), Vector3(24, 15, 12), 0.0)
	_build_brick_house(parent, Vector3(90, 0, -520), Vector3(30, 18, 12), 0.0)
	_build_stalinka(parent, Vector3(440, 0, 210), Vector3(32, 18, 16))
	_build_school(parent, Vector3(-180, 0, 125), Vector3(30, 7, 18))
	_build_fire_station(parent, Vector3(710, 0, 120), Vector3(24, 6, 16))
	_build_private_street(parent, Vector3(-270, 0, 80))
	_build_post_office(parent, Vector3(5, 0, 245), Vector3(22, 7, 14))
	_build_cinema(parent, Vector3(225, 0, 245), Vector3(26, 8, 18))
	_build_market_hall(parent, Vector3(-185, 0, -175), Vector3(26, 8, 18))
	_build_warehouse(parent, Vector3(720, 0, -500), Vector3(30, 8, 22))
	# Extra one-off silhouettes so the drive doesn't repeat the same handful
	# of shapes - placed well clear of every route's waypoints and the fixed
	# traffic loops (checked against all three route layouts, not just 47).
	_build_auto_service(parent, Vector3(-260, 0, -520), Vector3(20, 6, 14))
	# NOT (300,-520): that sits directly on the fixed north-south connecting
	# street at x=300 (z -600..-460) in _build_filler's `links` - confirmed
	# by tests/city_roads_test.gd finding 10 blocked lane samples there.
	_build_mall(parent, Vector3(580, 0, -650), Vector3(34, 9, 20))
	_build_sports_hall(parent, Vector3(650, 0, 245), Vector3(28, 9, 20))

static func _build_brick_house(parent: Node3D, pos: Vector3, size: Vector3, y_rot: float) -> void:
	var building := _box(parent, pos + Vector3(0, size.y * 0.5, 0), size, Color("a86e55"), true, y_rot)
	_add_window_band(building, size)
	_box(parent, pos + Vector3(0, size.y + 0.18, 0), Vector3(size.x + 0.45, 0.35, size.z + 0.45), Color("5b4b43"), false, y_rot)

static func _build_stalinka(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var building := _box(parent, pos + Vector3(0, size.y * 0.5, 0), size, Color("b8a486"))
	_add_window_band(building, size)
	for x in [-size.x * 0.34, size.x * 0.34]:
		_box(parent, pos + Vector3(x, size.y * 0.5, -size.z * 0.53), Vector3(0.55, size.y, 0.30), Color("8d7962"), false)
	_box(parent, pos + Vector3(0, size.y + 0.25, 0), Vector3(size.x + 2.0, 0.5, size.z + 2.0), Color("756654"), false)

static func _build_school(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var building := _box(parent, pos + Vector3(0, size.y * 0.5, 0), size, Color("c7b98f"))
	_add_window_band(building, size)
	_box(parent, pos + Vector3(0, size.y + 0.15, 0), Vector3(size.x + 0.5, 0.30, size.z + 0.5), Color("6d766d"), false)
	BusVisual.label(parent, "ШКОЛА № 7", pos + Vector3(0, 3.1, -size.z * 0.54), PI, 0.004)
	_box(parent, pos + Vector3(0, 0.35, -size.z * 0.9), Vector3(9.0, 0.7, 5.0), Color("57734d"), false)

static func _build_fire_station(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var building := _box(parent, pos + Vector3(0, size.y * 0.5, 0), size, Color("a85643"))
	_add_window_band(building, size)
	for x in [-7.0, 0.0, 7.0]:
		_box(parent, pos + Vector3(x, 1.45, -size.z * 0.54), Vector3(5.0, 2.4, 0.12), Color("3f5558"), false)
	BusVisual.label(parent, "ПОЖАРНАЯ ЧАСТЬ", pos + Vector3(0, size.y + 0.7, -size.z * 0.54), PI, 0.003)

static func _build_private_street(parent: Node3D, origin: Vector3) -> void:
	for i in range(4):
		var pos := origin + Vector3(float(i) * 28.0, 0, 0)
		_box(parent, pos + Vector3(0, 2.2, 0), Vector3(18.0, 4.4, 10.0), Color("b58d68"))
		_box(parent, pos + Vector3(0, 4.6, 0), Vector3(19.0, 0.35, 11.0), Color("5c4f43"), false)
		_box(parent, pos + Vector3(0, 0.45, -6.4), Vector3(20.0, 0.9, 0.18), Color("7c684c"), true)

static func _build_post_office(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var building := _box(parent, pos + Vector3(0, size.y * 0.5, 0), size, Color("c28362"))
	_add_window_band(building, size)
	_box(parent, pos + Vector3(0, size.y + 0.2, 0), Vector3(size.x + 0.7, 0.35, size.z + 0.7), Color("6a7169"), false)
	BusVisual.label(parent, "ПОЧТА", pos + Vector3(0, 4.3, -size.z * 0.55), PI, 0.005)

static func _build_cinema(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var building := _box(parent, pos + Vector3(0, size.y * 0.5, 0), size, Color("6b7182"))
	_add_window_band(building, size)
	_box(parent, pos + Vector3(0, 4.6, -size.z * 0.55), Vector3(size.x * 0.75, 2.2, 0.14), Color("384e60"), false)
	BusVisual.label(parent, "КИНОТЕАТР «ЗАРЯ»", pos + Vector3(0, 4.7, -size.z * 0.65), PI, 0.003)

static func _build_market_hall(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var building := _box(parent, pos + Vector3(0, size.y * 0.5, 0), size, Color("9d7655"))
	_add_window_band(building, size)
	_box(parent, pos + Vector3(0, size.y + 0.45, 0), Vector3(size.x + 1.2, 0.8, size.z + 1.2), Color("4d5b59"), false)
	for x in [-8.0, 0.0, 8.0]:
		_box(parent, pos + Vector3(x, 1.4, -size.z * 0.58), Vector3(5.5, 2.0, 0.12), Color("b85a42"), false)
	BusVisual.label(parent, "ГОРОДСКОЙ РЫНОК", pos + Vector3(0, 5.2, -size.z * 0.62), PI, 0.003)

static func _build_warehouse(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var building := _box(parent, pos + Vector3(0, size.y * 0.5, 0), size, Color("777b73"))
	_add_window_band(building, size)
	for x in [-9.0, 0.0, 9.0]:
		_box(parent, pos + Vector3(x, 1.7, -size.z * 0.55), Vector3(6.0, 3.0, 0.14), Color("354a50"), false)
	BusVisual.label(parent, "СКЛАД / ЛОГИСТИКА", pos + Vector3(0, 5.4, -size.z * 0.60), PI, 0.003)

static func _build_auto_service(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var building := _box(parent, pos + Vector3(0, size.y * 0.5, 0), size, Color("8f8f92"))
	_add_window_band(building, size)
	_box(parent, pos + Vector3(0, 1.4, -size.z * 0.55), Vector3(size.x * 0.5, 2.8, 0.12), Color("2f3436"), false)
	_box(parent, pos + Vector3(size.x * 0.3, size.y + 0.2, 0), Vector3(1.2, 0.3, 1.2), Color("596461"), false)
	BusVisual.label(parent, "АВТОСЕРВИС", pos + Vector3(0, size.y + 0.6, -size.z * 0.56), PI, 0.0035)

static func _build_mall(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var building := _box(parent, pos + Vector3(0, size.y * 0.5, 0), size, Color("bcb7a4"))
	_add_window_band(building, size)
	_box(parent, pos + Vector3(0, size.y * 0.82, -size.z * 0.53), Vector3(size.x * 0.9, size.y * 0.5, 0.2), Color("46707a"), false)
	_box(parent, pos + Vector3(0, size.y + 0.3, 0), Vector3(size.x + 1.4, 0.6, size.z + 1.4), Color("5a625d"), false)
	BusVisual.label(parent, "ТЦ «РОДИНА»", pos + Vector3(0, 4.6, -size.z * 0.63), PI, 0.0038)

static func _build_sports_hall(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var building := _box(parent, pos + Vector3(0, size.y * 0.5, 0), size, Color("7d8a76"))
	_add_window_band(building, size)
	var roof := _box(parent, pos + Vector3(0, size.y + 0.5, 0), Vector3(size.x + 0.6, 0.9, size.z + 0.6), Color("4a5a4d"), false)
	roof.rotation.x = 0.06
	BusVisual.label(parent, "СПОРТКОМПЛЕКС «ТРУД»", pos + Vector3(0, size.y + 1.4, -size.z * 0.55), PI, 0.0032)

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
		_box(building,Vector3(size.x*0.25,-size.y/2.0+float(floor_index)*FLOOR_HEIGHT,-size.z/2.0-0.45),Vector3(2.3,0.18,1.0),Color("aca796"),false)
		_box(building,Vector3(size.x*0.25,-size.y/2.0+float(floor_index)*FLOOR_HEIGHT+0.52,-size.z/2.0-0.94),Vector3(2.3,0.9,0.10),Color("8b958b"),false)

## Continuous street fronts and deeper residential blocks, with explicit lot
## reservations so scenery never occupies roads, stops or existing landmarks.
static func _build_filler(parent: Node3D, waypoints: Array[Vector3], rng: RandomNumberGenerator) -> void:
	rng.seed = 82371
	var front_entries: Array = []
	var back_entries: Array = []
	var occupied: Array[Rect2] = []
	_collect_major_occupied(parent, occupied)
	var streets: Array = []
	for i in range(waypoints.size()):
		streets.append([waypoints[i], waypoints[(i+1)%waypoints.size()]])
	var ring: Array[Vector3] = [Vector3(-140,0,-600),Vector3(760,0,-600),Vector3(760,0,280),Vector3(-140,0,280)]
	_build_road(parent, ring)
	for i in range(4):
		streets.append([ring[i],ring[(i+1)%4]])
	# Secondary city grid: the route is only one part of the road network.
	# These loops intentionally use different scales so the map reads as
	# districts connected by streets rather than a single racing circuit.
	var civic_loop: Array[Vector3] = [Vector3(-90,0,-80),Vector3(250,0,-80),Vector3(250,0,110),Vector3(-90,0,110)]
	var industrial_loop: Array[Vector3] = [Vector3(380,0,-430),Vector3(680,0,-430),Vector3(680,0,-170),Vector3(520,0,-110),Vector3(380,0,-190)]
	var west_loop: Array[Vector3] = [Vector3(-100,0,-470),Vector3(90,0,-470),Vector3(90,0,-270),Vector3(-40,0,-200),Vector3(-170,0,-300)]
	_add_network_loop(parent, streets, civic_loop)
	_add_network_loop(parent, streets, industrial_loop)
	_add_network_loop(parent, streets, west_loop)
	_build_roundabout(parent, streets, Vector3(285,0,-95), 48.0)
	_build_narrow_street(parent, streets, Vector3(270,0,110), Vector3(390,0,240))
	_build_bridge_feature(parent, streets)
	var links: Array = [[Vector3(-140,0,-140),Vector3(0,0,-140)], [Vector3(300,0,-600),Vector3(300,0,-460)], [Vector3(760,0,-140),Vector3(620,0,-140)], [Vector3(300,0,280),Vector3(300,0,140)]]
	var link_surfaces: Array = []
	for link in links:
		streets.append(link)
		_register_road_surface(parent, link[0], link[1], 10.0, 5.0)
		var delta: Vector3 = link[1]-link[0]
		link_surfaces.append({"size":Vector3(10,0.14,delta.length()+10),"position":(link[0]+link[1])*0.5+Vector3(0,0.07,0),"y_rot":atan2(delta.x,delta.z)})
	_multimesh_boxes(parent,"ConnectingStreets",CityMaterials.surface("asphalt"),link_surfaces)
	var reserved: Array[Rect2] = []
	for street in streets:
		var a: Vector3 = street[0]
		var b: Vector3 = street[1]
		_reserve_street(reserved, a, b)
	for waypoint in waypoints:
		reserved.append(Rect2(Vector2(waypoint.x - 20.0, waypoint.z - 20.0), Vector2(40.0, 40.0)))
	for stop in RouteDefinition.stops():
		var p := RouteDefinition.stop_position(stop.waypoint_index)
		reserved.append(Rect2(Vector2(p.x-16,p.z-16),Vector2(32,32)))
	# Long apartment slabs line both sides; a second row closes the skyline.
	for street in streets:
		var a: Vector3 = street[0]
		var b: Vector3 = street[1]
		var dir: Vector3 = (b-a).normalized()
		var perp := Vector3(-dir.z,0,dir.x)
		var count := int(a.distance_to(b)/40.0)
		for i in range(count):
			for side in [-1.0,1.0]:
				for row in range(2):
					var pos: Vector3 = a.lerp(b,(i+0.5)/float(count))+perp*side*(23.0+row*38.0)
					var size := Vector3(34, float(rng.randi_range(5,9))*FLOOR_HEIGHT,14) if absf(dir.x)>0.5 else Vector3(14,float(rng.randi_range(5,9))*FLOOR_HEIGHT,34)
					_place_city_block(parent,pos,size,reserved,occupied,front_entries,rng)
	# Smaller three-to-six-storey sections fit between junction clearances and
	# landmarks where a full 30-metre slab would leave an empty street edge.
	for street in streets:
		var a: Vector3 = street[0]
		var b: Vector3 = street[1]
		var dir := (b - a).normalized()
		var perp := Vector3(-dir.z, 0, dir.x)
		var count := int(a.distance_to(b) / 24.0)
		for i in range(count):
			for side: float in [-1.0, 1.0]:
				var pos: Vector3 = a.lerp(b, (float(i) + 0.5) / float(count)) + perp * side * 22.0
				var size := Vector3(20, float(rng.randi_range(3, 6)) * FLOOR_HEIGHT, 12) if absf(dir.x) > 0.5 else Vector3(12, float(rng.randi_range(3, 6)) * FLOOR_HEIGHT, 20)
				# ~1 in 5 of these street-edge slots gets a real Kenney
				# building model instead of another procedural box - low
				# enough here that it reads as a real standalone shopfront,
				# not a skyline gap.
				if rng.randf() > 0.8 and _place_variety_building(parent, pos, size, reserved, occupied, rng):
					continue
				_place_city_block(parent, pos, size, reserved, occupied, front_entries, rng)
	# Fill the interior and extend beyond the outer avenue - out to just
	# short of the fixed backdrop skyline (see MAP_MARGIN) so that band isn't
	# bare grass between the built-up city and the distant silhouette.
	# Alternating slab orientation leaves connected courtyards instead of
	# isolated towers.
	for x in range(-280, 971, 46):
		for z in range(-770, 471, 46):
			var pos := Vector3(x,0,z)
			var size := Vector3(36,float(rng.randi_range(5,12))*FLOOR_HEIGHT,18) if (x/46+z/46)%2==0 else Vector3(18,float(rng.randi_range(5,12))*FLOOR_HEIGHT,36)
			# A real building model dropped into an occasional interior slot
			# instead of yet another panelka - a low shopfront/kiosk sitting
			# in a gap between tall blocks is a normal sight in a real
			# district, not a mistake.
			if rng.randf() > 0.88 and _place_variety_building(parent, pos, size, reserved, occupied, rng):
				continue
			_place_city_block(parent,pos,size,reserved,occupied,front_entries,rng)
	_build_backdrop_blocks(back_entries, rng)
	parent.set_meta("city_buildings",front_entries.size())
	parent.set_meta("city_backdrop_buildings", back_entries.size())
	parent.set_meta("city_streets",streets)

	var body_mat := CityMaterials.facade(Color.WHITE, true)
	_multimesh_colored_boxes(parent, "FillerFront", body_mat, front_entries)
	_multimesh_colored_boxes(parent, "FillerBack", body_mat, back_entries)
	var walks: Array=[]
	var roofs: Array=[]
	var balconies: Array=[]
	var doors: Array=[]
	var rooftop_units: Array=[]
	var penthouses: Array=[]
	for entry_index in range(front_entries.size()):
		var e: Dictionary = front_entries[entry_index]
		# Wider than the building's own footprint by a real margin, not just
		# a token strip - a narrow gap between two closely-spaced blocks is a
		# service alley in reality, never bare grass, and this is usually
		# enough for two neighbouring buildings' paving to meet in the middle.
		walks.append({"size":Vector3(e.size.x+7,0.08,e.size.z+7),"position":Vector3(e.position.x,0.04,e.position.z),"y_rot":0.0})
		roofs.append({"size":Vector3(e.size.x+0.25,0.18,e.size.z+0.25),"position":e.position+Vector3(0,e.size.y/2.0,0),"y_rot":0.0})
		if entry_index % 3 == 0:
			rooftop_units.append({"size": Vector3(3.6, 1.2, 2.5), "position": e.position + Vector3(e.size.x * 0.18, e.size.y / 2.0 + 0.7, 0), "y_rot": 0.0})
		# A stepped-back penthouse on roughly one building in nine breaks the
		# flat-roof skyline rhythm without touching placement/collision at all
		# - purely a taller box sitting on a footprint already approved above.
		if entry_index % 9 == 4 and e.size.y >= 15.0:
			penthouses.append({"size": Vector3(e.size.x * 0.55, 4.0, e.size.z * 0.55), "position": e.position + Vector3(0, e.size.y / 2.0 + 2.0, 0), "y_rot": 0.0})
		if e.size.x >= e.size.z:
			var balcony_x: float = e.position.x + e.size.x * 0.23
			for facade_side: float in [-1.0, 1.0]:
				var front_z: float = e.position.z + facade_side * e.size.z / 2.0
				doors.append({"size": Vector3(1.2, 2.1, 0.05), "position": Vector3(e.position.x, 1.05, front_z + facade_side * 0.03), "y_rot": 0.0})
				roofs.append({"size": Vector3(2.1, 0.14, 1.5), "position": Vector3(e.position.x, 2.4, front_z + facade_side * 0.7), "y_rot": 0.0})
				for floor_index in range(1, int(e.size.y / 3.0)):
					var y := float(floor_index) * FLOOR_HEIGHT + 0.3
					balconies.append({"size": Vector3(2.2, 0.14, 0.95), "position": Vector3(balcony_x, y, front_z + facade_side * 0.45), "y_rot": 0.0})
					balconies.append({"size": Vector3(2.2, 0.82, 0.08), "position": Vector3(balcony_x, y + 0.45, front_z + facade_side * 0.89), "y_rot": 0.0})
		else:
			var balcony_z: float = e.position.z + e.size.z * 0.23
			for facade_side: float in [-1.0, 1.0]:
				var front_x: float = e.position.x + facade_side * e.size.x / 2.0
				doors.append({"size": Vector3(0.05, 2.1, 1.2), "position": Vector3(front_x + facade_side * 0.03, 1.05, e.position.z), "y_rot": 0.0})
				roofs.append({"size": Vector3(1.5, 0.14, 2.1), "position": Vector3(front_x + facade_side * 0.7, 2.4, e.position.z), "y_rot": 0.0})
				for floor_index in range(1, int(e.size.y / 3.0)):
					var y := float(floor_index) * FLOOR_HEIGHT + 0.3
					balconies.append({"size": Vector3(0.95, 0.14, 2.2), "position": Vector3(front_x + facade_side * 0.45, y, balcony_z), "y_rot": 0.0})
					balconies.append({"size": Vector3(0.08, 0.82, 2.2), "position": Vector3(front_x + facade_side * 0.89, y + 0.45, balcony_z), "y_rot": 0.0})
	_multimesh_boxes(parent,"ApartmentFootpaths",CityMaterials.surface("paving"),walks)
	_multimesh_boxes(parent,"RoofCapsAndCanopies",BusVisual.material(Color("697167")),roofs)
	_multimesh_boxes(parent,"RoofEquipment",BusVisual.material(Color("59615e")),rooftop_units)
	_multimesh_boxes(parent,"Penthouses",CityMaterials.facade(Color("9a9384")),penthouses)
	_multimesh_boxes(parent,"BalconyPanels",BusVisual.material(Color("899184"), 0.35, 0.5),balconies)
	_multimesh_boxes(parent,"EntranceDoors",BusVisual.material(Color("3d5851"), 0.2, 0.45),doors)

static func _reserve_street(reserved: Array[Rect2], start: Vector3, finish: Vector3) -> void:
	var part_count := maxi(1, ceili(start.distance_to(finish) / 12.0))
	for part_index in range(part_count):
		var a := start.lerp(finish, float(part_index) / float(part_count))
		var b := start.lerp(finish, float(part_index + 1) / float(part_count))
		reserved.append(Rect2(Vector2(minf(a.x, b.x), minf(a.z, b.z)), Vector2(absf(b.x - a.x), absf(b.z - a.z))).grow(9.5))

static func _build_backdrop_blocks(entries: Array, rng: RandomNumberGenerator) -> void:
	var colors := [Color("858c8b"), Color("8f8c84"), Color("7d8589"), Color("91877e")]
	for z: float in [-790.0, -840.0, 490.0, 540.0]:
		for x in range(-340, 981, 38):
			var size := Vector3(28.0, float(rng.randi_range(7, 15)) * FLOOR_HEIGHT, 18.0)
			entries.append({"size": size, "position": Vector3(x, size.y * 0.5, z), "y_rot": 0.0, "color": colors[rng.randi() % colors.size()]})
	for x: float in [-350.0, -400.0, 990.0, 1040.0]:
		for z in range(-752, 453, 38):
			var size := Vector3(18.0, float(rng.randi_range(7, 15)) * FLOOR_HEIGHT, 28.0)
			entries.append({"size": size, "position": Vector3(x, size.y * 0.5, z), "y_rot": 0.0, "color": colors[rng.randi() % colors.size()]})

static func _add_network_loop(parent: Node3D, streets: Array, points: Array[Vector3]) -> void:
	_build_road(parent, points)
	for i in range(points.size()):
		streets.append([points[i], points[(i + 1) % points.size()]])

static func _build_roundabout(parent: Node3D, streets: Array, center: Vector3, radius: float) -> void:
	var points: Array[Vector3] = []
	for i in range(8):
		var angle: float = TAU * float(i) / 8.0
		points.append(center + Vector3(cos(angle), 0, sin(angle)) * radius)
	_add_network_loop(parent, streets, points)
	_box(parent, center + Vector3(0, 0.12, 0), Vector3(radius * 0.92, 0.22, radius * 0.92), Color("68775b"), true)
	for i in range(8):
		var angle: float = TAU * float(i) / 8.0
		var tree_pos: Vector3 = center + Vector3(cos(angle), 0.8, sin(angle)) * (radius * 0.32)
		_box(parent, tree_pos, Vector3(1.0, 1.6, 1.0), Color("54704d"), true)

static func _build_narrow_street(parent: Node3D, streets: Array, start: Vector3, finish: Vector3) -> void:
	_register_road_surface(parent, start, finish, 6.2, 4.0)
	var dir: Vector3 = (finish - start).normalized()
	var middle: Vector3 = (start + finish) * 0.5
	_box(parent, middle + Vector3(0, 0.05, 0), Vector3(6.2, 0.12, start.distance_to(finish) + 8.0), Color("343b3b"), false, atan2(dir.x, dir.z))
	streets.append([start, finish])
	# Close the lane with a pair of close walls, making this a deliberate
	# low-speed shortcut rather than another open highway.
	var side: Vector3 = Vector3(-dir.z, 0, dir.x)
	_box(parent, start.lerp(finish, 0.5) + side * 4.8 + Vector3(0, 1.0, 0), Vector3(0.35, 2.0, finish.distance_to(start)), Color("77736b"), true, atan2(dir.x, dir.z))
	_box(parent, start.lerp(finish, 0.5) - side * 4.8 + Vector3(0, 1.0, 0), Vector3(0.35, 2.0, finish.distance_to(start)), Color("77736b"), true, atan2(dir.x, dir.z))

static func _build_bridge_feature(parent: Node3D, streets: Array) -> void:
	var start := Vector3(250, 0, -80)
	var finish := Vector3(380, 0, -80)
	_register_road_surface(parent, start, finish, 12.8, 0.0)
	var dir: Vector3 = (finish - start).normalized()
	var side: Vector3 = Vector3(-dir.z, 0, dir.x)
	var rail_start := start + dir * 12.0
	var rail_middle := (rail_start + finish) * 0.5
	var rail_length := rail_start.distance_to(finish)
	streets.append([start, finish])
	_box(parent, (start + finish) * 0.5 + Vector3(0, 0.16, 0), Vector3(12.8, 0.28, start.distance_to(finish)), Color("4b5353"), false, atan2(dir.x, dir.z))
	_box(parent, rail_middle + side * 6.3 + Vector3(0, 0.85, 0), Vector3(0.28, 1.4, rail_length), Color("77756d"), true, atan2(dir.x, dir.z))
	_box(parent, rail_middle - side * 6.3 + Vector3(0, 0.85, 0), Vector3(0.28, 1.4, rail_length), Color("77756d"), true, atan2(dir.x, dir.z))
	for x in [0.18, 0.50, 0.82]:
		var post_pos: Vector3 = start.lerp(finish, x)
		_box(parent, post_pos + side * 6.3 + Vector3(0, 0.9, 0), Vector3(0.34, 1.8, 0.34), Color("8e887a"), true)
		_box(parent, post_pos - side * 6.3 + Vector3(0, 0.9, 0), Vector3(0.34, 1.8, 0.34), Color("8e887a"), true)


## Same oriented rectangles as the asphalt meshes, including extended ends.
static func _register_road_surface(parent: Node3D, a: Vector3, b: Vector3, width: float, extension: float) -> void:
	var surfaces: Array = parent.get_meta("road_surfaces", [])
	surfaces.append({"a": a, "b": b, "width": width, "extension": extension})
	parent.set_meta("road_surfaces", surfaces)

static func is_road_surface(pos: Vector3, surfaces: Array, margin: float = 0.0) -> bool:
	for surface: Dictionary in surfaces:
		var a: Vector3 = surface["a"]
		var b: Vector3 = surface["b"]
		var direction: Vector3 = (b - a).normalized()
		var offset: Vector3 = pos - a
		var along: float = offset.dot(direction)
		var lateral: float = absf(offset.dot(Vector3(-direction.z, 0, direction.x)))
		var extension: float = float(surface["extension"]) + margin
		if along >= -extension and along <= a.distance_to(b) + extension and lateral <= float(surface["width"]) * 0.5 + margin:
			return true
	return false

## A CIS courtyard's parking/garage row is never an island in the grass -
## it hangs off a real проезд from the street. Draws a straight asphalt
## strip from a yard lot to the nearest registered road's centerline (skips
## it if that road is implausibly far away, rather than drawing a driveway
## across half the district).
static func _add_yard_driveway(pos: Vector3, surfaces: Array, driveways: Array) -> void:
	var best_dist := INF
	var best_point := pos
	for surface: Dictionary in surfaces:
		var a: Vector3 = surface["a"]
		var b: Vector3 = surface["b"]
		var point := Geometry3D.get_closest_point_to_segment(pos, a, b)
		var dist := pos.distance_to(point)
		if dist < best_dist:
			best_dist = dist
			best_point = point
	if best_dist < 3.0 or best_dist > 42.0:
		return
	var to_road: Vector3 = best_point - pos
	to_road.y = 0.0
	var dir := to_road.normalized()
	var mid := pos + dir * (best_dist * 0.5)
	driveways.append({"size": Vector3(4.4, 0.09, best_dist + 4.0), "position": Vector3(mid.x, 0.045, mid.z), "y_rot": atan2(dir.x, dir.z)})

## A handful of small colored blocks scattered over a green planter/hedge -
## turns a flat mono-green box into a readable CIS-courtyard flowerbed
## (клумба) instead of just more undifferentiated grass-green.
const FLOWER_COLORS := [Color("c94f4f"), Color("d9b23c"), Color("c15fa0"), Color("d97f3c")]
static func _flower_cluster(flowers: Array, center: Vector3, seed_i: int) -> void:
	var offsets := [Vector3(-0.9,0,-0.5), Vector3(0.7,0,0.5), Vector3(0.05,0,0.85), Vector3(-0.45,0,0.65), Vector3(0.85,0,-0.35)]
	for i in range(offsets.size()):
		var color: Color = FLOWER_COLORS[(seed_i + i) % FLOWER_COLORS.size()]
		flowers.append({"size": Vector3(0.24, 0.22, 0.24), "position": center + offsets[i] + Vector3(0, 0.04, 0), "y_rot": 0.0, "color": color})

## A single sphere scaled to a tree's canopy still reads as a lollipop -
## one lopsided second lobe, offset deterministically from the trunk
## position (no rng available in this pass), breaks the perfect-blob
## silhouette without needing real foliage geometry.
static func _leafy_crown(tree_crowns: Array, center: Vector3, radius: float) -> void:
	tree_crowns.append({"size": Vector3(radius * 2.0, radius * 2.3, radius * 2.0), "position": center, "y_rot": 0.0})
	var h1 := fmod(absf(center.x * 12.9898 + center.z * 78.233), 1.0)
	var h2 := fmod(absf(center.x * 39.34 + center.z * 11.71), 1.0)
	var off := Vector3((h1 - 0.5) * radius * 1.4, radius * 0.2, (h2 - 0.5) * radius * 1.4)
	tree_crowns.append({"size": Vector3(radius * 1.25, radius * 1.45, radius * 1.25), "position": center + off, "y_rot": 0.0})

## Turns leftover lots into readable courtyards instead of scattering the
## same tiny planter across every empty patch.
static func _build_pocket_gardens(parent: Node3D) -> void:
	var occupied: Array[Rect2] = []
	_collect_occupied(parent, occupied)
	var surfaces: Array = parent.get_meta("road_surfaces", [])
	var courtyard_paths: Array = []
	var parking_surfaces: Array = []
	var parking_lines: Array = []
	var planters: Array = []
	var foliage: Array = []
	var flowers: Array = []
	var seats: Array = []
	var tree_trunks: Array = []
	var tree_crowns: Array = []
	var parked_cars: Array = []
	var parked_windows: Array = []
	var garage_bodies: Array = []
	var garage_roofs: Array = []
	var garage_doors: Array = []
	var driveways: Array = []
	var count: int = 0
	# Covers the same footprint as the building fill grid (see MAP_MARGIN /
	# the interior fill loop above) - this used to stop at the old, smaller
	# city bounds, so most of the newer, wider city was just bare grass
	# around the buildings with no yards, paths or playgrounds at all.
	# The building-fill pass keeps a 20m clearance box around every route
	# waypoint (corners need room to turn) but that reservation is a plain
	# Rect2, never a real collider, so _collect_occupied() below can't see
	# it - a pocket-garden prop (garage, parked car) could land right on a
	# corner's swept path. Rebuild that same clearance here explicitly.
	var waypoint_clearance: Array[Rect2] = []
	for point in RouteDefinition.waypoints():
		waypoint_clearance.append(Rect2(Vector2(point.x - 20.0, point.z - 20.0), Vector2(40.0, 40.0)))
	for x in range(-280, 971, 22):
		for z in range(-770, 471, 22):
			var pos := Vector3(x, 0, z)
			var lot := Rect2(Vector2(x - 9, z - 9), Vector2(18, 18))
			var blocked: bool = is_road_surface(pos, surfaces, 13.0)
			for rect: Rect2 in waypoint_clearance:
				if lot.intersects(rect):
					blocked = true
					break
			for rect: Rect2 in occupied:
				if blocked:
					break
				if lot.intersects(rect):
					blocked = true
					break
			if blocked:
				continue
			occupied.append(lot)
			var grid_x := int((x + 280) / 22)
			var grid_z := int((z + 770) / 22)
			var variant := (floori(float(grid_x) / 2.0) + floori(float(grid_z) / 2.0)) % 3
			match variant:
				0:
					courtyard_paths.append({"size": Vector3(16, 0.06, 2.2), "position": pos + Vector3(0, 0.03, 0), "y_rot": 0.0})
					courtyard_paths.append({"size": Vector3(2.2, 0.06, 16), "position": pos + Vector3(0, 0.03, 0), "y_rot": 0.0})
					for side: float in [-1.0, 1.0]:
						var bed := pos + Vector3(side * 5.5, 0.22, 5.4)
						planters.append({"size": Vector3(3.5, 0.44, 2.2), "position": bed, "y_rot": 0.0})
						foliage.append({"size": Vector3(3.1, 0.72, 1.8), "position": bed + Vector3(0, 0.54, 0), "y_rot": 0.0})
						_flower_cluster(flowers, bed + Vector3(0, 0.92, 0), grid_x + grid_z)
						seats.append({"size": Vector3(2.4, 0.45, 0.65), "position": pos + Vector3(side * 4.6, 0.225, -2.3), "y_rot": 0.0})
						var tree_pos := pos + Vector3(side * 5.8, 0, -5.5)
						tree_trunks.append({"size": Vector3(0.7, 2.2, 0.7), "position": tree_pos + Vector3(0, 1.1, 0), "y_rot": 0.0})
						_leafy_crown(tree_crowns, tree_pos + Vector3(0, 3.5, 0), 1.8)
						_invisible_collider(parent, tree_pos + Vector3(0, 1.1, 0), Vector3(0.9, 2.2, 0.9))
				1:
					parking_surfaces.append({"size": Vector3(20, 0.08, 20), "position": pos + Vector3(0, 0.04, 0), "y_rot": 0.0})
					for line_x in [-7.0, -3.5, 0.0, 3.5, 7.0]:
						parking_lines.append({"size": Vector3(0.10, 0.015, 15), "position": pos + Vector3(line_x, 0.09, 0), "y_rot": 0.0})
					for car_x in [-5.2, 0.0, 5.2]:
						var car_pos := pos + Vector3(car_x, 0, 1.2)
						parked_cars.append({"size": Vector3(1.75, 0.62, 3.5), "position": car_pos + Vector3(0, 0.42, 0), "y_rot": 0.0})
						parked_windows.append({"size": Vector3(1.38, 0.36, 1.65), "position": car_pos + Vector3(0, 0.85, -0.1), "y_rot": 0.0})
						_invisible_collider(parent, car_pos + Vector3(0, 0.65, 0), Vector3(1.85, 1.3, 3.6))
					_add_yard_driveway(pos, surfaces, driveways)
				2:
					parking_surfaces.append({"size": Vector3(20, 0.08, 20), "position": pos + Vector3(0, 0.04, 0), "y_rot": 0.0})
					for garage_x in [-5.7, 0.0, 5.7]:
						var garage_pos := pos + Vector3(garage_x, 0, 1.8)
						garage_bodies.append({"size": Vector3(5.0, 2.7, 6.5), "position": garage_pos + Vector3(0, 1.35, 0), "y_rot": 0.0})
						garage_roofs.append({"size": Vector3(5.3, 0.20, 6.8), "position": garage_pos + Vector3(0, 2.8, 0), "y_rot": 0.0})
						garage_doors.append({"size": Vector3(4.2, 2.15, 0.10), "position": garage_pos + Vector3(0, 1.1, -3.3), "y_rot": 0.0})
						_invisible_collider(parent, garage_pos + Vector3(0, 1.35, 0), Vector3(5.0, 2.7, 6.5))
					_add_yard_driveway(pos, surfaces, driveways)
			count += 1
	# The 22m/18x18 pass above only lands where a whole courtyard fits - most
	# of a real gap between two 46m-spaced building rows is narrower than
	# that and got rejected outright, so it stayed bare grass with nothing
	# in it at all. A second, finer pass (11m step, 8x8 lot) can't fit a
	# parking lot but can always fit a tree or a bench, so it catches
	# everything the first pass had to skip.
	var fine_count := 0
	for x in range(-280, 971, 11):
		for z in range(-770, 471, 11):
			if (int((x + 280) / 11) + int((z + 770) / 11)) % 2 != 0:
				continue # half-density checkerboard keeps this pass cheap and uncluttered
			var pos := Vector3(x, 0, z)
			var lot := Rect2(Vector2(x - 4, z - 4), Vector2(8, 8))
			var blocked: bool = is_road_surface(pos, surfaces, 8.0)
			for rect: Rect2 in waypoint_clearance:
				if lot.intersects(rect):
					blocked = true
					break
			for rect: Rect2 in occupied:
				if blocked:
					break
				if lot.intersects(rect):
					blocked = true
					break
			if blocked:
				continue
			occupied.append(lot)
			match (int((x + 280) / 11) + int((z + 770) / 11) * 3) % 3:
				0:
					tree_trunks.append({"size": Vector3(0.6, 1.9, 0.6), "position": pos + Vector3(0, 0.95, 0), "y_rot": 0.0})
					_leafy_crown(tree_crowns, pos + Vector3(0, 3.0, 0), 1.55)
				1:
					seats.append({"size": Vector3(2.2, 0.42, 0.6), "position": pos + Vector3(0, 0.21, 0), "y_rot": deg_to_rad(90.0) if int(x) % 22 == 0 else 0.0})
					foliage.append({"size": Vector3(1.6, 0.6, 1.4), "position": pos + Vector3(0, 0.3, 1.6), "y_rot": 0.0})
				_:
					planters.append({"size": Vector3(2.6, 0.4, 1.8), "position": pos + Vector3(0, 0.2, 0), "y_rot": 0.0})
					foliage.append({"size": Vector3(2.2, 0.6, 1.4), "position": pos + Vector3(0, 0.5, 0), "y_rot": 0.0})
					_flower_cluster(flowers, pos + Vector3(0, 0.85, 0), int(x) + int(z))
			fine_count += 1
	parent.set_meta("pocket_gardens", count)
	parent.set_meta("pocket_gardens_fine", fine_count)
	_multimesh_boxes(parent, "CourtyardPaths", CityMaterials.surface("paving"), courtyard_paths)
	_multimesh_boxes(parent, "YardDriveways", CityMaterials.surface("asphalt"), driveways)
	_multimesh_boxes(parent, "LotParking", CityMaterials.surface("asphalt"), parking_surfaces)
	_multimesh_boxes(parent, "ParkingLines", BusVisual.material(Color("c6c5b8")), parking_lines)
	_multimesh_boxes(parent, "GardenBeds", CityMaterials.surface("concrete"), planters)
	_multimesh_boxes(parent, "GardenHedges", BusVisual.material(Color("57704b")), foliage)
	var flower_mat := StandardMaterial3D.new()
	flower_mat.vertex_color_use_as_albedo = true
	flower_mat.roughness = 0.85
	_multimesh_colored_boxes(parent, "GardenFlowers", flower_mat, flowers)
	_multimesh_boxes(parent, "GardenSeats", BusVisual.material(Color("735442")), seats)
	_multimesh_boxes(parent, "CourtyardTrees", BusVisual.material(Color("694c38")), tree_trunks)
	_multimesh_spheres(parent, "CourtyardCrowns", BusVisual.material(Color("4d6d47"), 0.0, 0.95), tree_crowns)
	_multimesh_boxes(parent, "ParkedCarBodies", BusVisual.material(Color("6d7875"), 0.15, 0.42), parked_cars)
	_multimesh_boxes(parent, "ParkedCarWindows", BusVisual.material(Color("34484c"), 0.0, 0.12), parked_windows)
	_multimesh_boxes(parent, "GarageRows", CityMaterials.surface("concrete"), garage_bodies)
	_multimesh_boxes(parent, "GarageRoofs", BusVisual.material(Color("555d5c"), 0.4, 0.55), garage_roofs)
	_multimesh_boxes(parent, "GarageDoors", BusVisual.material(Color("48605e"), 0.5, 0.5), garage_doors)

static func _collect_occupied(node: Node, occupied: Array[Rect2]) -> void:
	if node.name == "GroundBody":
		return
	if node is CollisionShape3D and node.shape is BoxShape3D and node.get_parent() is StaticBody3D:
		var box: AABB = node.global_transform * AABB(-node.shape.size*0.5,node.shape.size)
		occupied.append(Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)).grow(2.0))
	for child in node.get_children():
		_collect_occupied(child,occupied)

static func _collect_major_occupied(node: Node, occupied: Array[Rect2]) -> void:
	if node.name == "GroundBody":
		return
	if node is CollisionShape3D and node.shape is BoxShape3D and node.get_parent() is StaticBody3D:
		var footprint: float = node.shape.size.x * node.shape.size.z
		if footprint >= 8.0:
			var box: AABB = node.global_transform * AABB(-node.shape.size * 0.5, node.shape.size)
			occupied.append(Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z)).grow(2.0))
	for child in node.get_children():
		_collect_major_occupied(child, occupied)

## Occasionally drops one of the real Kenney building models into a filler
## slot instead of another procedural box - breaks up the "identical
## panelka" skyline with a real low-poly shopfront/kiosk silhouette. Returns
## whether it placed (same lot-overlap rules as _place_city_block, so a
## caller can fall back to the procedural box on false).
static func _place_variety_building(parent: Node3D, pos: Vector3, size: Vector3, reserved: Array[Rect2], occupied: Array[Rect2], rng: RandomNumberGenerator) -> bool:
	var lot := Rect2(Vector2(pos.x-size.x/2,pos.z-size.z/2),Vector2(size.x,size.z)).grow(2.0)
	for rect in reserved:
		if lot.intersects(rect):
			return false
	for rect in occupied:
		if lot.intersects(rect):
			return false
	occupied.append(lot)
	var model: String = SHOP_MODELS[rng.randi() % SHOP_MODELS.size()]
	var y_rot: float = [0.0, PI * 0.5, PI, PI * 1.5][rng.randi() % 4]
	_model_prop(parent, model, pos, size.x, y_rot)
	return true

static func _place_city_block(parent: Node3D, pos: Vector3, size: Vector3, reserved: Array[Rect2], occupied: Array[Rect2], entries: Array, rng: RandomNumberGenerator) -> void:
	var lot := Rect2(Vector2(pos.x-size.x/2,pos.z-size.z/2),Vector2(size.x,size.z)).grow(2.0)
	for rect in reserved:
		if lot.intersects(rect):
			return
	for rect in occupied:
		if lot.intersects(rect):
			return
	occupied.append(lot)
	# A wider, less uniform palette than the original five tones - panel
	# blocks, brick and a couple of cooler modern-renovation colors mixed in
	# so a long street doesn't read as the same building copy-pasted.
	# Muted a notch darker - against a grey overcast sky the original palette
	# (tuned brighter, before the ambient/sun pass below was dialed back)
	# read as too light, like the buildings were lit from a sun that wasn't
	# actually there.
	var colors := [
		Color("968f80"), Color("7c8988"), Color("978570"), Color("7f8390"), Color("9c9580"),
		Color("8e6249"), Color("737d70"), Color("a68d63"), Color("6b747e"), Color("947a67"),
	]
	var center := pos+Vector3(0,size.y/2,0)
	entries.append({"size":size,"position":center,"y_rot":0.0,"color":colors[rng.randi()%colors.size()]})
	_invisible_collider(parent,center,size)


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
	var signs: Array[Vector3] = []
	for child in parent.get_children():
		if child is TrafficLightProp or child.name.begins_with("Sign_"):
			signs.append(child.position)
	var transforms: Array[Transform3D] = []
	var solid_positions: Array[Vector3] = []
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
				if rng.randf() > 0.22:
					continue
				var dist: float = rng.randf_range(7.0, 12.0)
				var pos: Vector3 = base_pos + perp * side * dist
				var hides_sign := false
				for sign_pos in signs:
					if pos.distance_to(sign_pos)<4.0:
						hides_sign=true
						break
				if not hides_sign and _clear_of_road(pos, Vector3(1,1,1), waypoints) and not is_road_surface(pos, parent.get_meta("road_surfaces", []), 4.5):
					transforms.append(Transform3D(Basis(), pos + Vector3(0, 0.8, 0)))
					solid_positions.append(pos + Vector3(0, 1.15, 0))

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

	# A second, smaller lobe offset from center on every tree - one perfect
	# sphere per tree reads as a lollipop; two overlapping, unevenly sized
	# ones read as an actual irregular canopy.
	var foliage2_mm := MultiMesh.new()
	foliage2_mm.transform_format = MultiMesh.TRANSFORM_3D
	foliage2_mm.mesh = foliage_mesh
	foliage2_mm.use_colors = true
	foliage2_mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		var base2: Transform3D = transforms[i]
		var off := Vector3(rng.randf_range(-1.1, 1.1), rng.randf_range(-0.2, 0.6), rng.randf_range(-1.1, 1.1))
		var s := rng.randf_range(0.45, 0.7)
		foliage2_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s, s * rng.randf_range(0.9, 1.2), s)), base2.origin + Vector3(0, 2.15, 0) + off))
		foliage2_mm.set_instance_color(i, Color("546742").lerp(Color("879064"), rng.randf()).srgb_to_linear())
	var foliage2_inst := MultiMeshInstance3D.new()
	foliage2_inst.multimesh = foliage2_mm
	foliage2_inst.material_override = foliage_mat
	foliage2_inst.name = "TreeFoliageLobes"
	parent.add_child(foliage2_inst)

	# MultiMesh trees have no per-instance collision. Add cheap primitive
	# trunks so the player cannot cut through the new greenery or use it as a
	# shortcut around the road rules.
	for solid_pos in solid_positions:
		_invisible_collider(parent, solid_pos, Vector3(1.15, 2.3, 1.15))

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
