## Tile types: ids (= columns in the tile atlas), names, hardness tier and drops.
class_name Tiles
extends RefCounted

const AIR := -1
const GRASS := 0         # meadow turf (surface)
const FOREST_FLOOR := 1  # needle-and-leaf litter (surface in the woods)
const MOSSY_ROCK := 2    # rocky ground (surface in the Stonecrag)
const DIRT := 3
const CLAY := 4
const STONE := 5
const DEEP_STONE := 6
const BEDROCK := 7       # unbreakable: world floor, the old cliff
const COAL := 8
const IRON_ORE := 9
const GOLD := 10
const RUIN := 11         # old worked stone (Stonecrag ruins)
const COUNT := 12

const NAMES := ["grass", "forest floor", "mossy rock", "dirt", "clay", "stone", "deep stone",
		"bedrock", "coal", "iron ore", "gold", "old stonework"]


static func is_solid(id: int) -> bool:
	return id != AIR


## Hardness tier: 0 = by hand, 1 = needs a stone pickaxe, 2 = needs an iron pickaxe, -1 = never.
static func tier(id: int) -> int:
	match id:
		GRASS, FOREST_FLOOR, DIRT, CLAY:
			return 0
		MOSSY_ROCK, STONE, COAL, IRON_ORE, RUIN:
			return 1
		DEEP_STONE, GOLD:
			return 2
	return -1


## Item you get for breaking a tile ("" = nothing).
static func drop(id: int) -> String:
	match id:
		CLAY:
			return "clay"
		MOSSY_ROCK, STONE, DEEP_STONE, RUIN:
			return "stone"
		COAL:
			return "coal"
		IRON_ORE:
			return "iron_ore"
		GOLD:
			return "gold"
	return ""
