# CLAUDE.md — Fingerboard game rules

Realistic finger skateboarding (fingerboard) game for Android, Godot 4 (4.5+), GDScript.
The user is a real skater: controls must feel intuitive and predictable to skaters.
Follow these rules in every session. If a request conflicts with them, say so before coding.

## Core control rules (non-negotiable)

1. **Two fingers are the skater's feet.**
   - A touch that lands on the **back half** of the board = **back foot** (tail).
   - A touch that lands on the **front half** = **front foot** (front bolts).
   - Assignment happens once, when the touch lands, by raycasting from the screen to the board.
2. **No gesture recognition. No canned trick animations.**
   - The board is a `RigidBody3D`. Every physics tick, each finger's position and velocity
     *on the board* (board space) is converted into forces/torques applied *at that point*.
   - Never write code like `if swipe_matches("ollie"): play_ollie()`. Tricks must emerge from physics.
   - Detecting physical *events* (tail strike, wheels touching down) for haptics/UI is fine;
     those detections must never add trick-shaped motion.
3. **Determinism: same input → same result.**
   - Fixed physics ticks (`BoardTuning.physics_ticks_per_second`). All game physics runs in
     `_integrate_forces` / `_physics_process`, never in `_process`.
   - Finger velocity is measured over a fixed number of physics ticks, not wall-clock time.
   - Screen↔world ray math uses our own camera math (`ScreenMath`) on the camera's physics-tick
     transform, so rendering/interpolation never changes physics.
   - Anything that runs in `_process` (debug overlay, haptics) must not affect physics.
4. **All tuning values live in one resource**: `res://tuning/board_tuning.tres`
   (script `scripts/board_tuning.gd`, class `BoardTuning`). No magic tuning numbers in other
   scripts — add an `@export` field to `BoardTuning` instead, with a comment and units.
5. **Failure is physical.** If a finger leaves the board, or doesn't follow through, the trick
   fails because the forces stop — never because a rule says "fail".
6. **Target**: Android phones, landscape, 60 fps minimum, multitouch.
7. **Code style**: small, single-purpose scripts; comment everything; explain any physics math
   (units, sign conventions, why) in comments next to the code.

## Conventions

- **World scale**: 1 world unit = 10 cm real (`BoardTuning.world_scale = 10` units per metre).
  Board geometry is entered in real millimetres and converted. Gravity = 9.81 m/s² × world_scale.
- **Board local axes**: +X = right, +Y = up (out of the grip tape), **−Z = nose**, **+Z = tail**.
  Origin = middle of the flat part of the deck, at mid-thickness.
- Mass in kilograms, forces in kg·unit/s², speeds in units/s.
- `state.apply_force(f, offset)`: `offset` is from the body origin, in *global* orientation.

## Physics model decisions (from M1 — keep unless the user asks otherwise)

- A foot **drives its deck point toward a target speed** (velocity matching with an effective mass,
  `FootPhysics`), it does not apply a raw force ∝ finger speed. Raw forces made the 14 g board spin
  uncontrollably in the air.
- Press speed = finger screen speed toward the **nearest board end**; press only works in the outer
  "press zone" (where kicks rise). Back foot: flick down onto the tail. Front foot: drag up to nose.
- On the ground with the foot past an axle, the board tips about that axle (parallel-axis inertia +
  weight hold force). In the air: rotation about the centre of mass only.
- Resting finger weight applies **only while grounded** (a still finger in the air must not push).
- The pop is the tail strike plus `tail_restitution` bounce, applied at the **average** kick contact.
- Board collision is frictionless; wheel grip/rolling are explicit forces (`WheelPhysics`).
- Headless tests run each scenario in a fresh `SubViewport` world (a shared Jolt world isn't a true
  repeat). Visual checks: Mobile renderer via lavapipe (`--rendering-driver vulkan
  --rendering-method mobile` under xvfb); the Compatibility renderer over-exposes under llvmpipe.

## Milestones

- **M1 (done)**: project setup, ground, board, chase camera, finger→foot input, ollie via physics,
  pushing, debug overlay, haptics.
- Do **not** build kickflips or other tricks until the user asks for the next milestone.

## Testing

- Headless physics tests: `godot --headless --path . -s res://tests/test_ollie.gd`
  (simulates touch input, checks the board pops / levels / pushes). Run after physics changes.
