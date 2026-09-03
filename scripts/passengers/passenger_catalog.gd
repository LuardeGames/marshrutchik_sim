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
	list.append(regular)

	var pensioner := PassengerArchetype.new()
	pensioner.id = "pensioner"
	pensioner.display_name = "Пенсионер"
	pensioner.color = Color(0.6, 0.6, 0.65)
	pensioner.base_fare = 20
	pensioner.fare_variance = 0
	pensioner.patience = 1.4
	pensioner.tip_chance = 0.05
	list.append(pensioner)

	var schoolkid := PassengerArchetype.new()
	schoolkid.id = "schoolkid"
	schoolkid.display_name = "Школьник"
	schoolkid.color = Color(0.85, 0.3, 0.3)
	schoolkid.base_fare = 25
	schoolkid.fare_variance = 0
	schoolkid.patience = 0.9
	schoolkid.tip_chance = 0.02
	list.append(schoolkid)

	var hurry := PassengerArchetype.new()
	hurry.id = "hurry"
	hurry.display_name = "Спешащий пассажир"
	hurry.color = Color(0.9, 0.6, 0.15)
	hurry.base_fare = 45
	hurry.fare_variance = 5
	hurry.patience = 0.6
	hurry.tip_chance = 0.2
	list.append(hurry)

	var grumpy := PassengerArchetype.new()
	grumpy.id = "grumpy"
	grumpy.display_name = "Недовольный пассажир"
	grumpy.color = Color(0.5, 0.25, 0.55)
	grumpy.base_fare = 45
	grumpy.fare_variance = 5
	grumpy.patience = 0.5
	grumpy.tip_chance = 0.0
	list.append(grumpy)

	return list

static func random_archetype() -> PassengerArchetype:
	var list := build()
	return list[randi() % list.size()]
