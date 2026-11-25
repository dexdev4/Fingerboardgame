## Crafting rules (pure). Recipes come from GameTuning.recipes; each needs a station:
##   hand      — anywhere,
##   workbench — inside the cabin, with a workbench placed,
##   hearth    — inside the cabin, with a hearth placed.
## Cabin upgrades are recipes too: crafting one changes the cabin instead of adding an item.
class_name Crafting
extends RefCounted

const TOOL_LINES := {"stone_axe": "axe", "iron_axe": "axe", "stone_pick": "pick", "iron_pick": "pick"}


## "" if `id` can be crafted now, else the reason (shown in the craft list).
static func block(t: GameTuning, id: String, inv: Inventory, cabin: Cabin, at_home: bool) -> String:
	var r: Dictionary = t.recipes.get(id, {})
	if r.is_empty():
		return "Unknown"
	match r.station:
		"workbench":
			if not (at_home and cabin.has_function("workbench")):
				return "Needs your workbench"
		"hearth":
			if not (at_home and cabin.has_function("hearth")):
				return "Needs your hearth"
	if Catalog.kind(id) == "upgrade":
		var why := cabin.upgrade_block(id)
		if why != "":
			return why
	if TOOL_LINES.has(id) and tool_tier(inv, TOOL_LINES[id]) >= tier_of(id):
		return "You have one"
	if not inv.can_afford(r.cost):
		return "Not enough"
	return ""


## Craft `id` if possible. Returns true on success.
static func craft(t: GameTuning, id: String, inv: Inventory, cabin: Cabin, at_home: bool) -> bool:
	if block(t, id, inv, cabin, at_home) != "":
		return false
	var r: Dictionary = t.recipes[id]
	inv.spend(r.cost)
	if Catalog.kind(id) == "upgrade":
		cabin.apply_upgrade(id)
	else:
		inv.add(id, int(r.get("out", 1)))
	return true


## Best tool tier carried for a line ("axe" / "pick"): 0 none, 1 stone, 2 iron.
static func tool_tier(inv: Inventory, line: String) -> int:
	if inv.count("iron_" + line) > 0:
		return 2
	if inv.count("stone_" + line) > 0:
		return 1
	return 0


static func tier_of(tool_id: String) -> int:
	return 2 if tool_id.begins_with("iron_") else 1


## "3 Plank, 1 Iron bar" for a cost.
static func cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for item in cost:
		parts.append("%d %s" % [int(cost[item]), Catalog.item_name(item)])
	return ", ".join(parts)
