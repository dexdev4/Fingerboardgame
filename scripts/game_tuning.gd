## Every tuning value for Tessaris: world generation, player, survival, base, day/night, camera.
## The saved instance is res://tuning/game_tuning.tres — edit it in the Inspector.
## Units: distances in pixels (px) or tiles, times in seconds, rates per second.
class_name GameTuning
extends Resource

@export_group("World")
## Seed for a new game (0 = pick one from the clock when starting a new game).
@export var default_seed: int = 0
## Size of one tile (px).
@export var tile_size: int = 32
## Width of a generated chunk (tiles).
@export var chunk_width: int = 32
## Chunks kept loaded on each side of the player's chunk.
@export var chunk_radius: int = 2
## Highest tile row generated (sky; negative = up) and lowest (bedrock).
@export var world_top: int = -48
@export var world_bottom: int = 96
## West edge of the world (tiles): the crater wall behind the crash site.
@export var world_min_x: int = -40
## Average surface row and how far hills rise/fall from it (tiles).
@export var surface_base: int = 0
@export var hill_amplitude: float = 10.0
## Horizontal size of the big hills / small bumps (tiles per noise cell).
@export var hill_scale: float = 48.0
@export var bump_scale: float = 9.0
@export var bump_amplitude: float = 2.5
## Flat landing zone around the ship: |x| < this (tiles) is flattened to surface_base.
@export var crash_flat_radius: int = 7
## Depth of the soft top layer (regolith/soil) before rock (tiles).
@export var topsoil_depth: int = 4
## Rock turns into deep rock this many tiles under the surface.
@export var deep_rock_depth: int = 30
## Caves: 2D noise above this threshold is hollow (0..1; higher = fewer caves).
@export var cave_threshold: float = 0.68
@export var cave_scale: float = 11.0
## No caves this close under the surface (tiles), so the ground doesn't collapse into holes.
@export var cave_min_depth: int = 6
## Ore veins: noise threshold per resource (0..1; higher = rarer) and vein size (tiles).
@export var ore_threshold: float = 0.80
@export var ice_threshold: float = 0.78
@export var crystal_threshold: float = 0.80
@export var alloy_threshold: float = 0.83
@export var vein_scale: float = 4.0

@export_group("Biomes (east distance from the ship, tiles)")
## Where each biome starts (jittered by noise). Past the last one, biomes cycle.
@export var biome_crystal_start: int = 120
@export var biome_fungal_start: int = 300
@export var biome_ruins_start: int = 500
## Noise jitter of biome borders (tiles).
@export var biome_jitter: float = 25.0
## Length of one biome after the ruins, when the biome cycle repeats (tiles).
@export var biome_cycle_length: int = 220

@export_group("Surface pickups")
## Chance per surface column of an air-bladder plant / glowcap fungus / wreck part (0..1),
## scaled by biome (see WorldGen._pickup_chances).
@export var bladder_chance: float = 0.035
@export var glowcap_chance: float = 0.05
@export var wreck_chance: float = 0.03
## Crew-log pods: one every this many tiles east of the ship (with jitter).
@export var crew_log_spacing: int = 70
## Monoliths (ruin lore): one every this many tiles inside ruins biomes.
@export var monolith_spacing: int = 60

@export_group("Player")
@export var run_speed: float = 220.0          ## px/s
@export var run_accel: float = 1600.0         ## px/s²
@export var air_accel: float = 900.0          ## px/s² (less control in the air)
@export var jump_speed: float = 520.0         ## px/s upward
@export var gravity: float = 1250.0           ## px/s² (Tessaris is a bit heavier than Earth)
@export var max_fall_speed: float = 900.0     ## px/s
## Landing faster than this hurts (px/s), damage per px/s above it.
@export var fall_safe_speed: float = 720.0
@export var fall_damage_per_speed: float = 0.12
## Reach for mining / picking up / using (tiles from the player's centre).
@export var reach_tiles: float = 3.2
## Grace time after leaving a ledge during which a jump still works (s).
@export var coyote_time: float = 0.1

@export_group("Mining")
## Hits needed per tile type: soft (regolith/soil), rock, deep rock, ore/ice/crystal, alloy.
@export var hits_soft: int = 1
@export var hits_rock: int = 2
@export var hits_deep: int = 3
@export var hits_ore: int = 2
@export var hits_alloy: int = 4
## Suit power used per mining hit.
@export var mine_power_cost: float = 0.6
## Holding a finger on a tile keeps hitting it every this many seconds.
@export var mine_interval: float = 0.22
## Wreckage: metal it always gives, and the chance it also holds a power cell (0..1).
@export var wreck_metal: int = 2
@export var wreck_cell_chance: float = 0.4

@export_group("Survival (per second unless noted)")
@export var oxygen_max: float = 120.0
@export var food_max: float = 100.0
@export var power_max: float = 100.0
@export var health_max: float = 100.0
@export var oxygen_drain: float = 1.0
@export var food_drain: float = 0.22
## Headlamp power use while it's dark (night or underground).
@export var lamp_drain: float = 0.35
## Extra power use at night outside the ship (the suit heater fights the cold).
@export var cold_drain: float = 0.4
## Health loss while oxygen / food / power (at night: freezing) is empty.
@export var suffocate_damage: float = 4.0
@export var starve_damage: float = 0.6
@export var freeze_damage: float = 1.2
## Health regeneration while oxygen, food and power are all above regen_threshold (fraction).
@export var health_regen: float = 0.8
@export var regen_threshold: float = 0.5
## Darkness counts as "underground" this many tiles below the surface.
@export var underground_depth: int = 4

@export_group("Items")
## Oxygen from an air-bladder plant, food from a glowcap, power from a power cell.
@export var bladder_oxygen: float = 35.0
@export var glowcap_food: float = 25.0
@export var cell_power: float = 45.0
## Oxygen from one crafted O2 canister.
@export var canister_oxygen: float = 60.0
## On death, this fraction of every carried resource is lost.
@export var death_loss: float = 0.5

@export_group("Ship (base)")
## Range around the ship where you're "at base" (tiles).
@export var base_radius: float = 4.0
## Oxygen/power refill at the ship before and after repairing the scrubber / solar array.
@export var base_oxygen_trickle: float = 3.0
@export var base_oxygen_repaired: float = 25.0
@export var base_power_trickle: float = 1.0
@export var base_power_repaired: float = 15.0
## Ship repairs: id → resources needed. (Names and effects are in ship.gd.)
@export var repairs: Dictionary = {
	"scrubber": {"metal": 4, "ice": 3},
	"solar": {"metal": 6, "crystal": 3},
	"tank": {"metal": 5, "ice": 4, "crystal": 2},
	"antenna": {"metal": 10, "crystal": 6, "alloy": 4},
}
## Things you can make at the ship: item → resources needed.
@export var crafts: Dictionary = {
	"canister": {"ice": 2},
	"cell": {"crystal": 2},
}
## Health regeneration bonus while at the ship (per second).
@export var base_heal: float = 1.5
## Oxygen capacity added by the suit tank upgrade.
@export var tank_upgrade_oxygen: float = 80.0

@export_group("Day and night")
## Length of one full day (s) and the share of it that is night (0..1).
@export var day_length: float = 300.0
@export var night_fraction: float = 0.35
## Game starts at this time of day (0 = dawn, 0.5 = dusk-ish; fraction of a day).
@export var start_time: float = 0.08
## Darkness at midnight / deep underground (0 = black, 1 = full light).
@export var night_light: float = 0.18
@export var underground_light: float = 0.12

@export_group("Camera")
## Camera zoom (1 = 720 px of world across the screen in portrait design pixels).
@export var camera_zoom: float = 1.0
## Shifts the view down so the player sits above the touch buttons (px).
@export var camera_offset_y: float = 150.0
## Camera smoothing speed (higher = tighter follow).
@export var camera_smoothing: float = 6.0

@export_group("Controls")
## Height of the touch button bar at the bottom of the screen (design px, 1280-high screen).
@export var touch_bar_height: float = 230.0

@export_group("Saving")
## Autosave interval (s).
@export var autosave_interval: float = 30.0


## Pixels → tile coordinate (floor).
func to_tile(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / tile_size), floori(p.y / tile_size))


## Tile coordinate → centre of that tile (px).
func tile_center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * tile_size
