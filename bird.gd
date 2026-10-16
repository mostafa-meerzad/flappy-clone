extends CharacterBody2D

const GRAVITY := 1250.0
const FLAP_VEL := -330.0
const MAX_FALL := 480.0
const TILT_DELAY := 0.35
const TILT_SPEED := 480.0

var active: bool = false
var spr: Sprite2D
var base_scale: Vector2 = Vector2.ONE
var since_flap: float = 0.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var tex: Texture2D = load("res://art/bird.png")
	spr = Sprite2D.new()
	spr.texture = tex
	var ts: Vector2 = tex.get_size()
	var us: float = minf(34.0 / ts.x, 24.0 / ts.y)
	base_scale = Vector2(us, us)
	spr.scale = base_scale
	add_child(spr)
	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	col.shape = circle
	add_child(col)

func _physics_process(delta: float) -> void:
	if not active:
		return
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	position.y += velocity.y * delta
	since_flap += delta
	if since_flap >= TILT_DELAY:
		rotation_degrees = minf(rotation_degrees + TILT_SPEED * delta, 90.0)

func flap() -> void:
	velocity.y = FLAP_VEL
	since_flap = 0.0
	rotation_degrees = -25.0
	spr.scale = base_scale * Vector2(1.15, 0.85)
	var tw := create_tween()
	tw.tween_property(spr, "scale", base_scale, 0.1)

func reset(y: float) -> void:
	active = false
	velocity = Vector2.ZERO
	position = Vector2(80.0, y)
	rotation_degrees = 0.0
	since_flap = 0.0
	spr.scale = base_scale
