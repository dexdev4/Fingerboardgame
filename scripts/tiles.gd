## Tile types: ids, names, colours, how hard they are to mine and what they drop.
## A tile id is also its column in the generated tile atlas (TileSetBuilder).
class_name Tiles
extends RefCounted

const AIR := -1
const REGOLITH := 0     # rusty top layer (crash plains)
const SAND := 1         # pale crystal sand (crystal fields)
const SOIL := 2         # dark spongy soil (fungal lowlands)
const DUST := 3         # grey ash (ruins expanse)
const ROCK := 4
const DEEP_ROCK := 5
const BEDROCK := 6      # unbreakable (world floor, crater wall)
const ORE := 7          # metal ore → metal
const ICE := 8          # water ice → ice
const CRYSTAL := 9      # energy crystal → crystal
const ALLOY := 10       # alien alloy (ruins) → alloy
const RUIN := 11        # carved ruin stone (pillars)
const COUNT := 12

const NAMES := ["regolith", "crystal sand", "soil", "ash", "rock", "deep rock", "bedrock",
		"metal ore", "ice", "energy crystal", "alien alloy", "ruin stone"]

## Base colour of each tile (the atlas adds texture on top).
const COLORS := [
	Color("a4553b"), Color("c9b6d8"), Color("4a2f5c"), Color("6f7584"),
	Color("5b4a5e"), Color("3c3145"), Color("1c1622"),
	Color("5b4a5e"), Color("a8e2f0"), Color("5b4a5e"), Color("2c3340"), Color("7d7a8c")]

## Highlight colour for veins/spots (ore flecks, crystal shards, alloy circuitry).
const ACCENTS := [
	Color("c97a55"), Color("efe3f7"), Color("8ff0c8"), Color("9aa0ae"),
	Color("6e5c70"), Color("4d4057"), Color("2a2230"),
	Color("e0b36a"), Color("e9fbff"), Color("ff5fd2"), Color("66f0ff"), Color("b6f5e6")]


## True for tiles you can stand on (everything except air).
static func is_solid(id: int) -> bool:
	return id != AIR


## Mining hits needed (0 = can't be mined).
static func hits(id: int, t: GameTuning) -> int:
	match id:
		REGOLITH, SAND, SOIL, DUST:
			return t.hits_soft
		ROCK:
			return t.hits_rock
		DEEP_ROCK:
			return t.hits_deep
		ORE, ICE, CRYSTAL:
			return t.hits_ore
		ALLOY, RUIN:
			return t.hits_alloy
	return 0   # air, bedrock


## Item you get for breaking a tile ("" = nothing).
static func drop(id: int) -> String:
	match id:
		ORE:
			return "metal"
		ICE:
			return "ice"
		CRYSTAL:
			return "crystal"
		ALLOY:
			return "alloy"
	return ""
