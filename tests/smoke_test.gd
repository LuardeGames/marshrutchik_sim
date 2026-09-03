extends SceneTree
## Headless smoke test. Run with:
##   godot4 --headless --path . --script res://tests/smoke_test.gd
## Exits with code 0 on success, 1 on any failed check.
##
## Note: autoload singletons are fetched via /root/<Name> instead of their
## global identifiers, because those identifiers are only registered for
## scripts compiled *after* autoload setup - a plain --script main loop
## compiles before that, so the global names aren't resolvable here (they
## work normally in any regular scene script).

var failures: Array[String] = []
var passed: int = 0

var SaveManager: Node
var EconomyManager: Node
var GameManager: Node
var PlatformService: Node
var AudioManager: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	SaveManager = root.get_node("SaveManager")
	EconomyManager = root.get_node("EconomyManager")
	GameManager = root.get_node("GameManager")
	PlatformService = root.get_node("PlatformService")
	AudioManager = root.get_node("AudioManager")

	print("=== Маршрутчик Simulator: smoke test ===")

	_check("route has 6 stops", RouteDefinition.stops().size() == 6)
	_check("route waypoints non-empty", RouteDefinition.waypoints().size() > 0)
	_check("route total length is reasonable (500-6000m)", RouteDefinition.total_length() > 500.0 and RouteDefinition.total_length() < 6000.0)

	# --- save/load roundtrip ---
	SaveManager.data["money"] = 999
	SaveManager.save_game()
	SaveManager.data = {}
	SaveManager.load_game()
	_check("save/load roundtrip preserves money", SaveManager.get_money() == 999)

	# --- upgrade purchase ---
	SaveManager.data["money"] = 100000
	SaveManager.data["upgrades"] = {"engine": 0, "brakes": 0, "suspension": 0, "capacity": 0, "doors": 0}
	SaveManager.save_game()
	var before_level: int = SaveManager.get_upgrade_level("engine")
	var bought: bool = EconomyManager.purchase_upgrade("engine")
	_check("upgrade purchase succeeds with enough money", bought)
	_check("upgrade level increased", SaveManager.get_upgrade_level("engine") == before_level + 1)
	_check("upgrade catalog has >= 5 tracks", EconomyManager.upgrades.size() >= 5)
	for u in EconomyManager.upgrades:
		_check("upgrade '%s' has >= 3 levels" % u.id, u.max_level >= 3)

	# --- vehicle catalog ---
	var vehicles := VehicleCatalog.build()
	_check("at least 2 vehicles available", vehicles.size() >= 2)

	# --- gameplay scene loads and builds world ---
	var gameplay_scene: PackedScene = load("res://scenes/gameplay/gameplay.tscn")
	_check("gameplay scene loads", gameplay_scene != null)
	var gameplay: Node = gameplay_scene.instantiate()
	root.add_child(gameplay)
	await process_frame
	await process_frame
	await process_frame

	_check("gameplay has RouteManager", gameplay.route_manager != null)
	_check("gameplay has 6 stop areas", gameplay.route_manager.stops.size() == 6)
	_check("gameplay has PassengerManager", gameplay.passenger_manager != null)
	_check("gameplay has vehicle spawned", gameplay.vehicle != null)
	_check("vehicle has passenger capacity > 0", gameplay.vehicle.capacity > 0)
	_check("competitor AI spawned", gameplay.competitor != null)

	# generate waiting passengers check
	var any_waiting := false
	for stop in gameplay.route_manager.stops:
		if gameplay.passenger_manager.get_waiting_count(stop.stop_id) > 0:
			any_waiting = true
	_check("passengers were generated at stops", any_waiting)

	# --- simulate a full trip completion programmatically ---
	GameManager.comfort = 90.0
	GameManager.trip_time = 120.0
	GameManager.trip_running = true
	EconomyManager.reset_trip()
	EconomyManager.add_fare(300)
	var summary: Dictionary = GameManager.complete_trip()
	_check("trip summary has total", summary.has("total"))
	_check("trip summary total > 0", summary.total > 0)
	_check("trip summary has rating 1-3", summary.rating >= 1 and summary.rating <= 3)

	# --- PlatformService fallback ---
	PlatformService.init()
	_check("PlatformService reports ready", PlatformService.is_ready())
	PlatformService.save_cloud({"money": SaveManager.get_money()})
	var cloud_data: Dictionary = PlatformService.load_cloud()
	_check("PlatformService cloud fallback returns data", cloud_data.has("money"))

	gameplay.queue_free()
	await process_frame

	print("\n=== RESULT: %d passed, %d failed ===" % [passed, failures.size()])
	if failures.size() > 0:
		for f in failures:
			print("FAILED: ", f)
		quit(1)
	else:
		print("ALL CHECKS PASSED")
		quit(0)

func _check(desc: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("[PASS] ", desc)
	else:
		failures.append(desc)
		print("[FAIL] ", desc)
