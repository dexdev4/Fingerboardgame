## Every tuning value for Eldwood: world generation, player, tools, survival, cabin, crafting,
## day/night, camera. The saved instance is res://tuning/game_tuning.tres (edit in the Inspector).
## Units: pixels (px, at the game's 180×320 resolution) or tiles; seconds; rates per second.
class_name GameTuning
extends Resource

@export_group("World")
## Seed for a new game (0 = pick one from the clock when starting a new game).
@export var default_seed: int = 0
## Size of one tile (px).
@export var tile_size: int = 8
## Width of a generated chunk (tiles), and chunks kept loaded each side of the player.
@export var chunk_width: int = 32
@export var chunk_radius: int = 2
## Highest (sky) and lowest (bedrock) tile rows.
@export var world_top: int = -48
@export var world_bottom: int = 96
## West edge (tiles): the old cliff behind the cabin.
@export var world_min_x: int = -36
## Average surface row; hill height and size (tiles).
@export var surface_base: int = 0
@export var hill_amplitude: float = 9.0
@export var hill_scale: float = 44.0
@export var bump_scale: float = 8.0
@export var bump_amplitude: float = 2.0
## Flat clearing around the cabin: |x| < this (tiles).
@export var clearing_radius: int = 9
## Soil depth before stone (tiles), and where stone turns to deep stone.
@export var topsoil_depth: int = 5
@export var deep_stone_depth: int = 28
## Caves: 2D noise above this is hollow (higher = fewer caves); size; no caves this near the surface.
@export var cave_threshold: float = 0.68
@export var cave_scale: float = 10.0
@export var cave_min_depth: int = 7
## Ore veins: noise thresholds (0..1, higher = rarer) and vein size (tiles).
@export var clay_threshold: float = 0.70
@export var coal_threshold: float = 0.87
@export var iron_threshold: float = 0.91
@export var gold_threshold: float = 0.93
@export var vein_scale: float = 4.0

@export_group("Biomes (tiles east of the cabin)")
@export var biome_pinewood_start: int = 90
@export var biome_elderwood_start: int = 260
@export var biome_stonecrag_start: int = 460
@export var biome_jitter: float = 20.0
## Length of each biome after the Stonecrag, when they start repeating (tiles).
@export var biome_cycle_length: int = 200

@export_group("Trees and forage")
## A tree may grow every this many columns (one candidate per slot).
@export var tree_slot: int = 3
## Chance of a tree per slot by biome: meadow, pinewood, elderwood, stonecrag.
@export var tree_density: Array[float] = [0.4, 0.75, 0.6, 0.2]
## Hits of strength 1 needed to fell a pine / oak / birch.
@export var tree_hp_pine: int = 6
@export var tree_hp_oak: int = 8
@export var tree_hp_birch: int = 5
## Logs from a pine / oak / birch; chance an oak also drops an apple.
@export var logs_pine: int = 3
@export var logs_oak: int = 4
@export var logs_birch: int = 2
@export var oak_apple_chance: float = 0.5
## Forage chance per surface column (scaled per biome in WorldGen).
@export var berry_chance: float = 0.03
@export var mushroom_chance: float = 0.03
@export var flax_chance: float = 0.03
@export var herb_chance: float = 0.02
@export var rock_chance: float = 0.04
## What forage gives: berries, mushrooms, fiber (flax), herbs, stone (loose rocks).
@export var berry_yield: int = 3
@export var mushroom_yield: int = 2
@export var flax_yield: int = 2
@export var herb_yield: int = 1
@export var rock_yield: int = 2
## Hermit's journal pages: one every this many tiles east (jittered).
@export var page_spacing: int = 60
## Runestones: one every this many tiles inside the Stonecrag.
@export var runestone_spacing: int = 50

@export_group("Player")
@export var run_speed: float = 56.0          ## px/s
@export var run_accel: float = 420.0         ## px/s²
@export var air_accel: float = 240.0         ## px/s²
@export var jump_speed: float = 132.0        ## px/s upward (about 2.5 tiles high)
@export var gravity: float = 330.0           ## px/s²
@export var max_fall_speed: float = 240.0    ## px/s
@export var fall_safe_speed: float = 190.0   ## landing faster than this hurts (px/s)
@export var fall_damage_per_speed: float = 0.45
@export var reach_tiles: float = 3.2         ## reach for chopping, mining, picking up
@export var coyote_time: float = 0.1

@export_group("Tools and work")
## Hits needed per tile hardness tier (0 soil/clay, 1 stone/ores, 2 deep stone/gold).
@export var tier_hits: Array[int] = [1, 2, 3]
## Pick power: tiles of tier > pick tier can't be mined; damage per hit (hands, stone, iron).
@export var pick_damage: Array[int] = [1, 1, 2]
## Axe damage per chop (hands, stone axe, iron axe).
@export var axe_damage: Array[int] = [1, 2, 3]
## Holding a finger on something keeps working it every this many seconds.
@export var work_interval: float = 0.3
## Stamina per chop or mining hit.
@export var work_stamina: float = 3.0

@export_group("Survival (per second unless noted)")
@export var health_max: float = 100.0
@export var hunger_max: float = 100.0
@export var warmth_max: float = 100.0
@export var stamina_max: float = 100.0
@export var hunger_drain: float = 0.16
## Warmth: lost at night outside; gained by day outside, at home, and more beside a hearth.
@export var cold_drain: float = 0.75
@export var sun_warmth: float = 0.4
@export var home_warmth: float = 2.0
@export var hearth_warmth: float = 6.0
## Stamina comes back while you're not working (halved when starving).
@export var stamina_regen: float = 7.0
## Health loss while starving / freezing; regen while fed and warm (above regen_threshold).
@export var starve_damage: float = 0.5
@export var freeze_damage: float = 1.5
@export var health_regen: float = 0.6
@export var regen_threshold: float = 0.5
## Underground (darker, a little colder) this many tiles below the surface.
@export var underground_depth: int = 4
## On death, this fraction of every carried material is lost (the chest keeps things safe).
@export var death_loss: float = 0.5

@export_group("Food and medicine")
## Food: hunger restored. Medicine: health restored.
@export var food_values: Dictionary = {"berries": 10.0, "apple": 14.0, "mushroom": 8.0, "stew": 38.0}
@export var heal_values: Dictionary = {"herb": 10.0, "poultice": 35.0}

@export_group("Torches and light")
## One torch burns this long (s) while it's dark and you carry torches.
@export var torch_burn_time: float = 90.0
## Light radius with / without a torch (px).
@export var torch_radius: float = 70.0
@export var glow_radius: float = 22.0

@export_group("Cabin")
## Interior width at the start, added per extension, and the most extensions.
@export var cabin_width: int = 14
@export var cabin_extend_width: int = 6
@export var cabin_max_extensions: int = 2
## Interior height (tiles) and wall-slot rows (from the top) furniture can hang on.
@export var cabin_height: int = 9
## Base interior light (0..1) and how much each light source adds.
@export var cabin_base_light: float = 0.45
@export var light_values: Dictionary = {"hearth": 0.3, "candle_stand": 0.12, "sconce": 0.1, "lantern": 0.18, "window": 0.12}
## Comfort points per placed item and per upgrade; sleeping heals 2 health per comfort point.
@export var comfort_values: Dictionary = {
	"bed_straw": 1, "bed_wood": 4, "hearth": 3, "workbench": 0, "chest": 1, "table": 2, "chair": 1,
	"stool": 1, "bookshelf": 3, "barrel": 1, "plant_pot": 2, "candle_stand": 1, "window": 2,
	"shelf": 1, "banner": 2, "tapestry": 3, "sconce": 1, "lantern": 1, "dried_herbs": 1, "rug": 2, "mat": 1,
	"floor_planks": 3, "floor_stone": 4, "walls_planks": 3, "walls_plaster": 5, "roof_shingles": 2, "extend": 2}
@export var sleep_heal_per_comfort: float = 2.0
## Hunger used by a night's sleep.
@export var sleep_hunger: float = 15.0

@export_group("Crafting")
## Recipes: id → {"cost": {item: n}, "station": "hand" | "workbench" | "hearth", "out": n}.
## Ids are items (catalog.gd) or cabin upgrades.
@export var recipes: Dictionary = {
	# By hand, anywhere
	"workbench": {"cost": {"log": 6}, "station": "hand", "out": 1},
	"torch": {"cost": {"log": 1, "fiber": 2}, "station": "hand", "out": 2},
	"stone_axe": {"cost": {"log": 2, "stone": 3}, "station": "hand", "out": 1},
	"stone_pick": {"cost": {"log": 2, "stone": 3}, "station": "hand", "out": 1},
	# Workbench: materials and tools
	"plank": {"cost": {"log": 1}, "station": "workbench", "out": 2},
	"cloth": {"cost": {"fiber": 3}, "station": "workbench", "out": 1},
	"poultice": {"cost": {"herb": 2, "cloth": 1}, "station": "workbench", "out": 1},
	"iron_axe": {"cost": {"plank": 2, "iron": 3}, "station": "workbench", "out": 1},
	"iron_pick": {"cost": {"plank": 2, "iron": 3}, "station": "workbench", "out": 1},
	# Workbench: furniture and decor
	"hearth": {"cost": {"stone": 14, "clay": 6}, "station": "workbench", "out": 1},
	"chest": {"cost": {"plank": 6, "iron": 1}, "station": "workbench", "out": 1},
	"bed_wood": {"cost": {"plank": 10, "cloth": 4}, "station": "workbench", "out": 1},
	"table": {"cost": {"plank": 6}, "station": "workbench", "out": 1},
	"chair": {"cost": {"plank": 3}, "station": "workbench", "out": 1},
	"stool": {"cost": {"plank": 2}, "station": "workbench", "out": 1},
	"bookshelf": {"cost": {"plank": 8}, "station": "workbench", "out": 1},
	"barrel": {"cost": {"plank": 5, "iron": 1}, "station": "workbench", "out": 1},
	"plant_pot": {"cost": {"clay": 3, "herb": 1}, "station": "workbench", "out": 1},
	"candle_stand": {"cost": {"iron": 1, "fiber": 2}, "station": "workbench", "out": 1},
	"window": {"cost": {"plank": 4}, "station": "workbench", "out": 1},
	"shelf": {"cost": {"plank": 3}, "station": "workbench", "out": 1},
	"banner": {"cost": {"cloth": 3, "plank": 1}, "station": "workbench", "out": 1},
	"tapestry": {"cost": {"cloth": 6, "plank": 1}, "station": "workbench", "out": 1},
	"sconce": {"cost": {"iron": 1, "log": 1}, "station": "workbench", "out": 1},
	"lantern": {"cost": {"iron": 2, "coal": 1}, "station": "workbench", "out": 1},
	"dried_herbs": {"cost": {"herb": 3, "fiber": 2}, "station": "workbench", "out": 1},
	"rug": {"cost": {"cloth": 5}, "station": "workbench", "out": 1},
	"mat": {"cost": {"fiber": 6}, "station": "workbench", "out": 1},
	# Workbench: cabin upgrades
	"floor_planks": {"cost": {"plank": 14}, "station": "workbench", "out": 1},
	"floor_stone": {"cost": {"stone": 20}, "station": "workbench", "out": 1},
	"walls_planks": {"cost": {"plank": 18}, "station": "workbench", "out": 1},
	"walls_plaster": {"cost": {"clay": 14, "stone": 6}, "station": "workbench", "out": 1},
	"roof_shingles": {"cost": {"plank": 12, "clay": 8}, "station": "workbench", "out": 1},
	"extend": {"cost": {"log": 20, "stone": 10}, "station": "workbench", "out": 1},
	# Hearth: cooking and smelting
	"stew": {"cost": {"mushroom": 2}, "station": "hearth", "out": 1},
	"iron": {"cost": {"iron_ore": 1, "coal": 1}, "station": "hearth", "out": 1},
}

@export_group("Backgrounds (character origins)")
## Starting kit per background, plus how much night cold it feels (1 = normal).
@export var backgrounds: Dictionary = {
	"woodcutter": {"items": {"stone_axe": 1, "log": 4}, "cold": 1.0},
	"mason": {"items": {"stone_pick": 1, "stone": 6}, "cold": 1.0},
	"herbalist": {"items": {"herb": 4, "berries": 8, "poultice": 1}, "cold": 1.0},
	"wanderer": {"items": {"torch": 4, "berries": 3}, "cold": 0.6},
}

@export_group("Day and night")
## Length of a day (s), the share that is night, and the start time (0 = dawn).
@export var day_length: float = 360.0
@export var night_fraction: float = 0.35
@export var start_time: float = 0.06
## You can sleep from this time of day on (fraction of the day).
@export var sleep_from: float = 0.55
## Light at midnight and deep underground (0 = black, 1 = full).
@export var night_light: float = 0.16
@export var underground_light: float = 0.12

@export_group("Camera")
@export var camera_zoom: float = 1.0
## Shifts the view down so the player stands above the touch buttons (px).
@export var camera_offset_y: float = 30.0
@export var camera_smoothing: float = 7.0

@export_group("Controls")
## Height of the touch button bar at the bottom (px at 180×320).
@export var touch_bar_height: float = 50.0

@export_group("Saving")
@export var autosave_interval: float = 30.0


func to_tile(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / tile_size), floori(p.y / tile_size))


func tile_center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * tile_size
