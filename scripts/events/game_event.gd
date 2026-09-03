extends Resource
class_name GameEvent

enum Effect { NONE, MONEY_BONUS, MONEY_PENALTY, COMFORT_BONUS, COMFORT_PENALTY }

@export var id: String
@export var text: String
@export var weight: float = 1.0
@export var effect: Effect = Effect.NONE
@export var effect_value: float = 0.0
@export var min_value: int = 0
@export var max_value: int = 0
