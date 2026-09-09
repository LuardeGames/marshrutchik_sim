extends RefCounted
class_name PassengerCatalog

static func build() -> Array[PassengerArchetype]:
	var list: Array[PassengerArchetype] = []

	var regular := PassengerArchetype.new()
	regular.id = "regular"
	regular.display_name = "Обычный пассажир"
	regular.color = Color(0.3, 0.5, 0.7)
	regular.base_fare = 45
	regular.fare_variance = 5
	regular.patience = 1.0
	regular.tip_chance = 0.12
	regular.boarding_lines = ["«На следующей остановите»", "«Картой можно?»"]
	regular.jolt_lines = ["«Полегче на поворотах!»"]
	list.append(regular)

	var pensioner := PassengerArchetype.new()
	pensioner.id = "pensioner"
	pensioner.display_name = "Пенсионер"
	pensioner.color = Color(0.6, 0.6, 0.65)
	pensioner.base_fare = 20
	pensioner.fare_variance = 0
	pensioner.patience = 1.4
	pensioner.tip_chance = 0.05
	pensioner.boarding_lines = ["«Мне бы до поликлиники»", "«Передайте за проезд»"]
	pensioner.jolt_lines = ["«В моё время ездили аккуратнее»"]
	list.append(pensioner)

	var schoolkid := PassengerArchetype.new()
	schoolkid.id = "schoolkid"
	schoolkid.display_name = "Школьник"
	schoolkid.color = Color(0.85, 0.3, 0.3)
	schoolkid.base_fare = 25
	schoolkid.fare_variance = 0
	schoolkid.patience = 0.9
	schoolkid.tip_chance = 0.02
	schoolkid.boarding_lines = ["«До рынка, пожалуйста»", "«У меня льготный»"]
	schoolkid.jolt_lines = ["«Ой, рюкзак упал!»"]
	list.append(schoolkid)

	var hurry := PassengerArchetype.new()
	hurry.id = "hurry"
	hurry.display_name = "Спешащий пассажир"
	hurry.color = Color(0.9, 0.6, 0.15)
	hurry.base_fare = 45
	hurry.fare_variance = 5
	hurry.patience = 0.6
	hurry.tip_chance = 0.2
	hurry.boarding_lines = ["«Водитель, я опаздываю!»", "«На следующей, очень срочно»"]
	hurry.jolt_lines = ["«Можно побыстрее, но не так!»"]
	list.append(hurry)

	var grumpy := PassengerArchetype.new()
	grumpy.id = "grumpy"
	grumpy.display_name = "Недовольный пассажир"
	grumpy.color = Color(0.5, 0.25, 0.55)
	grumpy.base_fare = 45
	grumpy.fare_variance = 5
	grumpy.patience = 0.5
	grumpy.tip_chance = 0.0
	grumpy.boarding_lines = ["«Опять ждать пришлось»", "«Дверь нормально откройте»"]
	grumpy.jolt_lines = ["«Вы людей вообще возите?»"]
	list.append(grumpy)

	var worker := PassengerArchetype.new()
	worker.id = "worker"
	worker.display_name = "Работяга"
	worker.color = Color("5d6b75")
	worker.base_fare = 55
	worker.fare_variance = 10
	worker.patience = 1.15
	worker.tip_chance = 0.10
	worker.boarding_lines = ["«После смены только бы доехать»", "«На вокзал, если без гонок»"]
	worker.jolt_lines = ["«Инструменты по салону поехали!»"]
	list.append(worker)

	var bag_carrier := PassengerArchetype.new()
	bag_carrier.id = "bag_carrier"
	bag_carrier.display_name = "Пассажир с сумкой"
	bag_carrier.color = Color("92724d")
	bag_carrier.base_fare = 50
	bag_carrier.fare_variance = 5
	bag_carrier.patience = 0.8
	bag_carrier.tip_chance = 0.08
	bag_carrier.boarding_lines = ["«Сумку придержите, пожалуйста»", "«Я с этим на конечную»"]
	bag_carrier.jolt_lines = ["«Картошка опять рассыпалась!»"]
	list.append(bag_carrier)

	return list

static func random_archetype() -> PassengerArchetype:
	var list := build()
	return list[randi() % list.size()]
