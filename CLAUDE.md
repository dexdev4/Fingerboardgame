# CLAUDE.md — Tessaris game rules

Tessaris: a procedurally generated survival side-scroller with a developing story, for Android,
Godot 4 (4.5+), GDScript. You are a crash-landed explorer on the alien planet Tessaris: keep your
suit alive (oxygen, food, power, health), repair your crashed ship as a base, and travel east
through a generated world, uncovering what happened to your crew and to the planet.
(This repository used to hold a fingerboard game; it was replaced at the user's request. The old
code is in git history before the "Tessaris M1" commits.)
Follow these rules in every session. If a request conflicts with them, say so before coding.

## Core rules

1. **Procedural, seeded, deterministic world.** The world comes from one integer seed. The same
   seed must always give the same terrain, caves, resources, pickups and lore placement
   (`WorldGen` uses our own integer hash noise — no `randf()`, no engine RNG, no wall-clock
   time in generation). Any chunk generated alone must equal the same chunk generated in
   sequence (no generation order dependence).
2. **The story develops in order.** Chapters (story/story.json) advance through objectives in a
   fixed order; lore pickups (crew logs, monolith inscriptions) always reveal the NEXT unread
   entry, whichever pickup is found — so the generated world can't scramble the story.
3. **Survival is systemic.** Oxygen, food, power and health drain and refill through rules in
   `Survival` driven by tuning values; failure (running out) hurts health, and death sends you
   back to the ship and costs carried resources. No scripted deaths.
4. **All tuning values live in one resource**: `res://tuning/game_tuning.tres` (script
   `scripts/game_tuning.gd`, class `GameTuning`). No magic numbers in other scripts — add an
   `@export` field with a comment and units. Story text lives in story/story.json.
5. **Target**: Android phones, **portrait** (held upright), 60 fps, touch controls (on-screen
   ◀ ▶ JUMP; tap the world to mine / pick up / use). Keyboard + mouse work for desktop testing.
6. **Code style**: small, single-purpose scripts; comment everything; units in comments.
7. **Saves**: the world is regenerated from the seed; a save only stores the seed and what the
   player CHANGED (mined cells, collected pickups, inventory, stats, story progress, repairs).

## Conventions

- Tiles are `GameTuning.tile_size` px (32). Tile coords: x grows east (story direction), y grows
  DOWN (Godot 2D). The ship sits at tile x = 0 on the surface; the world wall is at x < world_min_x.
- Chunks are `chunk_width` tiles wide, generated whole (all rows from sky to bedrock).
- Time: game physics in `_physics_process` (60 Hz); survival/day-night tick there too.
- Visuals are generated in code (tile atlas, sky, silhouettes, sprites) — no imported art yet.

## Testing

- Headless tests: `godot --headless --path . -s res://tests/test_game.gd`
  (world determinism + chunk independence, spawn site, mining persistence, survival rates,
  story order, save/load roundtrip, player walking/jumping in the real scene).
- New `class_name` scripts need one `godot --headless --editor --quit` before headless tests.
- Visual checks: `xvfb-run` + `--rendering-driver vulkan --rendering-method mobile` (lavapipe).

## Milestones

- **M1**: new project; seeded chunked world (biomes, caves, ores, ice, crystals, ruins); player
  with portrait touch controls; mining; survival stats; crashed-ship base with repairs and
  crafting; day/night; story chapters + ordered lore; HUD; autosave; tests.
