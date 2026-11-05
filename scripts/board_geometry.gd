## Board dimensions in world units, derived from BoardTuning (which is in real mm).
## Board local axes: +X right, +Y up (out of the grip), -Z nose, +Z tail.
## Origin: centre of the flat part of the deck, at mid-thickness.
class_name BoardGeometry
extends RefCounted

var half_length: float      # half of the full deck length (tip to tip, seen from above)
var half_width: float
var thickness: float
var flat_half: float        # the flat middle section runs from z = -flat_half to +flat_half
var kick_length: float      # along the kick surface
var kick_angle: float       # radians
var axle_z: float           # axles at z = ±axle_z
var wheel_x: float          # wheels at x = ±wheel_x
var wheel_radius: float
var wheel_width: float
var wheel_y: float          # wheel centre height (local)
var rest_height: float      # height of the origin above the ground when standing on 4 wheels


func _init(t: BoardTuning) -> void:
	half_length = t.mm(t.deck_length_mm) * 0.5
	half_width = t.mm(t.deck_width_mm) * 0.5
	thickness = t.mm(t.deck_thickness_mm)
	kick_length = t.mm(t.kick_length_mm)
	kick_angle = deg_to_rad(t.kick_angle_deg)
	# The kick's horizontal footprint is kick_length·cos(angle); the rest is the flat part.
	flat_half = half_length - kick_length * cos(kick_angle)
	axle_z = t.mm(t.wheelbase_mm) * 0.5
	wheel_x = t.mm(t.wheel_track_mm) * 0.5
	wheel_radius = t.mm(t.wheel_diameter_mm) * 0.5
	wheel_width = t.mm(t.wheel_width_mm)
	var clearance := t.mm(t.deck_clearance_mm)
	rest_height = thickness * 0.5 + clearance
	# Ground is at y = -rest_height (local) when resting, so the wheel centre is one radius above it.
	wheel_y = -rest_height + wheel_radius


func deck_top() -> float:
	return thickness * 0.5


## Height of the grip-tape surface at local z (flat in the middle, rising along the kicks).
func surface_y(z: float) -> float:
	var past := clampf(absf(z) - flat_half, 0.0, kick_length * cos(kick_angle))
	return deck_top() + past * tan(kick_angle)


## Outward surface normal (local) of the grip tape at local z.
## On a kick y = (|z| - flat_half)·tan(a), whose normal tilts toward the board centre:
## tail (+z): (0, cos a, -sin a); nose (-z): (0, cos a, +sin a).
func surface_normal(z: float) -> Vector3:
	if absf(z) <= flat_half:
		return Vector3.UP
	return Vector3(0.0, cos(kick_angle), -signf(z) * sin(kick_angle))


## Local position of the tail tip (top surface).
func tail_tip() -> Vector3:
	return Vector3(0.0, surface_y(half_length), half_length)


func nose_tip() -> Vector3:
	return Vector3(0.0, surface_y(-half_length), -half_length)
