## Headless tests for Eldwood:
##   godot --headless --path . -s res://tests/test_game.gd
## Pure checks first (world generation, survival, crafting, cabin, story, character), then the
## real game scene (cabin start, walking, chopping, digging, building, sleeping, save/load).
extends SceneTree

const SEED := 424242

var failures := 0
var t: GameTuning = preload("res://tuning/game_tuning.tres")


func _initialize() -> void:
	_test_determinism()
	_test_clearing()
	_test_world_shape()
	_test_survival()
	_test_cabin()
	_test_crafting()
	_test_story()
	_test_character_and_font()
	await _test_game_scene()
	print("\n%d failure(s)" % failures)
	quit(1 if failures > 0 else 0)


func _expect(ok: bool, what: String) -> void:
	print(("  PASS: " if ok else "  FAIL: ") + what)
	if not ok:
		failures += 1


# ---- World generation ------------------------------------------------------------------

func _test_determinism() -> void:
	print("\n== world determinism ==")
	var a := WorldGen.new(SEED, t)
	var b := WorldGen.new(SEED, t)
	var c := WorldGen.new(SEED + 1, t)
	var same := true
	var differs := false
	for cx in range(-2, 8):
		var ca := a.generate_chunk(cx)
		if ca != b.generate_chunk(cx) or str(a.objects_in_chunk(cx)) != str(b.objects_in_chunk(cx)):
			same = false
		if ca != c.generate_chunk(cx):
			differs = true
	_expect(same, "same seed → identical terrain, trees, forage and lore")
	_expect(differs, "different seed → a different forest")
	var alone := WorldGen.new(SEED, t).generate_chunk(5)
	var seq := WorldGen.new(SEED, t)
	for cx in range(0, 5):
		seq.generate_chunk(cx)
	_expect(alone == seq.generate_chunk(5), "a chunk doesn't depend on generation order")
	var ok := true
	var tiles := a.generate_chunk(3)
	for i in range(0, tiles.size(), 37):
		var x := 3 * t.chunk_width + i % t.chunk_width
		var y := t.world_top + i / t.chunk_width
		if tiles[i] != a.tile_at(x, y) and y >= a.surface_y(x) - 6:
			ok = false
	_expect(ok, "generate_chunk agrees with tile_at")


func _test_clearing() -> void:
	print("\n== the cabin's clearing ==")
	var g := WorldGen.new(SEED, t)
	var flat := true
	var clear := true
	for x in range(-t.clearing_radius, t.clearing_radius + 1):
		if g.surface_y(x) != t.surface_base or not Tiles.is_solid(g.tile_at(x, t.surface_base)):
			flat = false
		for y in range(t.surface_base - 8, t.surface_base):
			if g.tile_at(x, y) != Tiles.AIR:
				clear = false
	_expect(flat, "the clearing is flat ground")
	_expect(clear, "the air over the clearing is clear")
	var trees_in_clearing := false
	for cx in [-1, 0]:
		for o in g.objects_in_chunk(cx):
			if o.kind.begins_with("tree_") and absi(o.cell.x) < 6:
				trees_in_clearing = true
	_expect(not trees_in_clearing, "no trees grow on the cabin")
	var wall := true
	for y in range(t.world_top + 12, t.world_bottom):
		if g.tile_at(t.world_min_x - 1, y) != Tiles.BEDROCK:
			wall = false
	_expect(wall, "an unbreakable cliff closes off the west")


func _test_world_shape() -> void:
	print("\n== biomes, terrain, resources, forest ==")
	var g := WorldGen.new(SEED, t)
	var seen := {}
	var max_step := 0
	for x in range(0, 3000):
		seen[g.biome_at(x)] = true
		max_step = maxi(max_step, absi(g.surface_y(x + 1) - g.surface_y(x)))
	print("  steepest surface step: %d tiles" % max_step)
	_expect(seen.size() == 4, "all four biomes appear within 3000 tiles")
	_expect(g.biome_at(10) == WorldGen.Biome.MEADOW, "the cabin stands in the meadow")
	_expect(max_step <= 2, "the ground is walkable: steps of at most 2 tiles (jump height)")
	var counts := {}
	for cx in range(0, 40):
		var tiles := g.generate_chunk(cx)
		for i in tiles.size():
			counts[tiles[i]] = counts.get(tiles[i], 0) + 1
	print("  clay %d, coal %d, iron %d, gold %d, ruins %d" % [counts.get(Tiles.CLAY, 0), counts.get(Tiles.COAL, 0),
			counts.get(Tiles.IRON_ORE, 0), counts.get(Tiles.GOLD, 0), counts.get(Tiles.RUIN, 0)])
	_expect(counts.get(Tiles.CLAY, 0) > 100 and counts.get(Tiles.COAL, 0) > 100 and counts.get(Tiles.IRON_ORE, 0) > 100,
			"clay, coal and iron are common enough")
	_expect(counts.get(Tiles.GOLD, 0) > 10 and counts.get(Tiles.RUIN, 0) > 5, "gold and old stonework exist")
	# Early game: near the cabin there must be trees, rocks and clay for a workbench and a hearth.
	var trees := 0
	var rocks := 0
	var kinds := {}
	for cx in range(-1, 3):
		for o in g.objects_in_chunk(cx):
			if absi(o.cell.x) < 60:
				if o.kind.begins_with("tree_"):
					trees += 1
				if o.kind == "rock":
					rocks += 1
	var clay := 0
	for x in range(-30, 40):
		var s := g.surface_y(x)
		for y in range(s, s + t.topsoil_depth):
			if g.tile_at(x, y) == Tiles.CLAY:
				clay += 1
	for cx in range(0, 30):
		for o in g.objects_in_chunk(cx):
			kinds[o.kind] = kinds.get(o.kind, 0) + 1
	print("  within 60 tiles of the cabin: %d trees, %d rocks; clay in reach: %d" % [trees, rocks, clay])
	print("  first 960 tiles: %s" % str(kinds))
	_expect(trees >= 8, "there are trees to chop near the cabin")
	_expect(rocks * t.rock_yield >= 10 and clay >= 6, "stone and clay for a hearth are close by")
	_expect(kinds.get("page", 0) >= 8 and kinds.get("runestone", 0) >= 2, "journal pages and runestones lie along the way")
	_expect(kinds.get("tree_pine", 0) > 30 and kinds.get("tree_oak", 0) > 20 and kinds.get("tree_birch", 0) > 10,
			"pines, oaks and birches all grow")


# ---- Survival ----------------------------------------------------------------------------

func _tick(s: Survival, seconds: float, ctx: Dictionary) -> void:
	for i in int(seconds * 60.0):
		s.tick(1.0 / 60.0, ctx)


func _test_survival() -> void:
	print("\n== survival ==")
	var s := Survival.new(t)
	_tick(s, 10.0, {})
	_expect(absf(s.hunger - (t.hunger_max - 10.0 * t.hunger_drain)) < 0.01, "hunger drains steadily")
	var w := s.warmth
	_tick(s, 10.0, {"night": true})
	_expect(s.warmth < w - 5.0, "night outside makes you cold")
	s.warmth = 0.0
	var h := s.health
	_tick(s, 2.0, {"night": true})
	_expect(s.health < h, "freezing hurts")
	_tick(s, 5.0, {"home": true, "hearth": true, "night": true})
	_expect(s.warmth > 25.0, "a hearth at home warms you, even at night")
	var hardy := Survival.new(t)
	hardy.cold_factor = 0.6
	var normal := Survival.new(t)
	_tick(hardy, 10.0, {"night": true})
	_tick(normal, 10.0, {"night": true})
	_expect(hardy.warmth > normal.warmth, "a Wanderer feels the cold less")
	var st := Survival.new(t)
	var worked := 0
	while st.work():
		worked += 1
	_expect(worked == int(t.stamina_max / t.work_stamina), "work uses stamina until you're too tired")
	_tick(st, 3.0, {})
	_expect(st.stamina > 15.0, "stamina comes back while you rest")


# ---- Cabin -------------------------------------------------------------------------------

func _test_cabin() -> void:
	print("\n== cabin ==")
	var c := Cabin.starter(t)
	_expect(c.has_function("bed") and c.has("window"), "you start with a straw bed and a window")
	_expect(c.can_place("chest", 2) != "", "can't place on top of the bed")
	_expect(c.can_place("table", c.width() - 2) != "", "can't block the door")
	_expect(c.can_place("workbench", 5) == "", "an empty spot is fine")
	c.place("workbench", 5)
	_expect(c.can_place("chest", 6) != "" and c.can_place("chest", 7) == "", "floor items can't overlap")
	_expect(c.can_place("rug", 4) == "", "a rug can lie under furniture")
	_expect(c.can_place("banner", 8, 0) != "", "wall decor can't hang on the ceiling beam")
	_expect(c.can_place("banner", 8, 2) == "" and c.can_place("tapestry", 5, 2) != "", "wall decor can't overlap the window")
	var idx := c.item_at(5, c.height() - 2)
	_expect(idx >= 0 and c.placed[idx].id == "workbench", "tapping a piece finds it")
	var comfort0 := c.comfort()
	var light_night := c.light(0.0)
	c.place("candle_stand", 8)
	_expect(c.comfort() > comfort0 and c.light(0.0) > light_night, "furniture adds comfort and candles add light")
	_expect(c.light(1.0) > c.light(0.0), "windows let daylight in")
	_expect(c.remove(c.item_at(8, c.height() - 2)) == "candle_stand", "taking a piece back returns it")
	var w0 := c.width()
	_expect(c.apply_upgrade("extend") and c.width() == w0 + t.cabin_extend_width, "extending widens the cabin")
	_expect(c.apply_upgrade("floor_planks") and c.upgrade_block("floor_planks") != "", "upgrades apply once")
	var copy := Cabin.new(t)
	copy.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	_expect(str(copy.to_dict()) == str(c.to_dict()), "the cabin survives a save/load")


# ---- Crafting ----------------------------------------------------------------------------

func _test_crafting() -> void:
	print("\n== crafting ==")
	var inv := Inventory.new()
	var c := Cabin.starter(t)
	_expect(Crafting.block(t, "workbench", inv, c, false) == "Not enough", "recipes need their materials")
	inv.add("log", 6)
	_expect(Crafting.craft(t, "workbench", inv, c, false) and inv.count("workbench") == 1 and inv.count("log") == 0,
			"a workbench can be made by hand anywhere")
	inv.add("log", 5)
	_expect(Crafting.block(t, "plank", inv, c, true) == "Needs your workbench", "planks need a placed workbench")
	c.place("workbench", 5)
	_expect(Crafting.block(t, "plank", inv, c, false) == "Needs your workbench", "...and you must be at home")
	_expect(Crafting.craft(t, "plank", inv, c, true) and inv.count("plank") == 2, "a log makes two planks at the workbench")
	inv.add("stone", 6)
	inv.add("log", 4)
	_expect(Crafting.craft(t, "stone_pick", inv, c, false) and Crafting.tool_tier(inv, "pick") == 1, "a stone pickaxe raises your pick tier")
	_expect(Crafting.block(t, "stone_pick", inv, c, false) == "You have one", "no second copy of a tool you have")
	inv.add("plank", 14)
	var floor0 := c.floor_type
	_expect(Crafting.craft(t, "floor_planks", inv, c, true) and c.floor_type != floor0 and inv.count("floor_planks") == 0,
			"an upgrade changes the cabin instead of adding an item")
	_expect(Crafting.block(t, "iron", inv, c, true) == "Needs your hearth", "smelting needs a hearth")


# ---- Story -------------------------------------------------------------------------------

func _test_story() -> void:
	print("\n== story order ==")
	var st := Story.new()
	var started: Array = []
	st.chapter_started.connect(func(ch): started.append(ch.id))
	st.begin()
	_expect(started == ["cabin"], "the story starts at the cabin")
	st.on_place("hearth")
	_expect(st.current().id == "cabin", "doing a later goal early doesn't skip ahead")
	st.on_place("workbench")
	_expect(started == ["cabin", "warmth", "night"], "placing the workbench moves on; the hearth (already built) passes in order")
	st.on_night_survived()
	_expect(st.current().id == "page", "surviving the night leads to the journal")
	var p1 := st.on_lore("page")
	var p2 := st.on_lore("page")
	_expect(p1.title.ends_with("page 1") and p2.title.ends_with("page 2"), "journal pages come in order, whichever is found")
	st.on_position(100, WorldGen.Biome.PINEWOOD)
	_expect(st.current().id == "home", "reaching the Pinewood moves on")
	st.on_comfort(12)
	_expect(st.current().id == "oaks", "a comfortable cabin moves on")
	for i in 10:
		st.on_lore("page")
	_expect(st.on_lore("page").title == "A loose page", "after the last page, a fallback entry")
	var copy := Story.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())))
	_expect(copy.current().id == st.current().id and copy.lore_read.page == st.lore_read.page, "story progress survives a save/load")


func _test_character_and_font() -> void:
	print("\n== character and font ==")
	var look := CharacterLook.default_look()
	var all_ok := true
	for opt in CharacterLook.OPTIONS:
		for i in CharacterLook.choice_count(opt[0]):
			look[opt[0]] = i
			var fr := CharacterLook.frames(look)
			if fr.size() != 3 or fr[0].get_size() != Vector2(8, 14) or CharacterLook.choice_name(look, opt[0]) == "":
				all_ok = false
	_expect(all_ok, "every appearance choice builds a 3-frame 8×14 sprite with a name")
	_expect(t.backgrounds.size() == Catalog.BACKGROUNDS.size(), "every background has a starting kit")
	var f := PixelFont.get_font()
	_expect(f != null and f.get_string_size("ELDWOOD", HORIZONTAL_ALIGNMENT_LEFT, -1, PixelFont.SIZE).x == 42.0,
			"the pixel font is monospace: 6 px per character")
	var missing := false
	for id in t.recipes:
		if not Catalog.ITEMS.has(id):
			missing = true
	_expect(not missing, "every recipe makes a catalogued item")


# ---- The real game scene -----------------------------------------------------------------

func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _close_pages(main: Main) -> void:
	main.hud._queue.clear()
	main.hud.close_panel()
	paused = false


func _test_game_scene() -> void:
	print("\n== game scene ==")
	Main.pending_seed = SEED
	var main: Main = load("res://scenes/main.tscn").instantiate()
	main.use_save = false
	root.add_child(main)
	await process_frame
	_close_pages(main)
	await _frames(20)
	var p := main.player
	_expect(main.inside and p.is_on_floor(), "a new game starts inside the cabin, on the floor")
	_expect(main.inventory.count("stone_axe") == 1, "the Woodcutter starts with a stone axe")
	# Out the door.
	var door := main.interior.global_position + Vector2((main.cabin.width() - 1) * t.tile_size + 4, (main.cabin.height() - 2) * t.tile_size)
	main._tap(main.get_viewport().get_canvas_transform() * door, true)
	await _frames(30)
	_expect(not main.inside and p.is_on_floor(), "tapping the door takes you outside, onto the ground")
	var x0 := p.position.x
	Input.action_press("move_right")
	await _frames(60)
	Input.action_release("move_right")
	print("  walked %.0f px in 1 s" % (p.position.x - x0))
	_expect(p.position.x - x0 > 30.0, "holding ▶ walks east")
	await _frames(20)
	var y0 := p.position.y
	Input.action_press("jump")
	await _frames(8)
	Input.action_release("jump")
	_expect(p.position.y < y0 - 8.0, "JUMP leaves the ground")
	await _frames(50)

	# Chop the nearest tree (teleport beside it).
	var tree: WorldObject = null
	for o in main.world.objects():
		if o.is_tree() and (tree == null or absf(o.position.x - p.position.x) < absf(tree.position.x - p.position.x)):
			tree = o
	_expect(tree != null, "there's a tree to chop")
	if tree:
		p.position = tree.position + Vector2(-10, -8)
		var logs0 := main.inventory.count("log")
		var tid := tree.id
		var chops := 0
		while is_instance_valid(tree) and not tree.is_queued_for_deletion() and chops < 20:
			main.survival.stamina = t.stamina_max
			main._chop(tree)
			chops += 1
		print("  felled a %s in %d chops" % [tid.split("@")[0], chops])
		_expect(main.inventory.count("log") > logs0, "felling a tree gives logs")
		main.world.stream_around(Vector2(40000, 0), true)
		main.world.stream_around(p.position, true)
		var back := false
		for o in main.world.objects():
			if o.id == tid:
				back = true
		_expect(not back, "a felled tree stays felled after its chunk reloads")
	await _frames(30)

	# Dig: the soil under your feet comes away by hand; stone doesn't.
	var feet := t.to_tile(p.position + Vector2(0, Player.H * 0.5 + 2.0))
	var soil_id := main.world.tile_at(feet)
	var r: Dictionary = main.world.dig(feet, 0, 1)
	_expect(Tiles.tier(soil_id) == 0 and r.result == "broken", "you can dig soil by hand (%s)" % Tiles.NAMES[soil_id])
	var stone := Vector2i(feet.x, feet.y + t.topsoil_depth + 1)
	_expect(main.world.dig(stone, 0, 1).result == "too_hard", "stone needs a pickaxe")

	# Build: a workbench from logs, placed in the cabin → the story moves on.
	main.inventory.add("log", 6)
	main._craft("workbench")
	main._enter_cabin()
	await _frames(5)
	main._toggle_build()
	main._on_build_pick("workbench")
	main._build_tap(Vector2i(6, main.cabin.height() - 2))
	main._toggle_build()
	_expect(main.cabin.has("workbench") and main.inventory.count("workbench") == 0, "the workbench is placed in the cabin")
	_close_pages(main)
	_expect(main.story.current().id == "warmth", "placing the workbench moves the story on")

	# Sleep through the night.
	main.day_night.time = 0.8
	var day0 := main.day_night.day
	main._sleep()
	_close_pages(main)
	_expect(main.day_night.day == day0 + 1 and not main.day_night.is_night(), "sleeping in your bed skips to dawn")

	# Save and load into a fresh scene.
	main.chest.add("gold", 3)
	var data: Dictionary = JSON.parse_string(JSON.stringify(main.to_save()))
	main.queue_free()
	await _frames(2)
	var main2: Main = load("res://scenes/main.tscn").instantiate()
	main2.use_save = false
	main2.start_data = data
	root.add_child(main2)
	await process_frame
	paused = false
	await _frames(2)
	_expect(main2.world_seed == SEED and main2.look.name == data.look.name, "the save keeps the seed and your character")
	_expect(main2.cabin.has("workbench") and main2.inside, "the save keeps your cabin and where you were")
	_expect(main2.world.tile_at(feet) == Tiles.AIR, "the save keeps dug cells")
	_expect(main2.chest.count("gold") == 3 and main2.story.current().id == "warmth", "the save keeps the chest and the story")
	main2.queue_free()
	await _frames(2)
