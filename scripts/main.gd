## Wires the game together and runs the game rules that span systems: tapping the world (mine /
## pick up / use the ship), survival ticking, death and respawn, ship repairs and crafting,
## story events, day/night lighting, and autosaving.
class_name Main
extends Node2D

## Seed for the next "New world" (set before reloading the scene; 0 = none).
static var pending_seed := 0

@export var tuning: GameTuning = preload("res://tuning/game_tuning.tres")
## Load/save the game in user://. Headless tests turn this off.
@export var use_save := true
## Start from this saved-game dictionary instead of the save file (tests: save/load roundtrip).
var start_data := {}

var world_seed: int
var world: World
var ship: Ship
var player: Player
var camera: Camera2D
var shade: CanvasModulate
var survival: Survival
var inventory: Inventory
var story: Story
var day_night: DayNight
var hud: Hud
var touch: TouchControls
var background: Background

var _mine_held := false
var _mine_pos := Vector2.ZERO
var _mine_timer := 0.0
var _autosave := 0.0
var _last_far_msg := -10.0


func _ready() -> void:
	var data := SaveGame.read() if use_save else start_data
	if pending_seed != 0:
		data = {}
		world_seed = pending_seed
		pending_seed = 0
	elif data.has("seed"):
		world_seed = int(data.seed)
	else:
		world_seed = _fresh_seed()
	_build(data)


## A new seed: the tuning's default_seed, or one picked from the clock. (Only CHOOSING the seed
## uses the clock; the world generated from it is fully deterministic.)
func _fresh_seed() -> int:
	if tuning.default_seed != 0:
		return tuning.default_seed
	return int(Time.get_unix_time_from_system() * 1000.0) % 2147483646 + 1


func _build(data: Dictionary) -> void:
	get_tree().quit_on_go_back = false   # the back button pauses instead of quitting
	world = World.new()
	add_child(world)
	world.setup(tuning, world_seed)
	world.mined = SaveGame.list_to_cells(data.get("mined", []))
	for id in data.get("collected", []):
		world.collected[id] = true

	ship = Ship.new()
	add_child(ship)
	ship.setup(tuning)
	ship.repaired = data.get("repairs", {}).duplicate()

	player = Player.new()
	add_child(player)
	player.setup(tuning)
	player.position = spawn_point()
	if data.has("player"):
		player.position = Vector2(data.player[0], data.player[1])
	player.hard_landing.connect(_on_hard_landing)

	camera = Camera2D.new()
	camera.offset = Vector2(0, tuning.camera_offset_y)
	camera.zoom = Vector2.ONE * tuning.camera_zoom
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS   # follows the player's physics ticks
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = tuning.camera_smoothing
	camera.limit_bottom = tuning.world_bottom * tuning.tile_size
	player.add_child(camera)
	camera.make_current()

	shade = CanvasModulate.new()   # darkness at night / underground (the headlamp cuts through)
	add_child(shade)

	survival = Survival.new(tuning)
	inventory = Inventory.new()
	story = Story.new()
	day_night = DayNight.new(tuning)
	if data.has("stats"):
		survival.from_dict(data.stats)
	inventory.from_dict(data.get("inventory", {}))
	if data.has("story"):
		story.from_dict(data.story)
	day_night.time = float(data.get("time", tuning.start_time))
	day_night.day = int(data.get("day", 1))
	day_night.night_ended.connect(_on_night_ended)

	background = Background.new()
	add_child(background)
	background.setup(world_seed)
	touch = TouchControls.new()
	add_child(touch)
	touch.setup(tuning)
	hud = Hud.new()
	add_child(hud)
	hud.setup(tuning)
	hud.world_seed = world_seed
	hud.use_item.connect(_use_item)
	hud.repair.connect(_repair)
	hud.craft.connect(_craft)
	hud.paused.connect(_on_paused)
	hud.new_world.connect(_new_world)
	story.chapter_started.connect(func(ch: Dictionary): hud.show_story(ch.title, ch.text))
	inventory.changed.connect(func(): hud.update_inventory(inventory))
	hud.update_inventory(inventory)

	world.stream_around(player.position, true)   # ground under the player before physics starts
	if data.is_empty():
		story.begin()
	else:
		hud.toast("Welcome back. Day %d." % day_night.day, Color("7fe0d0"))


## Where you stand at the start / after a suit failure: just east of the ship, on the ground.
func spawn_point() -> Vector2:
	var x := 3
	var top := world.gen.surface_y(x)
	return Vector2((x + 0.5) * tuning.tile_size, top * tuning.tile_size - Player.H * 0.5 - 1.0)


# ---- Every tick ---------------------------------------------------------------------------

func _physics_process(dt: float) -> void:
	world.stream_around(player.position)
	day_night.tick(dt)
	var cell := tuning.to_tile(player.position)
	var depth := cell.y - world.gen.surface_y(cell.x)
	var night := day_night.is_night()
	var at_base := ship.in_range(player.position)
	survival.tick(dt, {"at_base": at_base, "night": night,
			"dark": night or depth >= tuning.underground_depth,
			"scrubber": ship.repaired.has("scrubber"), "solar": ship.repaired.has("solar")})
	if survival.is_dead():
		_on_suit_failure()
	story.on_position(cell.x, world.gen.biome_at(cell.x))
	if _mine_held:
		_mine_timer -= dt
		if _mine_timer <= 0.0:
			_mine_timer = tuning.mine_interval
			_tap_world(_mine_pos, false)
	_autosave += dt
	if _autosave >= tuning.autosave_interval:
		_autosave = 0.0
		save()


func _process(_dt: float) -> void:
	# Light: daylight, dimmed further the deeper you are underground.
	var cell := tuning.to_tile(player.position)
	var depth := cell.y - world.gen.surface_y(cell.x)
	var under := clampf((depth - tuning.underground_depth + 2) / 8.0, 0.0, 1.0)
	var light := minf(day_night.light(), lerpf(1.0, tuning.underground_light, under))
	shade.color = Color(light, light * 0.97, minf(light * 1.08, 1.0))
	player.set_darkness(light)
	background.daylight = day_night.daylight()
	background.camera_pos = camera.get_screen_center_position()
	hud.update_stats(survival)
	var biome: String = WorldGen.BIOME_NAMES[world.gen.biome_at(cell.x)]
	var place := "%s, %d m east" % [biome, maxi(cell.x, 0)]
	if ship.in_range(player.position):
		place = "At the ship (safe)"
	elif depth >= tuning.underground_depth:
		place += ", %d m down" % depth
	hud.update_info(day_night.clock_text() + ("  NIGHT" if day_night.is_night() else ""), place, story.objective())


# ---- Tapping the world --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mine_held = true
			_mine_pos = event.position
			_mine_timer = tuning.mine_interval
			_tap_world(event.position, true)
		else:
			_mine_held = false
	elif event is InputEventMouseMotion and _mine_held:
		_mine_pos = event.position


## A tap (or a held finger, repeating) at a screen point. On the first touch: pickups and the
## ship come first; otherwise (and while holding) it mines the tile under the finger.
func _tap_world(screen_pos: Vector2, first: bool) -> void:
	var p := get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	var reach := tuning.reach_tiles * tuning.tile_size
	if first:
		var pick := _pickup_at(p)
		if pick:
			if player.position.distance_to(pick.position + Vector2(0, -16)) <= reach + 16.0:
				_collect(pick)
			else:
				_too_far()
			_mine_held = false
			return
		if p.distance_to(ship.position + Vector2(0, -34)) < 130.0 and absf(p.y - (ship.position.y - 34)) < 60.0:
			_mine_held = false
			if ship.in_range(player.position):
				touch.release_all()
				hud.show_ship(inventory, ship.repaired)
			else:
				hud.toast("Walk to the ship to use it.")
			return
	var cell := tuning.to_tile(p)
	if not Tiles.is_solid(world.tile_at(cell)):
		return
	if player.position.distance_to(tuning.tile_center(cell)) > reach:
		if first:
			_too_far()
		return
	if Tiles.hits(world.tile_at(cell), tuning) <= 0:
		if first:
			hud.toast("Too hard to break.")
		return
	if survival.power <= 0.0:
		if first:
			hud.toast("Suit power empty: can't run the drill.", Color("ff5d6c"))
		return
	survival.add("power", -tuning.mine_power_cost)
	var result := world.hit(cell)
	if result != "" and result != "broken":
		inventory.add(result)
		hud.toast("+1 %s" % Hud.ITEM_NAMES[result], Hud.ITEM_COLORS.get(result, Color.WHITE))


func _pickup_at(p: Vector2) -> Pickup:
	var best: Pickup = null
	var best_d := 44.0
	for child in world.get_children():
		if child is Pickup:
			var d: float = (child.position + Vector2(0, -20)).distance_to(p)
			if d < best_d:
				best_d = d
				best = child
	return best


func _too_far() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_far_msg > 1.5:
		_last_far_msg = now
		hud.toast("Too far away. Get closer.")


func _collect(p: Pickup) -> void:
	match p.kind:
		"bladder":
			survival.add("oxygen", tuning.bladder_oxygen)
			hud.toast("+%d oxygen" % tuning.bladder_oxygen, Hud.BAR_COLORS.oxygen)
		"glowcap":
			inventory.add("glowcap")
			hud.toast("+1 Glowcap (food)", Hud.BAR_COLORS.food)
		"wreck":
			inventory.add("metal", tuning.wreck_metal)
			hud.toast("+%d Metal" % tuning.wreck_metal, Hud.ITEM_COLORS.metal)
			# Whether this wreck holds a power cell is fixed by the seed (same world → same loot).
			if HashNoise.hash_f(world_seed, p.cell.x, 0, 999) < tuning.wreck_cell_chance:
				inventory.add("cell")
				hud.toast("+1 Power Cell", Hud.BAR_COLORS.power)
		"crew_log", "monolith":
			var entry := story.on_lore(p.kind)
			touch.release_all()
			hud.show_story(entry.title, entry.text)
	world.take(p)


# ---- Items, ship ---------------------------------------------------------------------------

func _use_item(item: String) -> void:
	if not inventory.spend({item: 1}):
		return
	match item:
		"glowcap":
			survival.add("food", tuning.glowcap_food)
		"canister":
			survival.add("oxygen", tuning.canister_oxygen)
		"cell":
			survival.add("power", tuning.cell_power)


func _repair(id: String) -> void:
	if ship.repaired.has(id) or not inventory.spend(tuning.repairs[id]):
		return
	ship.repaired[id] = true
	if id == "tank":
		survival.oxygen_cap += tuning.tank_upgrade_oxygen
	hud.toast("%s repaired!" % Ship.REPAIRS[id][0], Color("7fe0d0"))
	hud.refresh_ship(inventory, ship.repaired)
	story.on_repair(id)
	save()


func _craft(item: String) -> void:
	if inventory.spend(tuning.crafts[item]):
		inventory.add(item)
		hud.toast("Made: %s" % Ship.CRAFTS[item][0], Color("7fe0d0"))
		hud.refresh_ship(inventory, ship.repaired)


# ---- Events --------------------------------------------------------------------------------

func _on_hard_landing(speed: float) -> void:
	var dmg := (speed - tuning.fall_safe_speed) * tuning.fall_damage_per_speed
	survival.damage(dmg)
	hud.toast("Hard landing! -%d health" % dmg, Hud.BAR_COLORS.health)


func _on_night_ended() -> void:
	story.on_night_survived()
	hud.toast("Dawn of day %d. You survived the night." % day_night.day, Color("ffe08a"))


## Health hit 0: the suit's emergency system hauls you back to the ship, and you drop part of
## what you were carrying. (Physical consequence, not a scripted death — rule 3.)
func _on_suit_failure() -> void:
	var lost := inventory.lose_fraction(tuning.death_loss)
	survival.refill_all()
	player.position = spawn_point()
	player.velocity = Vector2.ZERO
	world.stream_around(player.position, true)
	camera.reset_smoothing()
	var lost_text := ""
	for item in lost:
		lost_text += "\n  %d %s" % [lost[item], Hud.ITEM_NAMES[item]]
	touch.release_all()
	hud.show_story("Suit failure", "Your vision goes dark. The suit's emergency system drags you back to the Meridian, and you wake on the cabin floor.\n\n" +
			("You lost:" + lost_text if lost_text != "" else "You were carrying nothing."))
	save()


func _on_paused(on: bool) -> void:
	get_tree().paused = on
	_mine_held = false
	touch.release_all()
	if on:
		save()


func _new_world() -> void:
	SaveGame.delete()
	pending_seed = int(Time.get_unix_time_from_system() * 1000.0) % 2147483646 + 1
	get_tree().paused = false
	get_tree().reload_current_scene()


# ---- Saving --------------------------------------------------------------------------------

func to_save() -> Dictionary:
	return {"version": SaveGame.VERSION, "seed": world_seed,
			"player": [player.position.x, player.position.y],
			"stats": survival.to_dict(), "inventory": inventory.to_dict(),
			"mined": SaveGame.cells_to_list(world.mined), "collected": world.collected.keys(),
			"story": story.to_dict(), "repairs": ship.repaired,
			"time": day_night.time, "day": day_night.day}


func save() -> void:
	if use_save:
		SaveGame.write(to_save())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and hud and not hud.panel_open():
		hud.show_pause()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if world:
			save()
