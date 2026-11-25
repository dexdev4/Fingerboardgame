## Generates the Eldwood from a seed: biomes, terrain, caves, ore veins, old stonework, trees,
## forage and lore placement. Every function is PURE (seed + copied tuning + arguments), so:
##   * the same seed always gives the same forest (rule 1),
##   * a chunk generated alone equals that chunk generated in sequence,
##   * generate_chunk() is safe on a worker thread.
class_name WorldGen
extends RefCounted

enum Biome { MEADOW, PINEWOOD, ELDERWOOD, STONECRAG }
const BIOME_NAMES := ["The Meadow", "Pinewood", "Elderwood", "Stonecrag"]

const S_HILLS := 11
const S_BUMPS := 23
const S_BIOME := 37
const S_CAVE := 41
const S_CLAY := 53
const S_COAL := 67
const S_IRON := 71
const S_GOLD := 83
const S_RUIN := 97
const S_FORAGE := 109
const S_TREE := 113
const S_PAGE := 127
const S_RUNE := 131

## Terrain shape per biome: [height offset (tiles, + = lower), hill amplitude factor].
const BIOME_SHAPE := [[0.0, 0.6], [0.0, 1.0], [2.0, 0.8], [-6.0, 1.7]]
const BLEND := 10.0
## Tree kinds by biome: [pine, oak, birch] weights.
const TREE_MIX := [[0.2, 0.2, 0.6], [0.85, 0.05, 0.1], [0.1, 0.8, 0.1], [0.6, 0.1, 0.3]]
## Forage scale by biome: [berries, mushrooms, flax, herbs, rocks].
const FORAGE_MIX := [[1.5, 0.2, 2.0, 0.6, 1.4], [0.8, 1.2, 0.3, 0.6, 0.6], [0.6, 2.0, 0.2, 1.8, 0.5], [0.3, 0.4, 0.1, 0.8, 2.5]]
const FORAGE_KINDS := ["berry_bush", "mushroom", "flax", "herb", "rock"]

var seed: int
var chunk_width: int
var top: int
var bottom: int
var min_x: int
var base: int
var hill_amp: float
var hill_scale: float
var bump_scale: float
var bump_amp: float
var clear_r: int
var topsoil: int
var deep_depth: int
var cave_thr: float
var cave_scale: float
var cave_min: int
var clay_thr: float
var coal_thr: float
var iron_thr: float
var gold_thr: float
var vein_scale: float
var borders: Array[float]
var cycle: float
var jitter: float
var tree_slot: int
var tree_density: Array[float]
var forage_chances: Array[float]
var page_spacing: int
var rune_spacing: int


func _init(world_seed: int, t: GameTuning) -> void:
	seed = world_seed
	chunk_width = t.chunk_width
	top = t.world_top
	bottom = t.world_bottom
	min_x = t.world_min_x
	base = t.surface_base
	hill_amp = t.hill_amplitude
	hill_scale = t.hill_scale
	bump_scale = t.bump_scale
	bump_amp = t.bump_amplitude
	clear_r = t.clearing_radius
	topsoil = t.topsoil_depth
	deep_depth = t.deep_stone_depth
	cave_thr = t.cave_threshold
	cave_scale = t.cave_scale
	cave_min = t.cave_min_depth
	clay_thr = t.clay_threshold
	coal_thr = t.coal_threshold
	iron_thr = t.iron_threshold
	gold_thr = t.gold_threshold
	vein_scale = t.vein_scale
	borders = [float(t.biome_pinewood_start), float(t.biome_elderwood_start), float(t.biome_stonecrag_start)]
	cycle = float(t.biome_cycle_length)
	jitter = t.biome_jitter
	tree_slot = t.tree_slot
	tree_density = t.tree_density.duplicate()
	forage_chances = [t.berry_chance, t.mushroom_chance, t.flax_chance, t.herb_chance, t.rock_chance]
	page_spacing = t.page_spacing
	rune_spacing = t.runestone_spacing


# ---- Biomes ----------------------------------------------------------------------------

func _bpos(x: int) -> float:
	return x + (HashNoise.value1(seed, S_BIOME, x / 40.0) - 0.5) * 2.0 * jitter


func _border(k: int) -> float:
	if k <= 0:
		return -INF
	if k <= 3:
		return borders[k - 1]
	return borders[2] + (k - 3) * cycle


func _segment(bp: float) -> int:
	if bp < borders[0]:
		return 0
	if bp < borders[1]:
		return 1
	if bp < borders[2]:
		return 2
	return 3 + floori((bp - borders[2]) / cycle)


## After the Stonecrag the biomes repeat: Pinewood → Elderwood → Stonecrag → Meadow → …
func _segment_biome(k: int) -> int:
	if k <= 3:
		return k
	return [Biome.PINEWOOD, Biome.ELDERWOOD, Biome.STONECRAG, Biome.MEADOW][(k - 4) % 4]


func biome_at(x: int) -> int:
	if x < 0:
		return Biome.MEADOW      # west of the cabin: meadow up to the old cliff
	return _segment_biome(_segment(_bpos(x)))


func _shape_of(k: int) -> Vector2:
	var s: Array = BIOME_SHAPE[_segment_biome(k)]
	return Vector2(s[0], s[1])


func _shape(x: int) -> Vector2:
	if x < 0:
		return _shape_of(0)
	var bp := _bpos(x)
	var k := _segment(bp)
	var here := _shape_of(k)
	var d_start := bp - _border(k)
	var d_end := _border(k + 1) - bp
	if d_start < BLEND and k > 0:
		return _shape_of(k - 1).lerp(here, smoothstep(-BLEND, BLEND, d_start))
	if d_end < BLEND:
		return here.lerp(_shape_of(k + 1), smoothstep(BLEND, -BLEND, d_end))
	return here


# ---- Terrain ---------------------------------------------------------------------------

func surface_y(x: int) -> int:
	var shape := _shape(x)
	var hills := (HashNoise.fbm1(seed, S_HILLS, x / hill_scale, 3) * 2.0 - 1.0) * hill_amp * shape.y
	var bumps := (HashNoise.value1(seed, S_BUMPS, x / bump_scale) * 2.0 - 1.0) * bump_amp
	var y := base + shape.x + hills + bumps
	# The cabin's clearing is flat, blending back into the land.
	var f := smoothstep(float(clear_r), float(clear_r + 10), absf(x))
	return roundi(lerpf(base, y, f))


## Height of an old stone wall fragment at x (0 = none). They stand in the Stonecrag.
func ruin_height(x: int) -> int:
	if biome_at(x) != Biome.STONECRAG:
		return 0
	var g := floori(x / 12.0)
	if HashNoise.hash_f(seed, g, 0, S_RUIN) > 0.45:
		return 0
	var start := g * 12 + int(HashNoise.hash_f(seed, g, 1, S_RUIN) * 6.0)
	var width := 2 + int(HashNoise.hash_f(seed, g, 2, S_RUIN) * 3.0)
	if x < start or x >= start + width:
		return 0
	return 1 + int(HashNoise.hash_f(seed, g, 3, S_RUIN) * 4.0) - (1 if x == start or x == start + width - 1 else 0)


func tile_at(x: int, y: int, s: int = 0x7FFFFFFF, b: int = -1) -> int:
	if y >= bottom - 2:
		return Tiles.BEDROCK
	if x < min_x:
		return Tiles.BEDROCK if y > top + 10 else Tiles.AIR    # the old cliff to the west
	if s == 0x7FFFFFFF:
		s = surface_y(x)
	if b < 0:
		b = biome_at(x)
	if y < s:
		var rh := ruin_height(x)
		return Tiles.RUIN if rh > 0 and y >= s - rh else Tiles.AIR
	var depth := y - s
	if depth >= cave_min:
		var fade := clampf((depth - cave_min) / 6.0, 0.0, 1.0)
		if HashNoise.fbm2(seed, S_CAVE, x / cave_scale, y / (cave_scale * 0.7), 2) > lerpf(1.0, cave_thr, fade):
			return Tiles.AIR
	var soil := 1 if b == Biome.STONECRAG else topsoil
	if depth == 0:
		return [Tiles.GRASS, Tiles.FOREST_FLOOR, Tiles.FOREST_FLOOR, Tiles.MOSSY_ROCK][b]
	var vx := x / vein_scale
	var vy := y / vein_scale
	if depth < soil:
		# Clay pockets in the soil (most in the meadow, by the old riverbed).
		if HashNoise.value2(seed, S_CLAY, vx, vy) > clay_thr - (0.06 if b == Biome.MEADOW else 0.0):
			return Tiles.CLAY
		return Tiles.DIRT
	if depth > 30 and HashNoise.value2(seed, S_GOLD, vx, vy) > gold_thr:
		return Tiles.GOLD
	if HashNoise.value2(seed, S_IRON, vx, vy) > iron_thr - (0.05 if b == Biome.STONECRAG else 0.0) - clampf(depth / 300.0, 0.0, 0.05):
		return Tiles.IRON_ORE
	if HashNoise.value2(seed, S_COAL, vx, vy) > coal_thr - (0.04 if b == Biome.STONECRAG else 0.0):
		return Tiles.COAL
	return Tiles.DEEP_STONE if depth > deep_depth else Tiles.STONE


## All tiles of chunk cx: index = (y − top) * chunk_width + (x − x0). Pure: thread-safe.
func generate_chunk(cx: int) -> PackedInt32Array:
	var rows := bottom - top
	var out := PackedInt32Array()
	out.resize(rows * chunk_width)
	out.fill(Tiles.AIR)
	var x0 := cx * chunk_width
	for i in chunk_width:
		var x := x0 + i
		var s := surface_y(x)
		var b := biome_at(x)
		var y_from := top if x < min_x else maxi(top, s - 6)
		for y in range(y_from, bottom):
			out[(y - top) * chunk_width + i] = tile_at(x, y, s, b)
	return out


# ---- Objects on the surface: trees, forage, lore -------------------------------------------

## Objects in chunk cx: [{id, kind, cell: Vector2i, variant}]. Kinds: "tree_pine", "tree_oak",
## "tree_birch", forage ("berry_bush", "mushroom", "flax", "herb", "rock"), "page" (the hermit's
## journal), "runestone". The id ("kind@x") is stable, so felled/collected objects can be saved.
func objects_in_chunk(cx: int) -> Array:
	var out: Array = []
	var taken := {}
	var x0 := cx * chunk_width
	var x1 := x0 + chunk_width
	# Journal pages: one every page_spacing tiles east of the cabin.
	for k in range(maxi(1, floori(float(x0) / page_spacing) - 1), floori(float(x1) / page_spacing) + 2):
		var px := k * page_spacing + int((HashNoise.hash_f(seed, k, 0, S_PAGE) - 0.5) * page_spacing * 0.4)
		if px >= x0 and px < x1 and ruin_height(px) == 0:
			out.append(_obj("page", px))
			taken[px] = true
	# Runestones: in the Stonecrag only.
	for k in range(floori(float(x0) / rune_spacing) - 1, floori(float(x1) / rune_spacing) + 2):
		var rx := k * rune_spacing + int((HashNoise.hash_f(seed, k, 0, S_RUNE) - 0.5) * rune_spacing * 0.5)
		if rx >= x0 and rx < x1 and rx > clear_r and biome_at(rx) == Biome.STONECRAG and ruin_height(rx) == 0 and not taken.has(rx):
			out.append(_obj("runestone", rx))
			taken[rx] = true
	# Trees: one candidate per slot of tree_slot columns.
	for slot in range(floori(float(x0) / tree_slot), floori(float(x1 - 1) / tree_slot) + 1):
		var tx := slot * tree_slot + int(HashNoise.hash_f(seed, slot, 1, S_TREE) * tree_slot)
		if tx < x0 or tx >= x1 or tx < min_x + 2 or absi(tx) < clear_r - 2 or taken.has(tx) or ruin_height(tx) > 0:
			continue
		var b := biome_at(tx)
		if HashNoise.hash_f(seed, slot, 0, S_TREE) >= tree_density[b]:
			continue
		var mix: Array = TREE_MIX[b]
		var r := HashNoise.hash_f(seed, slot, 2, S_TREE)
		var kind := "tree_pine" if r < mix[0] else ("tree_oak" if r < mix[0] + mix[1] else "tree_birch")
		var o := _obj(kind, tx)
		o.variant = int(HashNoise.hash_f(seed, slot, 3, S_TREE) * 4.0)
		out.append(o)
		taken[tx] = true
	# Forage on the remaining columns.
	for x in range(x0, x1):
		if taken.has(x) or x < min_x + 2 or absi(x) < 3 or ruin_height(x) > 0:
			continue
		var b := biome_at(x)
		var r := HashNoise.hash_f(seed, x, 0, S_FORAGE)
		var acc := 0.0
		for i in FORAGE_KINDS.size():
			acc += forage_chances[i] * FORAGE_MIX[b][i]
			if r < acc:
				out.append(_obj(FORAGE_KINDS[i], x))
				break
	return out


func _obj(kind: String, x: int) -> Dictionary:
	return {"id": "%s@%d" % [kind, x], "kind": kind, "cell": Vector2i(x, surface_y(x) - 1), "variant": 0}
