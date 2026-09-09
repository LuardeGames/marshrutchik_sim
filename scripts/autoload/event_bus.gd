extends Node
## Global signal bus so gameplay systems stay decoupled from each other.

signal passenger_boarded(passenger)
signal passenger_left(passenger, tip: int)
signal stop_reached(stop_id: int, quality: String) # quality: "good" | "far" | "missed"
signal comfort_changed(value: float)
signal money_earned(amount: int, reason: String)
signal notification(text: String, duration: float)
signal random_event_triggered(event_name: String)
signal change_choice_requested(fare: int, given: int, options: Array)
signal trip_started
signal trip_completed(summary: Dictionary)
signal trip_failed(summary: Dictionary)
signal upgrade_purchased(upgrade_id: String, level: int)
signal vehicle_collision(strength: float)
signal competitor_took_passengers(stop_id: int, count: int)
signal rule_violation(kind: String, fine: int)
