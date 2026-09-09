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

var boarding_manager: PassengerManager
var _passenger_door: Node3D
var _door_origin: Vector3
var _body_mesh: Node3D
var _wheel_meshes: Array[MeshInstance3D] = []
var _brake_light_mat: StandardMaterial3D
var _headlight: SpotLight3D
var _exhaust_particles: GPUParticles3D
var _dust_particles: GPUParticles3D

var _horn_cooldown: float = 0.0
var _door_warning_cooldown: float = 0.0
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
	AudioManager.set_vehicle_type(definition.modern)

func _apply_definition() -> void:
	var engine_mult := EconomyManager.get_upgrade_multiplier("engine")
	var brake_mult := EconomyManager.get_upgrade_multiplier("brakes")
	# Damage gently affects the way the bus feels without making a single
	# collision a softlock. Repairs in the garage restore the full values.
	var condition_mult := lerpf(0.72, 1.0, SaveManager.get_vehicle_condition() / 100.0)
	max_speed = definition.base_max_speed * engine_mult * condition_mult
	acceleration = definition.base_acceleration * engine_mult * condition_mult
	brake_force = definition.base_brake_force * brake_mult
	capacity = definition.base_capacity + EconomyManager.get_extra_capacity()

func _physics_process(delta: float) -> void:
	if GameManager.state == GameManager.State.RESULTS:
		speed = 0.0
		AudioManager.set_engine_running(false)
		return
	_handle_input(delta)
	_apply_gravity(delta)
	_move(delta)
	_update_visuals(delta)
	_update_comfort(delta)
	_update_audio()

func _handle_input(delta: float) -> void:
	var throttle := 0.0 if doors_open else InputState.get_throttle()
	var brake := InputState.get_brake()
	if doors_open:
		speed = move_toward(speed, 0.0, brake_force * delta)
		brake = 0.0
	var steer_in := InputState.get_steer()
	var handbrake := InputState.get_handbrake()

	if throttle > 0.0 and brake <= 0.0:
		speed += acceleration * delta
	elif brake > 0.0:
		if speed > 0.0:
			speed = maxf(0.0, speed - brake_force * delta)
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

	if Input.is_physical_key_pressed(KEY_H) and _horn_cooldown <= 0.0:
		AudioManager.play_horn(definition.modern)
		_horn_cooldown=0.7
	_horn_cooldown=maxf(0.0,_horn_cooldown-delta)
	_door_warning_cooldown=maxf(0.0,_door_warning_cooldown-delta)
	if InputState.consume_doors_pressed():
		_toggle_doors()

func _toggle_doors() -> void:
	if doors_open and boarding_manager and boarding_manager.boarding_pending > 0:
		EventBus.notification.emit("Подождите, пассажиры ещё садятся", 1.5)
		return
	if abs(speed) > DOOR_SPEED_LIMIT:
		if _door_warning_cooldown <= 0.0:
			GameManager.register_rule_violation("moving_doors", 30, 3.0, "Нельзя открывать двери на ходу · штраф 30 ₽")
			_door_warning_cooldown = 2.0
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
	if _passenger_door:
		var target := _door_origin + (Vector3(0.12,0,0.86) if doors_open and not definition.modern else Vector3.ZERO)
		_passenger_door.rotation.y=lerpf(_passenger_door.rotation.y, -1.15 if doors_open and definition.modern else 0.0,minf(delta*6.0,1.0))
		_passenger_door.position = _passenger_door.position.lerp(target, minf(delta*6.0,1.0))
	if _body_mesh:
		var target_lean: float = clamp(-steer_angle * 1.4, -BODY_LEAN_MAX, BODY_LEAN_MAX)
		_body_mesh.rotation.z = lerp(_body_mesh.rotation.z, target_lean, 6.0 * delta)
		var pitch_target: float = clamp((_prev_speed - speed) * 0.02, -0.05, 0.08)
		_body_mesh.rotation.x = lerp(_body_mesh.rotation.x, pitch_target, 4.0 * delta)
	for w in _wheel_meshes:
		w.rotate_object_local(Vector3.UP, -speed * delta / (0.48 if definition.modern else 0.37))
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
	_body_mesh = Node3D.new()
	_body_mesh.name = "BodyVisual"
	add_child(_body_mesh)
	var parts := BusVisual.build(_body_mesh, definition)
	_wheel_meshes.assign(parts.wheels)
	_passenger_door = parts.door
	_door_origin = parts.door_origin
	_build_lights_and_extras(definition)

func _build_lights_and_extras(d: VehicleDefinition) -> void:
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
	col.position = Vector3(0, d.height * 0.425 - 0.13, 0)
	add_child(col)

	_exhaust_particles = _make_particles(Color(0.6, 0.6, 0.6, 0.5), 0.15, 6)
	_exhaust_particles.position = Vector3(d.width * 0.3, 0.35, d.length / 2.0 + 0.1)
	add_child(_exhaust_particles)

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

func get_door_position() -> Vector3:
	return to_global(_door_origin + Vector3(0.3,0,0))

func _exit_tree() -> void:
	AudioManager.set_engine_running(false)
