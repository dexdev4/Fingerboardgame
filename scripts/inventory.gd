## A bag of items: item id → count. Used for what you carry and for the cabin chest.
class_name Inventory
extends RefCounted

signal changed

var items := {}


func count(item: String) -> int:
	return items.get(item, 0)


func add(item: String, n: int = 1) -> void:
	if n == 0:
		return
	items[item] = count(item) + n
	if items[item] <= 0:
		items.erase(item)
	changed.emit()


func can_afford(cost: Dictionary) -> bool:
	for item in cost:
		if count(item) < int(cost[item]):
			return false
	return true


func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for item in cost:
		add(item, -int(cost[item]))
	changed.emit()
	return true


## Everything carried, sorted by name (for lists).
func ids() -> Array:
	var out := items.keys()
	out.sort()
	return out


## Lose `fraction` of every MATERIAL (rounded down) — what collapsing in the woods costs.
func lose_fraction(fraction: float) -> Dictionary:
	var lost := {}
	for item in items.keys():
		if Catalog.kind(item) != "material":
			continue
		var n := int(floor(count(item) * fraction))
		if n > 0:
			add(item, -n)
			lost[item] = n
	changed.emit()
	return lost


## Move every material and food into `other` (the chest). Tools, furniture and torches stay.
func deposit_into(other: Inventory) -> int:
	var moved := 0
	for item in items.keys():
		var k := Catalog.kind(item)
		if k == "material" or k == "food" or k == "medicine":
			var n := count(item)
			other.add(item, n)
			add(item, -n)
			moved += n
	return moved


## Move everything from this bag into `other`.
func take_all_into(other: Inventory) -> int:
	var moved := 0
	for item in items.keys():
		var n := count(item)
		other.add(item, n)
		add(item, -n)
		moved += n
	return moved


func to_dict() -> Dictionary:
	return items.duplicate()


func from_dict(d: Dictionary) -> void:
	items.clear()
	for k in d:
		if int(d[k]) > 0:
			items[k] = int(d[k])
	changed.emit()
