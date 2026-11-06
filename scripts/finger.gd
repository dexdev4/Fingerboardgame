## One touch on the screen and what it is doing to the board.
## Filled in by FingerInput every physics tick; read by FootPhysics and the debug overlay.
class_name Finger
extends RefCounted

## NONE = not decided yet (decided on the first physics tick after landing).
## IGNORED = landed somewhere useless (role already taken, or far from the board).
enum Role { NONE, BACK_FOOT, FRONT_FOOT, PUSH, IGNORED }

var touch_index: int
var role: Role = Role.NONE

## Latest screen position (pixels). Updated by input events, sampled once per physics tick.
var screen_pos: Vector2
## Screen positions at each of the last N physics ticks (oldest first).
var history: Array[Vector2] = []
## Screen velocity (pixels/s), measured across `history`.
var screen_vel := Vector2.ZERO

# ---- Feet only ----
## True while the finger's screen ray lands on the deck outline (plus catch margin).
var on_board := false
## Contact point on the grip tape, board local (world units).
var local_pos := Vector3.ZERO
## Finger velocity over the deck, board local (units/s). Pure finger motion: both ends are
## measured against the *current* board pose, so the board moving under a still finger reads 0.
var local_vel := Vector3.ZERO
## Finger speed on screen toward the end of the board nearest it (screen units/s; 1 unit = the screen's short side).
var press_speed := 0.0
## Finger speed on screen toward the side edge (rail) nearest it (screen units/s; 1 unit = the screen's short side).
var press_speed_side := 0.0
## Last forces applied (for the debug overlay), world units.
var press_force := 0.0
var drag_force := 0.0

# ---- Push finger only ----
## Height of the surface the push finger landed on (the park isn't flat).
var ground_y := 0.0
## Finger velocity across that ground plane (units/s), relative to the camera/board.
var ground_vel := Vector3.ZERO


func _init(index: int, pos: Vector2) -> void:
	touch_index = index
	screen_pos = pos


## Called once per physics tick: record where the finger is, and measure its velocity
## over the window. Using ticks (not wall-clock time) keeps it deterministic.
func sample(window_ticks: int, dt: float) -> void:
	history.append(screen_pos)
	while history.size() > window_ticks + 1:
		history.pop_front()
	var span := (history.size() - 1) * dt
	screen_vel = (history[-1] - history[0]) / span if span > 0.0 else Vector2.ZERO


## Screen position at the start of the velocity window.
func window_start() -> Vector2:
	return history[0]


func window_time(dt: float) -> float:
	return (history.size() - 1) * dt
