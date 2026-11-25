## The explorer: runs, jumps and carries a headlamp. Movement reads the move_left / move_right /
## jump input actions (the touch buttons press them, as do the keyboard keys).
## Drawn in code (suit, helmet, backpack); the walk cycle is visual only.
class_name Player
extends CharacterBody2D

## Landed hard: `speed` px/s downward at impact, above the safe speed.
signal hard_landing(speed: float)

const W := 20.0   ## collision box width (px)
const H := 46.0   ## collision box height (px); the origin is its centre

var t: GameTuning
var facing := 1.0
var lamp: PointLight2D
var _air_time := 0.0
var _fall_speed := 0.0
var _walk := 0.0


func setup(tuning: GameTuning) -> void:
	t = tuning
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(W, H)
	shape.shape = rect
	add_child(shape)
	floor_snap_length = 6.0
	# Headlamp: a soft cone of light ahead of the helmet (only visible when it's dark).
	lamp = PointLight2D.new()
	lamp.texture = _lamp_texture()
	lamp.texture_scale = 2.2
	lamp.energy = 1.2
	lamp.color = Color(1.0, 0.95, 0.85)
	lamp.position = Vector2(0, -14)
	add_child(lamp)


func _physics_process(dt: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	var target := dir * t.run_speed
	var accel := t.run_accel if is_on_floor() else t.air_accel
	velocity.x = move_toward(velocity.x, target, accel * dt)
	if dir != 0.0:
		facing = signf(dir)
	# Gravity, with coyote time: a jump still works just after running off a ledge.
	if is_on_floor():
		_air_time = 0.0
	else:
		_air_time += dt
		velocity.y = minf(velocity.y + t.gravity * dt, t.max_fall_speed)
	if Input.is_action_just_pressed("jump") and _air_time <= t.coyote_time:
		velocity.y = -t.jump_speed
		_air_time = t.coyote_time + 1.0
	var was_air := not is_on_floor()
	_fall_speed = velocity.y
	move_and_slide()
	if was_air and is_on_floor() and _fall_speed > t.fall_safe_speed:
		hard_landing.emit(_fall_speed)
	_walk += absf(velocity.x) * dt * 0.06 if is_on_floor() else 0.0
	lamp.position.x = facing * 8.0
	queue_redraw()


## Light level 0..1 of the surroundings: the lamp fades in as it gets dark.
func set_darkness(light_level: float) -> void:
	lamp.energy = clampf((1.0 - light_level) * 1.6, 0.0, 1.4)


func _draw() -> void:
	var f := facing
	var step := sin(_walk) * 5.0 if absf(velocity.x) > 10.0 and is_on_floor() else 0.0
	var suit := Color("e9e6df")
	var trim := Color("e07b39")
	# Legs (swinging) and boots.
	draw_line(Vector2(-4, 8), Vector2(-4 + step, 22), suit, 7.0)
	draw_line(Vector2(4, 8), Vector2(4 - step, 22), suit, 7.0)
	draw_rect(Rect2(-8 + step, 19, 9, 4), Color("4a4a52"))
	draw_rect(Rect2(-1 - step, 19, 9, 4), Color("4a4a52"))
	# Backpack (life support) behind, body, orange trim.
	draw_rect(Rect2(-f * 12 - 5, -12, 10, 20), Color("9aa0ae"))
	draw_rect(Rect2(-9, -12, 18, 22), suit)
	draw_rect(Rect2(-9, -2, 18, 3), trim)
	# Arm swinging opposite the legs.
	draw_line(Vector2(f * 2, -8), Vector2(f * 8 - step * 0.6, 6), suit, 6.0)
	# Helmet with a tinted visor facing the way we walk.
	draw_circle(Vector2(0, -17), 9.0, suit)
	draw_colored_polygon(PackedVector2Array([Vector2(f * 1, -22), Vector2(f * 9, -20), Vector2(f * 9, -13), Vector2(f * 1, -12)]), Color("3a7ca5"))
	draw_circle(Vector2(f * 6, -19), 1.5, Color(1, 1, 1, 0.8))


static func _lamp_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex
