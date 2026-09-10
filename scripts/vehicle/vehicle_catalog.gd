extends RefCounted
class_name VehicleCatalog

static func build() -> Array[VehicleDefinition]:
	var list: Array[VehicleDefinition] = []

	var old := VehicleDefinition.new()
	old.id = "old_marshrutka"
	old.display_name = "ГАЗель-3221"
	old.description = "Старая добрая маршрутка. Дребезжит, но едет."
	old.price = 0
	old.body_color = Color("dfc77d")
	old.accent_color = Color(0.25, 0.25, 0.25)
	old.base_max_speed = 25.0 # ~90 km/h top end - well above the 60 city limit
	old.base_acceleration = 2.6 # heavy, gradual pull-off, not a jackrabbit start
	old.base_brake_force = 9.0
	old.base_capacity = 10
	old.length = 5.45
	old.width = 1.95
	old.height = 2.25
	old.modern = false
	old.model_path = ""
	list.append(old)

	var modern := VehicleDefinition.new()
	# Preserve the old save ID so an already purchased bus becomes the PAZ.
	modern.id = "modern_microbus"
	modern.display_name = "ПАЗ-3205"
	modern.description = "Вместительный пазик. Тяжелее, спокойнее, больше выручки."
	modern.price = 2500
	modern.body_color = Color("ddd4b2")
	modern.accent_color = Color("817b45")
	modern.base_max_speed = 22.0 # ~79 km/h - lower top end than the Gazelle
	modern.base_acceleration = 1.9 # noticeably heavier off the line
	modern.base_brake_force = 8.0
	modern.base_capacity = 23
	modern.length = 6.9
	modern.width = 2.5
	modern.height = 2.95
	modern.modern = true
	modern.model_path = ""
	list.append(modern)

	return list

static func get_by_id(id: String) -> VehicleDefinition:
	for v in build():
		if v.id == id:
			return v
	return build()[0]
