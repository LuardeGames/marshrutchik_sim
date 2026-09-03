extends Resource
class_name PassengerArchetype

@export var id: String
@export var display_name: String
@export var color: Color
@export var base_fare: int = 40
@export var fare_variance: int = 15
@export var patience: float = 1.0 # multiplier, higher = more tolerant
@export var tip_chance: float = 0.15
