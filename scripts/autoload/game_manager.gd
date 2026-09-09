extends Node
## Top level game state + orchestration. Scenes are switched from here so
## individual systems don't need to know about each other's scenes.

enum State { MENU, DRIVING, RESULTS, FAILED, GARAGE }

const GAMEPLAY_SCENE := "res://scenes/gameplay/gameplay.tscn"
const MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const GARAGE_SCENE := "res://scenes/garage/garage.tscn"

var state: State = State.MENU
var _last_summary: Dictionary = {}
var _failure_reason: String = ""

# --- running trip stats (reset at trip start) ---
var comfort: float = 100.0
var trip_time: float = 0.0
var passengers_delivered: int = 0
var collisions: int = 0
var missed_required_stops: int = 0
var rule_violations: int = 0
var fines_paid: int = 0
var trip_running: bool = false
var daily_challenge: Dictionary = {}
var _double_reward_pending: bool = false
var _double_reward_claimed: bool = false
signal double_reward_claimed(amount: int)

func _ready() -> void:
	PlatformService.init()
	RouteDefinition.set_active_route(SaveManager.get_selected_route())

func start_trip() -> void:
	get_tree().paused = false
	AudioManager.set_game_paused(false)
	InputState.reset_touch()
	_last_summary = {}
	_failure_reason = ""
	comfort = 100.0
	trip_time = 0.0
	passengers_delivered = 0
	collisions = 0
	missed_required_stops = 0
	rule_violations = 0
	fines_paid = 0
	trip_running = true
	daily_challenge = DailyChallenge.today()
	RouteDefinition.set_active_route(SaveManager.get_selected_route())
	_double_reward_pending = false
	_double_reward_claimed = false
	EconomyManager.reset_trip()
	state = State.DRIVING
	PlatformService.start_gameplay()
	get_tree().change_scene_to_file(GAMEPLAY_SCENE)

func go_to_menu() -> void:
	get_tree().paused = false
	AudioManager.set_game_paused(false)
	PlatformService.stop_gameplay()
	PlatformService.save_cloud(SaveManager.data)
	InputState.reset_touch()
	state = State.MENU
	trip_running = false
	get_tree().change_scene_to_file(MENU_SCENE)

func go_to_garage() -> void:
	get_tree().paused = false
	AudioManager.set_game_paused(false)
	PlatformService.stop_gameplay()
	PlatformService.save_cloud(SaveManager.data)
	InputState.reset_touch()
	state = State.GARAGE
	trip_running = false
	get_tree().change_scene_to_file(GARAGE_SCENE)

func _process(delta: float) -> void:
	if trip_running:
		trip_time += delta

func modify_comfort(delta: float) -> void:
	comfort = clamp(comfort + delta, 0.0, 100.0)
	EventBus.comfort_changed.emit(comfort)

func register_collision(strength: float) -> void:
	if not trip_running or state != State.DRIVING:
		return
	collisions += 1
	var damage: float = clampf(strength * 16.0, 3.0, 18.0)
	SaveManager.damage_vehicle(damage)
	modify_comfort(-clamp(strength * 12.0, 3.0, 25.0))
	var fine := clampi(int(round(strength * 45.0)), 20, 70)
	_register_fine(fine, "collision", clampf(strength * 3.0, 2.0, 8.0), "ДТП! Штраф %d ₽ · состояние машины: %d%%" % [fine, int(round(SaveManager.get_vehicle_condition()))])
	EventBus.vehicle_collision.emit(strength)
	AudioManager.play_collision(strength)
	if trip_running and (SaveManager.get_vehicle_condition() <= 0.0 or collisions >= 6):
		fail_trip("Машина разбита: слишком много столкновений", 350)

func register_rule_violation(kind: String, fine: int, comfort_loss: float, message: String) -> void:
	if not trip_running or state != State.DRIVING:
		return
	_register_fine(fine, kind, comfort_loss, message)
	if trip_running and (rule_violations >= 8 or fines_paid >= 300):
		fail_trip("Рейс сорван: инспектор снял маршрутку с линии", 400)

func _register_fine(fine: int, kind: String, comfort_loss: float, message: String) -> void:
	rule_violations += 1
	fines_paid += maxi(0, fine)
	EconomyManager.add_penalty(maxi(0, fine))
	if comfort_loss > 0.0:
		modify_comfort(comfort_loss * -1.0)
	EventBus.rule_violation.emit(kind, fine)
	EventBus.notification.emit(message, 2.6)

func fail_trip(reason: String, final_fine: int = 0) -> void:
	if not trip_running or state != State.DRIVING:
		return
	if final_fine > 0:
		fines_paid += final_fine
		EconomyManager.add_penalty(final_fine)
	_failure_reason = reason
	trip_running = false
	var summary := {
		"reason": reason,
		"passengers": passengers_delivered,
		"fares": EconomyManager.trip_fares,
		"penalties": EconomyManager.trip_penalties,
		"total": EconomyManager.get_trip_total(),
		"comfort": comfort,
		"vehicle_condition": SaveManager.get_vehicle_condition(),
		"collisions": collisions,
		"rule_violations": rule_violations,
		"fines_paid": fines_paid,
		"time": trip_time,
	}
	_last_summary = summary.duplicate(true)
	state = State.FAILED
	PlatformService.stop_gameplay()
	PlatformService.save_cloud(SaveManager.data)
	EventBus.trip_failed.emit(summary)
	AudioManager.play_collision(1.0)

func register_passenger_delivered() -> void:
	passengers_delivered += 1

func register_missed_stop() -> void:
	missed_required_stops += 1

func format_time(t: float) -> String:
	var total := int(t)
	var m := total / 60
	var s := total % 60
	return "%02d:%02d" % [m, s]

## Called by RouteManager once the final stop is reached. Builds the result
## summary dictionary and switches to results state (HUD shows ResultScreen).
func complete_trip() -> Dictionary:
	if (state == State.RESULTS or state == State.FAILED) and not _last_summary.is_empty():
		return _last_summary.duplicate(true)
	if not trip_running:
		return _last_summary.duplicate(true)
	trip_running = false
	var comfort_bonus := int(round((comfort / 100.0) * 60))
	if comfort_bonus > 0:
		EconomyManager.add_comfort_bonus(comfort_bonus)
	var speed_bonus := 0
	if trip_time < 210.0:
		speed_bonus = 40
		EconomyManager.add_stop_bonus(speed_bonus)
	var late_penalty := 0
	if trip_time > 240.0:
		late_penalty = mini(120, int(ceil((trip_time - 240.0) / 20.0)) * 15)
		EconomyManager.add_penalty(late_penalty)
	var daily_bonus := 0
	if DailyChallenge.is_completed(daily_challenge, comfort):
		daily_bonus = int(daily_challenge.get("bonus", 0))
		if daily_bonus > 0:
			EconomyManager.add_stop_bonus(daily_bonus)

	var total := EconomyManager.get_trip_total()
	var rating := _compute_rating(total)
	SaveManager.register_trip_result(total, rating)

	var mastered_before := bool(SaveManager.data.get("route_mastered", false))
	var mastered := rating == 3 and SaveManager.get_selected_vehicle() == "modern_microbus"
	if mastered:
		SaveManager.data["route_mastered"] = true
		SaveManager.save_game()
	var summary := {
		"mastered_now": mastered and not mastered_before,
		"passengers": passengers_delivered,
		"fares": EconomyManager.trip_fares,
		"comfort_bonus": EconomyManager.trip_comfort_bonus,
		"stop_bonus": EconomyManager.trip_stop_bonus,
		"penalties": EconomyManager.trip_penalties,
		"time": trip_time,
		"total": total,
		"rating": rating,
		"comfort": comfort,
		"vehicle_condition": SaveManager.get_vehicle_condition(),
		"collisions": collisions,
		"rule_violations": rule_violations,
		"fines_paid": fines_paid,
		"late_penalty": late_penalty,
		"daily_title": String(daily_challenge.get("title", "")),
		"daily_bonus": daily_bonus,
	}
	_last_summary = summary.duplicate(true)
	state = State.RESULTS
	PlatformService.stop_gameplay()
	PlatformService.save_cloud(SaveManager.data)
	PlatformService.set_leaderboard_score(int(SaveManager.data.get("best_earnings", 0)))
	EventBus.trip_completed.emit(summary)
	AudioManager.play_trip_complete()
	PlatformService.maybe_show_interstitial(int(SaveManager.data.get("trips_completed", 0)))
	return summary

func claim_double_reward() -> bool:
	if state != State.RESULTS or _last_summary.is_empty() or _double_reward_claimed or _double_reward_pending or PlatformService.is_ad_active():
		return false
	if int(_last_summary.get("total", 0)) <= 0:
		return false
	_double_reward_pending = true
	PlatformService.rewarded_finished.connect(_on_rewarded_finished, CONNECT_ONE_SHOT)
	PlatformService.show_rewarded("double_reward")
	return true

func _on_rewarded_finished(granted: bool) -> void:
	_double_reward_pending = false
	if not granted or _double_reward_claimed or _last_summary.is_empty():
		return
	var amount := maxi(0, int(_last_summary.get("total", 0)))
	if amount <= 0:
		return
	SaveManager.add_money(amount)
	_double_reward_claimed = true
	_last_summary["double_reward_claimed"] = true
	PlatformService.save_cloud(SaveManager.data)
	double_reward_claimed.emit(amount)

func _compute_rating(total: int) -> int:
	var stars := 1
	if comfort >= 60 and total >= 150 and rule_violations <= 5:
		stars = 2
	if comfort >= 80 and total >= 280 and missed_required_stops == 0 and rule_violations <= 1 and fines_paid <= 70:
		stars = 3
	return stars
