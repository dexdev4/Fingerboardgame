## The explorer's suit: oxygen, food, power and health, and how they drain and refill.
## Pure rules driven by GameTuning (rule 3): tick() is called every physics tick with the
## situation (at the ship? dark? night?). Running out of something hurts health; at 0 health the
## suit fails (Main handles respawning at the ship).
class_name Survival
extends RefCounted

var t: GameTuning
var oxygen: float
var food: float
var power: float
var health: float
## Oxygen capacity (the suit tank upgrade raises it).
var oxygen_cap: float


func _init(tuning: GameTuning) -> void:
	t = tuning
	oxygen_cap = t.oxygen_max
	refill_all()


func refill_all() -> void:
	oxygen = oxygen_cap
	food = t.food_max
	power = t.power_max
	health = t.health_max


## One step of `dt` seconds. ctx keys (all bool):
##   at_base  — inside the ship's range (it supplies air/power and shelter from the cold)
##   dark     — night or underground: the headlamp is on
##   night    — it's night (the suit heater uses power outside the ship)
##   scrubber / solar — those ship systems are repaired (faster refills at the ship)
func tick(dt: float, ctx: Dictionary) -> void:
	var at_base: bool = ctx.get("at_base", false)
	if at_base:
		oxygen += (t.base_oxygen_repaired if ctx.get("scrubber", false) else t.base_oxygen_trickle) * dt
		power += (t.base_power_repaired if ctx.get("solar", false) else t.base_power_trickle) * dt
		health += t.base_heal * dt
	else:
		oxygen -= t.oxygen_drain * dt
		if ctx.get("dark", false):
			power -= t.lamp_drain * dt
		if ctx.get("night", false):
			power -= t.cold_drain * dt
	food -= t.food_drain * dt
	# Running out hurts.
	if oxygen <= 0.0:
		health -= t.suffocate_damage * dt
	if food <= 0.0:
		health -= t.starve_damage * dt
	if power <= 0.0 and ctx.get("night", false) and not at_base:
		health -= t.freeze_damage * dt
	# Well supplied → slowly heal.
	if oxygen > oxygen_cap * t.regen_threshold and food > t.food_max * t.regen_threshold \
			and power > t.power_max * t.regen_threshold:
		health += t.health_regen * dt
	_clamp()


func _clamp() -> void:
	oxygen = clampf(oxygen, 0.0, oxygen_cap)
	food = clampf(food, 0.0, t.food_max)
	power = clampf(power, 0.0, t.power_max)
	health = clampf(health, 0.0, t.health_max)


func add(stat: String, amount: float) -> void:
	set(stat, get(stat) + amount)
	_clamp()


func damage(amount: float) -> void:
	health -= amount
	_clamp()


func is_dead() -> bool:
	return health <= 0.0


func to_dict() -> Dictionary:
	return {"oxygen": oxygen, "food": food, "power": power, "health": health, "oxygen_cap": oxygen_cap}


func from_dict(d: Dictionary) -> void:
	oxygen_cap = d.get("oxygen_cap", t.oxygen_max)
	oxygen = d.get("oxygen", oxygen_cap)
	food = d.get("food", t.food_max)
	power = d.get("power", t.power_max)
	health = d.get("health", t.health_max)
	_clamp()
