## Headless tests for Tessaris:
##   godot --headless --path . -s res://tests/test_game.gd
## Pure checks first (world generation, survival, story, save data), then the real game scene
## (walking, jumping, mining, pickups, chunk reloads, save/load roundtrip).
extends SceneTree

const SEED := 424242

var failures := 0
var t: GameTuning = preload("res://tuning/game_tuning.tres")


func _initialize() -> void:
	_test_determinism()
	_test_spawn_site()
	_test_world_shape()
	_test_survival()
	_test_story()
	_test_inventory_and_save_data()
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
		if ca != b.generate_chunk(cx) or str(a.pickups_in_chunk(cx)) != str(b.pickups_in_chunk(cx)):
			same = false
		if ca != c.generate_chunk(cx):
			differs = true
	_expect(same, "same seed → identical chunks and pickups")
	_expect(differs, "different seed → a different world")
	# Order independence: chunk 5 generated alone vs. after its neighbours, by fresh generators.
	var alone := WorldGen.new(SEED, t).generate_chunk(5)
	var seq := WorldGen.new(SEED, t)
	for cx in range(0, 5):
		seq.generate_chunk(cx)
	_expect(alone == seq.generate_chunk(5), "a chunk doesn't depend on generation order")
	# Chunk array matches tile_at cell by cell (spot check).
	var ok := true
	var tiles := a.generate_chunk(3)
	for i in range(0, tiles.size(), 37):
		var x := 3 * t.chunk_width + i % t.chunk_width
		var y := t.world_top + i / t.chunk_width
		if tiles[i] != a.tile_at(x, y) and y >= a.surface_y(x) - 8:
			ok = false
	_expect(ok, "generate_chunk agrees with tile_at")


func _test_spawn_site() -> void:
	print("\n== crash site ==")
	var g := WorldGen.new(SEED, t)
	var flat := true
	var clear := true
	for x in range(-t.crash_flat_radius, t.crash_flat_radius + 1):
		if g.surface_y(x) != t.surface_base:
			flat = false
		for y in range(t.surface_base - 6, t.surface_base):
			if g.tile_at(x, y) != Tiles.AIR:
				clear = false
		if not Tiles.is_solid(g.tile_at(x, t.surface_base)):
			flat = false
	_expect(flat, "the crash site is flat solid ground")
	_expect(clear, "the air above the crash site is clear")
	var wall := true
	for y in range(t.world_top + 8, t.world_bottom):
		if g.tile_at(t.world_min_x - 1, y) != Tiles.BEDROCK:
			wall = false
	_expect(wall, "an unbreakable crater wall closes off the west")


func _test_world_shape() -> void:
	print("\n== biomes, terrain, caves, resources ==")
	var g := WorldGen.new(SEED, t)
	var seen := {}
	var max_step := 0
	for x in range(0, 3000):
		seen[g.biome_at(x)] = true
		max_step = maxi(max_step, absi(g.surface_y(x + 1) - g.surface_y(x)))
	print("  steepest surface step: %d tiles" % max_step)
	_expect(seen.size() == 4, "all four biomes appear within 3000 tiles")
	_expect(g.biome_at(10) == WorldGen.Biome.PLAINS, "the crash site is in the Crash Plains")
	_expect(max_step <= 3, "the surface is walkable/jumpable (steps ≤ 3 tiles)")
	var counts := {}
	var caves := 0
	for cx in range(0, 40):
		var tiles := g.generate_chunk(cx)
		for i in tiles.size():
			counts[tiles[i]] = counts.get(tiles[i], 0) + 1
		for i in range(0, t.chunk_width, 4):
			var x := cx * t.chunk_width + i
			var s := g.surface_y(x)
			for y in range(s + t.cave_min_depth + 2, t.world_bottom - 4):
				if g.tile_at(x, y) == Tiles.AIR:
					caves += 1
	print("  ore %d, ice %d, crystal %d, alloy %d, cave cells sampled %d" % [counts.get(Tiles.ORE, 0),
			counts.get(Tiles.ICE, 0), counts.get(Tiles.CRYSTAL, 0), counts.get(Tiles.ALLOY, 0), caves])
	_expect(counts.get(Tiles.ORE, 0) > 100 and counts.get(Tiles.ICE, 0) > 100, "metal ore and ice are common")
	_expect(counts.get(Tiles.CRYSTAL, 0) > 50 and counts.get(Tiles.ALLOY, 0) > 20, "crystal and alloy exist")
	_expect(caves > 200, "there are caves underground")
	# Near the ship: enough ice and metal within reach for the first repair.
	var near := {Tiles.ORE: 0, Tiles.ICE: 0}
	for x in range(-30, 40):
		var s := g.surface_y(x)
		for y in range(s, s + 12):
			var id := g.tile_at(x, y)
			if near.has(id):
				near[id] += 1
	print("  within 40 tiles of the ship, 12 deep: ore %d, ice %d" % [near[Tiles.ORE], near[Tiles.ICE]])
	_expect(near[Tiles.ORE] >= 4 and near[Tiles.ICE] >= 3, "the first repair is possible near the ship")
	var logs := 0
	var monos := 0
	var plants := 0
	for cx in range(0, 30):
		for p in g.pickups_in_chunk(cx):
			match p.kind:
				"crew_log":
					logs += 1
				"monolith":
					monos += 1
				"bladder", "glowcap":
					plants += 1
	print("  first 960 tiles: crew logs %d, monoliths %d, plants %d" % [logs, monos, plants])
	_expect(logs >= 8 and monos >= 2 and plants > 20, "story pickups and plants are placed along the way")


# ---- Survival ----------------------------------------------------------------------------

func _test_survival() -> void:
	print("\n== survival ==")
	var s := Survival.new(t)
	for i in 600:   # 10 s outside by day, at 60 ticks/s
		s.tick(1.0 / 60.0, {})
	_expect(absf(s.oxygen - (t.oxygen_max - 10.0 * t.oxygen_drain)) < 0.01, "oxygen drains at oxygen_drain per second")
	s.oxygen = 0.0
	var h := s.health
	for i in 60:
		s.tick(1.0 / 60.0, {})
	_expect(s.health < h - t.suffocate_damage * 0.9, "no oxygen → health drops")
	for i in 120:
		s.tick(1.0 / 60.0, {"at_base": true, "scrubber": true})
	_expect(s.oxygen > 40.0, "the repaired ship refills oxygen")
	s.power = 0.0
	h = s.health
	s.oxygen = s.oxygen_cap
	for i in 60:
		s.tick(1.0 / 60.0, {"night": true})
	_expect(s.health < h, "no power at night outside → freezing")
	s.health = 0.0
	_expect(s.is_dead(), "0 health = suit failure")


# ---- Story -------------------------------------------------------------------------------

func _test_story() -> void:
	print("\n== story order ==")
	var st := Story.new()
	var started: Array = []
	st.chapter_started.connect(func(ch): started.append(ch.id))
	st.begin()
	_expect(started == ["impact"], "the story starts with the crash")
	st.on_repair("solar")
	_expect(st.current().id == "impact", "doing a later goal early doesn't skip ahead")
	st.on_repair("scrubber")
	_expect(st.current().id == "scattered", "repairing the scrubber advances the story")
	var e1 := st.on_lore("crew_log")
	var e2 := st.on_lore("crew_log")
	_expect(e1.title.contains("Hale") and e2.title.contains("Okafor"), "crew logs come in order, whichever pod is found")
	_expect(st.current().id == "nightfall", "finding a pod advances to nightfall")
	st.on_night_survived()
	# Solar was already repaired, so "sunlight" completes immediately → "glow".
	_expect(st.current().id == "glow", "goals already met are passed in order (no skipping text)")
	_expect(started == ["impact", "scattered", "nightfall", "sunlight", "glow"], "every chapter is shown, in order")
	for i in 10:
		st.on_lore("crew_log")
	var extra := st.on_lore("crew_log")
	_expect(extra.title == "Crew pod", "after the last log, pods give a fallback entry")
	var copy := Story.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())))
	_expect(copy.current().id == st.current().id and copy.lore_read.crew_log == st.lore_read.crew_log,
			"story progress survives a save/load")


func _test_inventory_and_save_data() -> void:
	print("\n== inventory and save data ==")
	var inv := Inventory.new()
	inv.add("metal", 3)
	inv.add("ice", 3)
	_expect(inv.can_afford(t.repairs.scrubber) == false, "can't afford a repair without enough metal")
	inv.add("metal", 3)
	_expect(inv.can_afford(t.repairs.scrubber), "6 metal + 3 ice affords the scrubber (4 metal, 3 ice)")
	_expect(inv.spend({"metal": 4, "ice": 3}) and inv.count("metal") == 2 and inv.count("ice") == 0, "spending removes the cost")
	inv.add("crystal", 7)
	var lost := inv.lose_fraction(0.5)
	_expect(lost.get("crystal", 0) == 3 and inv.count("crystal") == 4, "a suit failure loses half of each resource")
	var cells := {Vector2i(3, -1): true, Vector2i(-7, 40): true}
	_expect(SaveGame.list_to_cells(JSON.parse_string(JSON.stringify(SaveGame.cells_to_list(cells)))) == cells,
			"mined cells survive JSON")


# ---- The real game scene -----------------------------------------------------------------

func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _test_game_scene() -> void:
	print("\n== game scene ==")
	Main.pending_seed = SEED
	var main: Main = load("res://scenes/main.tscn").instantiate()
	main.use_save = false
	root.add_child(main)
	await process_frame
	main.hud._close_panel()   # the opening story page pauses the game; close it
	main.hud._panel_queue.clear()
	main.hud._close_panel()
	paused = false
	await _frames(30)
	var p := main.player
	_expect(p.is_on_floor(), "the player stands on the ground at the crash site")
	var x0 := p.position.x
	Input.action_press("move_right")
	await _frames(90)
	Input.action_release("move_right")
	print("  walked %.0f px in 1.5 s" % (p.position.x - x0))
	_expect(p.position.x - x0 > 150.0, "holding ▶ walks east")
	await _frames(20)
	var y0 := p.position.y
	Input.action_press("jump")
	await _frames(12)
	Input.action_release("jump")
	_expect(p.position.y < y0 - 40.0, "JUMP leaves the ground")
	await _frames(60)
	_expect(p.is_on_floor(), "the player lands again")

	# Mining: the tile right under the player's feet, tapped through the real tap handler.
	var feet := t.to_tile(p.position + Vector2(0, Player.H * 0.5 + 4.0))
	var id := main.world.tile_at(feet)
	var screen := main.get_viewport().get_canvas_transform() * t.tile_center(feet)
	for i in Tiles.hits(id, t):
		main._tap_world(screen, true)
	_expect(main.world.tile_at(feet) == Tiles.AIR, "tapping a tile enough times breaks it (%s)" % Tiles.NAMES[id])
	# Chunk reload: walk the stream far away and back; the hole must still be there.
	main.world.stream_around(Vector2(40000, 0), true)
	_expect(not main.world.is_loaded(0), "far chunks unload")
	main.world.stream_around(p.position, true)
	_expect(main.world.map.get_cell_source_id(feet) == -1, "a mined cell stays mined after its chunk reloads")

	# Pickups: collect the nearest one by teleporting next to it.
	var pick: Pickup = null
	for c in main.world.get_children():
		if c is Pickup and (c.kind == "wreck" or c.kind == "bladder" or c.kind == "glowcap"):
			pick = c
			break
	_expect(pick != null, "there are pickups near the crash site")
	if pick:
		var pid := pick.id
		p.position = pick.position + Vector2(0, -30)
		main._collect(pick)
		main.world.stream_around(Vector2(40000, 0), true)
		main.world.stream_around(p.position, true)
		var back := false
		for c in main.world.get_children():
			if c is Pickup and not c.is_queued_for_deletion() and c.id == pid:
				back = true
		_expect(main.world.collected.has(pid) and not back, "a collected pickup doesn't come back")

	# Ship: repair the scrubber with resources in hand.
	main.inventory.add("metal", 4)
	main.inventory.add("ice", 3)
	main._repair("scrubber")
	_expect(main.ship.repaired.has("scrubber") and main.story.current().id == "scattered",
			"repairing at the ship works and moves the story on")

	# Save/load roundtrip into a fresh scene.
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
	_expect(main2.world_seed == SEED, "the save keeps the world seed")
	_expect(main2.world.tile_at(feet) == Tiles.AIR, "the save keeps mined cells")
	_expect(main2.ship.repaired.has("scrubber") and main2.story.current().id == "scattered", "the save keeps repairs and story")
	_expect(main2.player.position.distance_to(Vector2(data.player[0], data.player[1])) < 40.0, "the save keeps the player's position")
	main2.queue_free()
	await _frames(2)
