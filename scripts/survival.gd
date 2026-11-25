## Your body in the Eldwood: health, hunger, warmth and stamina (rule 3).
## tick() is called every physics tick with the situation (at home? by the hearth? night?
## working?). Running out of food or warmth hurts health; working costs stamina, which comes
## back while you rest. At 0 health you collapse (Main sends you home).
class_name Survival
extends RefCounted

var t: GameTuning
var health: float
var hunger: float      # 100 = full, 0 = starving
var warmth: float
var stamina: float
## How strongly night cold bites (backgrounds: the Wanderer feels less).
var cold_factor := 1.0
var _rest := 0.0       # seconds since the last bit of work (stamina regenerates after a moment)


func _init(tuning: GameTuning) -> void:
	t = tuning
	refill_all()


func refill_all() -> void:
	health = t.health_max
	hunger = t.hunger_max
	warmth = t.warmth_max
	stamina = t.stamina_max


## One step of dt seconds. ctx keys (bool): home (inside the cabin), hearth (it has a hearth),
## night, underground.
func tick(dt: float, ctx: Dictionary) -> void:
	var home: bool = ctx.get("home", false)
	var night: bool = ctx.get("night", false)
	hunger -= t.hunger_drain * dt
	# Warmth.
	if home:
		warmth += (t.hearth_warmth if ctx.get("hearth", false) else t.home_warmth) * dt
	elif night:
		warmth -= t.cold_drain * cold_factor * dt
	elif not ctx.get("underground", false):
		warmth += t.sun_warmth * dt
	# Stamina comes back once you've rested a moment.
	_rest += dt
	if _rest > 0.4:
		stamina += t.stamina_regen * (0.5 if hunger <= 0.0 else 1.0) * dt
	# Running out hurts; being fed and warm heals.
	if hunger <= 0.0:
		health -= t.starve_damage * dt
	if warmth <= 0.0:
		health -= t.freeze_damage * dt
	if hunger > t.hunger_max * t.regen_threshold and warmth > t.warmth_max * t.regen_threshold:
		health += t.health_regen * dt
	_clamp()


## Spend stamina on one chop / dig. False (and nothing spent) if you're too tired.
func work() -> bool:
	if stamina < t.work_stamina:
		return false
	stamina -= t.work_stamina
	_rest = 0.0
	return true


func _clamp() -> void:
	health = clampf(health, 0.0, t.health_max)
	hunger = clampf(hunger, 0.0, t.hunger_max)
	warmth = clampf(warmth, 0.0, t.warmth_max)
	stamina = clampf(stamina, 0.0, t.stamina_max)


func add(stat: String, amount: float) -> void:
	set(stat, get(stat) + amount)
	_clamp()


func is_dead() -> bool:
	return health <= 0.0


func to_dict() -> Dictionary:
	return {"health": health, "hunger": hunger, "warmth": warmth, "stamina": stamina}


func from_dict(d: Dictionary) -> void:
	health = d.get("health", t.health_max)
	hunger = d.get("hunger", t.hunger_max)
	warmth = d.get("warmth", t.warmth_max)
	stamina = d.get("stamina", t.stamina_max)
	_clamp()
