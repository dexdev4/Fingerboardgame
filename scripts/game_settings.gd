## The player's pause-menu settings, saved on the device (user://settings.cfg).
##
## They sit ON TOP of the tuning resource: on start we remember the tuning's own values (the
## "defaults"), and apply() writes the player's choices into the live tuning, so every script
## keeps reading one resource (board_tuning.tres stays the single source of tuning numbers).
## Multipliers (flip speed, flick sensitivity) scale the tuning's values; gravity and the camera
## settings are absolute values with the tuning's values as defaults.
class_name GameSettings
extends RefCounted

const PATH := "user://settings.cfg"
const SECTION := "settings"
## Every saved setting (names of the properties below).
const KEYS := ["game_speed", "flip_speed", "flick_sensitivity", "gravity", "camera_distance",
		"camera_height", "camera_orbit_deg", "camera_aim_height", "camera_fov_deg"]

## Time manipulator: 1 = real time, 0.5 = half-speed slow motion.
var game_speed := 1.0
## × the tuning's flip / shove spin ceilings (how fast a kickflip rolls, a shove-it spins).
var flip_speed := 1.0
## × the tuning's flick_sensitivity (how much a finger speed counts as a press).
var flick_sensitivity := 1.0
## Gravity, × real gravity (the tuning's gravity_multiplier).
var gravity := 0.4
## Camera position and angle (world units / degrees), defaults from the tuning.
var camera_distance := 1.15
var camera_height := 0.8
var camera_orbit_deg := 0.0
var camera_aim_height := 0.0
var camera_fov_deg := 55.0

var _base := {}   # tuning values at start (the defaults)


func _init(t: BoardTuning) -> void:
	# Defaults come from a fresh copy of the tuning FILE: the loaded resource is shared and cached,
	# so after apply() its values are the player's, not the defaults (e.g. if the scene reloads).
	var fresh: Resource = null
	if t.resource_path != "":
		fresh = ResourceLoader.load(t.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var src: Resource = fresh if fresh is BoardTuning else t
	for k in ["physics_ticks_per_second", "gravity_multiplier", "press_side_max_roll",
			"press_side_max_speed", "press_scoop_max_spin", "flick_sensitivity", "camera_distance",
			"camera_height", "camera_orbit_deg", "camera_aim_height", "camera_fov_deg"]:
		_base[k] = src.get(k)
	reset_to_defaults()


## Back to the tuning resource's own values.
func reset_to_defaults() -> void:
	game_speed = 1.0
	flip_speed = 1.0
	flick_sensitivity = 1.0
	gravity = _base.gravity_multiplier
	camera_distance = _base.camera_distance
	camera_height = _base.camera_height
	camera_orbit_deg = _base.camera_orbit_deg
	camera_aim_height = _base.camera_aim_height
	camera_fov_deg = _base.camera_fov_deg


func load_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return   # first run: keep the defaults
	for k in KEYS:
		set(k, float(cfg.get_value(SECTION, k, get(k))))


func save() -> void:
	var cfg := ConfigFile.new()
	for k in KEYS:
		cfg.set_value(SECTION, k, get(k))
	cfg.save(PATH)


## Write the settings into the live tuning and the engine. `space`: the physics world (gravity).
func apply(t: BoardTuning, space: RID) -> void:
	t.gravity_multiplier = gravity
	PhysicsServer3D.area_set_param(space, PhysicsServer3D.AREA_PARAM_GRAVITY, t.gravity())
	t.press_side_max_roll = _base.press_side_max_roll * flip_speed
	t.press_side_max_speed = _base.press_side_max_speed * flip_speed
	t.press_scoop_max_spin = _base.press_scoop_max_spin * flip_speed
	t.flick_sensitivity = _base.flick_sensitivity * flick_sensitivity
	t.camera_distance = camera_distance
	t.camera_height = camera_height
	t.camera_orbit_deg = camera_orbit_deg
	t.camera_aim_height = camera_aim_height
	t.camera_fov_deg = camera_fov_deg
	apply_game_speed(_base.physics_ticks_per_second, game_speed)


## Game speed WITHOUT changing the physics: Godot steps physics by (1 / ticks) × time_scale
## seconds. Running ticks = base × speed per real second with time_scale = ticks / base keeps
## every step at exactly 1 / base s — the same ticks as at full speed, just fewer of them per real
## second. So the same fingers (per tick) give the same trick in slow motion (determinism).
## Note: your fingers are NOT slowed down — at half speed a real flick spans half as many
## ticks, so it reads twice as fast. Slow motion = you're faster than the world.
static func apply_game_speed(base_ticks: int, speed: float) -> void:
	var ticks := maxi(1, roundi(base_ticks * speed))
	Engine.physics_ticks_per_second = ticks
	Engine.time_scale = float(ticks) / float(base_ticks)
	Engine.max_physics_steps_per_frame = maxi(8, ticks / 15)
