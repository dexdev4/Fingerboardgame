## What the explorer carries: item name → count.
## Resources: metal, ice, crystal, alloy. Usables: glowcap (food), canister (oxygen), cell (power).
class_name Inventory
extends RefCounted

signal changed

const RESOURCES := ["metal", "ice", "crystal", "alloy"]
const USABLES := ["glowcap", "canister", "cell"]

var items := {}


func count(item: String) -> int:
	return items.get(item, 0)


func add(item: String, n: int = 1) -> void:
	items[item] = count(item) + n
	changed.emit()


## True if every item in `cost` ({item: n}) is carried in that amount.
func can_afford(cost: Dictionary) -> bool:
	for item in cost:
		if count(item) < int(cost[item]):
			return false
	return true


## Remove `cost`; returns false (and removes nothing) if it isn't affordable.
func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for item in cost:
		items[item] = count(item) - int(cost[item])
	changed.emit()
	return true


## Lose `fraction` of every resource (rounded down) — what a suit failure costs.
## Returns what was lost.
func lose_fraction(fraction: float) -> Dictionary:
	var lost := {}
	for item in RESOURCES:
		var n := int(floor(count(item) * fraction))
		if n > 0:
			items[item] = count(item) - n
			lost[item] = n
	changed.emit()
	return lost


func to_dict() -> Dictionary:
	return items.duplicate()


func from_dict(d: Dictionary) -> void:
	items.clear()
	for k in d:
		items[k] = int(d[k])
	changed.emit()
