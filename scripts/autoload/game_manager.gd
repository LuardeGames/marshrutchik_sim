extends Node
## Top level game state + orchestration. Scenes are switched from here so
## individual systems don't need to know about each other's scenes.

enum State { MENU, DRIVING, RESULTS, GARAGE }

const GAMEPLAY_SCENE := "res://scenes/gameplay/gameplay.tscn"
const MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const GARAGE_SCENE := "res://scenes/garage/garage.tscn"

var state: State = State.MENU
var _last_summary: Dictionary = {}

# --- running trip stats (reset at trip start) ---
var comfort: float = 100.0
var trip_time: float = 0.0
var passengers_delivered: int = 0
var collisions: int = 0
var missed_required_stops: int = 0
var trip_running: bool = false

func _ready() -> void:
	PlatformService.init()

func start_trip() -> void:
	get_tree().paused = false
	InputState.reset_touch()
	_last_summary = {}
	comfort = 100.0
	trip_time = 0.0
	passengers_delivered = 0
	collisions = 0
	missed_required_stops = 0
	trip_running = true
	EconomyManager.reset_trip()
	state = State.DRIVING
	get_tree().change_scene_to_file(GAMEPLAY_SCENE)

func go_to_menu() -> void:
	get_tree().paused = false
	InputState.reset_touch()
	state = State.MENU
	trip_running = false
	get_tree().change_scene_to_file(MENU_SCENE)

func go_to_garage() -> void:
	get_tree().paused = false
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
	collisions += 1
	modify_comfort(-clamp(strength * 12.0, 3.0, 25.0))
	EventBus.vehicle_collision.emit(strength)
	AudioManager.play_collision(strength)

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
	if state == State.RESULTS and not _last_summary.is_empty():
		return _last_summary.duplicate(true)
	trip_running = false
	var comfort_bonus := int(round((comfort / 100.0) * 60))
	if comfort_bonus > 0:
		EconomyManager.add_comfort_bonus(comfort_bonus)
	var speed_bonus := 0
	if trip_time < 210.0:
		speed_bonus = 40
		EconomyManager.add_stop_bonus(speed_bonus)
	if missed_required_stops > 0:
		EconomyManager.add_penalty(missed_required_stops * 30)

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
	}
	_last_summary = summary.duplicate(true)
	state = State.RESULTS
	EventBus.trip_completed.emit(summary)
	AudioManager.play_trip_complete()
	PlatformService.maybe_show_interstitial(int(SaveManager.data.get("trips_completed", 0)))
	return summary

func _compute_rating(total: int) -> int:
	var stars := 1
	if comfort >= 60 and total >= 150:
		stars = 2
	if comfort >= 80 and total >= 280 and missed_required_stops == 0:
		stars = 3
	return stars
