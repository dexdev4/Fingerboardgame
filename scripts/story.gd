## The story director (rule 2). Chapters from story/story.json advance in a fixed order, each
## when its goal is met; lore pickups always reveal the NEXT unread entry of their kind, whichever
## pod or monolith the player finds. So the procedurally generated world can't scramble the story.
##
## Goal types: repair {id}, lore {kind, count}, night {count}, biome {biome}, reach_x {x}, end.
class_name Story
extends RefCounted

signal chapter_started(chapter: Dictionary)

const PATH := "res://story/story.json"

var chapters: Array = []
var lore := {}
var fallback := {}
## Index of the current chapter.
var chapter := 0
## Progress the goals look at.
var lore_read := {"crew_log": 0, "monolith": 0}
var nights := 0
var repairs := {}
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


## Start the story (emits the first chapter).
func begin() -> void:
	chapter_started.emit(current())
	_check()


# ---- Events from the game ---------------------------------------------------------------

func on_repair(id: String) -> void:
	repairs[id] = true
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


## A pod or monolith was read: returns its {title, text} — the next unread entry of that kind.
func on_lore(kind: String) -> Dictionary:
	var entries: Array = lore.get(kind, [])
	var n: int = lore_read.get(kind, 0)
	var entry: Dictionary = entries[n] if n < entries.size() else fallback.get(kind, {"title": "", "text": ""})
	lore_read[kind] = n + 1
	_check()
	return entry


# ---- Goals ------------------------------------------------------------------------------

func _goal_met(goal: Dictionary) -> bool:
	match goal.type:
		"repair":
			return repairs.has(goal.id)
		"lore":
			return lore_read.get(goal.kind, 0) >= int(goal.count)
		"night":
			return nights >= int(goal.count)
		"biome":
			return biomes_seen.has(int(goal.biome))
		"reach_x":
			return max_x >= int(goal.x)
	return false   # "end": the last chapter stays open


## Advance through every chapter whose goal is already met (in order).
func _check() -> void:
	while chapter < chapters.size() - 1 and _goal_met(current().goal):
		chapter += 1
		chapter_started.emit(current())


func to_dict() -> Dictionary:
	return {"chapter": chapter, "lore_read": lore_read, "nights": nights, "repairs": repairs,
			"biomes_seen": biomes_seen.keys(), "max_x": max_x}


## Restore progress (no chapter_started signals: the player has already seen them).
func from_dict(d: Dictionary) -> void:
	chapter = clampi(int(d.get("chapter", 0)), 0, chapters.size() - 1)
	for k in d.get("lore_read", {}):
		lore_read[k] = int(d.lore_read[k])
	nights = int(d.get("nights", 0))
	repairs = d.get("repairs", {}).duplicate()
	biomes_seen.clear()
	for b in d.get("biomes_seen", []):
		biomes_seen[int(b)] = true
	max_x = int(d.get("max_x", 0))
