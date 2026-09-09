extends RefCounted
class_name DailyChallenge
## Small deterministic daily modifier. It needs no server state for the
## first release, so every device gets a stable challenge for its local day.

static func today() -> Dictionary:
	var d := Time.get_date_dict_from_system()
	var key: int = int(d.year) * 372 + int(d.month) * 31 + int(d.day)
	match posmod(key, 3):
		0:
			return {"id":"rush_hour", "title":"Час пик", "description":"На остановках больше пассажиров", "passenger_multiplier":1.45, "bonus":70}
		1:
			return {"id":"careful_day", "title":"Аккуратный рейс", "description":"Закончите с комфортом 85%+", "passenger_multiplier":1.0, "bonus":90, "comfort_target":85.0}
		_:
			return {"id":"fare_day", "title":"День зарплаты", "description":"Пассажиры оставляют больше выручки", "passenger_multiplier":1.15, "fare_multiplier":1.18, "bonus":75}

static func is_completed(challenge: Dictionary, comfort: float) -> bool:
	return comfort >= float(challenge.get("comfort_target", 0.0))
