## The player's medieval appearance and how to draw it.
## A look is a Dictionary of option indices (saved with the game). The 8×14 sprite is built from
## layers — cloak (behind), body, beard, hair, hat — and recoloured from the option palettes.
class_name CharacterLook
extends RefCounted

const SKINS := [Color("f2c9a0"), Color("e0ac7e"), Color("c68955"), Color("a0663c"), Color("7a4a2a"), Color("5a3520")]
const HAIR_COLORS := [Color("241a14"), Color("4a2e1c"), Color("7a4a28"), Color("9b4a22"),
		Color("d9b45a"), Color("b8471f"), Color("8f8a86"), Color("e3ddd2")]
const HAIR_COLOR_NAMES := ["Black", "Dark brown", "Brown", "Auburn", "Blond", "Red", "Grey", "White"]
const CLOTH := [Pal.RED, Pal.LEAF, Pal.BLUE, Pal.BARK, Pal.TAN, Pal.STONE, Pal.PURPLE, Color("b08a2e"), Color("2b2b33")]
const CLOTH_NAMES := ["Red", "Green", "Blue", "Brown", "Tan", "Grey", "Purple", "Mustard", "Black"]
const BOOTS := [Pal.BARK_DARK, Pal.INK, Color("5b3a1e")]
const BOOT_NAMES := ["Brown", "Black", "Russet"]

const HAIR_STYLES := ["Bald", "Short", "Long", "Braid", "Curly", "Topknot"]
const BEARDS := ["None", "Stubble", "Moustache", "Full", "Long"]
const HATS := ["None", "Hood", "Cap", "Straw hat", "Feathered cap"]
const CLOAKS := ["None", "Cloak"]

## Option name → [label, list of choice names]. The order is the creator's row order.
const OPTIONS := [
	["skin", "Skin"], ["hair_style", "Hair"], ["hair_color", "Hair colour"], ["beard", "Beard"],
	["hat", "Hat"], ["tunic", "Tunic"], ["trousers", "Trousers"], ["cloak", "Cloak"],
	["cloak_color", "Cloak colour"], ["boots", "Boots"]]

# ---- Layers (8 wide × 14 tall, facing right; "." = nothing) ----------------------------------
const BODY := ["........", "........", "..SSSS..", "..SSSE..", "..SSSS..", "...SS...", "..TTTT..",
		".TTTTTT.", ".TTTTTT.", ".SLLLLS.", "..TTTT..", "..PPPP.."]
## Legs for the idle / walk frames (rows 12–13).
const LEGS := [["..P..P..", "..K..K.."], [".P...P..", ".K....K."], ["..PP....", "..KK...."]]
const HAIR := {
	"Short": ["........", "..HHHH..", ".HH.....", ".H......"],
	"Long": ["........", "..HHHH..", ".HHH....", ".HH.....", ".HH.....", ".HH.....", ".H......"],
	"Braid": ["........", "..HHHH..", ".HH.....", ".H......", "H.......", "H.......", "H.......", "H......."],
	"Curly": ["..HHH...", ".HHHHH..", "HHH.....", "HH......", ".H......"],
	"Topknot": ["...HH...", "..HHHH..", ".H......"],
}
const BEARD := {
	"Stubble": ["", "", "", "", "...F.F.."],
	"Moustache": ["", "", "", "", "...FFF.."],
	"Full": ["", "", "", "", "..FFFF..", "...FF..."],
	"Long": ["", "", "", "", "..FFFF..", "..FFFF..", "...FF..."],
}
const HAT := {
	"Hood": ["..AAA...", ".AAAAA..", "AAA..A..", "AA......", "AA......", ".A......"],
	"Cap": ["........", "..AAAA..", "..AAAAA."],
	"Straw hat": ["...YY...", "..YYYY..", "YYYYYYYY"],
	"Feathered cap": ["......r.", "..AAAAr.", "..AAAAA."],
}
const CLOAK := ["", "", "", "", "", "", ".CCCCC..", "CCCCCCC.", "CCCCCCC.", "CCCCCCC.", "CCCCCC..", "CCCCC...", "CCC....."]


static func default_look() -> Dictionary:
	return {"name": "Wren", "skin": 1, "hair_style": 1, "hair_color": 2, "beard": 0, "hat": 0,
			"tunic": 1, "trousers": 3, "cloak": 1, "cloak_color": 3, "boots": 0, "background": "woodcutter"}


## How many choices option `key` has.
static func choice_count(key: String) -> int:
	match key:
		"skin": return SKINS.size()
		"hair_style": return HAIR_STYLES.size()
		"hair_color": return HAIR_COLORS.size()
		"beard": return BEARDS.size()
		"hat": return HATS.size()
		"tunic", "trousers", "cloak_color": return CLOTH.size()
		"cloak": return CLOAKS.size()
		"boots": return BOOTS.size()
	return 1


## The name of the current choice for option `key`.
static func choice_name(look: Dictionary, key: String) -> String:
	var i: int = look.get(key, 0)
	match key:
		"skin": return "Tone %d" % (i + 1)
		"hair_style": return HAIR_STYLES[i]
		"hair_color": return HAIR_COLOR_NAMES[i]
		"beard": return BEARDS[i]
		"hat": return HATS[i]
		"tunic", "trousers", "cloak_color": return CLOTH_NAMES[i]
		"cloak": return CLOAKS[i]
		"boots": return BOOT_NAMES[i]
	return ""


## The three animation frames (idle, step A, step B) as textures, facing right.
static func frames(look: Dictionary) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for f in 3:
		out.append(ImageTexture.create_from_image(_frame_image(look, f)))
	return out


static func _frame_image(look: Dictionary, frame: int) -> Image:
	var hair_c: Color = HAIR_COLORS[look.hair_color]
	var legend := {
		"S": SKINS[look.skin], "E": Pal.INK, "H": hair_c, "F": hair_c.darkened(0.1),
		"T": CLOTH[look.tunic], "L": Pal.BARK_DARK, "P": CLOTH[look.trousers], "K": BOOTS[look.boots],
		"C": CLOTH[look.cloak_color].darkened(0.15), "A": CLOTH[look.cloak_color], "Y": Pal.YELLOW, "r": Pal.RED,
	}
	var img := Image.create(8, 14, false, Image.FORMAT_RGBA8)
	if look.cloak == 1:
		_paint(img, CLOAK, legend)
	var body := BODY.duplicate()
	body.append_array(LEGS[frame])
	_paint(img, body, legend)
	var beard: String = BEARDS[look.beard]
	if BEARD.has(beard):
		_paint(img, BEARD[beard], legend)
	var hat: String = HATS[look.hat]
	var style: String = HAIR_STYLES[look.hair_style]
	# Hoods hide most hair; other hats sit on top of it.
	if HAIR.has(style) and hat != "Hood":
		_paint(img, HAIR[style], legend)
	if HAT.has(hat):
		_paint(img, HAT[hat], legend)
	return img


## Paint rows over the image ("." and missing rows leave pixels as they are).
static func _paint(img: Image, rows: Array, legend: Dictionary) -> void:
	for y in mini(rows.size(), img.get_height()):
		var row: String = rows[y]
		for x in mini(row.length(), img.get_width()):
			var ch := row[x]
			if ch != "." and legend.has(ch):
				img.set_pixel(x, y, legend[ch])


const FIRST_NAMES := ["Wren", "Aldric", "Maud", "Osric", "Elsa", "Bram", "Hild", "Tomas", "Agnes",
		"Cedric", "Isolde", "Garrick", "Rowena", "Edmund", "Ylva", "Piers", "Matilda", "Leofric",
		"Ada", "Hugo", "Elric", "Gwen", "Ansel", "Brida"]


## A random medieval name (the creator's "random" button; not part of world generation).
static func random_name() -> String:
	return FIRST_NAMES[randi() % FIRST_NAMES.size()]
