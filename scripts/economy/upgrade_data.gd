extends Resource
class_name UpgradeData
## Data-driven definition of one upgrade track (e.g. Engine, Brakes...).

@export var id: String
@export var display_name: String
@export var description: String
@export var max_level: int = 3
@export var base_cost: int = 200
@export var cost_growth: float = 1.6
## Per-level numeric effect values (index 0 = level 1 effect, etc). Meaning
## depends on the track (e.g. acceleration multiplier, comfort loss reduction).
@export var level_effects: Array = []

func cost_for_level(level: int) -> int:
	# level is the level being purchased (1-based)
	return int(round(base_cost * pow(cost_growth, level - 1)))

func effect_for_level(level: int) -> float:
	if level <= 0:
		return level_effects[0] if level_effects.size() > 0 else 0.0
	var idx: int = clamp(level - 1, 0, level_effects.size() - 1)
	return level_effects[idx]
