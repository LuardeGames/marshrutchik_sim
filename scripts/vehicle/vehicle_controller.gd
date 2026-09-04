extends CharacterBody3D
class_name VehicleController
## Arcade-style marshrutka controller: not a realistic car sim, but with
## enough weight/inertia/lean to feel like driving a minibus.

signal doors_toggled(open: bool)
signal harsh_event(kind: String, strength: float)

@export var definition: VehicleDefinition

var max_speed: float = 15.0
var acceleration: float = 6.0
var brake_force: float = 12.0
var capacity: int = 10

var speed: float = 0.0 # signed, forward positive
var steer_angle: float = 0.0
var doors_open: bool = false
var passengers_aboard: int = 0

const STEER_RATE := 2.4
const STEER_MAX := 0.6
const MAX_TURN_RATE := 1.15 # rad/s at full lock, low speed (~66°/s)
const GRAVITY := 18.0
const BODY_LEAN_MAX := 0.12
const COMFORT_CHECK_COOLDOWN := 0.35
const COLLISION_COOLDOWN := 0.6
## Single source of truth for "stopped enough to work the doors" - used by
## the vehicle itself, RouteManager (stop-arrival check) and PassengerManager
## (board/alight permission). These three used to disagree (1.5 / 0.35 / 0.35
## m/s), so the doors would visibly open while still rolling just enough
## that boarding silently never triggered - looked like "0 passengers,
## always" even though the boarding code itself was fine.
const DOOR_SPEED_LIMIT := 1.0

var _body_mesh: Node3D
var _wheel_meshes: Array[MeshInstance3D] = []
var _brake_light_mat: StandardMaterial3D
var _headlight: SpotLight3D
var _exhaust_particles: GPUParticles3D
var _dust_particles: GPUParticles3D

var _prev_speed: float = 0.0
var _comfort_cooldown: float = 0.0
var _collision_cooldown: float = 0.0
var _was_on_floor := true

func _ready() -> void:
	add_to_group("vehicle")
	collision_layer = 2
	collision_mask = 1 | 4 # world + competitor
	if definition == null:
		definition = VehicleCatalog.build()[0]
	_apply_definition()
	_build_visual()
	AudioManager.set_engine_running(true)

func _apply_definition() -> void:
	var engine_mult := EconomyManager.get_upgrade_multiplier("engine")
	var brake_mult := EconomyManager.get_upgrade_multiplier("brakes")
	max_speed = definition.base_max_speed * engine_mult
	acceleration = definition.base_acceleration * engine_mult
	brake_force = definition.base_brake_force * brake_mult
	capacity = definition.base_capacity + EconomyManager.get_extra_capacity()

func _physics_process(delta: float) -> void:
	_handle_input(delta)
	_apply_gravity(delta)
	_move(delta)
	_update_visuals(delta)
	_update_comfort(delta)
	_update_audio()

func _handle_input(delta: float) -> void:
	var throttle := InputState.get_throttle()
	var brake := InputState.get_brake()
	var steer_in := InputState.get_steer()
	var handbrake := InputState.get_handbrake()

	if throttle > 0.0 and brake <= 0.0:
		speed += acceleration * delta
	elif brake > 0.0:
		if speed > 0.0:
			speed -= brake_force * delta
		else:
			speed -= (acceleration * 0.6) * delta
	else:
		# engine braking / rolling friction
		speed = move_toward(speed, 0.0, acceleration * 0.5 * delta)

	if handbrake:
		speed = move_toward(speed, 0.0, brake_force * 1.6 * delta)

	speed = clamp(speed, -max_speed * 0.4, max_speed)

	var speed_ratio: float = clamp(abs(speed) / max(max_speed, 0.01), 0.0, 1.0)
	var steer_authority: float = lerp(0.35, 1.0, 1.0 - speed_ratio * 0.5)
	steer_angle = move_toward(steer_angle, steer_in * STEER_MAX, STEER_RATE * delta)

	if abs(speed) > 0.2:
		var turn_dir := 1.0 if speed >= 0 else -1.0
		# steer_angle is a smoothed fraction of full lock (-STEER_MAX..STEER_MAX);
		# normalize it to get an actual, tunable angular speed in rad/s instead
		# of re-multiplying by STEER_RATE (already used above) plus a flat x6
		# fudge factor - that combo spun the bus at ~500°/s, basically a donut
		# at any real speed, which is what was flinging it into buildings.
		var turn_fraction: float = steer_angle / STEER_MAX
		rotate_y(-turn_fraction * MAX_TURN_RATE * turn_dir * steer_authority * delta)

	if InputState.consume_doors_pressed():
		_toggle_doors()

func _toggle_doors() -> void:
	if abs(speed) > DOOR_SPEED_LIMIT:
		EventBus.notification.emit("Остановите маршрутку, чтобы открыть двери!", 1.5)
		return
	doors_open = not doors_open
	doors_toggled.emit(doors_open)
	AudioManager.play_doors()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5

func _move(delta: float) -> void:
	var forward := -global_transform.basis.z
	var horizontal := forward * speed
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	var was_on_floor := is_on_floor()
	move_and_slide()

	# Collision response: only react to walls/obstacles, not the floor -
	# move_and_slide() reports the ground itself as a "slide collision" every
	# frame while driving, so floor-ish normals (mostly pointing up) must be
	# ignored or the bus would brake to a crawl on every physics tick.
	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		if collider == null or collider == self:
			continue
		var normal := col.get_normal()
		if normal.dot(Vector3.UP) > 0.6:
			continue # floor/ramp contact, not a real impact
		var impact_strength: float = clamp(abs(speed) / max_speed, 0.0, 1.0)
		if impact_strength > 0.18 and _collision_cooldown <= 0.0:
			GameManager.register_collision(impact_strength)
			harsh_event.emit("collision", impact_strength)
			_collision_cooldown = COLLISION_COOLDOWN
		speed *= 0.35
		break

func _update_visuals(delta: float) -> void:
	if _body_mesh:
		var target_lean: float = clamp(-steer_angle * 1.4, -BODY_LEAN_MAX, BODY_LEAN_MAX)
		_body_mesh.rotation.z = lerp(_body_mesh.rotation.z, target_lean, 6.0 * delta)
		var pitch_target: float = clamp((_prev_speed - speed) * 0.02, -0.05, 0.08)
		_body_mesh.rotation.x = lerp(_body_mesh.rotation.x, pitch_target, 4.0 * delta)
	for w in _wheel_meshes:
		w.rotate_x(-speed * delta * 1.2)
	if _brake_light_mat:
		var braking := InputState.get_brake() > 0.0 or InputState.get_handbrake()
		_brake_light_mat.emission_energy_multiplier = 3.0 if braking else 0.3
	if _exhaust_particles:
		_exhaust_particles.emitting = abs(speed) < max_speed * 0.15
	if _dust_particles:
		_dust_particles.emitting = abs(speed) > max_speed * 0.5

func _update_comfort(delta: float) -> void:
	_comfort_cooldown = max(0.0, _comfort_cooldown - delta)
	_collision_cooldown = max(0.0, _collision_cooldown - delta)
	var suspension_mult: float = EconomyManager.get_upgrade_multiplier("suspension")
	var safe_delta: float = max(delta, 0.001)
	var brake_rate: float = (_prev_speed - speed) / safe_delta
	if brake_rate > 14.0 and _comfort_cooldown <= 0.0:
		GameManager.modify_comfort(-4.0 * suspension_mult)
		harsh_event.emit("hard_brake", clamp(brake_rate / 30.0, 0.0, 1.0))
		AudioManager.play_brake()
		_comfort_cooldown = COMFORT_CHECK_COOLDOWN
	if abs(steer_angle) > STEER_MAX * 0.85 and abs(speed) > max_speed * 0.5 and _comfort_cooldown <= 0.0:
		GameManager.modify_comfort(-2.5 * suspension_mult)
		harsh_event.emit("sharp_turn", 0.5)
		_comfort_cooldown = COMFORT_CHECK_COOLDOWN
	if abs(speed) > max_speed * 0.92:
		# gentle continuous drain for sustained extreme-speed driving - was
		# previously a flat per-frame penalty (-0.3 every physics tick,
		# ~-18/s) which crashed comfort to 0 within a few seconds of just
		# driving fast in a straight line. Scaled by delta and much softer.
		GameManager.modify_comfort(-0.6 * delta)
	if abs(speed) < max_speed * 0.6 and abs(steer_angle) < STEER_MAX * 0.3:
		GameManager.modify_comfort(0.4 * delta)
	_prev_speed = speed

func _update_audio() -> void:
	AudioManager.set_engine_rpm(clamp(abs(speed) / max(max_speed, 0.01), 0.0, 1.0))

func get_speed_kmh() -> float:
	return abs(speed) * 3.6

func speed_ratio() -> float:
	return clamp(abs(speed) / max(max_speed, 0.01), 0.0, 1.0)

# ---------------------------------------------------------------------------
# Visual build - real low-poly model (Kenney Car Kit, CC0) when available,
# procedural boxes as a fallback for any vehicle without one.
# ---------------------------------------------------------------------------

func _build_visual() -> void:
	if definition.model_path != "" and ResourceLoader.exists(definition.model_path):
		_build_visual_from_model()
	else:
		_build_visual_procedural()

func _build_visual_from_model() -> void:
	var d := definition
	# _body_mesh is a plain wrapper (kept at identity rotation so the
	# lean/pitch tween in _update_visuals and the headlight/brake-light
	# placement below both use the normal "front = -Z" convention). The
	# actual glTF root goes one level deeper since IT needs a 180° flip
	# (Kenney's own wheel-front-*/wheel-back-* naming shows the model's
	# front faces local +Z) plus non-uniform scaling to our target size.
	_body_mesh = Node3D.new()
	_body_mesh.name = "BodyVisual"
	add_child(_body_mesh)

	var model_scene: PackedScene = load(definition.model_path)
	var model_root: Node3D = model_scene.instantiate()
	model_root.name = "Model"
	_body_mesh.add_child(model_root)

	var raw_aabb = _collect_visual_aabb(model_root, model_root)
	var raw_size: Vector3 = raw_aabb.size if raw_aabb != null else Vector3(d.width, d.height, d.length)
	model_root.scale = Vector3(
		d.width / max(raw_size.x, 0.01),
		d.height / max(raw_size.y, 0.01),
		d.length / max(raw_size.z, 0.01)
	)
	model_root.rotation.y = PI

	_wheel_meshes.clear()
	_recolor_and_collect_wheels(model_root)

	_build_lights_and_extras(d)

## Paints the body/door meshes a single flat color and collects the wheel
## meshes so _update_visuals can spin them.
##
## Kenney's kit ships ONE shared "colormap" material/texture across the
## whole model - the body's paint pattern (stripes, cab panel, etc.) comes
## entirely from where each face's UVs sample that palette image, not from
## separate materials. Duplicating that material and only changing
## albedo_color just tints the existing multi-color pattern (still visibly
## striped), so this instead drops the texture and uses a flat
## StandardMaterial3D for a properly uniform paint job - wheels keep the
## original textured material so tires/rims stay dark.
func _recolor_and_collect_wheels(node: Node) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		if mi.name.begins_with("wheel-"):
			_wheel_meshes.append(mi)
		elif mi.name == "body" or mi.name.begins_with("door-"):
			var mat := StandardMaterial3D.new()
			mat.albedo_color = definition.body_color
			mat.roughness = 0.5
			mat.metallic = 0.15
			mi.set_surface_override_material(0, mat)
	for c in node.get_children():
		_recolor_and_collect_wheels(c)

## Headlights, brake lights, collision shape and particle emitters - shared
## between the real-model and procedural-box visual builds so both drive,
## collide and light up identically regardless of which body they wear.
func _build_lights_and_extras(d: VehicleDefinition) -> void:
	var headlight_mat := StandardMaterial3D.new()
	headlight_mat.albedo_color = Color(1, 1, 0.9)
	headlight_mat.emission_enabled = true
	headlight_mat.emission = Color(1, 1, 0.8)
	headlight_mat.emission_energy_multiplier = 2.0
	for side in [-1, 1]:
		var hl := MeshInstance3D.new()
		var hl_mesh := BoxMesh.new()
		hl_mesh.size = Vector3(0.25, 0.18, 0.05)
		hl.mesh = hl_mesh
		hl.position = Vector3(side * d.width * 0.35, d.height * 0.32, -d.length / 2.0 - 0.06)
		hl.material_override = headlight_mat
		_body_mesh.add_child(hl)

	_headlight = SpotLight3D.new()
	_headlight.position = Vector3(0, d.height * 0.32, -d.length / 2.0 - 0.2)
	_headlight.spot_range = 18.0
	_headlight.spot_angle = 35.0
	_headlight.light_energy = 1.2
	_headlight.light_color = Color(1, 1, 0.9)
	_body_mesh.add_child(_headlight)

	_brake_light_mat = StandardMaterial3D.new()
	_brake_light_mat.albedo_color = Color(1, 0.1, 0.1)
	_brake_light_mat.emission_enabled = true
	_brake_light_mat.emission = Color(1, 0.05, 0.05)
	_brake_light_mat.emission_energy_multiplier = 0.3
	for side in [-1, 1]:
		var bl := MeshInstance3D.new()
		var bl_mesh := BoxMesh.new()
		bl_mesh.size = Vector3(0.3, 0.2, 0.05)
		bl.mesh = bl_mesh
		bl.position = Vector3(side * d.width * 0.35, d.height * 0.35, d.length / 2.0 + 0.05)
		bl.material_override = _brake_light_mat
		_body_mesh.add_child(bl)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(d.width, d.height * 0.85, d.length)
	col.shape = shape
	col.position = Vector3(0, d.height * 0.5, 0)
	add_child(col)

	_exhaust_particles = _make_particles(Color(0.6, 0.6, 0.6, 0.5), 0.15, 6)
	_exhaust_particles.position = Vector3(d.width * 0.3, 0.35, d.length / 2.0 + 0.1)
	add_child(_exhaust_particles)

	_dust_particles = _make_particles(Color(0.7, 0.6, 0.4, 0.4), 0.25, 10)
	_dust_particles.position = Vector3(0, 0.15, d.length / 2.0)
	add_child(_dust_particles)

## Merges the local-space AABBs of every VisualInstance3D under `node`,
## expressed relative to `root_node`. AABB is a value type in GDScript so
## this returns a nullable result (null = nothing found yet) instead of
## mutating a passed-in accumulator.
func _collect_visual_aabb(node: Node, root_node: Node3D):
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

func _build_visual_procedural() -> void:
	var d := definition
	_body_mesh = Node3D.new()
	_body_mesh.name = "BodyVisual"
	add_child(_body_mesh)

	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(d.width, d.height * 0.62, d.length)
	body.mesh = body_mesh
	body.position = Vector3(0, d.height * 0.42, 0)
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = d.body_color
	body.material_override = body_mat
	_body_mesh.add_child(body)

	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(d.width * 0.94, d.height * 0.4, d.length * 0.86)
	roof.mesh = roof_mesh
	roof.position = Vector3(0, d.height * 0.82, -d.length * 0.02)
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = d.body_color.lightened(0.12)
	roof.material_override = roof_mat
	_body_mesh.add_child(roof)

	# windshield / windows band
	var windows := MeshInstance3D.new()
	var win_mesh := BoxMesh.new()
	win_mesh.size = Vector3(d.width * 0.98, d.height * 0.24, d.length * 0.92)
	windows.mesh = win_mesh
	windows.position = Vector3(0, d.height * 0.66, 0)
	var win_mat := StandardMaterial3D.new()
	win_mat.albedo_color = Color(0.55, 0.75, 0.85, 0.85)
	win_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	windows.material_override = win_mat
	_body_mesh.add_child(windows)

	# front bumper / grille accent
	var grille := MeshInstance3D.new()
	var grille_mesh := BoxMesh.new()
	grille_mesh.size = Vector3(d.width * 0.9, d.height * 0.2, 0.15)
	grille.mesh = grille_mesh
	grille.position = Vector3(0, d.height * 0.28, -d.length / 2.0 - 0.05)
	var grille_mat := StandardMaterial3D.new()
	grille_mat.albedo_color = d.accent_color
	grille.material_override = grille_mat
	_body_mesh.add_child(grille)

	# route sign plate on the front
	var plate := MeshInstance3D.new()
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(d.width * 0.4, 0.22, 0.05)
	plate.mesh = plate_mesh
	plate.position = Vector3(0, d.height * 0.58, -d.length / 2.0 - 0.06)
	var plate_mat := StandardMaterial3D.new()
	plate_mat.albedo_color = Color(0.95, 0.85, 0.1)
	plate_mat.emission_enabled = true
	plate_mat.emission = Color(0.6, 0.5, 0.05)
	plate.material_override = plate_mat
	_body_mesh.add_child(plate)

	# headlights
	var headlight_mat := StandardMaterial3D.new()
	headlight_mat.albedo_color = Color(1, 1, 0.9)
	headlight_mat.emission_enabled = true
	headlight_mat.emission = Color(1, 1, 0.8)
	headlight_mat.emission_energy_multiplier = 2.0
	for side in [-1, 1]:
		var hl := MeshInstance3D.new()
		var hl_mesh := BoxMesh.new()
		hl_mesh.size = Vector3(0.25, 0.18, 0.05)
		hl.mesh = hl_mesh
		hl.position = Vector3(side * d.width * 0.35, d.height * 0.32, -d.length / 2.0 - 0.06)
		hl.material_override = headlight_mat
		_body_mesh.add_child(hl)

	_headlight = SpotLight3D.new()
	_headlight.position = Vector3(0, d.height * 0.32, -d.length / 2.0 - 0.2)
	_headlight.spot_range = 18.0
	_headlight.spot_angle = 35.0
	_headlight.light_energy = 1.2
	_headlight.light_color = Color(1, 1, 0.9)
	_body_mesh.add_child(_headlight)

	# brake lights (rear)
	_brake_light_mat = StandardMaterial3D.new()
	_brake_light_mat.albedo_color = Color(1, 0.1, 0.1)
	_brake_light_mat.emission_enabled = true
	_brake_light_mat.emission = Color(1, 0.05, 0.05)
	_brake_light_mat.emission_energy_multiplier = 0.3
	for side in [-1, 1]:
		var bl := MeshInstance3D.new()
		var bl_mesh := BoxMesh.new()
		bl_mesh.size = Vector3(0.3, 0.2, 0.05)
		bl.mesh = bl_mesh
		bl.position = Vector3(side * d.width * 0.35, d.height * 0.35, d.length / 2.0 + 0.05)
		bl.material_override = _brake_light_mat
		_body_mesh.add_child(bl)

	# door (driver side visual, cosmetic)
	var door := MeshInstance3D.new()
	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(0.05, d.height * 0.55, d.length * 0.32)
	door.mesh = door_mesh
	door.position = Vector3(d.width / 2.0 + 0.02, d.height * 0.42, d.length * 0.12)
	var door_mat := StandardMaterial3D.new()
	door_mat.albedo_color = d.accent_color
	door.material_override = door_mat
	_body_mesh.add_child(door)

	# wheels
	var wheel_mat := StandardMaterial3D.new()
	wheel_mat.albedo_color = Color(0.08, 0.08, 0.08)
	var wheel_positions := [
		Vector3(d.width / 2.0 + 0.05, 0.4, -d.length * 0.3),
		Vector3(-d.width / 2.0 - 0.05, 0.4, -d.length * 0.3),
		Vector3(d.width / 2.0 + 0.05, 0.4, d.length * 0.32),
		Vector3(-d.width / 2.0 - 0.05, 0.4, d.length * 0.32),
	]
	for pos in wheel_positions:
		var wheel := MeshInstance3D.new()
		var wheel_mesh := CylinderMesh.new()
		wheel_mesh.top_radius = 0.42
		wheel_mesh.bottom_radius = 0.42
		wheel_mesh.height = 0.32
		wheel.mesh = wheel_mesh
		wheel.rotation.z = PI / 2.0
		wheel.position = pos
		wheel.material_override = wheel_mat
		add_child(wheel)
		_wheel_meshes.append(wheel)

	# body collision shape
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(d.width, d.height * 0.7, d.length)
	col.shape = shape
	col.position = Vector3(0, d.height * 0.42, 0)
	add_child(col)

	# exhaust smoke
	_exhaust_particles = _make_particles(Color(0.6, 0.6, 0.6, 0.5), 0.15, 6)
	_exhaust_particles.position = Vector3(d.width * 0.3, 0.35, d.length / 2.0 + 0.1)
	add_child(_exhaust_particles)

	# dust when driving fast
	_dust_particles = _make_particles(Color(0.7, 0.6, 0.4, 0.4), 0.25, 10)
	_dust_particles.position = Vector3(0, 0.15, d.length / 2.0)
	add_child(_dust_particles)

func _make_particles(color: Color, size: float, amount: int) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = 0.9
	particles.emitting = false
	particles.one_shot = false
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 1)
	mat.spread = 30.0
	mat.gravity = Vector3(0, 0.3, 0)
	mat.initial_velocity_min = 0.3
	mat.initial_velocity_max = 1.0
	mat.scale_min = size * 0.6
	mat.scale_max = size
	mat.color = color
	particles.process_material = mat
	var mesh := SphereMesh.new()
	mesh.radius = 0.15
	mesh.height = 0.3
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = color
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = pmat
	particles.draw_pass_1 = mesh
	return particles
