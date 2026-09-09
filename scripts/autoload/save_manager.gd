extends Node
## Persists player progression to user:// so it survives a restart.

const SAVE_PATH := "user://savegame.json"

const DEFAULT_DATA := {
	"money": 300,
	"route_mastered": false,
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
	"vehicle_condition": 100.0,
	"sound": {
		"master": 1.0,
		"music": 0.35,
		"sfx": 1.0,
		"muted": false,
	},
}

var data: Dictionary = {}

func _ready() -> void:
	load_game()

func load_game() -> void:
	data=DEFAULT_DATA.duplicate(true)
	for path in [SAVE_PATH,SAVE_PATH+".bak"]:
		if not FileAccess.file_exists(path):
			continue
		var f:=FileAccess.open(path,FileAccess.READ)
		if f==null:
			continue
		var parser:=JSON.new()
		var parsed = parser.data if parser.parse(f.get_as_text())==OK else null
		f.close()
		if parsed is Dictionary:
			_merge_defaults(data,parsed)
			_validate_data()
			return
	save_game()

func _merge_defaults(base: Dictionary, incoming: Dictionary) -> void:
	for key in base.keys():
		if not incoming.has(key):
			continue
		if base[key] is Dictionary:
			if incoming[key] is Dictionary:
				_merge_defaults(base[key],incoming[key])
		elif base[key] is Array:
			if incoming[key] is Array:
				base[key]=incoming[key]
		elif typeof(base[key]) in [TYPE_INT,TYPE_FLOAT]:
			if typeof(incoming[key]) in [TYPE_INT,TYPE_FLOAT]:
				base[key]=incoming[key]
		elif typeof(base[key])==typeof(incoming[key]):
			base[key]=incoming[key]

func _validate_data() -> void:
	for key in ["master","music","sfx"]:
		data.sound[key]=clampf(float(data.sound[key]),0.0,1.0)
	for u in UpgradeCatalog.build():
		data.upgrades[u.id]=clampi(int(data.upgrades[u.id]),0,u.max_level)
	var unlocked: Array=["old_marshrutka"]
	if data.unlocked_vehicles.has("modern_microbus"):
		unlocked.append("modern_microbus")
	data.unlocked_vehicles=unlocked
	if not unlocked.has(data.selected_vehicle):
		data.selected_vehicle="old_marshrutka"
	data.best_rating=clampi(int(data.best_rating),0,3)
	data.trips_completed=maxi(0,int(data.trips_completed))
	data.vehicle_condition=clampf(float(data.get("vehicle_condition",100.0)),0.0,100.0)

func save_game() -> void:
	var temporary:=SAVE_PATH+".tmp"
	var f:=FileAccess.open(temporary,FileAccess.WRITE)
	if f==null:
		push_warning("SaveManager: unable to write progress")
		return
	f.store_string(JSON.stringify(data,"\t"))
	f.flush()
	f.close()
	# Keep the previous valid snapshot; interrupted writes leave it recoverable.
	if FileAccess.file_exists(SAVE_PATH):
		var current:=FileAccess.open(SAVE_PATH,FileAccess.READ)
		var parser:=JSON.new()
		if current and parser.parse(current.get_as_text())==OK and parser.data is Dictionary:
			current.close()
			DirAccess.copy_absolute(SAVE_PATH,SAVE_PATH+".bak")
	var error:=DirAccess.rename_absolute(temporary,SAVE_PATH)
	if error!=OK:
		push_warning("SaveManager: unable to replace progress file")

func get_money() -> int:
	return int(data.get("money", 0))

func add_money(amount: int) -> void:
	data["money"] = int(data.get("money", 0)) + amount
	save_game()

func spend_money(amount: int) -> bool:
	if amount < 0 or get_money() < amount:
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

func get_vehicle_condition() -> float:
	return clampf(float(data.get("vehicle_condition",100.0)),0.0,100.0)

func damage_vehicle(amount: float) -> void:
	if amount <= 0.0:
		return
	data["vehicle_condition"] = clampf(get_vehicle_condition() - amount, 0.0, 100.0)
	save_game()

func get_repair_cost() -> int:
	return int(ceil((100.0 - get_vehicle_condition()) * 4.0))

func repair_vehicle() -> bool:
	var cost := get_repair_cost()
	if cost <= 0:
		return false
	if not spend_money(cost):
		return false
	data["vehicle_condition"] = 100.0
	save_game()
	return true

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
