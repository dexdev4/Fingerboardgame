# Eldwood

A rustic 8-bit survival side-scroller set in a great medieval forest. Made with Godot 4.5 and
GDScript for Android phones held upright (portrait).

Make your character, then take up the old woodsman's cabin at the edge of the Eldwood. Chop,
forage and dig for materials, make the cabin your own with everything you craft, survive the
cold nights, and follow the story of what happened to old Aldous and what lives in the forest.

> This repository was first a fingerboard game, then an alien survival game called Tessaris.
> Both were replaced by Eldwood; their code is still in the git history.

## Getting started

1. **Title screen:** New game (or Continue).
2. **Character creator:** pick your name (or roll a random one with "?"). Choose your skin, hair
   style and colour, beard, hat, tunic, trousers, cloak and cloak colour, and boots.
3. **Origin:** pick the background you start with.

| Origin | You start with |
|---|---|
| Woodcutter | A stone axe and some logs |
| Stonemason | A stone pickaxe and stone |
| Herbalist | Herbs, berries and a poultice |
| Wanderer | Torches, and you feel the night cold less |

You wake up in a small, bare cabin with a straw bed and one window.

## Controls

| Control | What it does |
|---|---|
| **◀ ▶** / **JUMP** (bottom) | Walk and jump. Two fingers work at once. |
| **Tap a tree** | Chop it (hold your finger down to keep chopping). An axe chops faster. |
| **Tap the ground** | Dig. Soil and clay by hand; stone, coal and iron need a stone pickaxe; deep stone and gold need an iron one. |
| **Tap plants and rocks** | Pick berries, mushrooms, flax and herbs; collect loose stones. |
| **Tap pages and runestones** | Read them. The story unfolds. |
| **Tap your cabin / its door** | Go in / out. |
| **Tap furniture** (inside) | Bed: sleep (after dusk). Workbench / hearth: craft. Chest: store things. |
| **CRAFT** | Make things. What's available depends on where you are: by hand, at your workbench, or at your hearth. |
| **BAG** | See what you carry; eat food and use medicine. |
| **BUILD** (inside) | Arrange your cabin: pick a piece, tap where it goes; "Take back" returns pieces to your bag. |
| **II** / back button | Pause; save and quit to the title. |

Desktop testing: A/D or arrow keys to walk, Space/W/↑ to jump, click to tap.

## Surviving

- **Health** drops when you're starving or freezing, and from hard falls. It heals while you're fed and warm.
- **Hunger:** eat berries, apples, mushrooms, or stew cooked at your hearth.
- **Warmth:** nights are cold outside. The cabin warms you, and a hearth warms you fast.
- **Stamina:** every chop and dig costs some; rest a moment to get it back.
- **Torches** light the dark (nights and underground). One burns for 90 seconds while it's dark.
- **Sleeping** in your bed after dusk skips the night. The more comfortable your cabin, the more health you recover.
- **Collapsing:** you wake up at home and lose half the materials you were carrying. Things in your chest are safe.

## Your cabin

Craft furniture and decor at the workbench, then place them anywhere with BUILD:

- **Furniture:** bed (straw or wooden), hearth, workbench, chest, table, chair, stool,
  bookshelf, barrel, potted herbs, candle stand.
- **On the walls:** windows, a shelf, a banner, a tapestry, a wall candle, a lantern, drying herbs.
- **On the floor:** a rug and a woven mat.
- **Upgrades:**
  - plank or stone floor
  - planed or plastered walls
  - a shingle roof
  - two extensions that make the cabin wider

Furniture and upgrades add **comfort**. Hearths, candles, lanterns and windows add **light**. From
outside you can see your roof, the chimney smoking once you have a hearth, and the windows
glowing at night.

## The forest

Every forest comes from a seed: the same seed always makes the same forest. Going east from
your cabin:

1. **The Meadow:** birches, berries, flax, loose rocks, clay under the turf.
2. **Pinewood:** dense pines and mushrooms.
3. **Elderwood:** great oaks (with apples), herbs and mushrooms.
4. **Stonecrag:** rocky hills, coal and iron, old ruined walls and runestones.

After that the biomes keep repeating. Underground there are caves and deeper, harder stone with gold.

## The story

Ten chapters, each with a goal, run from building your first workbench to the mystery of the
First Root. The pages of Aldous's journal and the runestones tell two threads, always in order
wherever you find them. All the text is in `story/story.json`.

The game autosaves every 30 seconds, when you pause or sleep, and when you leave the app.

## Run it

1. Install **Godot 4.5.x** (standard build) from godotengine.org.
2. Open this folder in Godot (Import → `project.godot`) and press Play.

### On your Android phone

One-time setup:

1. In Godot: **Editor → Manage Export Templates → Download and Install**.
2. Install **OpenJDK 17** and the **Android SDK**. In Android Studio's SDK Manager, install
   Platform-Tools, Build-Tools 35.x, Platform 35 and Command-line Tools.
3. Set both paths in **Editor → Editor Settings → Export → Android**. The JDK path is the JDK 17
   *folder*, not java.exe.
4. Enable USB debugging on the phone.

Then either:
- click the Android icon in the editor's top-right run bar (one-click deploy), or
- use **Project → Export… → Android → Export Project** (`build/eldwood.apk`), then run
  `adb install -r build/eldwood.apk`.

## Tuning

Every number is in **`tuning/game_tuning.tres`**, including:
- world shape, biome lengths, tree density and ore rarity
- speeds and survival rates
- every recipe and its cost
- food values, comfort and light values
- background starting kits

Set `default_seed` to play one fixed forest.

## Tests

```
godot --headless --path . -s res://tests/test_game.gd
```

The headless tests check:
- World determinism, and the cabin's clearing.
- Biomes, resources and forest density near home.
- Survival rates.
- Cabin placement rules.
- Crafting stations, tool tiers and upgrades.
- Story order, and that every character option builds a sprite.
- The real game: starting in the cabin, the door, walking, chopping, digging, placing a
  workbench, sleeping, and a save/load roundtrip.

## Layout

```
scenes/main.tscn          the game (everything else is created in code)
tuning/game_tuning.tres   all tuning values (script: scripts/game_tuning.gd)
story/story.json          chapters, journal pages, runestones
scripts/
  main.gd                 title → creator → game; tapping, survival, building, sleeping, saving
  title_screen.gd         title screen
  character_creator.gd    character creation menu
  character_look.gd       layered 8×14 character sprite and options
  palette.gd              the colour palette
  pixel_font.gd           5×7 bitmap font
  ui_theme.gd             8-bit UI theme
  sprites.gd              pixel-art icons, furniture, forage, procedural trees
  hash_noise.gd           deterministic integer-hash noise
  world_gen.gd            biomes, terrain, caves, ores, ruins, trees, forage, lore (seeded)
  world.gd                chunk streaming, digging, felled/picked state
  world_object.gd         trees, forage, pages, runestones
  tiles.gd                tile types, hardness, drops
  tileset_builder.gd      8×8 tile art and collision
  cabin.gd                cabin data: placement rules, upgrades, comfort, light
  cabin_interior.gd       the walkable room, furniture drawing, build mode
  cabin_exterior.gd       the cabin seen from outside
  catalog.gd              item names, kinds, furniture footprints, origins
  crafting.gd             recipe rules (stations, tool tiers, upgrades)
  survival.gd             health, hunger, warmth, stamina
  inventory.gd            bag and chest
  day_night.gd            time of day, sleep
  story.gd                chapters and ordered lore
  player.gd               movement, sprite, torch light
  touch_controls.gd       portrait multitouch buttons
  hud.gd                  bars, info, panels, build palette
  background.gd           sky, sun/moon, parallax hills and tree lines
  save_game.gd            save file (seed + changes)
tests/test_game.gd        headless tests
```
