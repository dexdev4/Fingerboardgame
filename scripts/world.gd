## The live world: streams generated chunks in and out around the player, applies the player's
## changes (mined cells, collected pickups) on top of the generated terrain, and handles mining.
##
## Chunks are generated on a worker thread (WorldGen.generate_chunk is pure), then written into
## the TileMapLayer on the main thread, so walking east never stutters.
## The world itself is never saved: only `mined` and `collected` are (rule 7).
class_name World
extends Node2D

signal pickup_spawned(p: Pickup)

var t: GameTuning
var gen: WorldGen
var map: TileMapLayer
## Cells the player has dug out: Vector2i → true.
var mined := {}
## Mining progress on cells that aren't broken yet: Vector2i → hits so far.
var damage := {}
## Pickups already taken: id → true.
var collected := {}

var _loaded := {}      # cx → {"pickups": Array[Pickup]}
var _pending := {}     # cx → WorkerThreadPool task id
var _results := {}     # cx → PackedInt32Array (filled by worker threads)
var _mutex := Mutex.new()
var _cracks: Node2D
var _backdrop: Node2D
## Per loaded chunk: the surface row of each column (for the cave back wall).
var _surfaces := {}


func setup(tuning: GameTuning, world_seed: int) -> void:
	t = tuning
	gen = WorldGen.new(world_seed, t)
	# Dark rock "back wall" behind everything underground, so dug shafts and caves show rock
	# instead of the sky. Added first = drawn behind the tiles.
	_backdrop = Node2D.new()
	_backdrop.draw.connect(_draw_backdrop)
	add_child(_backdrop)
	map = TileMapLayer.new()
	map.tile_set = TileSetBuilder.build(t)
	add_child(map)
	_cracks = Node2D.new()
	_cracks.draw.connect(_draw_cracks)
	add_child(_cracks)


## Keep chunks within chunk_radius of `focus` (px) loaded. `wait` = generate synchronously
## (used at start and in tests so the ground exists before the player falls).
func stream_around(focus: Vector2, wait: bool = false) -> void:
	var pc := floori(focus.x / (t.chunk_width * t.tile_size))
	var want := {}
	for cx in range(pc - t.chunk_radius, pc + t.chunk_radius + 1):
		want[cx] = true
		if not _loaded.has(cx):
			_request(cx, wait)
	_collect_finished()
	for cx in _loaded.keys():
		if not want.has(cx):
			_unload(cx)


func _request(cx: int, wait: bool) -> void:
	if wait:
		if _pending.has(cx):
			WorkerThreadPool.wait_for_task_completion(_pending[cx])
			_pending.erase(cx)
		var tiles: PackedInt32Array
		_mutex.lock()
		if _results.has(cx):
			tiles = _results[cx]
			_results.erase(cx)
		_mutex.unlock()
		if tiles.is_empty():
			tiles = gen.generate_chunk(cx)
		_apply(cx, tiles)
		return
	if _pending.has(cx):
		return
	_pending[cx] = WorkerThreadPool.add_task(_generate_task.bind(cx))


## Runs on a worker thread.
func _generate_task(cx: int) -> void:
	var tiles := gen.generate_chunk(cx)
	_mutex.lock()
	_results[cx] = tiles
	_mutex.unlock()


func _collect_finished() -> void:
	for cx in _pending.keys():
		if WorkerThreadPool.is_task_completed(_pending[cx]):
			WorkerThreadPool.wait_for_task_completion(_pending[cx])
			_pending.erase(cx)
			_mutex.lock()
			var tiles: PackedInt32Array = _results.get(cx, PackedInt32Array())
			_results.erase(cx)
			_mutex.unlock()
			if not _loaded.has(cx) and not tiles.is_empty():
				_apply(cx, tiles)


## Write a generated chunk into the tile map (minus mined cells) and spawn its pickups.
func _apply(cx: int, tiles: PackedInt32Array) -> void:
	var w := t.chunk_width
	var x0 := cx * w
	for i in tiles.size():
		var id := tiles[i]
		if id == Tiles.AIR:
			continue
		var cell := Vector2i(x0 + i % w, t.world_top + i / w)
		if not mined.has(cell):
			map.set_cell(cell, 0, Vector2i(id, 0))
	var pickups: Array[Pickup] = []
	for data in gen.pickups_in_chunk(cx):
		if collected.has(data.id):
			continue
		var p := Pickup.new()
		p.setup(data, t)
		add_child(p)
		pickups.append(p)
		pickup_spawned.emit(p)
	_loaded[cx] = {"pickups": pickups}
	var tops := PackedInt32Array()
	for i in w:
		var x := x0 + i
		tops.append(gen.surface_y(x) if x >= t.world_min_x else t.world_top + 7)
	_surfaces[cx] = tops
	_backdrop.queue_redraw()


func _unload(cx: int) -> void:
	var w := t.chunk_width
	for x in range(cx * w, (cx + 1) * w):
		for y in range(t.world_top, t.world_bottom):
			map.erase_cell(Vector2i(x, y))
	for p: Pickup in _loaded[cx].pickups:
		if is_instance_valid(p):
			p.queue_free()
	_loaded.erase(cx)
	_surfaces.erase(cx)
	_backdrop.queue_redraw()


func is_loaded(cx: int) -> bool:
	return _loaded.has(cx)


## Current tile at a cell (generated terrain minus what the player mined).
func tile_at(cell: Vector2i) -> int:
	if mined.has(cell):
		return Tiles.AIR
	return gen.tile_at(cell.x, cell.y)


## Hit a cell once with the mining tool. Returns "" if nothing broke, "broken" for a tile with no
## drop, otherwise the dropped item name ("metal", "ice", ...). Unbreakable tiles return "".
func hit(cell: Vector2i) -> String:
	var id := tile_at(cell)
	var need := Tiles.hits(id, t)
	if need <= 0:
		return ""
	var done: int = damage.get(cell, 0) + 1
	if done < need:
		damage[cell] = done
		_cracks.queue_redraw()
		return ""
	damage.erase(cell)
	mined[cell] = true
	map.erase_cell(cell)
	_cracks.queue_redraw()
	var d := Tiles.drop(id)
	return d if d != "" else "broken"


## Mark a pickup as taken and remove it from the world.
func take(p: Pickup) -> void:
	collected[p.id] = true
	for cx in _loaded:
		_loaded[cx].pickups.erase(p)
	p.queue_free()


## The cave back wall: a dark strip per column, from one tile under the surface down to the
## world floor (visual only).
func _draw_backdrop() -> void:
	var s := float(t.tile_size)
	var bottom := t.world_bottom * s
	for cx: int in _surfaces:
		var tops: PackedInt32Array = _surfaces[cx]
		var x0 := cx * t.chunk_width
		for i in tops.size():
			var y := (tops[i] + 1) * s
			_backdrop.draw_rect(Rect2((x0 + i) * s, y, s, bottom - y), Color("1d1622"))


## Cracks over half-mined cells (visual only).
func _draw_cracks() -> void:
	var s := float(t.tile_size)
	for cell: Vector2i in damage:
		var need := Tiles.hits(tile_at(cell), t)
		var f := float(damage[cell]) / maxf(need, 1)
		var o := Vector2(cell) * s
		var c := Color(0, 0, 0, 0.35 + 0.4 * f)
		_cracks.draw_line(o + Vector2(s * 0.5, 2), o + Vector2(s * 0.35, s * 0.55), c, 2.0)
		_cracks.draw_line(o + Vector2(s * 0.35, s * 0.55), o + Vector2(s * 0.6, s - 2), c, 2.0)
		if f >= 0.5:
			_cracks.draw_line(o + Vector2(2, s * 0.4), o + Vector2(s * 0.35, s * 0.55), c, 2.0)
			_cracks.draw_line(o + Vector2(s * 0.35, s * 0.55), o + Vector2(s - 2, s * 0.3), c, 2.0)


func _exit_tree() -> void:
	for cx in _pending:   # never leave worker tasks running against a freed node
		WorkerThreadPool.wait_for_task_completion(_pending[cx])
	_pending.clear()
