extends Area2D

signal scored(perfect: bool)
signal ring_taken

const PIPE_W := 52.0
const GAP := 120.0
const BODY_LEN := 520.0
# Opaque art inside the 1200x1200 canvas: shaft x 480-755, cap x 468-767 (y 700-840).
const CAP_REGION := Rect2(468.0, 700.0, 300.0, 140.0)
const SHAFT_REGION := Rect2(468.0, 300.0, 300.0, 100.0)

const PERFECT_WINDOW := 20.0
const RING_CHANCE := 0.25
const RING_RADIUS := 15.0
const RING_WIDTH := 4.0
const RING_SEGMENTS := 24
const RING_OFFSET := 25.0
const RING_PULSE := 1.14
const RING_PULSE_TIME := 0.55
const RING_COLOR := Color(1.0, 0.84, 0.22)
const SPARK_AMOUNT := 28
const SPARK_LIFETIME := 0.45

var gap_y: float = 0.0
var ring: Area2D
var ring_line: Line2D
var sparks: CPUParticles2D
var ring_done: bool = false
var speed: float = 120.0
var moving: bool = true
var counted: bool = false

func setup(gap_center: float) -> void:
	gap_y = gap_center
	collision_layer = 0
	collision_mask = 1
	monitorable = false
	z_index = -10
	var tex: Texture2D = load("res://art/pipe.png")
	var s := PIPE_W / CAP_REGION.size.x
	var cap_h := CAP_REGION.size.y * s

	# Top pipe: cap end sits exactly on the upper gap edge, body runs off the top.
	var top_edge := gap_center - GAP * 0.5
	_add_sprite(tex, CAP_REGION, Vector2(s, s), Vector2(0.0, top_edge - cap_h * 0.5), false)
	_add_sprite(tex, SHAFT_REGION, Vector2(s, BODY_LEN / SHAFT_REGION.size.y),
		Vector2(0.0, top_edge - cap_h - BODY_LEN * 0.5), false)
	_add_shape(Vector2(0.0, top_edge - (cap_h + BODY_LEN) * 0.5), cap_h + BODY_LEN)

	# Bottom pipe: same art flipped vertically.
	var bot_edge := gap_center + GAP * 0.5
	_add_sprite(tex, CAP_REGION, Vector2(s, s), Vector2(0.0, bot_edge + cap_h * 0.5), true)
	_add_sprite(tex, SHAFT_REGION, Vector2(s, BODY_LEN / SHAFT_REGION.size.y),
		Vector2(0.0, bot_edge + cap_h + BODY_LEN * 0.5), true)
	_add_shape(Vector2(0.0, bot_edge + (cap_h + BODY_LEN) * 0.5), cap_h + BODY_LEN)

	var zone := Area2D.new()
	zone.collision_layer = 0
	zone.collision_mask = 1
	zone.monitorable = false
	zone.position = Vector2(PIPE_W * 0.5 + 4.0, gap_center)
	var zc := CollisionShape2D.new()
	var zr := RectangleShape2D.new()
	zr.size = Vector2(8.0, GAP)
	zc.shape = zr
	zone.add_child(zc)
	zone.body_entered.connect(_on_zone_entered)
	add_child(zone)

	if randf() < RING_CHANCE:
		_add_ring(gap_center + randf_range(-RING_OFFSET, RING_OFFSET))

func _add_ring(y: float) -> void:
	ring = Area2D.new()
	ring.collision_layer = 0
	ring.collision_mask = 1
	ring.monitorable = false
	ring.position = Vector2(0.0, y)
	ring.z_index = -9

	ring_line = Line2D.new()
	var pts := PackedVector2Array()
	for i in RING_SEGMENTS + 1:
		var a := float(i) / float(RING_SEGMENTS) * TAU
		pts.append(Vector2(cos(a), sin(a)) * RING_RADIUS)
	ring_line.points = pts
	ring_line.closed = true
	ring_line.width = RING_WIDTH
	ring_line.default_color = RING_COLOR
	ring_line.joint_mode = Line2D.LINE_JOINT_ROUND
	ring.add_child(ring_line)

	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RING_RADIUS
	cs.shape = circle
	ring.add_child(cs)

	sparks = CPUParticles2D.new()
	sparks.emitting = false
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = SPARK_AMOUNT
	sparks.lifetime = SPARK_LIFETIME
	sparks.spread = 180.0
	sparks.gravity = Vector2(0.0, 120.0)
	sparks.initial_velocity_min = 60.0
	sparks.initial_velocity_max = 170.0
	sparks.scale_amount_min = 1.0
	sparks.scale_amount_max = 2.5
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.97, 0.7, 1.0))
	grad.set_color(1, Color(1.0, 0.72, 0.1, 0.0))
	sparks.color_ramp = grad
	ring.add_child(sparks)

	ring.body_entered.connect(_on_ring_entered)
	add_child(ring)

	var tw := ring_line.create_tween()
	tw.set_loops()
	tw.tween_property(ring_line, "scale", Vector2(RING_PULSE, RING_PULSE), RING_PULSE_TIME)
	tw.tween_property(ring_line, "scale", Vector2.ONE, RING_PULSE_TIME)

func _on_ring_entered(_body: Node2D) -> void:
	if ring_done:
		return
	ring_done = true
	ring_line.visible = false
	ring.set_deferred("monitoring", false)
	sparks.emitting = true
	ring_taken.emit()

func _add_sprite(tex: Texture2D, region: Rect2, spr_scale: Vector2, pos: Vector2, flip: bool) -> void:
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.region_enabled = true
	spr.region_rect = region
	spr.scale = spr_scale
	spr.position = pos
	spr.flip_v = flip
	add_child(spr)

func _add_shape(pos: Vector2, height: float) -> void:
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(PIPE_W, height)
	cs.shape = rect
	cs.position = pos
	add_child(cs)

func _on_zone_entered(body: Node2D) -> void:
	if counted:
		return
	counted = true
	var dy: float = absf(body.global_position.y - global_position.y - gap_y)
	scored.emit(dy <= PERFECT_WINDOW)

func _process(delta: float) -> void:
	if not moving:
		return
	position.x -= speed * delta
	if position.x < -PIPE_W - 20.0:
		queue_free()
