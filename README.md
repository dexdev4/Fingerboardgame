# Tessaris

A procedurally generated survival side-scroller with a developing story, for Android phones held
upright (portrait). Made with Godot 4.5 and GDScript.

Your section of the survey ship *Meridian* has crashed on the alien planet Tessaris. Keep your
suit alive, repair the wreck as your base, and travel east through a world generated from a
seed, following your scattered crew and uncovering what happened to the planet.

> This repository used to hold a fingerboard game. It was replaced by Tessaris; the old code is
> still in the git history.

## How to play

| Control | What it does |
|---|---|
| **◀ ▶** (bottom left) | Walk. Slide your thumb between them to turn without lifting it. |
| **JUMP** (bottom right) | Jump (works for a moment after running off a ledge). |
| **Tap a tile** near you | Mine it. Hold your finger on it to keep digging. Ore, ice, crystal and alloy go into your pack. |
| **Tap a plant / wreckage** | Pick it up: air bladders refill oxygen, glowcaps are food, wreckage gives metal (and sometimes a power cell). |
| **Tap a crew pod / monolith** | Read it. The story unfolds. |
| **Tap the ship** (when next to it) | Repair systems and make supplies. |
| **Item buttons** (above the controls) | Eat a glowcap, use an O2 canister or a power cell. |
| **II** (top right) or the back button | Pause: resume, see the world seed, or start a new world. |

Desktop testing: A/D or arrow keys to walk, Space/W/↑ to jump, click to tap.

## Survival

- **Oxygen** drains outside the ship. Refill it at the ship, from air-bladder plants, or with O2 canisters.
- **Food** drains slowly. Eat glowcaps.
- **Power** runs your drill (each hit), your headlamp (at night and underground) and your heater
  (at night, outside the ship). Refill it at the ship or with power cells.
- **Health**: running out of oxygen, food, or power at night hurts. It heals when you're well
  supplied, and faster at the ship. Hard landings hurt too.
- If health reaches zero, the suit drags you back to the ship and you lose half of what you were carrying.
- **Day and night**: a day is 5 minutes and the last third of it is a cold, dark night.

## The ship

| Repair | Cost | Effect |
|---|---|---|
| O2 Scrubber | 4 metal, 3 ice | Fast oxygen refill at the ship |
| Solar Array | 6 metal, 3 crystal | Fast power refill at the ship |
| Suit Tank | 5 metal, 4 ice, 2 crystal | +80 oxygen capacity |
| Long-range Antenna | 10 metal, 6 crystal, 4 alloy | ...send the signal |

You can also make O2 canisters (2 ice) and power cells (2 crystal).

## The world

Every world comes from a seed: the same seed always makes the same world.

- **Biomes**, going east: Crash Plains, Crystal Fields (tall hills, energy crystal), Fungal
  Lowlands (glowcaps, air plants), Ruins Expanse (pillars, alien alloy, monoliths). After the ruins,
  the biomes keep repeating, with different terrain each time.
- **Underground**: caves, metal ore, ice, crystal and alloy veins, and deep rock that gets harder and darker.
- A crater wall closes off the west, so the story always leads east.
- The world is generated in chunks on a background thread as you travel.

## The story

Ten chapters, each with a goal (repair the scrubber, find a crew pod, survive the night, and so
on), lead to a signal and an answer. Two lore threads run alongside: **crew logs** (what happened
to your crew) and **monolith inscriptions** (the planet's past). Pods and monoliths always reveal
the *next* entry, so the story reads in order wherever you find them. All the text is in
`story/story.json`.

Your game autosaves every 30 seconds, when you pause, and when you leave the app.

## Run it

1. Install **Godot 4.5.x** (standard build) from godotengine.org.
2. Open this folder in Godot (Import → `project.godot`) and press Play.

### On your Android phone

One-time setup, the same as before: in Godot, **Editor → Manage Export Templates → Download and
Install**; install **OpenJDK 17** and the **Android SDK** (Android Studio's SDK Manager: Platform-Tools,
Build-Tools 35.x, Platform 35, Command-line Tools); set both paths in **Editor → Editor Settings →
Export → Android** (the JDK path is the JDK 17 *folder*); enable USB debugging on the phone.

Then either click the Android icon in the editor's top-right run bar (one-click deploy), or
**Project → Export… → Android → Export Project** (`build/tessaris.apk`) and
`adb install -r build/tessaris.apk`. The preset is set up for arm64, portrait, full screen.

## Tuning

Every number (world shape, biome sizes, ore rarity, player speed, drain rates, repair costs, day
length, camera) is in **`tuning/game_tuning.tres`**: select it in the FileSystem dock and edit it in
the Inspector. Set `default_seed` to play one fixed world.

## Tests

```
godot --headless --path . -s res://tests/test_game.gd
```

The headless tests check:
- World determinism and chunk independence.
- The crash site and the crater wall.
- Biomes, caves and resources, and that the first repair is possible near the ship.
- Survival rates and that the story advances in order.
- In the real game scene: walking, jumping, mining that stays mined after a chunk reloads,
  pickups that don't come back, repairs, and a save/load roundtrip.

## Layout

```
scenes/main.tscn        the game (everything else is created in code)
tuning/game_tuning.tres all tuning values (script: scripts/game_tuning.gd)
story/story.json        chapters, crew logs, monolith inscriptions
scripts/
  main.gd               wires everything; tapping, survival ticks, repairs, death, saving
  hash_noise.gd         deterministic integer-hash noise
  world_gen.gd          biomes, terrain, caves, ores, ruins, pickups (pure, seeded)
  world.gd              chunk streaming (worker threads), mining, mined/collected state
  tiles.gd              tile types: colours, hardness, drops
  tileset_builder.gd    tile atlas + collision built in code
  player.gd             explorer movement, headlamp, drawing
  touch_controls.gd     portrait multitouch buttons
  survival.gd           oxygen, food, power, health
  inventory.gd          resources and usable items
  ship.gd               the crashed ship (base): range, repairs, drawing
  day_night.gd          time of day, light level
  story.gd              chapters and ordered lore
  hud.gd                bars, info, items, messages, story/ship/pause panels
  background.gd         sky, planet, moons, parallax mountains
  pickup.gd             plants, wreckage, pods, monoliths
  save_game.gd          save file (seed + changes only)
tests/test_game.gd      headless tests
```
