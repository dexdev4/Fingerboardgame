## Something standing in the forest: a tree to chop, forage to pick (berry bush, mushrooms,
## flax, herbs, loose rocks), a page of the hermit's journal, or a runestone.
## Trees take several hits (they shake when struck); everything else is taken with one tap.
## Drawn from pixel sprites; the shake/glow animation runs in _process and is visual only.
class_name WorldObject
extends Node2D

var id: String
var kind: String
var cell: Vector2i
var variant := 0
## Hits left (trees only; strength 1 per hand chop).
var hp := 1
var _shake := 0.0
var _t := 0.0
var _tex: Texture2D


func setup(data: Dictionary, t: GameTuning) -> void:
	id = data.id
	kind = data.kind
	cell = data.cell
	variant = data.get("variant", 0)
	# Stand on the floor of the cell (its bottom edge), centred.
	position = Vector2((cell.x + 0.5) * t.tile_size, (cell.y + 1) * t.tile_size)
	match kind:
		"tree_pine":
			hp = t.tree_hp_pine
			_tex = Sprites.tree("pine", variant)
		"tree_oak":
			hp = t.tree_hp_oak
			_tex = Sprites.tree("oak", variant)
		"tree_birch":
			hp = t.tree_hp_birch
			_tex = Sprites.tree("birch", variant)
		_:
			_tex = Sprites.world(kind)
	z_index = -1 if is_tree() else 0     # trees stand behind the player
	_t = float(absi(id.hash()) % 1000) / 100.0


func is_tree() -> bool:
	return kind.begins_with("tree_")


## Strike a tree with `damage`; true when it falls.
func chop(damage: int) -> bool:
	hp -= damage
	_shake = 0.25
	queue_redraw()
	return hp <= 0


## Rough tap target (px, world space) for finding what the player touched.
func hit_rect() -> Rect2:
	var s := _tex.get_size()
	if is_tree():   # the trunk and lower canopy, not the whole sprite
		return Rect2(position + Vector2(-8, -s.y * 0.75), Vector2(16, s.y * 0.75))
	return Rect2(position + Vector2(-s.x * 0.5 - 2, -s.y - 2), s + Vector2(4, 4))


func _process(dt: float) -> void:
	_t += dt
	if _shake > 0.0:
		_shake -= dt
	if kind == "runestone" or kind == "page" or _shake > 0.0:
		queue_redraw()


func _draw() -> void:
	var s := _tex.get_size()
	var off := Vector2(-floorf(s.x * 0.5), -s.y)
	if _shake > 0.0:
		off.x += 1.0 if int(_t * 30.0) % 2 == 0 else -1.0
	draw_texture(_tex, off)
	if kind == "runestone":   # the runes glow and fade
		var a := 0.25 + 0.25 * sin(_t * 2.0)
		draw_rect(Rect2(off + Vector2(2, 2), Vector2(4, 8)), Color(Pal.LIME, a))
	elif kind == "page" and int(_t * 2.0) % 4 == 0:   # the page flutters
		draw_rect(Rect2(off + Vector2(5, 1), Vector2(1, 2)), Pal.WHITE)
