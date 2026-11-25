## Builds the TileSet in code: one atlas image with a textured square per tile type (Tiles ids
## are atlas columns), plus a full-square collision polygon for every tile.
## The textures are drawn from a fixed hash, so they look the same every run.
class_name TileSetBuilder
extends RefCounted


static func build(t: GameTuning) -> TileSet:
	var size := t.tile_size
	var ts := TileSet.new()
	ts.tile_size = Vector2i(size, size)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(_atlas(size))
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


## The atlas: Tiles.COUNT squares side by side.
static func _atlas(size: int) -> Image:
	var img := Image.create(size * Tiles.COUNT, size, false, Image.FORMAT_RGBA8)
	for id in Tiles.COUNT:
		_paint_tile(img, id, size)
	return img


static func _paint_tile(img: Image, id: int, size: int) -> void:
	var base: Color = Tiles.COLORS[id]
	var accent: Color = Tiles.ACCENTS[id]
	var ox := id * size
	for y in size:
		for x in size:
			# Grainy base: each pixel slightly lighter/darker (fixed hash, salt = tile id).
			var n := HashNoise.hash_f(7, x, y, id) - 0.5
			var c := base.lightened(n * 0.12) if n > 0.0 else base.darkened(-n * 0.12)
			# Soft bevel: lighter top-left edge, darker bottom-right edge.
			if x == 0 or y == 0:
				c = c.lightened(0.08)
			elif x == size - 1 or y == size - 1:
				c = c.darkened(0.18)
			img.set_pixel(ox + x, y, c)
	match id:
		Tiles.ORE, Tiles.CRYSTAL:
			_spots(img, ox, size, accent, id, 7 if id == Tiles.ORE else 5, id == Tiles.CRYSTAL)
		Tiles.ICE:
			for i in 3:   # frosty diagonal streaks
				var y0 := 6 + i * 9
				for x in size:
					var y := y0 + x / 4
					if y < size - 1:
						img.set_pixel(ox + x, y, accent)
		Tiles.ALLOY:
			for x in range(4, size - 4):   # glowing circuit lines
				img.set_pixel(ox + x, size / 2, accent)
			for y in range(6, size / 2):
				img.set_pixel(ox + 8, y, accent)
				img.set_pixel(ox + size - 9, size - y, accent)
		Tiles.RUIN:
			for i in range(8, size - 8):   # carved glyph: a ring with a bar
				var a := float(i - 8) / (size - 16) * TAU
				img.set_pixel(ox + size / 2 + int(cos(a) * 7), size / 2 + int(sin(a) * 7), accent)
				img.set_pixel(ox + size / 2, i, accent)
		Tiles.REGOLITH, Tiles.SAND, Tiles.SOIL, Tiles.DUST:
			_spots(img, ox, size, accent, id, 4, false)


## Scattered flecks (ore) or small diagonal shards (crystal) in the accent colour.
static func _spots(img: Image, ox: int, size: int, accent: Color, salt: int, count: int, shards: bool) -> void:
	for i in count:
		var cx := 3 + int(HashNoise.hash_f(11, i, 0, salt) * (size - 6))
		var cy := 3 + int(HashNoise.hash_f(11, i, 1, salt) * (size - 6))
		var r := 1 + int(HashNoise.hash_f(11, i, 2, salt) * 2.0)
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var ok := dx == dy if shards else dx * dx + dy * dy <= r * r
				if ok and cx + dx >= 0 and cx + dx < size and cy + dy >= 0 and cy + dy < size:
					img.set_pixel(ox + cx + dx, cy + dy, accent)
