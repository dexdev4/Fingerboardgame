## The story director (rule 2). Chapters from story/story.json advance in a fixed order, each
## when its goal is met; journal pages and runestones always reveal the NEXT unread entry of their
## kind, whichever one the player finds — so the generated forest can't scramble the story.
##
## Goal types: place {id}, craft {id}, comfort {value}, lore {kind, count}, night {count},
## biome {biome}, reach_x {x}, end.
class_name Story
extends RefCounted

signal chapter_started(chapter: Dictionary)

const PATH := "res://story/story.json"

var chapters: Array = []
var lore := {}
var fallback := {}
var chapter := 0
var lore_read := {"page": 0, "runestone": 0}
var nights := 0
var placed := {}        # furniture ids ever placed
var crafted := {}       # item ids ever crafted
var comfort := 0
var biomes_seen := {}
var max_x := 0


func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	chapters = data.chapters
	lore = data.lore
	fallback = data.lore_fallback


func current() -> Dictionary:
	return chapters[chapter]


func objective() -> String:
	return current().objective


func begin() -> void:
	chapter_started.emit(current())
	_check()


# ---- Events from the game ----------------------------------------------------------------

func on_place(id: String) -> void:
	placed[id] = true
	_check()


func on_craft(id: String) -> void:
	crafted[id] = true
	_check()


func on_comfort(value: int) -> void:
	comfort = value
	_check()


func on_night_survived() -> void:
	nights += 1
	_check()


func on_position(x_tiles: int, biome: int) -> void:
	var changed := false
	if x_tiles > max_x:
		max_x = x_tiles
		changed = true
	if not biomes_seen.has(biome):
		biomes_seen[biome] = true
		changed = true
	if changed:
		_check()


## A page or runestone was read: returns {title, text}, the next unread entry of that kind.
func on_lore(kind: String) -> Dictionary:
	var entries: Array = lore.get(kind, [])
	var n: int = lore_read.get(kind, 0)
	var entry: Dictionary = entries[n] if n < entries.size() else fallback.get(kind, {"title": "", "text": ""})
	lore_read[kind] = n + 1
	_check()
	return entry


# ---- Goals -------------------------------------------------------------------------------

func _goal_met(goal: Dictionary) -> bool:
	match goal.type:
		"place":
			return placed.has(goal.id)
		"craft":
			return crafted.has(goal.id)
		"comfort":
			return comfort >= int(goal.value)
		"lore":
			return lore_read.get(goal.kind, 0) >= int(goal.count)
		"night":
			return nights >= int(goal.count)
		"biome":
			return biomes_seen.has(int(goal.biome))
		"reach_x":
			return max_x >= int(goal.x)
	return false   # "end"


func _check() -> void:
	while chapter < chapters.size() - 1 and _goal_met(current().goal):
		chapter += 1
		chapter_started.emit(current())


func to_dict() -> Dictionary:
	return {"chapter": chapter, "lore_read": lore_read, "nights": nights, "placed": placed.keys(),
			"crafted": crafted.keys(), "comfort": comfort, "biomes_seen": biomes_seen.keys(), "max_x": max_x}


func from_dict(d: Dictionary) -> void:
	chapter = clampi(int(d.get("chapter", 0)), 0, chapters.size() - 1)
	for k in d.get("lore_read", {}):
		lore_read[k] = int(d.lore_read[k])
	nights = int(d.get("nights", 0))
	placed.clear()
	for id in d.get("placed", []):
		placed[id] = true
	crafted.clear()
	for id in d.get("crafted", []):
		crafted[id] = true
	comfort = int(d.get("comfort", 0))
	biomes_seen.clear()
	for b in d.get("biomes_seen", []):
		biomes_seen[int(b)] = true
	max_x = int(d.get("max_x", 0))
