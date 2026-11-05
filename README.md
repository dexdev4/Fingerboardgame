# Fingerboard

A realistic fingerboard game for Android (Godot 4.5, GDScript, Jolt physics).
Your two fingers are the skater's feet. There are no canned tricks: every trick comes from
finger forces acting on a physics board.

**Milestone 1:** board, ground, chase camera, two-finger feet, ollie, pushing, debug overlay, haptics.

## Controls

| Finger | What it does |
|---|---|
| Touch the **back half** of the board | That finger is your **back foot** (orange dot). |
| Touch the **front half** | That finger is your **front foot** (cyan dot). |
| Back foot: **quick flick down the screen** on the tail | Snaps the tail down; it hits the ground and the board pops. A faster flick gives a harder pop. |
| Front foot: **drag up toward the nose** after the pop | Catches the rising nose and levels the board. No slide means the board keeps rotating. |
| **Swipe backward on the ground** beside the board | Pushes. You can't push faster than you swipe. |
| **RESET** (top right) | Puts the board back at the start. |

Tip: start the front-foot slide just after the tail snap. If you slide too early, you press the
board back down before it pops, just like a real ollie.

## How the physics works (short version)

Each physics tick (120 Hz), for every finger on the board:

- **Contact point and finger velocity in board space**: raycast from the screen onto the deck.
- **Press**: finger motion on screen toward the nearest end of the board drives that point of the
  deck downward at a matching speed. Kicks rise toward the tips, so a foot driven toward a tip
  pushes the kick down. The force applied is only what that speed needs, so the foot never
  over-drives the board.
- **Grip drag**: a sliding finger drags the grip tape, up to `grip_mu ×` its press force.

The forces act at the finger's contact point. Pressing behind the rear axle tips the board nose-up
until the tail strikes the ground; the strike's bounce (`tail_restitution`) is the pop.
`scripts/foot_physics.gd` has the full maths in its comments.

## Deploy to your Android phone

One-time setup:

1. Install **Godot 4.5.x** (standard build, not .NET) from godotengine.org.
2. Open this folder in Godot (Import → select `project.godot`).
3. **Editor → Manage Export Templates → Download and Install** (same version as the editor).
4. Install **OpenJDK 17** and the **Android SDK**. The simplest way is to install Android Studio,
   then in its SDK Manager install *Platform-Tools*, *Build-Tools 35.x*, *Platform 35* and
   *Command-line Tools*.
5. In Godot: **Editor → Editor Settings → Export → Android**: set *Java SDK Path* (JDK 17 folder)
   and *Android SDK Path*. Godot creates a debug keystore automatically.
6. On the phone, enable **Developer options** (tap *Build number* 7 times), then turn on
   **USB debugging**. Plug the phone in and accept the "Allow USB debugging" prompt.

Every time:

- **One-click:** when the phone is connected, an Android icon appears in the editor's top-right
  run bar. Click it ("Remote Deploy") and the game installs and launches on the phone.
- **Or build an APK:** *Project → Export… → Android → Export Project* (`build/fingerboard.apk`),
  then `adb install -r build/fingerboard.apk`.

The preset in `export_presets.cfg` is already set up: arm64, landscape (either way up),
immersive full screen, VIBRATE permission for haptics. Tests are excluded from the build.

Desktop testing: running in the editor works, and the mouse acts as one finger (push, or a single
foot). Ollies need two real fingers, so test those on the phone.

## Tuning

Every number lives in **`tuning/board_tuning.tres`**: select it in the FileSystem dock and edit it
in the Inspector. Geometry is in real millimetres and grams; everything else is in world units
(1 unit = 10 cm real). Geometry, mass and damping apply when the scene starts. Force settings also
apply live if you edit the resource while the game runs (Remote scene tree).

## Tests

Headless physics checks that simulate real touch input (an ollie with and without the front slide,
pushing, and a determinism repeat):

```
godot --headless --path . -s res://tests/test_ollie.gd
TRACE=0 godot --headless --path . -s res://tests/test_ollie.gd   # per-tick trace of scenario 0
```

## Layout

```
scenes/main.tscn          ground, light, board, camera, input, overlay
tuning/board_tuning.tres  all tuning values (script: scripts/board_tuning.gd)
scripts/
  main.gd                 wires everything from the tuning resource
  board.gd                RigidBody3D: reads contacts, applies forces, pop/landing events
  board_geometry.gd       board dimensions (mm → world units)
  board_builder.gd        collision shapes + meshes built from the geometry
  finger.gd               one touch: role, screen/board position and velocity
  finger_input.gd         touches → feet/push fingers, measured in board space each tick
  foot_physics.gd         finger → press + grip forces (the core control model)
  wheel_physics.gd        sideways grip and rolling resistance
  push_physics.gd         ground swipes → push force
  screen_math.gd          deterministic camera ray / projection math
  chase_camera.gd         low smooth chase camera
  haptics.gd              vibration on pop and landing
  debug_overlay.gd        finger dots/arrows, board map, speed/height/angles, reset
shaders/grid.gdshader     light ground with a 1 cm / 10 cm grid
tests/test_ollie.gd       headless physics tests
```
