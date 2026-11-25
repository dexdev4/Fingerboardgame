## What every item is: its name, kind and (for furniture) where and how it's placed.
## Costs and numbers live in GameTuning (rule 4); this is the descriptive catalog.
class_name Catalog
extends RefCounted

## id → [display name, kind]. Kinds: material, food, medicine, tool, light, furniture, upgrade.
const ITEMS := {
	"log": ["Log", "material"], "plank": ["Plank", "material"], "stone": ["Stone", "material"],
	"clay": ["Clay", "material"], "fiber": ["Flax fibre", "material"], "cloth": ["Cloth", "material"],
	"iron_ore": ["Iron ore", "material"], "iron": ["Iron bar", "material"], "coal": ["Coal", "material"],
	"gold": ["Gold", "material"],
	"berries": ["Berries", "food"], "apple": ["Apple", "food"], "mushroom": ["Mushroom", "food"],
	"stew": ["Mushroom stew", "food"],
	"herb": ["Herb", "medicine"], "poultice": ["Poultice", "medicine"],
	"torch": ["Torch", "light"],
	"stone_axe": ["Stone axe", "tool"], "iron_axe": ["Iron axe", "tool"],
	"stone_pick": ["Stone pickaxe", "tool"], "iron_pick": ["Iron pickaxe", "tool"],
	"workbench": ["Workbench", "furniture"], "hearth": ["Hearth", "furniture"], "chest": ["Chest", "furniture"],
	"bed_straw": ["Straw bed", "furniture"], "bed_wood": ["Wooden bed", "furniture"],
	"table": ["Table", "furniture"], "chair": ["Chair", "furniture"], "stool": ["Stool", "furniture"],
	"bookshelf": ["Bookshelf", "furniture"], "barrel": ["Barrel", "furniture"], "plant_pot": ["Potted herbs", "furniture"],
	"candle_stand": ["Candle stand", "furniture"], "window": ["Window", "furniture"], "shelf": ["Shelf", "furniture"],
	"banner": ["Banner", "furniture"], "tapestry": ["Tapestry", "furniture"], "sconce": ["Wall candle", "furniture"],
	"lantern": ["Lantern", "furniture"], "dried_herbs": ["Drying herbs", "furniture"], "rug": ["Rug", "furniture"],
	"mat": ["Woven mat", "furniture"],
	"floor_planks": ["Plank floor", "upgrade"], "floor_stone": ["Stone floor", "upgrade"],
	"walls_planks": ["Planed walls", "upgrade"], "walls_plaster": ["Plastered walls", "upgrade"],
	"roof_shingles": ["Shingle roof", "upgrade"], "extend": ["Extend cabin", "upgrade"],
}

## Furniture placement: id → [layer, width in tiles, height in tiles (wall items)].
## Layers: "floor" stands on the floor, "wall" hangs on the back wall, "rug" lies on the floor.
const FURNITURE := {
	"bed_straw": ["floor", 2, 1], "bed_wood": ["floor", 3, 2], "hearth": ["floor", 2, 3],
	"workbench": ["floor", 2, 2], "chest": ["floor", 1, 1], "table": ["floor", 2, 1],
	"chair": ["floor", 1, 2], "stool": ["floor", 1, 1], "bookshelf": ["floor", 1, 2],
	"barrel": ["floor", 1, 1], "plant_pot": ["floor", 1, 1], "candle_stand": ["floor", 1, 2],
	"window": ["wall", 2, 2], "shelf": ["wall", 2, 1], "banner": ["wall", 1, 2], "tapestry": ["wall", 2, 2],
	"sconce": ["wall", 1, 1], "lantern": ["wall", 1, 1], "dried_herbs": ["wall", 1, 1],
	"rug": ["rug", 3, 1], "mat": ["rug", 2, 1],
}

## What using a piece of furniture does (tap it in the cabin).
const FUNCTIONS := {"bed_straw": "bed", "bed_wood": "bed", "hearth": "hearth", "workbench": "workbench", "chest": "chest"}

## Background id → [name, description].
const BACKGROUNDS := {
	"woodcutter": ["Woodcutter", "Starts with a stone axe and some logs."],
	"mason": ["Stonemason", "Starts with a stone pickaxe and stone."],
	"herbalist": ["Herbalist", "Starts with herbs, berries and a poultice."],
	"wanderer": ["Wanderer", "Hardened to the cold. Starts with torches."],
}

## Craft panel groups (in order) and which recipe ids go in each.
const GROUPS := [
	["Tools", ["workbench", "torch", "stone_axe", "stone_pick", "iron_axe", "iron_pick"]],
	["Materials", ["plank", "cloth", "iron"]],
	["Food & medicine", ["stew", "poultice"]],
	["Furniture", ["hearth", "chest", "bed_wood", "table", "chair", "stool", "bookshelf", "barrel", "plant_pot", "candle_stand"]],
	["Wall decor", ["window", "shelf", "banner", "tapestry", "sconce", "lantern", "dried_herbs"]],
	["Rugs", ["rug", "mat"]],
	["Cabin upgrades", ["floor_planks", "floor_stone", "walls_planks", "walls_plaster", "roof_shingles", "extend"]],
]


static func item_name(id: String) -> String:
	return ITEMS.get(id, [id.capitalize()])[0]


static func kind(id: String) -> String:
	return ITEMS.get(id, ["", "material"])[1]


static func is_furniture(id: String) -> bool:
	return FURNITURE.has(id)


## Icon texture for any item (furniture uses its sprite).
static func icon(id: String) -> Texture2D:
	if FURNITURE.has(id):
		return Sprites.furniture(id)
	return Sprites.icon(id)
