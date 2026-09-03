extends RefCounted
class_name EventCatalog
## Data-driven pool of comedic in-ride events. New events = one more entry.

static func build() -> Array[GameEvent]:
	var list: Array[GameEvent] = []

	list.append(_e("shout_stop", "«На следующей остановите!» - кричат с заднего ряда.", Effect_None(), 0))
	list.append(_e("late_stop_request", "Пассажир просит остановить... уже после того как вы отъехали.", Effect_ComfortPenalty(), 2))
	list.append(_e("pass_for_one", "«Передайте за одного, пожалуйста!» - шелестят мелочью по салону.", Effect_MoneyBonus(), 10))
	list.append(_e("schoolkid_discount", "Школьник умоляюще смотрит и просит скидку.", Effect_MoneyPenalty(), 10))
	list.append(_e("wrong_direction", "«А вы до аэропорта едете?» - нет, это маршрутка №3.", Effect_None(), 0))
	list.append(_e("stop_by_shop", "«Остановите вон там, возле магазина!»", Effect_None(), 0))
	list.append(_e("annoyed_braking", "Кто-то из салона недоволен резким торможением.", Effect_ComfortPenalty(), 3))
	list.append(_e("sleepy_passenger", "Пассажир задремал и чуть не пропустил остановку.", Effect_MoneyBonus(), 8))
	list.append(_e("wait_for_friend", "«Подождите, там мой друг бежит!» - вздыхает пассажир.", Effect_ComfortBonus(), 2))
	list.append(_e("slow_door", "Дверь закрывается как-то подозрительно медленно...", Effect_None(), 0))
	list.append(_e("dropped_bag", "От резкого манёвра у кого-то упал пакет с картошкой.", Effect_ComfortPenalty(), 4))
	list.append(_e("big_bill", "Пассажир протягивает крупную купюру - придётся искать сдачу.", Effect_None(), 0))
	list.append(_e("competitor_overtake", "Конкурент лихо обгоняет вас перед самой остановкой!", Effect_None(), 0))
	list.append(_e("grumpy_comment", "«В моё время маршрутки ездили аккуратнее» - ворчит пассажир.", Effect_None(), 0))
	list.append(_e("radio_joke", "По радио в салоне шутят про пробки. Никто не смеётся.", Effect_None(), 0))

	return list

static func _e(id: String, text: String, effect: GameEvent.Effect, value: float) -> GameEvent:
	var ev := GameEvent.new()
	ev.id = id
	ev.text = text
	ev.effect = effect
	ev.effect_value = value
	ev.weight = 1.0
	return ev

static func Effect_None() -> GameEvent.Effect:
	return GameEvent.Effect.NONE

static func Effect_MoneyBonus() -> GameEvent.Effect:
	return GameEvent.Effect.MONEY_BONUS

static func Effect_MoneyPenalty() -> GameEvent.Effect:
	return GameEvent.Effect.MONEY_PENALTY

static func Effect_ComfortBonus() -> GameEvent.Effect:
	return GameEvent.Effect.COMFORT_BONUS

static func Effect_ComfortPenalty() -> GameEvent.Effect:
	return GameEvent.Effect.COMFORT_PENALTY
