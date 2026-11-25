## Runs Eldwood: title screen → character creation → the game. Wires the systems together and
## runs the rules that span them: tapping (chop, dig, pick up, read, use furniture, build),
## survival ticks, torches, sleeping, collapsing, crafting, the cabin's inside/outside, saving.
class_name Main
extends Node2D

## Seed for the next new game (tests set it; 0 = pick one).
static var pending_seed := 0

@export var tuning: GameTuning = preload("res://tuning/game_tuning.tres")
## Use the save file and the title menus. Headless tests turn this off and start straight in.
@export var use_save := true
## Tests: start from this saved-game dictionary ({} = a new game with the default character).
var start_data := {}

var world_seed: int
var look: Dictionary
var world: World
var exterior: CabinExterior
var interior: CabinInterior
var cabin: Cabin
var player: Player
var camera: Camera2D
var shade: CanvasModulate
var survival: Survival
var inventory: Inventory
var chest: Inventory
var story: Story
var day_night: DayNight
var hud: Hud
var touch: TouchControls
var background: Background
var inside := false
var running := false

var _menu_layer: CanvasLayer
var _work_held := false
var _work_pos := Vector2.ZERO
var _work_timer := 0.0
var _torch_burn := 0.0
var _autosave := 0.0
var _last_msg := {}
var _build := false
var _build_pick := ""
var _build_remove := false


func _ready() -> void:
	get_tree().quit_on_go_back = false   # the back button pauses instead of quitting
	if not use_save:
		_start_game(start_data, CharacterLook.default_look())
		return
	_menu_layer = CanvasLayer.new()
	_menu_layer.layer = 20
	add_child(_menu_layer)
	var title := TitleScreen.new()
	_menu_layer.add_child(title)
	title.setup(SaveGame.exists())
	title.continue_game.connect(func(): _start_game(SaveGame.read(), {}))
	title.new_game.connect(func():
		title.queue_free()
		var creator := CharacterCreator.new()
		_menu_layer.add_child(creator)
		creator.setup()
		creator.finished.connect(func(new_look: Dictionary):
			SaveGame.delete()
			_start_game({}, new_look)))


func _fresh_seed() -> int:
	if pending_seed != 0:
		var s := pending_seed
		pending_seed = 0
		return s
	if tuning.default_seed != 0:
		return tuning.default_seed
	return int(Time.get_unix_time_from_system() * 1000.0) % 2147483646 + 1


# ---- Building the game ------------------------------------------------------------------------

func _start_game(data: Dictionary, new_look: Dictionary) -> void:
	if _menu_layer:
		_menu_layer.queue_free()
		_menu_layer = null
	var fresh := data.is_empty()
	world_seed = int(data.seed) if data.has("seed") else _fresh_seed()
	look = data.get("look", new_look)
	for k in CharacterLook.default_look():   # older/partial looks get defaults for missing keys
		if not look.has(k):
			look[k] = CharacterLook.default_look()[k]

	world = World.new()
	add_child(world)
	world.setup(tuning, world_seed)
	world.mined = SaveGame.list_to_cells(data.get("mined", []))
	for id in data.get("collected", []):
		world.collected[id] = true

	cabin = Cabin.starter(tuning)
	if data.has("cabin"):
		cabin.from_dict(data.cabin)
	exterior = CabinExterior.new()
	add_child(exterior)
	exterior.setup(tuning, cabin)
	interior = CabinInterior.new()
	add_child(interior)
	interior.setup(tuning, cabin)

	player = Player.new()
	add_child(player)
	player.setup(tuning, look)
	player.hard_landing.connect(_on_hard_landing)
	camera = Camera2D.new()
	camera.offset = Vector2(0, tuning.camera_offset_y)   # look a bit lower: you stand above the buttons
	camera.zoom = Vector2.ONE * tuning.camera_zoom
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = tuning.camera_smoothing
	player.add_child(camera)
	camera.make_current()
	shade = CanvasModulate.new()
	add_child(shade)

	survival = Survival.new(tuning)
	inventory = Inventory.new()
	chest = Inventory.new()
	story = Story.new()
	day_night = DayNight.new(tuning)
	var bg: Dictionary = tuning.backgrounds.get(look.background, {})
	survival.cold_factor = float(bg.get("cold", 1.0))
	if fresh:
		for item in bg.get("items", {}):
			inventory.add(item, int(bg.items[item]))
	else:
		survival.from_dict(data.get("stats", {}))
		inventory.from_dict(data.get("inventory", {}))
		chest.from_dict(data.get("chest", {}))
		story.from_dict(data.get("story", {}))
		day_night.time = float(data.get("time", tuning.start_time))
		day_night.day = int(data.get("day", 1))
		_torch_burn = float(data.get("torch_burn", 0.0))
	day_night.night_ended.connect(_on_night_ended)

	background = Background.new()
	add_child(background)
	background.setup(world_seed)
	background.day_fraction = 1.0 - tuning.night_fraction
	touch = TouchControls.new()
	add_child(touch)
	touch.setup(tuning)
	hud = Hud.new()
	add_child(hud)
	hud.setup(tuning)
	hud.world_seed = world_seed
	hud.craft.connect(_craft)
	hud.use_item.connect(_use_item)
	hud.open_craft.connect(func(): touch.release_all(); hud.show_craft(inventory, cabin, inside))
	hud.open_bag.connect(func(): touch.release_all(); hud.show_bag(inventory))
	hud.toggle_build.connect(_toggle_build)
	hud.build_pick.connect(_on_build_pick)
	hud.build_remove.connect(_on_build_remove)
	hud.chest_deposit.connect(func():
		var n := inventory.deposit_into(chest)
		hud.toast("Stored %d things" % n)
		hud.refresh_chest(chest))
	hud.chest_take.connect(func():
		var n := chest.take_all_into(inventory)
		hud.toast("Took %d things" % n)
		hud.refresh_chest(chest))
	hud.paused.connect(_on_paused)
	hud.quit_to_title.connect(_quit_to_title)
	story.chapter_started.connect(func(ch: Dictionary): hud.show_story(ch.title, ch.text))
	inventory.changed.connect(func():
		hud.refresh_bag(inventory)
		if _build:
			hud.show_palette(inventory, _build_pick, _build_remove))

	# Where you are: a new game starts inside the cabin, by the bed.
	var at_home: bool = data.get("inside", true)
	if at_home:
		_enter_cabin(false)
		player.position = interior.bed_spot()
		if data.has("player"):
			player.position = Vector2(data.player[0], data.player[1])
	else:
		player.position = Vector2(data.player[0], data.player[1])
		_leave_cabin(false)
	world.stream_around(_stream_focus(), true)
	_snap_camera()
	running = true
	story.on_comfort(cabin.comfort())
	if fresh:
		story.begin()
		hud.toast("Welcome to the Eldwood, %s." % look.name)
	else:
		hud.toast("Welcome back, %s. Day %d." % [look.name, day_night.day])


## Jump the camera straight to the player (after going in/out or waking up), without easing.
func _snap_camera() -> void:
	if camera:
		camera.force_update_scroll()
		camera.reset_smoothing()


## Where the world streams around: the player outside, the cabin while you're inside.
func _stream_focus() -> Vector2:
	return exterior.global_position if inside else player.position


func outdoor_spawn() -> Vector2:
	var x := 4
	return Vector2(exterior.door_x() + 6, world.gen.surface_y(x) * tuning.tile_size - Player.H * 0.5 - 1)


# ---- Inside / outside ---------------------------------------------------------------------------

func _enter_cabin(move: bool = true) -> void:
	inside = true
	world.visible = false
	exterior.visible = false
	interior.visible = true
	if background:
		background.inside = true
	if move:
		player.position = interior.door_spot()
		player.velocity = Vector2.ZERO
	_set_camera_limits()
	_snap_camera()


func _leave_cabin(move: bool = true) -> void:
	if _build:
		_toggle_build()
	inside = false
	world.visible = true
	exterior.visible = true
	interior.visible = false
	if background:
		background.inside = false
	if move:
		player.position = outdoor_spawn()
		player.velocity = Vector2.ZERO
		world.stream_around(player.position, true)
	_set_camera_limits()
	_snap_camera()


func _set_camera_limits() -> void:
	var view := get_viewport().get_visible_rect().size
	if inside:
		var r := interior.room_rect()
		var margin := 8.0
		if r.size.x + margin * 2.0 <= view.x:   # small room: keep it centred
			camera.limit_left = int(r.get_center().x - view.x * 0.5)
			camera.limit_right = int(r.get_center().x + view.x * 0.5)
		else:
			camera.limit_left = int(r.position.x - margin)
			camera.limit_right = int(r.end.x + margin)
		camera.limit_bottom = int(r.end.y + tuning.touch_bar_height + 24)
		camera.limit_top = int(r.end.y + tuning.touch_bar_height + 24 - view.y)
	else:
		camera.limit_left = (tuning.world_min_x - 4) * tuning.tile_size
		camera.limit_right = 10000000
		camera.limit_top = -10000000
		camera.limit_bottom = tuning.world_bottom * tuning.tile_size


# ---- Every tick -------------------------------------------------------------------------------

func _physics_process(dt: float) -> void:
	if not running:
		return
	day_night.tick(dt)
	var cell := tuning.to_tile(player.position)
	var depth := 0 if inside else cell.y - world.gen.surface_y(cell.x)
	var underground := not inside and depth >= tuning.underground_depth
	var dark := not inside and (day_night.is_night() or underground)
	# A torch burns while it's dark and you carry one.
	if dark and inventory.count("torch") > 0:
		_torch_burn += dt
		if _torch_burn >= tuning.torch_burn_time:
			_torch_burn = 0.0
			inventory.add("torch", -1)
			_say("torch", "A torch burned out. (%d left)" % inventory.count("torch"))
	survival.tick(dt, {"home": inside, "hearth": cabin.has_function("hearth"),
			"night": day_night.is_night() or underground, "underground": underground})
	if survival.is_dead():
		_collapse()
		return
	if not inside:
		world.stream_around(player.position)
		story.on_position(cell.x, world.gen.biome_at(cell.x))
	if _work_held:
		_work_timer -= dt
		if _work_timer <= 0.0:
			_work_timer = tuning.work_interval
			_tap(_work_pos, false)
	_autosave += dt
	if _autosave >= tuning.autosave_interval:
		_autosave = 0.0
		save()


func _process(_dt: float) -> void:
	if not running:
		return
	var cell := tuning.to_tile(player.position)
	var light := 1.0
	var place := ""
	if inside:
		light = cabin.light(day_night.daylight())
		place = "Your cabin - comfort %d" % cabin.comfort()
	else:
		var depth := cell.y - world.gen.surface_y(cell.x)
		var under := clampf((depth - tuning.underground_depth + 2) / 8.0, 0.0, 1.0)
		light = minf(day_night.light(), lerpf(1.0, tuning.underground_light, under))
		place = "%s, %d paces east" % [WorldGen.BIOME_NAMES[world.gen.biome_at(cell.x)], maxi(cell.x, 0)]
		if depth >= tuning.underground_depth:
			place = "Underground, %d down" % depth
		elif exterior.in_range(player.position):
			place = "Outside your cabin"
	shade.color = Color(light, light * 0.96, light * 0.9)
	player.set_light(1.0 - light, not inside and inventory.count("torch") > 0)
	background.daylight = day_night.daylight()
	background.time = day_night.time
	background.camera_pos = camera.get_screen_center_position()
	hud.update_stats(survival)
	hud.update_info(day_night.clock_text() + ("  Night" if day_night.is_night() else ""), place, story.objective(), inside)


## A message, at most once every 1.5 s per key (so held fingers don't spam).
func _say(key: String, text: String, col: Color = Pal.CREAM) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_msg.get(key, -10.0)) > 1.5:
		_last_msg[key] = now
		hud.toast(text, col)


# ---- Tapping ----------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_work_pos = event.position
			_work_timer = tuning.work_interval
			_work_held = _tap(event.position, true)
		else:
			_work_held = false
	elif event is InputEventMouseMotion:
		if _work_held:
			_work_pos = event.position
		if _build and inside:
			interior.ghost_cell = interior.cell_at(_to_world(event.position))


func _to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


## Handle a tap (or a held finger repeating). Returns true if holding should keep working
## (chopping a tree or digging).
func _tap(screen_pos: Vector2, first: bool) -> bool:
	var p := _to_world(screen_pos)
	if inside:
		if first:
			_tap_inside(p)
		return false
	var reach := tuning.reach_tiles * tuning.tile_size
	var obj := _object_at(p)
	if obj:
		if player.position.distance_to(obj.position + Vector2(0, -6)) > reach + 8.0:
			if first:
				_say("far", "Too far away.")
			return false
		if obj.is_tree():
			_chop(obj)
			return true
		if first:
			_collect(obj)
		return false
	if first and exterior.rect().has_point(p):
		if exterior.in_range(player.position):
			touch.release_all()
			_enter_cabin()
		else:
			_say("far", "Walk to your cabin first.")
		return false
	return _dig(tuning.to_tile(p), first)


## The object under a tap: forage and lore first (they're small), then trees.
func _object_at(p: Vector2) -> WorldObject:
	var tree: WorldObject = null
	for o in world.objects():
		if o.hit_rect().has_point(p):
			if not o.is_tree():
				return o
			tree = o
	return tree


func _chop(o: WorldObject) -> void:
	if not survival.work():
		_say("tired", "Too tired. Rest a moment.", Pal.UI_BAD)
		return
	player.swing()
	var tier := Crafting.tool_tier(inventory, "axe")
	if not o.chop(tuning.axe_damage[tier]):
		return
	var logs: int = {"tree_pine": tuning.logs_pine, "tree_oak": tuning.logs_oak, "tree_birch": tuning.logs_birch}[o.kind]
	inventory.add("log", logs)
	hud.toast("+%d Log" % logs, Pal.TAN)
	# Whether an oak drops an apple is fixed by the seed (same forest, same apples).
	if o.kind == "tree_oak" and HashNoise.hash_f(world_seed, o.cell.x, 7, 777) < tuning.oak_apple_chance:
		inventory.add("apple")
		hud.toast("+1 Apple", Pal.RED)
	world.take(o)
	_work_held = false


func _collect(o: WorldObject) -> void:
	var gains := {"berry_bush": ["berries", tuning.berry_yield], "mushroom": ["mushroom", tuning.mushroom_yield],
			"flax": ["fiber", tuning.flax_yield], "herb": ["herb", tuning.herb_yield], "rock": ["stone", tuning.rock_yield]}
	if gains.has(o.kind):
		var g: Array = gains[o.kind]
		inventory.add(g[0], g[1])
		hud.toast("+%d %s" % [g[1], Catalog.item_name(g[0])])
	elif o.kind == "page" or o.kind == "runestone":
		var entry := story.on_lore(o.kind)
		touch.release_all()
		hud.show_story(entry.title, entry.text)
	world.take(o)


func _dig(cell: Vector2i, first: bool) -> bool:
	var id := world.tile_at(cell)
	if not Tiles.is_solid(id):
		return false
	if player.position.distance_to(tuning.tile_center(cell)) > tuning.reach_tiles * tuning.tile_size:
		if first:
			_say("far", "Too far away.")
		return false
	var tier := Crafting.tool_tier(inventory, "pick")
	var tr := Tiles.tier(id)
	if tr < 0 or tr > tier:
		if first:
			_say("hard", "Too hard. You need a %s." % ("stone pickaxe" if tr == 1 else ("iron pickaxe" if tr == 2 else "miracle")), Pal.UI_BAD)
		return false
	if not survival.work():
		_say("tired", "Too tired. Rest a moment.", Pal.UI_BAD)
		return true
	player.swing()
	var r := world.dig(cell, tier, tuning.pick_damage[tier])
	if r.result == "broken":
		if r.drop != "":
			inventory.add(r.drop)
			hud.toast("+1 %s" % Catalog.item_name(r.drop))
		return false
	return r.result == "hit"


# ---- Inside the cabin ---------------------------------------------------------------------------

func _tap_inside(p: Vector2) -> void:
	var c := interior.cell_at(p)
	if _build:
		_build_tap(c)
		return
	if interior.is_door(c):
		touch.release_all()
		_leave_cabin()
		return
	var idx := cabin.item_at(c.x, c.y)
	if idx < 0:
		return
	var id: String = cabin.placed[idx].id
	match Catalog.FUNCTIONS.get(id, ""):
		"bed":
			_sleep()
		"workbench", "hearth":
			touch.release_all()
			hud.show_craft(inventory, cabin, true)
		"chest":
			touch.release_all()
			hud.show_chest(chest)
		_:
			_say("item", Catalog.item_name(id))


func _toggle_build() -> void:
	if not inside and not _build:
		_say("build", "Build inside your cabin.")
		return
	_build = not _build
	_build_pick = ""
	_build_remove = false
	interior.build_mode = _build
	interior.ghost_id = ""
	if _build:
		hud.show_palette(inventory, "", false)
	else:
		hud.hide_palette()


func _on_build_pick(id: String) -> void:
	_build_pick = "" if _build_pick == id else id
	_build_remove = false
	interior.ghost_id = _build_pick
	hud.show_palette(inventory, _build_pick, false)


func _on_build_remove() -> void:
	_build_remove = not _build_remove
	_build_pick = ""
	interior.ghost_id = ""
	hud.show_palette(inventory, "", _build_remove)


func _build_tap(c: Vector2i) -> void:
	interior.ghost_cell = c
	if _build_remove:
		var idx := cabin.item_at(c.x, c.y)
		if idx >= 0:
			var id := cabin.remove(idx)
			inventory.add(id)
			hud.toast("%s back in your bag" % Catalog.item_name(id))
			_cabin_changed()
		return
	if _build_pick == "":
		return
	var at := interior.placement_for(_build_pick, c)
	var why := cabin.can_place(_build_pick, at.x, at.y)
	if why != "":
		_say("place", why, Pal.UI_BAD)
		return
	cabin.place(_build_pick, at.x, at.y)
	inventory.add(_build_pick, -1)
	story.on_place(_build_pick)
	hud.toast("Placed: %s" % Catalog.item_name(_build_pick), Pal.UI_GOOD)
	if inventory.count(_build_pick) <= 0:
		_build_pick = ""
		interior.ghost_id = ""
	_cabin_changed()


func _cabin_changed() -> void:
	interior.queue_redraw()
	exterior.queue_redraw()
	story.on_comfort(cabin.comfort())
	if _build:
		hud.show_palette(inventory, _build_pick, _build_remove)


func _sleep() -> void:
	if not day_night.can_sleep():
		_say("sleep", "You're not tired yet. Sleep after dusk.")
		return
	var heal := cabin.comfort() * tuning.sleep_heal_per_comfort
	survival.add("health", heal)
	survival.add("stamina", tuning.stamina_max)
	survival.add("warmth", tuning.warmth_max if cabin.has_function("hearth") else tuning.warmth_max * 0.3)
	survival.add("hunger", -tuning.sleep_hunger)
	day_night.sleep()
	touch.release_all()
	hud.show_story("A night's sleep", "You sleep until dawn. Your cabin's comfort (%d) restores %d health.%s" % [
			cabin.comfort(), int(heal), "" if cabin.has_function("hearth") else "\n\nWithout a hearth you wake up chilled."])
	save()


# ---- Crafting and items ---------------------------------------------------------------------------

func _craft(id: String) -> void:
	var old_width := cabin.width()
	if not Crafting.craft(tuning, id, inventory, cabin, inside):
		return
	hud.toast("Made: %s" % Catalog.item_name(id), Pal.UI_GOOD)
	if Catalog.kind(id) == "upgrade":
		interior.rebuild()
		if cabin.width() != old_width:
			_set_camera_limits()
		_cabin_changed()
	story.on_craft(id)
	hud.refresh_craft(inventory, cabin, inside)


func _use_item(id: String) -> void:
	if not inventory.spend({id: 1}):
		return
	if tuning.food_values.has(id):
		survival.add("hunger", tuning.food_values[id])
		hud.toast("Ate: %s" % Catalog.item_name(id), Pal.ORANGE)
	elif tuning.heal_values.has(id):
		survival.add("health", tuning.heal_values[id])
		hud.toast("Used: %s" % Catalog.item_name(id), Pal.RED)


# ---- Events -------------------------------------------------------------------------------------

func _on_hard_landing(speed: float) -> void:
	var dmg := (speed - tuning.fall_safe_speed) * tuning.fall_damage_per_speed
	survival.add("health", -dmg)
	hud.toast("Ouch! -%d health" % dmg, Pal.UI_BAD)


func _on_night_ended() -> void:
	story.on_night_survived()
	hud.toast("Dawn of day %d." % day_night.day, Pal.YELLOW)


## Health hit 0: you collapse and come to in your cabin, missing half your materials.
## (Things in the chest are safe.) Physical consequence, not a scripted death (rule 3).
func _collapse() -> void:
	var lost := inventory.lose_fraction(tuning.death_loss)
	survival.refill_all()
	survival.hunger = tuning.hunger_max * 0.5
	_work_held = false
	if not inside:
		_enter_cabin(false)
	player.position = interior.bed_spot()
	player.velocity = Vector2.ZERO
	_snap_camera()
	var lost_text := ""
	for item in lost:
		lost_text += "\n  %d %s" % [lost[item], Catalog.item_name(item)]
	touch.release_all()
	hud.show_story("You collapse", "The world goes dark. You wake in your own bed with no memory of the walk home, and your pack is lighter.\n\n" +
			("Lost:" + lost_text if lost_text != "" else "You were carrying nothing of value."))
	save()


func _on_paused(on: bool) -> void:
	get_tree().paused = on
	_work_held = false
	if touch:
		touch.release_all()
	if on:
		save()


func _quit_to_title() -> void:
	save()
	get_tree().paused = false
	get_tree().reload_current_scene()


# ---- Saving -------------------------------------------------------------------------------------

func to_save() -> Dictionary:
	return {"version": SaveGame.VERSION, "seed": world_seed, "look": look, "inside": inside,
			"player": [player.position.x, player.position.y],
			"stats": survival.to_dict(), "inventory": inventory.to_dict(), "chest": chest.to_dict(),
			"cabin": cabin.to_dict(), "mined": SaveGame.cells_to_list(world.mined),
			"collected": world.collected.keys(), "story": story.to_dict(),
			"time": day_night.time, "day": day_night.day, "torch_burn": _torch_burn}


func save() -> void:
	if use_save and running:
		SaveGame.write(to_save())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and running and not hud.panel_open():
		hud.show_pause()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()
