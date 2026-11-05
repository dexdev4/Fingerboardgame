## Wires the scene together from the single tuning resource.
## Children do nothing in their own _ready; everything is set up here, in a fixed order.
extends Node3D

@export var tuning: BoardTuning = preload("res://tuning/board_tuning.tres")

@onready var park: Node3D = $Skatepark
@onready var board: Board = $Board
@onready var camera: ChaseCamera = $ChaseCamera
@onready var finger_input: FingerInput = $FingerInput
@onready var haptics: Haptics = $Haptics
@onready var overlay: DebugOverlay = $DebugOverlay


func _ready() -> void:
	# Fixed tick rate and scaled gravity, both from the tuning resource.
	Engine.physics_ticks_per_second = tuning.physics_ticks_per_second
	Engine.max_physics_steps_per_frame = maxi(8, tuning.physics_ticks_per_second / 15)
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
	# Snap the camera back after a reset (deferred: the board's node moves after the tick).
	board.reset_done.connect(camera.snap, CONNECT_DEFERRED)
