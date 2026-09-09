extends Node
class_name PassengerManager
## Owns passenger spawning, boarding, riding and alighting. Deliberately
## avoids navmesh/AI - passengers just walk in straight lines to/from the
## vehicle's door, which reads perfectly well at arcade speed.
##
## Waiting passengers are spawned as real, standing NPCs right at their stop
## as soon as the trip starts (not conjured out of thin air when the bus
## happens to arrive), so the player can actually see who they're about to
## pick up - and see the group get smaller if the competitor beats them
## there.

var vehicle: VehicleController
var route_manager: RouteManager
var world_parent: Node3D
var stop_ids_in_order: Array[int] = []
var _stops_by_id: Dictionary = {}

# stop_id -> Array[Dictionary] {archetype, fare, destination_stop_id, node}
var waiting: Dictionary = {}
# Dictionary {archetype, fare, destination_stop_id} for onboard passengers
var aboard: Array[Dictionary] = []

var _processed_stop: StopArea = null
var boarding_pending: int = 0
var _boost_boarding_speed: float = 1.0
var _last_dialogue_time := -100.0

func setup(vehicle_ref: VehicleController, route_mgr: RouteManager, parent: Node3D, stops_order: Array[int]) -> void:
	vehicle = vehicle_ref
	route_manager = route_mgr
	world_parent = parent
	stop_ids_in_order = stops_order
	for stop in route_manager.stops:
		_stops_by_id[stop.stop_id] = stop
	vehicle.doors_toggled.connect(_on_doors_toggled)
	route_manager.stop_arrived.connect(_on_stop_arrived)
	for stop in route_manager.stops:
		_generate_waiting(stop.stop_id)
	_boost_boarding_speed = EconomyManager.get_upgrade_multiplier("doors")

func _generate_waiting(stop_id: int) -> void:
	if stop_id == stop_ids_in_order[stop_ids_in_order.size() - 1]:
		return # nobody waits to board at the final terminus
	var stop: StopArea = _stops_by_id.get(stop_id)
	var list: Array = waiting.get(stop_id, [])
	var multiplier: float = float(GameManager.daily_challenge.get("passenger_multiplier", 1.0))
	var count: int = clampi(int(round(float(randi_range(7, 12)) * multiplier)), 5, 16)
	for i in range(count):
		var archetype := PassengerCatalog.random_archetype()
		var dest := _pick_destination(stop_id)
		var fare: int = int(round(float(archetype.base_fare + randi_range(-archetype.fare_variance, archetype.fare_variance)) * float(GameManager.daily_challenge.get("fare_multiplier", 1.0))))
		var node := _spawn_standing_passenger(stop, archetype, i, count)
		list.append({"archetype": archetype, "fare": fare, "destination_stop_id": dest, "node": node})
	waiting[stop_id] = list

## Spawns a passenger standing near the stop's shelter, arranged in a loose
## little queue rather than one on top of the other.
func _spawn_standing_passenger(stop: StopArea, archetype: PassengerArchetype, index: int, total: int) -> Passenger:
	var p := Passenger.new()
	world_parent.add_child(p)
	p.setup(archetype)
	var lane_offset: float = (index - (total - 1) / 2.0) * 1.3
	p.global_position = stop.to_global(Vector3(3.5 + randf_range(-0.2, 0.2), 0.25, lane_offset))
	var face_target := stop.global_position
	face_target.y = p.global_position.y
	if face_target.distance_to(p.global_position) > 0.05:
		p.look_at(face_target, Vector3.UP)
	return p

func _pick_destination(from_stop_id: int) -> int:
	var idx := stop_ids_in_order.find(from_stop_id)
	var choices: Array[int] = []
	for i in range(idx + 1, stop_ids_in_order.size()):
		choices.append(stop_ids_in_order[i])
	if choices.is_empty():
		return stop_ids_in_order[stop_ids_in_order.size() - 1]
	return choices[randi() % choices.size()]

func get_waiting_count(stop_id: int) -> int:
	return (waiting.get(stop_id, []) as Array).size()

## Called by CompetitorAI when it reaches a stop before the player.
func competitor_take_passengers(stop_id: int) -> int:
	var list: Array = waiting.get(stop_id, [])
	if list.is_empty():
		return 0
	var take: int = min(maxi(0, list.size()-2), randi_range(1, 3))
	for i in range(take):
		var entry: Dictionary = list.pop_front()
		_despawn_taken_passenger(entry.get("node"))
	waiting[stop_id] = list
	EventBus.competitor_took_passengers.emit(stop_id, take)
	return take

## Shrinks & fades a standing passenger out when the competitor picks them
## up instead of the player, so the queue visibly gets shorter.
func _despawn_taken_passenger(node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var p: Passenger = node
	var tw: Tween = p.create_tween()
	tw.tween_property(p, "scale", Vector3.ZERO, 0.3)
	tw.tween_callback(p.queue_free)

func _on_stop_arrived(stop: StopArea, quality: String) -> void:
	var bonus := 25 if quality == "good" else 8
	EconomyManager.add_stop_bonus(bonus)
	AudioManager.play_stop_success()
	var msg := "Хорошая остановка! +%d ₽" % bonus if quality == "good" else "Остановились далековато... +%d ₽" % bonus
	EventBus.notification.emit(msg, 2.0)
	EventBus.stop_reached.emit(stop.stop_id, quality)

func _on_doors_toggled(open: bool) -> void:
	if not open:
		if _processed_stop != null:
			var finished := _processed_stop
			_processed_stop = null
			get_tree().create_timer(0.3).timeout.connect(func(): _maybe_advance(finished))
		return
	var stop := route_manager.player_in_zone
	var next_stop := route_manager.get_next_stop()
	if stop == null:
		GameManager.register_rule_violation("illegal_door", 20, 2.0, "Двери открывают только на остановке · штраф 20 ₽")
		EventBus.notification.emit("Здесь нет остановки - подъедьте к следующей: %s" % (next_stop.stop_name if next_stop else "?"), 2.0)
		return
	if stop != next_stop:
		GameManager.register_rule_violation("wrong_stop", 25, 2.0, "Это не ваша остановка · штраф 25 ₽")
		EventBus.notification.emit("Это не ваша остановка! Нужна: %s" % (next_stop.stop_name if next_stop else "?"), 2.0)
		return
	if not route_manager.can_service_stop(stop):
		GameManager.register_rule_violation("bad_parking", 25, 2.0, "Подъедьте ближе к остановочному карману · штраф 25 ₽")
		EventBus.notification.emit("Остановитесь в жёлтом кармане, чтобы принять пассажиров", 2.0)
		return
	if abs(vehicle.speed) > VehicleController.DOOR_SPEED_LIMIT:
		return # vehicle_controller already told the player to stop first
	_processed_stop = stop
	_process_stop(stop)

func _maybe_advance(stop: StopArea) -> void:
	if route_manager.get_next_stop() == stop:
		route_manager.advance_to_next_stop()

func _process_stop(stop: StopArea) -> void:
	_alight_passengers(stop)
	_board_passengers(stop)

func _board_passengers(stop: StopArea) -> void:
	var list: Array = waiting.get(stop.stop_id, [])
	var free_seats: int = vehicle.capacity - vehicle.passengers_aboard
	var boarding_count: int = min(list.size(), free_seats)
	for i in range(boarding_count):
		var entry: Dictionary = list.pop_front()
		_send_passenger_to_board(entry)
	waiting[stop.stop_id] = list
	_reflow_queue(stop)

## Walks an already-standing passenger (spawned back in _generate_waiting)
## over to the door and pays their fare on arrival - no new node created,
## it's the same NPC the player saw waiting.
func _send_passenger_to_board(entry: Dictionary) -> void:
	_say(entry.get("archetype"), "boarding_lines")
	var p: Passenger = entry.get("node")
	if p == null or not is_instance_valid(p):
		# NPC got cleaned up some other way - still honor the boarding so
		# money/seat accounting stays correct.
		vehicle.passengers_aboard += 1
		AudioManager.play_boarding()
		EconomyManager.add_fare(entry.fare)
		EventBus.passenger_boarded.emit(entry)
		aboard.append(entry)
		return
	var door_pos := vehicle.get_door_position()
	vehicle.passengers_aboard += 1
	var speed := 1.6 * _boost_boarding_speed
	boarding_pending += 1
	p.walk_to(door_pos, speed)
	p.arrived.connect(func():
		boarding_pending -= 1
		AudioManager.play_boarding()
		EconomyManager.add_fare(entry.fare)
		EventBus.passenger_boarded.emit(entry)
		aboard.append(entry)
		var tw := p.create_tween()
		tw.tween_property(p, "scale", Vector3.ZERO, 0.25)
		tw.tween_callback(p.queue_free)
	, CONNECT_ONE_SHOT)

## After some passengers leave the queue, shuffle the remaining ones inward
## so they don't look like they're waiting in a queue with gaps in it.
func _reflow_queue(stop: StopArea) -> void:
	var list: Array = waiting.get(stop.stop_id, [])
	for i in range(list.size()):
		var entry: Dictionary = list[i]
		var p: Passenger = entry.get("node")
		if p == null or not is_instance_valid(p) or p.is_walking():
			continue
		var lane_offset: float = (i - (list.size() - 1) / 2.0) * 1.3
		var target := stop.to_global(Vector3(3.5, 0.25, lane_offset))
		p.walk_to(target, 1.4)

func _alight_passengers(stop: StopArea) -> void:
	var leaving: Array[Dictionary] = []
	for entry in aboard:
		if entry.destination_stop_id == stop.stop_id:
			leaving.append(entry)
	for entry in leaving:
		aboard.erase(entry)
		_spawn_alighting_passenger(stop, entry)

func _spawn_alighting_passenger(stop: StopArea, entry: Dictionary) -> void:
	var p := Passenger.new()
	world_parent.add_child(p)
	p.setup(entry.archetype)
	var door_pos := vehicle.get_door_position()
	p.global_position = door_pos
	vehicle.passengers_aboard = max(0, vehicle.passengers_aboard - 1)
	GameManager.register_passenger_delivered()
	var target := stop.to_global(Vector3(4.2,0.25,randf_range(-3.5,3.5)))
	var speed := 1.6 * _boost_boarding_speed
	p.walk_to(target, speed)
	var tip_roll := randf()
	if tip_roll < entry.archetype.tip_chance:
		var tip := randi_range(10, 30)
		EconomyManager.add_comfort_bonus(tip)
		EventBus.notification.emit("Пассажир оставил чаевые: +%d ₽" % tip, 1.8)
	boarding_pending += 1
	p.arrived.connect(func():
		boarding_pending -= 1
		p.queue_free()
	, CONNECT_ONE_SHOT)

func jolt_passengers() -> void:
	for c in world_parent.get_children():
		if c is Passenger:
			c.react_to_jolt()
	if not aboard.is_empty():
		_say((aboard[randi() % aboard.size()] as Dictionary).get("archetype"), "jolt_lines")

func _say(archetype: PassengerArchetype, field: String) -> void:
	if archetype == null or GameManager.trip_time - _last_dialogue_time < 7.0:
		return
	var lines: PackedStringArray = archetype.boarding_lines if field == "boarding_lines" else archetype.jolt_lines
	if lines.is_empty():
		return
	_last_dialogue_time = GameManager.trip_time
	EventBus.notification.emit("%s — %s" % [lines[randi() % lines.size()], archetype.display_name], 2.6)
