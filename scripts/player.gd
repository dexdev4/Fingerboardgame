## You: walk, jump, and carry a light. Movement reads the move_left / move_right / jump input
## actions (the touch buttons press them, as do the keyboard keys). Drawn from the 8×14 sprite
## built from your character look (CharacterLook), with a two-step walk cycle.
class_name Player
extends CharacterBody2D

## Landed hard: `speed` px/s downward at impact (above the safe speed).
signal hard_landing(speed: float)

const W := 6.0    ## collision box width (px)
const H := 13.0   ## collision box height (px); the origin is its centre

var t: GameTuning
var facing := 1.0
var light: PointLight2D
var _frames: Array[Texture2D] = []
var _air_time := 0.0
var _walk := 0.0
var _swing := 0.0   # tool swing animation timer (visual only)


func setup(tuning: GameTuning, look: Dictionary) -> void:
	t = tuning
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(W, H)
	shape.shape = rect
	add_child(shape)
	floor_snap_length = 2.0
	light = PointLight2D.new()
	light.texture = _light_texture()
	light.color = Color(1.0, 0.85, 0.6)
	add_child(light)
	set_look(look)


func set_look(look: Dictionary) -> void:
	_frames = CharacterLook.frames(look)
	queue_redraw()


func _physics_process(dt: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	velocity.x = move_toward(velocity.x, dir * t.run_speed, (t.run_accel if is_on_floor() else t.air_accel) * dt)
	if dir != 0.0:
		facing = signf(dir)
	if is_on_floor():
		_air_time = 0.0
	else:
		_air_time += dt
		velocity.y = minf(velocity.y + t.gravity * dt, t.max_fall_speed)
	if Input.is_action_just_pressed("jump") and _air_time <= t.coyote_time:
		velocity.y = -t.jump_speed
		_air_time = t.coyote_time + 1.0
	var was_air := not is_on_floor()
	var fall := velocity.y
	move_and_slide()
	if was_air and is_on_floor() and fall > t.fall_safe_speed:
		hard_landing.emit(fall)
	if is_on_floor() and absf(velocity.x) > 5.0:
		_walk += dt * 8.0
	else:
		_walk = 0.0
	if _swing > 0.0:
		_swing -= dt
	queue_redraw()


## Light around you: a torch (bigger, warm) or just your own dim glow; `darkness` 0..1 fades it in.
func set_light(darkness: float, torch: bool) -> void:
	var radius := t.torch_radius if torch else t.glow_radius
	light.texture_scale = radius / 64.0
	light.energy = clampf(darkness * (1.3 if torch else 0.7), 0.0, 1.3)


## Play the chop/dig swing toward a point (visual only).
func swing() -> void:
	_swing = 0.18


func _draw() -> void:
	if _frames.is_empty():
		return
	var frame := 0
	if _walk > 0.0:
		frame = 1 + int(_walk) % 2
	var tex := _frames[frame]
	# Facing left = mirror the sprite. The sprite's feet are at the bottom of the collision box.
	draw_set_transform(Vector2(0, H * 0.5 - 14 + 0.5), 0.0, Vector2(facing, 1.0))
	draw_texture(tex, Vector2(-4, 0))
	if _swing > 0.0:   # a quick tool arc in front of you
		var k := _swing / 0.18
		draw_rect(Rect2(Vector2(3, 4 + (1.0 - k) * 4.0), Vector2(3, 1)), Pal.STONE_LIGHT)
	draw_set_transform(Vector2.ZERO)


static func _light_texture() -> Texture2D:
	# A stepped (banded) radial light: chunky 8-bit rings instead of a smooth glow.
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x - size * 0.5, y - size * 0.5).length() / (size * 0.5)
			var a := 0.0
			if d < 0.45:
				a = 1.0
			elif d < 0.7:
				a = 0.6
			elif d < 0.9:
				a = 0.3
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
