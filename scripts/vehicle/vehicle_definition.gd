extends Resource
class_name VehicleDefinition
## Data describing one purchasable/drivable marshrutka.

@export var id: String
@export var display_name: String
@export var description: String
@export var price: int = 0 # 0 = starter, free
@export var body_color: Color = Color(1, 1, 1)
@export var accent_color: Color = Color(0.2, 0.2, 0.2)
@export var base_max_speed: float = 16.0 # m/s
@export var base_acceleration: float = 7.0
@export var base_brake_force: float = 14.0
@export var base_capacity: int = 12
@export var length: float = 6.2
@export var width: float = 2.2
@export var height: float = 2.4
@export var modern: bool = false
