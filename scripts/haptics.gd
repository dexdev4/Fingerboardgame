## Short vibrations on physical events (tail pop, landing). Output only: never affects physics.
## Needs the VIBRATE permission in the Android export preset (already enabled).
class_name Haptics
extends Node

var tuning: BoardTuning


func setup(t: BoardTuning, board: Board) -> void:
	tuning = t
	board.popped.connect(_on_popped)
	board.landed.connect(_on_landed)


func _on_popped(strength: float) -> void:
	# Stronger snap → stronger buzz (amplitude 0..1).
	_buzz(tuning.haptic_pop_ms, clampf(strength / tuning.haptic_full_speed, 0.3, 1.0))


func _on_landed(speed: float) -> void:
	if speed >= tuning.haptic_land_min_speed:
		_buzz(tuning.haptic_land_ms, clampf(speed / tuning.haptic_full_speed, 0.3, 1.0))


func _buzz(ms: int, amplitude: float) -> void:
	if tuning.haptics_enabled:
		Input.vibrate_handheld(ms, amplitude)
