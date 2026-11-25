## Saving and loading (rule 7). The world is regenerated from its seed, so a save only holds the
## seed and what the player changed: mined cells, collected pickups, inventory, suit stats,
## story progress, ship repairs, time of day and where the player is.
class_name SaveGame
extends RefCounted

const PATH := "user://tessaris_save.json"
const VERSION := 1


static func exists() -> bool:
	return FileAccess.file_exists(PATH)


static func write(d: Dictionary) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


## The saved game, or {} if there is none (or it's unreadable / from another version).
static func read() -> Dictionary:
	if not exists():
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(d) != TYPE_DICTIONARY or int(d.get("version", 0)) != VERSION:
		return {}
	return d


static func delete() -> void:
	if exists():
		DirAccess.remove_absolute(PATH)


## Mined cells (Vector2i → true) as a flat [x, y, x, y, ...] list for JSON.
static func cells_to_list(cells: Dictionary) -> Array:
	var out := []
	for c: Vector2i in cells:
		out.append(c.x)
		out.append(c.y)
	return out


static func list_to_cells(list: Array) -> Dictionary:
	var out := {}
	for i in range(0, list.size() - 1, 2):
		out[Vector2i(int(list[i]), int(list[i + 1]))] = true
	return out
