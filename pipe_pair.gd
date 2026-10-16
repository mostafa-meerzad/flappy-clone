extends Area2D

signal scored

const PIPE_W := 52.0
const GAP := 120.0
const BODY_LEN := 520.0
# Opaque art inside the 1200x1200 canvas: shaft x 480-755, cap x 468-767 (y 700-840).
const CAP_REGION := Rect2(468.0, 700.0, 300.0, 140.0)
const SHAFT_REGION := Rect2(468.0, 300.0, 300.0, 100.0)

var speed: float = 120.0
var moving: bool = true
var counted: bool = false

func setup(gap_center: float) -> void:
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

func _on_zone_entered(_body: Node2D) -> void:
	if counted:
		return
	counted = true
	scored.emit()

func _process(delta: float) -> void:
	if not moving:
		return
	position.x -= speed * delta
	if position.x < -PIPE_W - 20.0:
		queue_free()
