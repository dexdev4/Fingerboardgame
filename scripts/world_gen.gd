## Generates the world of Tessaris from a seed: biomes, surface, caves, ore veins, ruins and
## surface pickups. Every function is PURE — it depends only on the seed, the tuning values copied
## at creation, and its arguments — so:
##   * the same seed always gives the same world (rule 1), and
##   * a chunk generated on its own equals that chunk generated after its neighbours,
##   * generate_chunk() is safe to run on a worker thread (it touches no nodes/resources).
class_name WorldGen
extends RefCounted

enum Biome { PLAINS, CRYSTAL, FUNGAL, RUINS }
const BIOME_NAMES := ["Crash Plains", "Crystal Fields", "Fungal Lowlands", "Ruins Expanse"]

# Noise channels (salts) so independent features don't correlate.
const S_HILLS := 11
const S_BUMPS := 23
const S_BIOME := 37
const S_CAVE := 41
const S_ORE := 53
const S_ICE := 67
const S_CRYSTAL := 71
const S_ALLOY := 83
const S_PILLAR := 97
const S_PICKUP := 109
const S_PICKUP_KIND := 113
const S_LOG := 127
const S_MONO := 131

## Biome terrain shape: [height offset (tiles, + = lower ground), hill amplitude factor].
const BIOME_SHAPE := [[0.0, 1.0], [-4.0, 1.5], [5.0, 0.7], [0.0, 0.5]]
## Half-width of the smooth terrain blend across a biome border (tiles).
const BLEND := 10.0

var seed: int
# Tuning values copied once (plain variables: safe to read from worker threads).
var chunk_width: int
var top: int
var bottom: int
var min_x: int
var base: int
var hill_amp: float
var hill_scale: float
var bump_scale: float
var bump_amp: float
var flat_r: int
var topsoil: int
var deep_depth: int
var cave_thr: float
var cave_scale: float
var cave_min: int
var ore_thr: float
var ice_thr: float
var crystal_thr: float
var alloy_thr: float
var vein_scale: float
var borders: Array[float]          # first three biome borders (tiles)
var cycle: float
var jitter: float
var chances: Array[float]           # bladder, glowcap, wreck base chances
var log_spacing: int
var mono_spacing: int


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
	flat_r = t.crash_flat_radius
	topsoil = t.topsoil_depth
	deep_depth = t.deep_rock_depth
	cave_thr = t.cave_threshold
	cave_scale = t.cave_scale
	cave_min = t.cave_min_depth
	ore_thr = t.ore_threshold
	ice_thr = t.ice_threshold
	crystal_thr = t.crystal_threshold
	alloy_thr = t.alloy_threshold
	vein_scale = t.vein_scale
	borders = [float(t.biome_crystal_start), float(t.biome_fungal_start), float(t.biome_ruins_start)]
	cycle = float(t.biome_cycle_length)
	jitter = t.biome_jitter
	chances = [t.bladder_chance, t.glowcap_chance, t.wreck_chance]
	log_spacing = t.crew_log_spacing
	mono_spacing = t.monolith_spacing


# ---- Biomes ----------------------------------------------------------------------------

## "Biome position": distance east, wobbled by noise so borders aren't straight lines.
func _bpos(x: int) -> float:
	return x + (HashNoise.value1(seed, S_BIOME, x / 40.0) - 0.5) * 2.0 * jitter


## Start of biome segment k (in bpos units). Segments 0–3: plains, crystal, fungal, ruins;
## after that they repeat every `cycle` tiles.
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


## Biome of segment k. After the ruins the order cycles crystal → fungal → ruins → plains → …
func _segment_biome(k: int) -> int:
	if k <= 3:
		return k
	return [Biome.CRYSTAL, Biome.FUNGAL, Biome.RUINS, Biome.PLAINS][(k - 4) % 4]


func biome_at(x: int) -> int:
	return _segment_biome(_segment(_bpos(x)))


## Terrain shape [offset, amplitude] at x, blended smoothly across biome borders.
func _shape(x: int) -> Vector2:
	var bp := _bpos(x)
	var k := _segment(bp)
	var here := Vector2(BIOME_SHAPE[_segment_biome(k)][0], BIOME_SHAPE[_segment_biome(k)][1])
	var d_start := bp - _border(k)
	var d_end := _border(k + 1) - bp
	if d_start < BLEND and k > 0:
		var prev := Vector2(BIOME_SHAPE[_segment_biome(k - 1)][0], BIOME_SHAPE[_segment_biome(k - 1)][1])
		return prev.lerp(here, smoothstep(-BLEND, BLEND, d_start))
	if d_end < BLEND:
		var next := Vector2(BIOME_SHAPE[_segment_biome(k + 1)][0], BIOME_SHAPE[_segment_biome(k + 1)][1])
		return here.lerp(next, smoothstep(BLEND, -BLEND, d_end))
	return here


# ---- Terrain ---------------------------------------------------------------------------

## Row of the first solid tile in column x (y grows down).
func surface_y(x: int) -> int:
	var shape := _shape(x)
	var hills := (HashNoise.fbm1(seed, S_HILLS, x / hill_scale, 3) * 2.0 - 1.0) * hill_amp * shape.y
	var bumps := (HashNoise.value1(seed, S_BUMPS, x / bump_scale) * 2.0 - 1.0) * bump_amp
	var y := base + shape.x + hills + bumps
	# The crash site is flat (the ship landed there), blending back into the hills.
	var f := smoothstep(float(flat_r), float(flat_r + 10), absf(x))
	return roundi(lerpf(base, y, f))


## Ruin pillar height at x (0 = no pillar). Pillars stand on the surface in ruins biomes.
func pillar_height(x: int) -> int:
	if biome_at(x) != Biome.RUINS:
		return 0
	# Pillars come in small groups: a group every ~9 columns, 1–2 columns wide.
	var g := floori(x / 9.0)
	if HashNoise.hash_f(seed, g, 0, S_PILLAR) > 0.55:
		return 0
	var start := g * 9 + int(HashNoise.hash_f(seed, g, 1, S_PILLAR) * 6.0)
	var width := 1 + int(HashNoise.hash_f(seed, g, 2, S_PILLAR) * 2.0)
	if x < start or x >= start + width:
		return 0
	return 2 + int(HashNoise.hash_f(seed, g, 3, S_PILLAR) * 5.0)


## Tile at (x, y). `s` = surface_y(x) and `b` = biome_at(x) can be passed in when the caller
## already has them (generate_chunk does), to avoid recomputing per row.
func tile_at(x: int, y: int, s: int = 0x7FFFFFFF, b: int = -1) -> int:
	if y >= bottom - 2:
		return Tiles.BEDROCK
	if x < min_x:
		return Tiles.BEDROCK if y > top + 6 else Tiles.AIR    # crater wall behind the crash
	if s == 0x7FFFFFFF:
		s = surface_y(x)
	if b < 0:
		b = biome_at(x)
	if y < s:
		var ph := pillar_height(x)
		return Tiles.RUIN if ph > 0 and y >= s - ph else Tiles.AIR
	var depth := y - s
	# Caves: blobs of 2D noise, fading in below cave_min so the surface stays solid.
	if depth >= cave_min:
		var fade := clampf((depth - cave_min) / 6.0, 0.0, 1.0)
		var c := HashNoise.fbm2(seed, S_CAVE, x / cave_scale, y / (cave_scale * 0.7), 2)
		if c > lerpf(1.0, cave_thr, fade):
			return Tiles.AIR
	if depth < topsoil:
		return [Tiles.REGOLITH, Tiles.SAND, Tiles.SOIL, Tiles.DUST][b]
	# Ore veins inside the rock.
	var vx := x / vein_scale
	var vy := y / vein_scale
	if b == Biome.RUINS and depth > 2 or depth > 40:
		if HashNoise.value2(seed, S_ALLOY, vx, vy) > alloy_thr:
			return Tiles.ALLOY
	if b == Biome.CRYSTAL or depth > 25:
		if HashNoise.value2(seed, S_CRYSTAL, vx, vy) > crystal_thr - (0.04 if b == Biome.CRYSTAL else 0.0):
			return Tiles.CRYSTAL
	if depth < 28 and HashNoise.value2(seed, S_ICE, vx, vy) > ice_thr + (0.04 if b == Biome.FUNGAL else 0.0):
		return Tiles.ICE
	if HashNoise.value2(seed, S_ORE, vx, vy) > ore_thr - clampf(depth / 200.0, 0.0, 0.1):
		return Tiles.ORE
	return Tiles.DEEP_ROCK if depth > deep_depth else Tiles.ROCK


## All tiles of chunk cx as a flat array: index = (y − top) * chunk_width + (x − x0).
## Pure: safe on a worker thread.
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
		var y_from := top
		if x >= min_x:
			y_from = maxi(top, s - 8)   # nothing above a ruin pillar's top: skip the sky fast
		for y in range(y_from, bottom):
			out[(y - top) * chunk_width + i] = tile_at(x, y, s, b)
	return out


# ---- Surface pickups ---------------------------------------------------------------------

## Pickups in chunk cx: [{id, kind, cell: Vector2i}]. Kinds: "bladder" (oxygen plant),
## "glowcap" (food fungus), "wreck" (ship debris: metal / power cell), "crew_log", "monolith".
## The id ("kind@x") is stable, so collected pickups can be remembered in a save.
func pickups_in_chunk(cx: int) -> Array:
	var out: Array = []
	var taken := {}      # columns already used
	var x0 := cx * chunk_width
	var x1 := x0 + chunk_width
	# Crew-log pods: one every log_spacing tiles east of the ship, jittered.
	for k in range(maxi(1, floori(float(x0) / log_spacing) - 1), floori(float(x1) / log_spacing) + 2):
		var lx := k * log_spacing + int((HashNoise.hash_f(seed, k, 0, S_LOG) - 0.5) * log_spacing * 0.4)
		if lx >= x0 and lx < x1:
			out.append(_pickup("crew_log", lx))
			taken[lx] = true
	# Monoliths: one every mono_spacing tiles, only where the column is in a ruins biome.
	for k in range(floori(float(x0) / mono_spacing) - 1, floori(float(x1) / mono_spacing) + 2):
		var mx := k * mono_spacing + int((HashNoise.hash_f(seed, k, 0, S_MONO) - 0.5) * mono_spacing * 0.5)
		if mx >= x0 and mx < x1 and mx > flat_r and biome_at(mx) == Biome.RUINS and pillar_height(mx) == 0:
			out.append(_pickup("monolith", mx))
			taken[mx] = true
	# Plants and debris.
	for x in range(x0, x1):
		if taken.has(x) or x < min_x + 2 or absf(x) < 3 or pillar_height(x) > 0:
			continue
		var c := _pickup_chances(x)
		var r := HashNoise.hash_f(seed, x, 0, S_PICKUP)
		if r < c[0]:
			out.append(_pickup("bladder", x))
		elif r < c[0] + c[1]:
			out.append(_pickup("glowcap", x))
		elif r < c[0] + c[1] + c[2]:
			out.append(_pickup("wreck", x))
	return out


func _pickup(kind: String, x: int) -> Dictionary:
	return {"id": "%s@%d" % [kind, x], "kind": kind, "cell": Vector2i(x, surface_y(x) - 1)}


## Chance per column of [bladder, glowcap, wreck], by biome. Debris is thick near the crash.
func _pickup_chances(x: int) -> Array:
	var b := biome_at(x)
	var scale: Array = [[1.0, 0.3, 0.4], [0.6, 0.3, 0.3], [1.2, 2.5, 0.2], [0.7, 0.8, 0.5]][b]
	var wreck_boost := 3.0 if absf(x) < 60 else 1.0
	return [chances[0] * scale[0], chances[1] * scale[1], chances[2] * scale[2] * wreck_boost]
