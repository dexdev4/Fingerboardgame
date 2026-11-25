## Pixel-art sprites, built in code (no imported art):
##  - small sprites (item icons, furniture) are hand-drawn pixel maps: one string per row, one
##    character per pixel, colours from LEGEND ("." = transparent);
##  - big sprites (trees) are painted procedurally from the palette with a fixed hash.
## Textures are built once and cached.
class_name Sprites
extends RefCounted

const LEGEND := {
	"k": Pal.INK, "d": Pal.BARK_DARK, "b": Pal.BARK, "w": Pal.WOOD, "t": Pal.TAN, "c": Pal.CREAM,
	"G": Pal.LEAF_DARK, "g": Pal.LEAF, "l": Pal.LEAF_LIGHT, "m": Pal.LIME,
	"S": Pal.STONE_DARK, "s": Pal.STONE, "a": Pal.STONE_LIGHT, "W": Pal.WHITE,
	"r": Pal.RED, "o": Pal.ORANGE, "y": Pal.YELLOW, "B": Pal.BLUE, "u": Pal.SKY,
	"p": Pal.PURPLE, "n": Pal.NIGHT, "P": Pal.PINK,
}

## 8×8 item icons.
const ICONS := {
	"log": ["........", ".dbbbbt.", "dbbbbbtw", "dbbbbbtc", "dbbbbbtw", ".dbbbbt.", "........", "........"],
	"plank": ["........", "........", "wwwwwwww", "tttttttw", "wwwwwwwb", "bbbbbbbb", "........", "........"],
	"stone": ["........", "...ss...", "..saas..", ".ssaass.", ".sssssS.", "..SSSS..", "........", "........"],
	"clay": ["........", "........", "..oooo..", ".owwwwo.", ".wwwwwb.", "..bbbb..", "........", "........"],
	"fiber": [".m..m...", "..mm.m..", "...tm...", "...tt...", "..dddd..", "...tt...", "...tt...", "........"],
	"cloth": ["........", ".cccccc.", ".ctctct.", ".cccccc.", ".tctctc.", ".cccccc.", "........", "........"],
	"iron_ore": ["........", "...ss...", "..soas..", ".ssaoss.", ".soSssS.", "..SSSS..", "........", "........"],
	"iron": ["........", "........", "..aaaa..", ".aWaaas.", "ssssssS.", ".SSSSS..", "........", "........"],
	"coal": ["........", "...kk...", "..kSak..", ".kkSkkk.", ".kkkkSk.", "..kkkk..", "........", "........"],
	"gold": ["........", "...ss...", "..syas..", ".ssayss.", ".syssyS.", "..SSSS..", "........", "........"],
	"berries": ["........", "...l....", "..lgl...", ".rr.rr..", "rPrrPrr.", ".rr.rr..", "........", "........"],
	"mushroom": ["........", "..rrrr..", ".rWrrWr.", "rrrrrrrr", "...cc...", "...cc...", "..cccc..", "........"],
	"apple": ["...b....", "...bl...", ".rrrrr..", "rrPrrrr.", "rrrrrrr.", "rrrrrrr.", ".rrrrr..", "........"],
	"herb": ["...l....", "..lgl.l.", ".l.g.lg.", "..lgl.g.", "...g.l..", "...gg...", "...g....", "........"],
	"stew": ["..W..W..", "...W....", ".oooooo.", "bwoooowb", ".bwwwwb.", "..bbbb..", "........", "........"],
	"bread": ["........", "..tttt..", ".tcttct.", "twwwwwwt", "wwwwwwwb", ".bbbbbb.", "........", "........"],
	"poultice": ["........", "...W....", "..WWW...", ".WlglW..", ".WglgW..", "..WWW...", "........", "........"],
	"torch": ["...y....", "..yoy...", "..ror...", "...b....", "...b....", "...b....", "...b....", "........"],
	"stone_axe": ["..sss...", ".ssaab..", ".sss.b..", ".....b..", ".....b..", ".....b..", ".....d..", "........"],
	"iron_axe": ["..aaa...", ".aaWWb..", ".aaa.b..", ".....b..", ".....b..", ".....b..", ".....d..", "........"],
	"stone_pick": [".ssssss.", "s...b..s", "....b...", "....b...", "....b...", "....b...", "....d...", "........"],
	"iron_pick": [".aaaaaa.", "a...b..a", "....b...", "....b...", "....b...", "....b...", "....d...", "........"],
	# HUD stat icons
	"ui_health": [".rr.rr..", "rPrrrrr.", "rrrrrrr.", ".rrrrr..", "..rrr...", "...r....", "........", "........"],
	"ui_hunger": ["...ww...", "..wwtw..", ".wwwww..", ".wwwww..", "..www...", "...c....", "..ccc...", "..c.c..."],
	"ui_warmth": ["...y....", "..yy....", "..yoy...", ".yoroy..", ".orrro..", ".orrro..", "..ooo...", "........"],
	"ui_stamina": ["....m...", "...mm...", "..mm....", ".mmmmm..", "...mm...", "..mm....", "..m.....", "........"],
}

## Furniture and decor (width = footprint × 8 px; the bottom row stands on the floor / hangs
## from the top-left of a wall slot).
const FURNITURE := {
	"bed_straw": [
		"................", "................", "bb..............", "bbcccc..........",
		"bbcWWctttttttttt", "bbtttttytttytttt", "bdddddddddddddbb", "bd............db"],
	"bed_wood": [
		"dd......................", "dbd.....................", "dbd.....................",
		"dbdcccc.................", "dbdcWWc.................", "dbdccccrrrrrrrrrrrrrrrrd",
		"dbdrrrrrrrrrrrrrrrrrrrrd", "dbdrPrrrPrrrPrrrPrrrrrrd", "dbdddddddddddddddddddddd",
		"dbwwwwwwwwwwwwwwwwwwwwbd", "db....................bd", "dd....................dd"],
	"hearth": [
		".....ssss.......", ".....sSas.......", ".....ssss.......", ".....saSs.......",
		".....ssss.......", ".....sSas.......", ".....ssss.......", ".....saSs.......",
		"..dddddddddddd..", "..wwwwwwwwwwww..", "..ssssssssssss..", "..sasSsasSsass..",
		"..sskkkkkkkkss..", "..sakkkkkkkkas..", "..sskkkykkkkss..", "..sSkkyoykkkSs..",
		"..sskyoroykkss..", "..sakorrrokkas..", "..sskbdbdbkkss..", "..ssssssssssss..",
		".SSSSSSSSSSSSSS."],
	"workbench": [
		"..s.........b...", "..sa.......bb...", "wwwwwwwwwwwwwwww", "tttttttttttttttw",
		"bbbbbbbbbbbbbbbb", ".b..........b...", ".b..dddddd..b...", ".b..d....d..b...",
		".bbbbbbbbbbbb...", ".b..........b...", ".b..........b...", ".d..........d..."],
	"chest": [".dddddd.", "dwwwwwwd", "dyddddyd", "dwwyywwd", "dwwwwwwd", "dyddddyd", "dwwwwwwd", "dddddddd"],
	"table": [
		"wwwwwwwwwwwwwwww", "tttttttttttttttb", "bbbbbbbbbbbbbbbb", ".b............b.",
		".b............b.", ".b............b.", ".b............b.", ".b............b.", ".d............d."],
	"chair": ["d.......", "db......", "db......", "db......", "db......", "dwwwwww.",
		"dbbbbbb.", "db....b.", "db....b.", "db....b.", "db....b.", "dd....d."],
	"stool": ["........", ".wwwwww.", ".bbbbbb.", ".b....b.", ".b....b.", ".d....d."],
	"bookshelf": ["dddddddd", "drBgprgd", "drBgprgd", "drBgprgd", "dddddddd", "dgpyrBrd",
		"dgpyrBrd", "dgpyrBrd", "dddddddd", "dBrg.ypd", "dBrg.ypd", "dBrgyypd", "dddddddd",
		"dwwwwwwd", "dwwwwwwd", "dddddddd"],
	"barrel": [".dddddd.", "dwwwwwwd", "SSSSSSSS", "dwwwwwwd", "dwtwwwtd", "dwwwwwwd", "SSSSSSSS", "dwwwwwwd", ".dddddd."],
	"plant_pot": ["..l.l...", ".lgl.l..", "lglglgl.", ".lgggl..", "..lgl...", ".oooooo.", ".owwwwo.", "..owwo..", "..oooo.."],
	"candle_stand": ["...y....", "..yoy...", "...W....", "...W....", "...W....", "..SSS...",
		"...S....", "...S....", "...S....", "...S....", "..SSS...", ".SSSSS.."],
	"window": [
		"bb.dddddddddd.bb", "bwbduuuduuuudbwb", "bwbduuuduuuudbwb", "bwbduuuduuuudbwb",
		"bwbddddddddddbwb", "bwbduuuduuuudbwb", "bwbduuuduuuudbwb", "bwbduuuduuuudbwb",
		"bb.dddddddddd.bb", "..wwwwwwwwwwww.."],
	"shelf": ["................", "..o...B.....r...", ".ooo.BBB...rrr..", ".ooo.BuB...rWr..",
		".ooo.BBB...rrr..", "wwwwwwwwwwwwwwww", "tttttttttttttttb", ".d............d."],
	"banner": ["dddddddd", ".rrrrrr.", ".rrrrrr.", ".rryyrr.", ".ryyyyr.", ".rryyrr.",
		".rryyrr.", ".rrrrrr.", ".rrrrrr.", ".rrrrrr.", ".rr..rr.", ".r....r."],
	"tapestry": [
		"dddddddddddddddd", ".yyyyyyyyyyyyyy.", ".yggggggggggggy.", ".ygggggllgggggy.",
		".yggggllllggggy.", ".ygggllllllgggy.", ".yggggllllggggy.", ".ygggggbbgggggy.",
		".ygggggbbgggggy.", ".yggggbbbbggggy.", ".yggggggggggggy.", ".yyyyyyyyyyyyyy.",
		"..y.y.y.y.y.y..."],
	"sconce": ["...y....", "..yoy...", "...W....", "...W....", "..SaS...", "...S....", "..SS...."],
	"lantern": ["...S....", "..SSS...", ".SyyyS..", ".SyoyS..", ".SyyyS..", "..SSS..."],
	"dried_herbs": ["dddddddd", ".b..b..b", ".l..g..l", "lgl.glgl", "glg.lglg", ".g...l.g"],
	"rug": ["y.y.y.y.y.y.y.y.y.y.y.y.", "rrrrrrrrrrrrrrrrrrrrrrrr", "rryrrryrrryrrryrrryrrryr", "rrrrrrrrrrrrrrrrrrrrrrrr"],
	"mat": ["tttttttttttttttt", "twtwtwtwtwtwtwtw"],
}

## Things standing in the world (bottom row = on the ground).
const WORLD := {
	"berry_bush": ["..g.g...", ".glglg..", "glrlglg.", "grglrgl.", "glglglgG", ".GgrgGg.", "..GGGG.."],
	"mushroom": ["........", ".rr.....", "rWrr..o.", "rrrr.ooo", ".cc..wo.", ".cc...c.", "cccc.ccc"],
	"flax": [".u.u....", "u.l.u...", ".lml.u..", "..l.l...", "..mlm...", "...l....", "..mlm...", "...l...."],
	"herb": ["...l....", "..lgl.l.", ".l.g.lgl", "..lglg..", "...gl...", "...g...."],
	"rock": ["........", "..sas...", ".saass..", "sssssSs.", "SsSSsSS."],
	"page": ["..cccc..", "..ctcc..", "..cccc..", "..ctcc..", "..cccc..", "...b....", "...b....", "...b....", "..dbd..."],
	"runestone": ["..ssss..", ".ssaass.", ".sm..ss.", ".sasmss.", ".s.mass.", ".smasss.", ".sasmss.",
		".sm..ss.", ".ssamss.", ".sssass.", ".ssssss.", "SSSSSSSS"],
	"stump": ["........", ".dbbbd..", "dtwtwtd.", "dbbbbbd."],
}

static var _cache := {}


## Build a texture from pixel rows. `legend` maps characters to colours (extra or overriding
## entries on top of LEGEND). Rows shorter than the widest are padded with transparency.
static func make(rows: Array, legend: Dictionary = {}) -> ImageTexture:
	var w := 0
	for r in rows:
		w = maxi(w, r.length())
	var img := Image.create(maxi(w, 1), maxi(rows.size(), 1), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch == ".":
				continue
			var col = legend.get(ch, LEGEND.get(ch))
			if col != null:
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func icon(id: String) -> Texture2D:
	return _cached("icon:" + id, func(): return make(ICONS.get(id, ICONS.stone)))


static func world(id: String) -> Texture2D:
	return _cached("world:" + id, func(): return make(WORLD[id]))


static func furniture(id: String) -> Texture2D:
	return _cached("furn:" + id, func(): return make(FURNITURE[id]))


static func _cached(key: String, build: Callable) -> Texture2D:
	if not _cache.has(key):
		_cache[key] = build.call()
	return _cache[key]


# ---- Procedural trees ----------------------------------------------------------------------

## A tree sprite: kind "pine", "oak" or "birch", `variant` 0..3 changes its shape a little.
## The bottom-centre of the texture is the foot of the trunk.
static func tree(kind: String, variant: int) -> Texture2D:
	return _cached("tree:%s:%d" % [kind, variant], func(): return _paint_tree(kind, variant))


static func _paint_tree(kind: String, v: int) -> ImageTexture:
	var img: Image
	match kind:
		"pine":
			var h := 52 + v * 4
			img = Image.create(24, h, false, Image.FORMAT_RGBA8)
			_trunk(img, 12, h, 3, 14, Pal.BARK_DARK, Pal.BARK)
			# Stacked triangles of needles, darker underneath each tier.
			var tiers := 4
			for i in tiers:
				var top := 2 + i * (h - 18) / tiers
				var bot := top + (h - 14) / tiers + 6
				for y in range(top, mini(bot, h - 6)):
					var f := float(y - top) / maxf(bot - top, 1)
					var half := int(2 + f * (5 + i * 1.6))
					for x in range(12 - half, 12 + half):
						if x < 0 or x >= 24:
							continue
						var c := Pal.LEAF_DARK if f > 0.75 or x < 12 - half + 1 else Pal.LEAF
						if HashNoise.hash_f(v, x, y, 31) < 0.12 and c == Pal.LEAF:
							c = Pal.LEAF_LIGHT
						img.set_pixel(x, y, c)
		"oak":
			var h := 44 + v * 3
			img = Image.create(32, h, false, Image.FORMAT_RGBA8)
			_trunk(img, 16, h, 4, 20, Pal.BARK_DARK, Pal.BARK)
			# A canopy of overlapping leaf blobs, lit from the top-left.
			var blobs := [[16, 12, 10], [9, 17, 8], [23, 17, 8], [12, 8, 7], [21, 9, 7], [16, 20, 8]]
			for b in blobs:
				_blob(img, b[0] + (v % 2), b[1], b[2], v)
		"birch":
			var h := 50 + v * 4
			img = Image.create(20, h, false, Image.FORMAT_RGBA8)
			for y in range(14, h):
				for x in range(9, 12):
					var c := Pal.WHITE if x < 11 else Pal.STONE_LIGHT
					if HashNoise.hash_f(v, 0, y / 3, 41) < 0.25 and x < 11:
						c = Pal.INK     # dark birch-bark marks
					img.set_pixel(x, y, c)
			for b in [[10, 10, 7], [6, 15, 5], [14, 15, 5], [10, 18, 5]]:
				_blob(img, b[0], b[1], b[2], v, true)
		_:
			img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	return ImageTexture.create_from_image(img)


static func _trunk(img: Image, cx: int, h: int, w: int, top: int, dark: Color, mid: Color) -> void:
	for y in range(top, h):
		for x in range(cx - w / 2, cx - w / 2 + w):
			img.set_pixel(x, y, dark if x == cx - w / 2 or x == cx - w / 2 + w - 1 else mid)
	# Roots flaring at the bottom.
	img.set_pixel(cx - w / 2 - 1, h - 1, dark)
	img.set_pixel(cx - w / 2 + w, h - 1, dark)


static func _blob(img: Image, cx: int, cy: int, r: int, v: int, light: bool = false) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var d := Vector2(x - cx, y - cy).length()
			if d > r:
				continue
			var lit := (x - cx) + (y - cy) < -r * 0.3
			var c := (Pal.LIME if light else Pal.LEAF_LIGHT) if lit else (Pal.LEAF_LIGHT if light else Pal.LEAF)
			if d > r - 1.2 and not lit:
				c = Pal.LEAF if light else Pal.LEAF_DARK
			if HashNoise.hash_f(v, x, y, 53) < 0.1:
				c = Pal.LEAF_DARK if not light else Pal.LEAF
			img.set_pixel(x, y, c)
