extends RefCounted
class_name UpgradeCatalog
## Builds the data-driven list of purchasable upgrades. Keeping this in one
## place means new upgrades/levels only require editing this array.

static func build() -> Array[UpgradeData]:
	var list: Array[UpgradeData] = []

	var engine := UpgradeData.new()
	engine.id = "engine"
	engine.display_name = "Двигатель"
	engine.description = "Разгон и максимальная скорость"
	engine.max_level = 3
	engine.base_cost = 250
	engine.cost_growth = 1.7
	engine.level_effects = [1.15, 1.3, 1.5] # multiplier on accel & top speed
	list.append(engine)

	var brakes := UpgradeData.new()
	brakes.id = "brakes"
	brakes.display_name = "Тормоза"
	brakes.description = "Короче тормозной путь"
	brakes.max_level = 3
	brakes.base_cost = 200
	brakes.cost_growth = 1.6
	brakes.level_effects = [1.2, 1.4, 1.65] # multiplier on brake force
	list.append(brakes)

	var suspension := UpgradeData.new()
	suspension.id = "suspension"
	suspension.display_name = "Подвеска"
	suspension.description = "Меньше потеря комфорта от манёвров"
	suspension.max_level = 3
	suspension.base_cost = 220
	suspension.cost_growth = 1.6
	suspension.level_effects = [0.8, 0.6, 0.4] # multiplier on comfort loss
	list.append(suspension)

	var capacity := UpgradeData.new()
	capacity.id = "capacity"
	capacity.display_name = "Вместимость"
	capacity.description = "Больше пассажиров за раз"
	capacity.max_level = 3
	capacity.base_cost = 260
	capacity.cost_growth = 1.55
	capacity.level_effects = [4, 8, 12] # extra seats
	list.append(capacity)

	var doors := UpgradeData.new()
	doors.id = "doors"
	doors.display_name = "Двери"
	doors.description = "Быстрее посадка и высадка"
	doors.max_level = 3
	doors.base_cost = 180
	doors.cost_growth = 1.55
	doors.level_effects = [1.25, 1.5, 1.8] # boarding speed multiplier
	list.append(doors)

	return list
