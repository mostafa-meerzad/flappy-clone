extends Area2D

signal scored

const PIPE_W := 52.0
const GAP := 110.0
const PIPE_LEN := 420.0

var speed: float = 120.0
var moving: bool = true
var counted: bool = false

func setup(gap_center: float) -> void:
	collision_layer = 0
	collision_mask = 1
	monitorable = false
	z_index = -10
	var tex: Texture2D = load("res://art/pipe.png")
	var ts: Vector2 = tex.get_size()
	var spr_scale := Vector2(PIPE_W / ts.x, PIPE_LEN / ts.y)

	var bottom := Sprite2D.new()
	bottom.texture = tex
	bottom.scale = spr_scale
	bottom.position = Vector2(0.0, gap_center + GAP * 0.5 + PIPE_LEN * 0.5)
	add_child(bottom)

	var top := Sprite2D.new()
	top.texture = tex
	top.scale = spr_scale
	top.flip_v = true
	top.position = Vector2(0.0, gap_center - GAP * 0.5 - PIPE_LEN * 0.5)
	add_child(top)

	var cap_s := PIPE_W / ts.x
	var cap_h := ts.y * cap_s

	var bcap := Sprite2D.new()
	bcap.texture = tex
	bcap.scale = Vector2(cap_s, cap_s)
	bcap.position = Vector2(0.0, gap_center + GAP * 0.5 + cap_h * 0.5)
	add_child(bcap)

	var tcap := Sprite2D.new()
	tcap.texture = tex
	tcap.scale = Vector2(cap_s, cap_s)
	tcap.flip_v = true
	tcap.position = Vector2(0.0, gap_center - GAP * 0.5 - cap_h * 0.5)
	add_child(tcap)

	_add_shape(bottom.position)
	_add_shape(top.position)

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

func _add_shape(pos: Vector2) -> void:
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(PIPE_W, PIPE_LEN)
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
