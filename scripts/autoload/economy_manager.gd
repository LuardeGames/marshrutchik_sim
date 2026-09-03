extends Node
## Wraps the upgrade catalog + persisted money and exposes purchase logic.
## Also accumulates the running trip's financial summary.

var upgrades: Array[UpgradeData] = []

# --- current trip running totals ---
var trip_fares: int = 0
var trip_stop_bonus: int = 0
var trip_comfort_bonus: int = 0
var trip_penalties: int = 0
var trip_passenger_count: int = 0

func _ready() -> void:
	upgrades = UpgradeCatalog.build()

func get_upgrade(id: String) -> UpgradeData:
	for u in upgrades:
		if u.id == id:
			return u
	return null

func get_upgrade_next_cost(id: String) -> int:
	var u := get_upgrade(id)
	if u == null:
		return -1
	var level := SaveManager.get_upgrade_level(id)
	if level >= u.max_level:
		return -1
	return u.cost_for_level(level + 1)

func can_purchase(id: String) -> bool:
	var cost := get_upgrade_next_cost(id)
	return cost > 0 and SaveManager.get_money() >= cost

func purchase_upgrade(id: String) -> bool:
	var cost := get_upgrade_next_cost(id)
	if cost <= 0:
		return false
	if not SaveManager.spend_money(cost):
		return false
	var new_level := SaveManager.get_upgrade_level(id) + 1
	SaveManager.set_upgrade_level(id, new_level)
	EventBus.upgrade_purchased.emit(id, new_level)
	AudioManager.play_money()
	return true

func get_upgrade_multiplier(id: String) -> float:
	var u := get_upgrade(id)
	if u == null:
		return 1.0
	var level := SaveManager.get_upgrade_level(id)
	if level <= 0:
		return 1.0
	return u.effect_for_level(level)

func get_extra_capacity() -> int:
	var u := get_upgrade("capacity")
	if u == null:
		return 0
	var level := SaveManager.get_upgrade_level("capacity")
	if level <= 0:
		return 0
	return int(u.effect_for_level(level))

# --- trip accumulation ---

func reset_trip() -> void:
	trip_fares = 0
	trip_stop_bonus = 0
	trip_comfort_bonus = 0
	trip_penalties = 0
	trip_passenger_count = 0

func add_fare(amount: int) -> void:
	trip_fares += amount
	SaveManager.add_money(amount)
	EventBus.money_earned.emit(amount, "fare")

func add_stop_bonus(amount: int) -> void:
	trip_stop_bonus += amount
	SaveManager.add_money(amount)
	EventBus.money_earned.emit(amount, "stop_bonus")

func add_comfort_bonus(amount: int) -> void:
	trip_comfort_bonus += amount
	SaveManager.add_money(amount)
	EventBus.money_earned.emit(amount, "comfort_bonus")

func add_penalty(amount: int) -> void:
	trip_penalties += amount
	SaveManager.add_money(-amount)
	EventBus.money_earned.emit(-amount, "penalty")

func get_trip_total() -> int:
	return trip_fares + trip_stop_bonus + trip_comfort_bonus - trip_penalties

## Builds 2-3 plausible change options for the "give change" mini-event.
func build_change_options(fare: int, given: int) -> Array:
	var correct := given - fare
	var options := [correct]
	var delta_options: Array = [5, 10, 15, 20]
	var sign_mult: int = 1 if randf() > 0.5 else -1
	var wrong1: int = correct + int(delta_options.pick_random()) * sign_mult
	wrong1 = max(0, wrong1)
	if wrong1 != correct:
		options.append(wrong1)
	var wrong2 := fare # common mistake: hand back the fare amount itself
	if wrong2 != correct and not options.has(wrong2):
		options.append(wrong2)
	options.shuffle()
	return options
