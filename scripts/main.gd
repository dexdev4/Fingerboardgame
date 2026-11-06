## Wires the scene together from the single tuning resource.
## Children do nothing in their own _ready; everything is set up here, in a fixed order.
extends Node3D

@export var tuning: BoardTuning = preload("res://tuning/board_tuning.tres")
## Load and save the player's pause-menu settings (user://settings.cfg). Headless tests turn this
## off so a settings file on the machine can never change their results.
@export var use_player_settings := true

@onready var park: Node3D = $Skatepark
@onready var board: Board = $Board
@onready var camera: ChaseCamera = $ChaseCamera
@onready var finger_input: FingerInput = $FingerInput
@onready var haptics: Haptics = $Haptics
@onready var overlay: DebugOverlay = $DebugOverlay

var settings: GameSettings
var pause_menu: PauseMenu


func _ready() -> void:
	# Fixed tick rate and scaled gravity, both from the tuning resource.
	GameSettings.apply_game_speed(tuning.physics_ticks_per_second, 1.0)   # real time
	var space := get_world_3d().space
	PhysicsServer3D.area_set_param(space, PhysicsServer3D.AREA_PARAM_GRAVITY, tuning.gravity())

	board.setup(tuning, finger_input)
	# The park decides where the board starts (and resets to).
	var spawn := park.get_node_or_null("Spawn") as Node3D
	if spawn:
		board.set_spawn(spawn.global_transform)
	finger_input.setup(tuning, board.geo, camera, board)
	camera.setup(tuning, board)
	haptics.setup(tuning, board)
	overlay.setup(board, finger_input)
	# The player's settings sit on top of the tuning (remembering the tuning's values as defaults).
	settings = GameSettings.new(tuning)
	if use_player_settings:
		settings.load_saved()
		apply_settings()
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.setup(settings, tuning, board, camera, finger_input, apply_settings, use_player_settings)
	# Snap the camera back after a reset (deferred: the board's node moves after the tick).
	board.reset_done.connect(camera.snap, CONNECT_DEFERRED)


## Push the pause-menu settings into the live tuning, the physics world and the engine.
func apply_settings() -> void:
	settings.apply(tuning, get_world_3d().space)
