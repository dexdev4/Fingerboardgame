## Builds the TileSet in code: an 8×8 pixel-art texture per tile type (Tiles ids are atlas
## columns) and a full-square collision polygon for each. Drawn from the palette with a fixed hash.
class_name TileSetBuilder
extends RefCounted


static func build(t: GameTuning) -> TileSet:
	var size := t.tile_size
	var ts := TileSet.new()
	ts.tile_size = Vector2i(size, size)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(atlas(size))
	src.texture_region_size = Vector2i(size, size)
	ts.add_source(src, 0)
	var h := size * 0.5
	var square := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	for id in Tiles.COUNT:
		src.create_tile(Vector2i(id, 0))
		var data := src.get_tile_data(Vector2i(id, 0), 0)
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, square)
	return ts


static func atlas(size: int) -> Image:
	var img := Image.create(size * Tiles.COUNT, size, false, Image.FORMAT_RGBA8)
	for id in Tiles.COUNT:
		_paint(img, id, id * size, size)
	return img


## One tile: a base colour with a darker/lighter speckle (2-tone dither), plus details.
static func _paint(img: Image, id: int, ox: int, n: int) -> void:
	var base: Color
	var dark: Color
	var light: Color
	match id:
		Tiles.GRASS, Tiles.FOREST_FLOOR, Tiles.DIRT:
			base = Pal.BARK; dark = Pal.BARK_DARK; light = Pal.WOOD
		Tiles.CLAY:
			base = Color("a8603a"); dark = Pal.BARK; light = Pal.ORANGE
		Tiles.MOSSY_ROCK, Tiles.STONE, Tiles.COAL, Tiles.IRON_ORE, Tiles.GOLD:
			base = Pal.STONE; dark = Pal.STONE_DARK; light = Pal.STONE_LIGHT
		Tiles.DEEP_STONE:
			base = Pal.STONE_DARK; dark = Color("26262b"); light = Pal.STONE
		Tiles.BEDROCK:
			base = Color("1f1d22"); dark = Pal.INK; light = Pal.STONE_DARK
		Tiles.RUIN:
			base = Pal.STONE_LIGHT; dark = Pal.STONE; light = Pal.WHITE
	for y in n:
		for x in n:
			var r := HashNoise.hash_f(5, x, y, id)
			var c := base
			if r < 0.18:
				c = dark
			elif r > 0.9:
				c = light
			img.set_pixel(ox + x, y, c)
	match id:
		Tiles.GRASS, Tiles.FOREST_FLOOR:
			var top := Pal.LEAF_LIGHT if id == Tiles.GRASS else Pal.LEAF
			var tip := Pal.LIME if id == Tiles.GRASS else Pal.LEAF_LIGHT
			for x in n:
				img.set_pixel(ox + x, 0, top)
				img.set_pixel(ox + x, 1, top if HashNoise.hash_f(6, x, 0, id) < 0.7 else base)
				if HashNoise.hash_f(6, x, 1, id) < 0.35:
					img.set_pixel(ox + x, 0, tip)
				if id == Tiles.FOREST_FLOOR and HashNoise.hash_f(6, x, 2, id) < 0.2:
					img.set_pixel(ox + x, 2, Pal.ORANGE)      # fallen needles
		Tiles.MOSSY_ROCK:
			for x in n:
				if HashNoise.hash_f(7, x, 0, id) < 0.6:
					img.set_pixel(ox + x, 0, Pal.LEAF)
		Tiles.COAL:
			_flecks(img, ox, n, Pal.INK, 9, 4)
		Tiles.IRON_ORE:
			_flecks(img, ox, n, Pal.ORANGE, 10, 3)
		Tiles.GOLD:
			_flecks(img, ox, n, Pal.YELLOW, 11, 3)
		Tiles.RUIN:
			for x in n:   # mortar lines: a brick pattern
				img.set_pixel(ox + x, 3, Pal.STONE)
				img.set_pixel(ox + x, 7, Pal.STONE)
			for y in range(0, 3):
				img.set_pixel(ox + 2, y, Pal.STONE)
			for y in range(4, 7):
				img.set_pixel(ox + 6, y, Pal.STONE)
	# Slight edge shading so the tile grid reads.
	for i in n:
		var c := img.get_pixel(ox + i, n - 1)
		img.set_pixel(ox + i, n - 1, c.darkened(0.15))


static func _flecks(img: Image, ox: int, n: int, col: Color, salt: int, count: int) -> void:
	for i in count:
		var x := 1 + int(HashNoise.hash_f(salt, i, 0, 3) * (n - 3))
		var y := 1 + int(HashNoise.hash_f(salt, i, 1, 3) * (n - 3))
		img.set_pixel(ox + x, y, col)
		img.set_pixel(ox + x + 1, y, col)
		img.set_pixel(ox + x, y + 1, col.darkened(0.2))
