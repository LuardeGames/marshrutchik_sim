extends Node
class_name RandomEventManager
## Fires flavor/comedy events during the ride, plus the rarer "give change"
## mini-event. Fully data-driven via EventCatalog / GameEvent resources.

var events: Array[GameEvent] = []
var _flavor_timer: float = 0.0
var _change_timer: float = 0.0
var active: bool = false

func _ready() -> void:
	events = EventCatalog.build()
	_reset_flavor_timer()
	_reset_change_timer()

func start() -> void:
	active = true

func stop() -> void:
	active = false

func _process(delta: float) -> void:
	if not active or not GameManager.trip_running:
		return
	_flavor_timer -= delta
	if _flavor_timer <= 0.0:
		_trigger_flavor_event()
		_reset_flavor_timer()
	_change_timer -= delta
	if _change_timer <= 0.0:
		_trigger_change_event()
		_reset_change_timer()

func _reset_flavor_timer() -> void:
	_flavor_timer = randf_range(12.0, 22.0)

func _reset_change_timer() -> void:
	_change_timer = randf_range(40.0, 70.0)

func _trigger_flavor_event() -> void:
	if events.is_empty():
		return
	var total_weight := 0.0
	for e in events:
		total_weight += e.weight
	var roll := randf() * total_weight
	var chosen: GameEvent = events[0]
	for e in events:
		roll -= e.weight
		if roll <= 0.0:
			chosen = e
			break
	_apply_event(chosen)

func _apply_event(ev: GameEvent) -> void:
	EventBus.notification.emit(ev.text, 3.0)
	EventBus.random_event_triggered.emit(ev.id)
	match ev.effect:
		GameEvent.Effect.MONEY_BONUS:
			EconomyManager.add_stop_bonus(int(ev.effect_value))
		GameEvent.Effect.MONEY_PENALTY:
			EconomyManager.add_penalty(int(ev.effect_value))
		GameEvent.Effect.COMFORT_BONUS:
			GameManager.modify_comfort(ev.effect_value)
		GameEvent.Effect.COMFORT_PENALTY:
			GameManager.modify_comfort(-ev.effect_value)
		_:
			pass

func _trigger_change_event() -> void:
	var fare: int = [40, 45, 50, 60][randi() % 4]
	var given: int = [500, 1000, 100][randi() % 3]
	if given <= fare:
		given = 500
	var options := EconomyManager.build_change_options(fare, given)
	EventBus.notification.emit("Пассажир дал %d ₽. Проезд %d ₽." % [given, fare], 3.5)
	EventBus.change_choice_requested.emit(fare, given, options)
