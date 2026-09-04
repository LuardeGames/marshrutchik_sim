extends RefCounted
class_name VehicleCatalog

static func build() -> Array[VehicleDefinition]:
	var list: Array[VehicleDefinition] = []

	var old := VehicleDefinition.new()
	old.id = "old_marshrutka"
	old.display_name = "ГАЗель-Старушка"
	old.description = "Старая добрая маршрутка. Дребезжит, но едет."
	old.price = 0
	old.body_color = Color(0.85, 0.85, 0.2)
	old.accent_color = Color(0.25, 0.25, 0.25)
	old.base_max_speed = 15.0
	old.base_acceleration = 6.0
	old.base_brake_force = 12.0
	old.base_capacity = 10
	old.length = 4.4
	old.width = 1.95
	old.height = 2.05
	old.modern = false
	old.model_path = "res://assets/vehicles/ambulance.glb"
	list.append(old)

	var modern := VehicleDefinition.new()
	modern.id = "modern_microbus"
	modern.display_name = "Спринтер-Люкс"
	modern.description = "Современный микроавтобус. Быстрее и вместительнее."
	modern.price = 2500
	modern.body_color = Color(0.15, 0.55, 0.85)
	modern.accent_color = Color(0.9, 0.9, 0.9)
	modern.base_max_speed = 19.0
	modern.base_acceleration = 8.5
	modern.base_brake_force = 15.5
	modern.base_capacity = 14
	modern.length = 4.8
	modern.width = 2.05
	modern.height = 2.3
	modern.modern = true
	modern.model_path = "res://assets/vehicles/van.glb"
	list.append(modern)

	return list

static func get_by_id(id: String) -> VehicleDefinition:
	for v in build():
		if v.id == id:
			return v
	return build()[0]
