## Your cabin, as data: its size and upgrades, and every piece of furniture and decor you've
## placed. Pure logic (placement rules, light, comfort) — CabinInterior draws it and handles taps.
##
## Room layout (tiles): columns 0 .. width−1 from the left wall; the last column holds the door.
## Rows 0 .. height−1 from the ceiling; the floor is the bottom row. Floor items and rugs stand on
## the floor at a column; wall items hang in the wall area (rows 1 .. height−4).
class_name Cabin
extends RefCounted

var t: GameTuning
var extensions := 0
var floor_type := "dirt"      # dirt | floor_planks | floor_stone
var wall_type := "logs"       # logs | walls_planks | walls_plaster
var roof_type := "thatch"     # thatch | roof_shingles
## Placed items: [{"id": String, "x": int, "y": int}] (y only matters for wall items).
var placed: Array = []


func _init(tuning: GameTuning) -> void:
	t = tuning


## The cabin you start with: a straw bed and one small window.
static func starter(tuning: GameTuning) -> Cabin:
	var c := Cabin.new(tuning)
	c.placed = [{"id": "bed_straw", "x": 1, "y": 0}, {"id": "window", "x": 5, "y": 2}]
	return c


func width() -> int:
	return t.cabin_width + extensions * t.cabin_extend_width


func height() -> int:
	return t.cabin_height


## Last row wall items may reach (the lower wall is left for tall floor furniture to sit in front of).
func wall_bottom() -> int:
	return height() - 4


# ---- Placement -----------------------------------------------------------------------------

static func layer(id: String) -> String:
	return Catalog.FURNITURE[id][0]


static func size_of(id: String) -> Vector2i:
	return Vector2i(Catalog.FURNITURE[id][1], Catalog.FURNITURE[id][2])


## "" if `id` can go at column x (and row y for wall items), else a short reason.
func can_place(id: String, x: int, y: int = 0, ignore: int = -1) -> String:
	if not Catalog.FURNITURE.has(id):
		return "Can't place that"
	var sz := size_of(id)
	var lay := layer(id)
	if x < 0 or x + sz.x - 1 > width() - 2:      # keep clear of the walls and the door column
		return "No room there"
	if lay == "wall" and (y < 1 or y + sz.y - 1 > wall_bottom()):
		return "Too high or too low"
	for i in placed.size():
		if i == ignore:
			continue
		var p: Dictionary = placed[i]
		if layer(p.id) != lay:
			continue
		var psz := size_of(p.id)
		var overlap_x: bool = x < p.x + psz.x and p.x < x + sz.x
		var overlap_y: bool = lay != "wall" or (y < p.y + psz.y and p.y < y + sz.y)
		if overlap_x and overlap_y:
			return "Something's in the way"
	return ""


func place(id: String, x: int, y: int = 0) -> bool:
	if can_place(id, x, y) != "":
		return false
	placed.append({"id": id, "x": x, "y": y if layer(id) == "wall" else 0})
	return true


## Index of the placed item covering cell (col, row), preferring floor items, then wall, then rug.
## -1 if none.
func item_at(col: int, row: int) -> int:
	for lay in ["floor", "wall", "rug"]:
		for i in placed.size():
			var p: Dictionary = placed[i]
			if layer(p.id) != lay:
				continue
			var sz := size_of(p.id)
			if col < p.x or col >= p.x + sz.x:
				continue
			match lay:
				"floor":   # covers rows from the floor up to its height
					if row >= height() - 1 - sz.y and row <= height() - 1:
						return i
				"wall":
					if row >= p.y and row < p.y + sz.y:
						return i
				"rug":
					if row == height() - 1:
						return i
	return -1


## Take a placed item back; returns its id.
func remove(index: int) -> String:
	var id: String = placed[index].id
	placed.remove_at(index)
	return id


func has(id: String) -> bool:
	for p in placed:
		if p.id == id:
			return true
	return false


## Is there furniture that does `function` ("bed", "hearth", "workbench", "chest")?
func has_function(function: String) -> bool:
	for p in placed:
		if Catalog.FUNCTIONS.get(p.id, "") == function:
			return true
	return false


# ---- Upgrades ------------------------------------------------------------------------------

## "" if the upgrade can be built now, else why not.
func upgrade_block(id: String) -> String:
	match id:
		"floor_planks":
			return "" if floor_type == "dirt" else "Already done"
		"floor_stone":
			return "" if floor_type != "floor_stone" else "Already done"
		"walls_planks":
			return "" if wall_type == "logs" else "Already done"
		"walls_plaster":
			return "" if wall_type != "walls_plaster" else "Already done"
		"roof_shingles":
			return "" if roof_type == "thatch" else "Already done"
		"extend":
			return "" if extensions < t.cabin_max_extensions else "Cabin is full size"
	return "Unknown upgrade"


func apply_upgrade(id: String) -> bool:
	if upgrade_block(id) != "":
		return false
	match id:
		"floor_planks", "floor_stone":
			floor_type = id
		"walls_planks", "walls_plaster":
			wall_type = id
		"roof_shingles":
			roof_type = id
		"extend":
			extensions += 1
	return true


# ---- Light and comfort ---------------------------------------------------------------------

## Interior light 0..1: a dim base, plus the hearth, candles, lanterns, and windows by day.
func light(daylight: float) -> float:
	var l := t.cabin_base_light
	for p in placed:
		var v: float = t.light_values.get(p.id, 0.0)
		if p.id == "window":
			v *= daylight
		l += v
	return clampf(l, 0.0, 1.0)


## Comfort: what your furnishings and upgrades add up to. Better sleep heals more.
func comfort() -> int:
	var c := 0
	for p in placed:
		c += int(t.comfort_values.get(p.id, 0))
	for u in [floor_type, wall_type, roof_type]:
		c += int(t.comfort_values.get(u, 0))
	c += extensions * int(t.comfort_values.get("extend", 0))
	return c


func to_dict() -> Dictionary:
	return {"extensions": extensions, "floor": floor_type, "walls": wall_type, "roof": roof_type,
			"placed": placed.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	extensions = int(d.get("extensions", 0))
	floor_type = d.get("floor", "dirt")
	wall_type = d.get("walls", "logs")
	roof_type = d.get("roof", "thatch")
	placed.clear()
	for p in d.get("placed", []):
		placed.append({"id": p.id, "x": int(p.x), "y": int(p.y)})
