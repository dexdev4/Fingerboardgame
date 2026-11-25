# CLAUDE.md — Eldwood game rules

Eldwood: a rustic 8-bit survival side-scroller set in a great medieval forest, for Android,
Godot 4 (4.5+), GDScript. You design your character, start in a small cabin at the forest's
edge, gather materials from a procedurally generated forest, customise the cabin with what you
craft, survive the cold nights, and follow a developing story into the woods.
(This repository was first a fingerboard game, then "Tessaris" (alien survival); both were
replaced at the user's request and are in git history.)
Follow these rules in every session. If a request conflicts with them, say so before coding.

## Core rules

1. **8-bit look.** The game renders at 180×320 real pixels (portrait), integer-scaled. Every
   colour comes from `Pal` (palette.gd); text uses `PixelFont` (5×7 bitmap font, 8 px lines);
   art is pixel maps or palette-painted pixels (`Sprites`, `TileSetBuilder`, `CharacterLook`).
   No smooth gradients, no anti-aliased shapes, no imported art yet.
2. **Procedural, seeded, deterministic world.** One integer seed → the same terrain, caves,
   ores, trees, forage and lore placement (`WorldGen`, our own `HashNoise`; no engine RNG or
   clock in generation). A chunk generated alone equals the same chunk generated in sequence.
3. **The story develops in order.** Chapters (story/story.json) advance through goals in a fixed
   order; journal pages and runestones always reveal the NEXT unread entry of their kind.
4. **Survival is systemic.** Health, hunger, warmth and stamina follow rules in `Survival`
   driven by tuning; running out hurts; collapsing sends you home and costs carried materials
   (the chest keeps things safe). No scripted deaths.
5. **The cabin is yours.** Everything in it is placed by the player from crafted items
   (`Cabin` data + `CabinInterior` view); upgrades (floor, walls, roof, extensions) are recipes.
   Placement rules live in `Cabin.can_place` (pure, tested).
6. **All tuning values live in one resource**: `res://tuning/game_tuning.tres` (script
   `scripts/game_tuning.gd`) — including recipes, costs, food values, comfort and light values,
   background kits. Names/kinds/footprints of items are in `catalog.gd`; story text in
   story/story.json. No magic numbers elsewhere.
7. **Target**: Android phones, portrait, 60 fps, touch: ◀ ▶ JUMP buttons; tap the world to
   chop / dig / pick up / read; tap furniture to use it; BUILD to arrange the cabin.
8. **Saves** store the seed and what the player changed (character, mined cells, felled /
   picked objects, bag, chest, stats, cabin, story, time, position) — never the world itself.
9. **Code style**: small, single-purpose scripts; comment everything; units in comments.

## Conventions

- Tiles are 8 px. x grows east (story direction), y grows down. The cabin is at tile x = 0 in a
  flat clearing; the old cliff closes the west (x < world_min_x).
- The cabin interior is a separate walkable room far above the world (`CabinInterior.ORIGIN`);
  going in/out moves the player and switches visibility, camera limits and the background.
- Tool tiers: hands 0, stone 1, iron 2. Tiles have hardness tiers (`Tiles.tier`); a pick must
  be at least that tier. Axes only change chop damage.
- Stations: hand (anywhere), workbench / hearth (inside, with that furniture placed).
- Game rules tick in `_physics_process` (60 Hz). Visual-only animation may use `_process`.

## Testing

- Headless tests: `godot --headless --path . -s res://tests/test_game.gd`
  (world determinism + chunk independence, clearing, biomes/resources/forest, survival, cabin
  placement rules, crafting stations/tiers/upgrades, story order, character sprites and font,
  and the real scene: cabin start, door, walking, chopping, digging, building, sleeping,
  save/load).
- New `class_name` scripts need one `godot --headless --editor --quit` before headless tests.
- Visual checks: `xvfb-run` + `--rendering-driver vulkan --rendering-method mobile` (lavapipe).
- Tuning notes: value-noise ore thresholds are sensitive (0.83→0.87 halves coal); check the
  test's resource counts after changing them. Meadow tree density 0.4 keeps 8+ trees near home.

## Milestones

- **M1 (Eldwood)**: 8-bit pipeline (low-res viewport, palette, pixel font, sprites); title
  screen; character creator (10 appearance options, name, 4 backgrounds with kits); forest world
  (meadow, pinewood, elderwood, stonecrag; trees to chop; forage; clay/coal/iron/gold; old
  stonework); survival (health/hunger/warmth/stamina, torches, sleep); crafting by station with
  tool tiers; the cabin (walkable interior, 21 furniture/decor pieces, build mode, 6 upgrades,
  bed/hearth/workbench/chest, comfort and light); medieval story (10 chapters, journal pages,
  runestones); pixel HUD; autosave; tests.
