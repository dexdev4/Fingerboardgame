## Low chase camera behind and slightly above the board.
## Moves in _physics_process with a fixed dt, so its pose (which the touch rays use) is
## deterministic; physics interpolation smooths it on screen at any frame rate.
##
## Smoothing uses exponential approach: x += (target − x)·(1 − e^(−k·dt)).
## Unlike a plain lerp with a constant factor, this behaves the same at any tick rate;
## k (1/s) is roughly "how many times per second it closes the gap".
class_name ChaseCamera
extends Camera3D

var tuning: BoardTuning
var board: Node3D
var _heading := Vector3.FORWARD   # flat direction the camera looks along


func setup(t: BoardTuning, b: Node3D) -> void:
	tuning = t
	board = b
	fov = t.camera_fov_deg
	near = 0.02
	far = 300.0
	snap()


## Jump straight to the target (used at start and on reset).
func snap() -> void:
	_heading = _board_heading(_heading)
	global_transform = _target_xf(board.global_position)
	reset_physics_interpolation()


func _physics_process(dt: float) -> void:
	if board == null:
		return
	fov = tuning.camera_fov_deg
	var turn := 1.0 - exp(-tuning.camera_turn_follow * dt)
	_heading = _heading.lerp(_board_heading(_heading), turn).normalized()
	var target := _target_xf(board.global_position)
	var follow := 1.0 - exp(-tuning.camera_follow * dt)
	global_position = global_position.lerp(target.origin, follow)
	look_at(board.global_position + _heading * tuning.camera_look_ahead, Vector3.UP)


## The board's nose direction flattened onto the ground. When the board points straight up
## or down (mid-trick) there is no clear heading, so keep the previous one.
func _board_heading(fallback: Vector3) -> Vector3:
	var nose := -board.global_transform.basis.z
	nose.y = 0.0
	return nose.normalized() if nose.length() > 0.3 else fallback


func _target_xf(board_pos: Vector3) -> Transform3D:
	var pos := board_pos - _heading * tuning.camera_distance + Vector3.UP * tuning.camera_height
	pos.y = maxf(pos.y, tuning.camera_height * 0.5)   # never dip under the ground when popping
	return Transform3D.IDENTITY.translated(pos).looking_at(
			board_pos + _heading * tuning.camera_look_ahead, Vector3.UP)
