## Every tuning value for the board, feet, wheels, camera and haptics.
## The saved instance is res://tuning/board_tuning.tres — edit it in the Inspector.
## Units: geometry in real millimetres / grams (converted with world_scale),
## everything else in world units (1 unit = 10 cm real by default).
class_name BoardTuning
extends Resource

@export_group("World")
## World units per real metre. 10 => the 96 mm board is 0.96 units long,
## a comfortable size for the physics engine and the camera.
@export var world_scale: float = 10.0
## 1.0 = real gravity (9.81 m/s² scaled to world units). Lower = floatier: longer hang time,
## slower falls. 0.3 gives the slow, floaty feel (M3); raise toward 1.0 for snappy realism.
@export var gravity_multiplier: float = 0.25
## Fixed physics rate. Higher = more stable contacts, more CPU. Keep a multiple of 60.
@export var physics_ticks_per_second: int = 120

@export_group("Board geometry (real mm)")
@export var deck_length_mm: float = 96.0
@export var deck_width_mm: float = 28.0
## Physical thickness of the collision deck (real decks ~1.5 mm; thicker is more stable).
@export var deck_thickness_mm: float = 2.0
## Length of each kick, measured along the kick from the bend to the tip.
@export var kick_length_mm: float = 17.0
@export var kick_angle_deg: float = 22.0
## Distance between the front and rear axle.
@export var wheelbase_mm: float = 54.0
## Distance between left and right wheel centres on one axle.
@export var wheel_track_mm: float = 24.0
@export var wheel_diameter_mm: float = 7.5
@export var wheel_width_mm: float = 4.5
## Height of the underside of the deck above the ground when standing on its wheels.
@export var deck_clearance_mm: float = 10.0

## Deck concave: how much higher the rails (edges) sit than the centre line (mm). Visual.
@export var concave_mm: float = 1.0

## Visual bend into each kick (mm either side of the bend). Real decks curve; 0 = sharp crease.
@export var kick_bend_mm: float = 5.0

@export_group("Board look")
## Wordmark printed on the bottom graphic (made-up brand) and its colour.
@export var deck_wordmark: String = "PLAZA 96"
@export var wordmark_color: Color = Color(0.08, 0.08, 0.1)
@export var grip_color: Color = Color(0.07, 0.07, 0.075)
## Bottom graphic: stripes/ends colour and the logo/middle colour.
@export var graphic_color_a: Color = Color(0.85, 0.2, 0.15)
@export var graphic_color_b: Color = Color(0.95, 0.92, 0.85)
@export var truck_color: Color = Color(0.78, 0.79, 0.82)
@export var bushing_color: Color = Color(0.9, 0.55, 0.1)
@export var wheel_color: Color = Color(0.97, 0.95, 0.88)

@export_group("Board mass")
## A real fingerboard with trucks and wheels is about 12-16 g.
@export var mass_g: float = 16.0
## Centre of mass below the deck mid-plane (trucks + wheels pull it down).
@export var com_drop_mm: float = 4.0
## Effective "box height" used for the inertia formula (spreads mass vertically).
@export var inertia_height_mm: float = 16.0
## Air drag on linear motion (1/s). Fingerboards are light, so a little drag matters.
@export var linear_damp: float = 0.02
## Damping of spin (1/s). Higher = board stops rotating sooner in the air.
@export var angular_damp: float = 2.5

@export_group("Wheels")
## How fast sideways sliding of a grounded wheel is cancelled (1/s). Keep < ticks/s.
@export var wheel_lateral_grip: float = 40.0
## Constant rolling deceleration from bearings/wheels (units/s²).
@export var rolling_resistance: float = 0.12
## Truck bushings + wheel urethane soaking up landings: while 3+ wheels are down, the board's
## pitch/roll spin and its bounce along the deck's up axis are damped at this rate (1/s).
## Higher = landings "stick" and feel heavier; 0 = a hard plastic toy. Keep < ticks/s.
@export var bushing_damping: float = 30.0

@export_group("Deck on the ground (bails)")
## Friction coefficient when the grip tape or deck edge touches the ground (landing upside down
## or on its side). Grip tape on concrete is very grippy: ~0.9.
@export var deck_friction_mu: float = 0.9
## How quickly that friction stops sliding (1/s, mass-normalised). Keep < ticks/s.
@export var deck_stick_rate: float = 40.0

@export_group("Grinds and slides")
## Friction of the metal trucks sliding on things (50-50s, 5-0s, nosegrinds). Steel on steel or
## waxed concrete is slick: ~0.15. Lower = grinds carry speed further.
@export var grind_mu: float = 0.15
## Friction of the wooden deck bottom / kicks sliding (boardslides, tailslides, noseslides).
## Grabbier than trucks: ~0.3. Each obstacle multiplies these by its "slide_friction_scale".
@export var slide_mu: float = 0.3

@export_group("Feet (fingers on the board)")
## Shifts the back/front split along the board (mm, + toward the tail).
@export var foot_split_mm: float = 0.0
## A finger counts as "on the board" this far past the deck's side edges (mm).
@export var foot_catch_margin_mm: float = 3.0
## ...and this far past the nose/tail tips (mm). Generous, because flicking down on the tail
## moves the finger past the tip on screen while, in "real life", it is still on the kick.
@export var foot_end_margin_mm: float = 30.0
## Finger velocity is measured across this many physics ticks (smooths 60 Hz touch input).
@export var finger_velocity_ticks: int = 16
## Downward force of a resting finger while the board is on its wheels, in board weights.
@export var foot_rest_weight: float = 0.25
## How fast a pressing finger drives its point of the deck down (units/s) per unit of
## press speed (screen heights/s). Press speed = finger speed on screen toward the end of the
## board nearest that finger. THE main "pop strength" knob.
@export var press_speed_gain: float = 3.2
## Press only works on the outer part of the board, where the kicks rise: it fades in from
## this distance from the centre (mm) to full strength at the kick bend. Default sits just
## inside the bolts, so a front foot slides freely until it reaches the front bolts.
@export var press_zone_start_mm: float = 15.0
## Top speed a foot can move the deck at (units/s) — both pressing it down and dragging it
## along the grip. Above this, flicking harder does nothing more: slow, deliberate fingers
## get the full effect and the board's reactions stay smooth however fast you flick.
@export var foot_max_speed: float = 2.8
## Side presses: a finger driven toward the nearest RAIL (side edge) presses that edge, because
## the concave rises toward the rails just like the kicks rise toward the ends. Strength relative
## to end presses (0 = off). On the ground the wheels stop the board rolling; in the air it rolls
## (flip tricks: pop, then flick the front finger off the side).
@export var press_side_gain: float = 10.0
## Top speed a side press can drive the rail at (units/s). Separate from foot_max_speed so
## flips can come round in one hang time while ollies keep the slow, smooth feel.
@export var press_side_max_speed: float = 12.0
## Response time for side presses (s). A flick off the side touches the rail only briefly, so
## it needs a quicker foot than the smooth ollie press (press_response_time). Keep ≥ 2 ticks.
@export var press_side_response_time: float = 0.03
## Side presses fade in from this distance from the centre line (mm) to full at the rail.
## The deck is 28 mm wide, so the rail is at 14 mm.
@export var press_side_zone_start_mm: float = 3.0
## Finger speeds below this (screen heights/s) don't press — filters jitter.
@export var press_deadzone: float = 0.15
## How quickly a foot gets its point of the deck up to speed (s). Smaller = snappier, harder
## feet. Keep ≥ 2 physics ticks (0.017 s at 120 Hz) for stability.
@export var press_response_time: float = 0.12
## Upper limit for one finger's press force, in board weights.
@export var press_max_weights: float = 10.0
## How strongly a sliding finger drags the grip tape (1/s, mass-normalised).
@export var grip_rate: float = 25.0
## Grip tape friction coefficient: drag force is capped at grip_mu × press force.
@export var grip_mu: float = 0.35

@export_group("Pop")
## Extra bounce when the tail strikes the ground (0 = dead tail, 1 = superball).
@export var tail_restitution: float = 0.6
## Tail strikes slower than this (units/s) don't bounce or buzz.
@export var pop_min_speed: float = 1.0

@export_group("Pushing")
## Push force per unit of (swipe speed − board speed), mass-normalised (1/s).
@export var push_gain: float = 20.0
## Max acceleration a push can give (units/s²).
@export var push_max_accel: float = 40.0
## Converts swipe speed across the ground into pushing-foot speed. The camera foreshortens
## the ground, so a natural swipe covers little ground; >1 makes a full swipe a full push.
@export var push_speed_scale: float = 2.0
## A ground touch must land within this distance of the board to push (mm).
@export var push_reach_mm: float = 250.0

@export_group("Camera")
## Horizontal distance behind the board (world units; the board is 0.96 long).
## Closer = bigger board on screen = finer finger control.
@export var camera_distance: float = 1.2
@export var camera_height: float = 0.5
@export var camera_fov_deg: float = 40.0
## The camera aims this far ahead of the board.
@export var camera_look_ahead: float = 0.1
## How quickly the camera catches up with the board (1/s).
@export var camera_follow: float = 3.0
## How quickly the camera swings round to the board's heading (1/s).
@export var camera_turn_follow: float = 1.5

@export_group("Haptics")
@export var haptics_enabled: bool = true
@export var haptic_pop_ms: int = 25
@export var haptic_land_ms: int = 40
## Landings slower than this (units/s downward) don't buzz.
@export var haptic_land_min_speed: float = 1.5
## Impact speed (units/s) that gives a full-strength buzz.
@export var haptic_full_speed: float = 15.0
## Airborne time (s) needed before a touchdown counts as a landing.
@export var landing_min_air_time: float = 0.1


# ---- Derived values (computed, not edited) -------------------------------------------

## Converts real millimetres to world units.
func mm(v: float) -> float:
	return v * 0.001 * world_scale

func mass_kg() -> float:
	return mass_g * 0.001

func gravity() -> float:
	return 9.81 * world_scale * gravity_multiplier

## Weight of the board in world force units; feet forces are expressed in these.
func board_weight() -> float:
	return mass_kg() * gravity()
