extends Node
## Persists player progression to user:// so it survives a restart.

const SAVE_PATH := "user://savegame.json"

const DEFAULT_DATA := {
	"money": 300,
	"upgrades": {
		"engine": 0,
		"brakes": 0,
		"suspension": 0,
		"capacity": 0,
		"doors": 0,
	},
	"unlocked_vehicles": ["old_marshrutka"],
	"selected_vehicle": "old_marshrutka",
	"best_rating": 0,
	"best_earnings": 0,
	"trips_completed": 0,
	"sound": {
		"master": 1.0,
		"music": 0.8,
		"sfx": 1.0,
		"muted": false,
	},
}

var data: Dictionary = {}

func _ready() -> void:
	load_game()

func load_game() -> void:
	data = DEFAULT_DATA.duplicate(true)
	if not FileAccess.file_exists(SAVE_PATH):
		save_game()
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		_merge_defaults(data, parsed)

func _merge_defaults(base: Dictionary, incoming: Dictionary) -> void:
	for key in incoming.keys():
		if base.has(key) and typeof(base[key]) == TYPE_DICTIONARY and typeof(incoming[key]) == TYPE_DICTIONARY:
			_merge_defaults(base[key], incoming[key])
		else:
			base[key] = incoming[key]

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("SaveManager: unable to open save file for writing")
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

func get_money() -> int:
	return int(data.get("money", 0))

func add_money(amount: int) -> void:
	data["money"] = int(data.get("money", 0)) + amount
	save_game()

func spend_money(amount: int) -> bool:
	if get_money() < amount:
		return false
	data["money"] = get_money() - amount
	save_game()
	return true

func get_upgrade_level(upgrade_id: String) -> int:
	return int(data.get("upgrades", {}).get(upgrade_id, 0))

func set_upgrade_level(upgrade_id: String, level: int) -> void:
	data["upgrades"][upgrade_id] = level
	save_game()

func is_vehicle_unlocked(vehicle_id: String) -> bool:
	return data.get("unlocked_vehicles", []).has(vehicle_id)

func unlock_vehicle(vehicle_id: String) -> void:
	if not is_vehicle_unlocked(vehicle_id):
		data["unlocked_vehicles"].append(vehicle_id)
		save_game()

func set_selected_vehicle(vehicle_id: String) -> void:
	data["selected_vehicle"] = vehicle_id
	save_game()

func get_selected_vehicle() -> String:
	return String(data.get("selected_vehicle", "old_marshrutka"))

func register_trip_result(earnings: int, rating: int) -> void:
	data["trips_completed"] = int(data.get("trips_completed", 0)) + 1
	if rating > int(data.get("best_rating", 0)):
		data["best_rating"] = rating
	if earnings > int(data.get("best_earnings", 0)):
		data["best_earnings"] = earnings
	save_game()

func get_sound_setting(key: String) -> float:
	return float(data.get("sound", {}).get(key, 1.0))

func set_sound_setting(key: String, value: float) -> void:
	data["sound"][key] = value
	save_game()

func is_muted() -> bool:
	return bool(data.get("sound", {}).get("muted", false))

func set_muted(value: bool) -> void:
	data["sound"]["muted"] = value
	save_game()
