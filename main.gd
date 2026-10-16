extends Node2D

const VW := 288.0
const VH := 512.0
const GROUND_Y := 400.0
const SCROLL := 120.0
const SPAWN_INTERVAL := 1.45
const BIRD_X := 80.0
const BIRD_START_Y := 200.0
const SAVE_PATH := "user://save.cfg"
const RING_SCORE := 3
const FIRE_STREAK := 5
const FIRE_SCORE := 2
const PERFECT_PITCH := 1.5
const PERFECT_POP := 1.35
const PERFECT_FADE := 0.6
const PERFECT_RISE := 26.0
const PERFECT_OFFSET := Vector2(18.0, -22.0)
const FIRE_TINT := Color(1.0, 0.76, 0.52)
const FIRE_TRAIL_OFFSET := Vector2(-18.0, 2.0)

const BirdScript := preload("res://bird.gd")
const PipeScript := preload("res://pipe_pair.gd")
const SfxScript := preload("res://sfx.gd")

enum State {READY, PLAYING, DEAD, GAME_OVER}

var state: int = State.READY
var score: int = 0
var best: int = 0
var is_new_best: bool = false
var spawn_t: float = 0.0
var bob_t: float = 0.0
var shake_t: float = 0.0
var over_t: float = 0.0
var last_gap: float = 220.0
var die_played: bool = false
var streak: int = 0
var on_fire: bool = false

var vr: Vector2 = Vector2(288.0, 512.0)
var sky: TextureRect
var sky_tex: GradientTexture2D
var ground: ColorRect
var hills: Array = []
var bands: Array = []

var perfect_lbl: Label
var fire: CPUParticles2D

var bird
var sfx
var cam: Camera2D
var pipes: Node2D
var scrollers: Array = []
var flash: ColorRect
var score_lbl: Label
var tap_lbl: Label
var panel: Panel
var score_val: Label
var best_val: Label
var medal_lbl: Label
var new_lbl: Label
var btn: Button

func _ready() -> void:
	randomize()
	_load_best()
	vr = get_viewport().get_visible_rect().size
	_build_world()
	_build_ui()
	_relayout()
	get_viewport().size_changed.connect(_relayout)
	sfx = SfxScript.new()
	add_child(sfx)
	_enter_ready()

# ---------- world ----------

func _build_world() -> void:
	sky = TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.42, 0.75, 0.93))
	grad.set_color(1, Color(0.78, 0.94, 0.95))
	sky_tex = GradientTexture2D.new()
	sky_tex.gradient = grad
	sky_tex.fill_from = Vector2(0, 0)
	sky_tex.fill_to = Vector2(0, 1)
	sky_tex.width = int(vr.x)
	sky_tex.height = int(vr.y)
	sky.texture = sky_tex
	sky.position = Vector2.ZERO
	sky.size = vr
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.z_index = -100
	add_child(sky)

	var hill_defs := [
		{"amp": 46.0, "base": 360.0, "col": Color(0.52, 0.80, 0.62), "phase": 0.0},
		{"amp": 30.0, "base": 392.0, "col": Color(0.40, 0.70, 0.50), "phase": 2.1},
	]
	for d in hill_defs:
		for copy in 2:
			var poly := Polygon2D.new()
			poly.polygon = _hill_points(float(d["amp"]), float(d["base"]), float(d["phase"]))
			poly.color = d["col"]
			poly.position = Vector2(vr.x * float(copy), 0.0)
			poly.z_index = -90
			add_child(poly)
			hills.append({"node": poly, "amp": float(d["amp"]), "base": float(d["base"]), "phase": float(d["phase"])})
			scrollers.append({"node": poly, "speed": SCROLL * 0.3})

	pipes = Node2D.new()
	add_child(pipes)

	ground = ColorRect.new()
	ground.color = Color(0.87, 0.78, 0.50)
	ground.position = Vector2(0.0, GROUND_Y)
	ground.size = Vector2(vr.x, vr.y - GROUND_Y)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.z_index = 0
	add_child(ground)

	for copy in 2:
		var band := Node2D.new()
		band.position = Vector2(vr.x * float(copy), GROUND_Y)
		band.z_index = 1
		for i in 40:
			var dash := ColorRect.new()
			dash.color = Color(0.64, 0.56, 0.32)
			dash.position = Vector2(float(i) * 24.0, 0.0)
			dash.size = Vector2(14.0, 10.0)
			dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
			band.add_child(dash)
		add_child(band)
		bands.append(band)
		scrollers.append({"node": band, "speed": SCROLL})

	bird = BirdScript.new()
	bird.z_index = 5
	add_child(bird)
	bird.reset(BIRD_START_Y)

	fire = CPUParticles2D.new()
	fire.emitting = false
	fire.amount = 48
	fire.lifetime = 0.5
	fire.position = FIRE_TRAIL_OFFSET
	fire.direction = Vector2(-1.0, 0.0)
	fire.spread = 18.0
	fire.initial_velocity_min = 60.0
	fire.initial_velocity_max = 130.0
	fire.scale_amount_min = 2.0
	fire.scale_amount_max = 4.5
	fire.damping_min = 40.0
	fire.damping_max = 90.0
	var fire_grad := Gradient.new()
	fire_grad.set_color(0, Color(1.0, 0.95, 0.35, 1.0))
	fire_grad.set_color(1, Color(1.0, 0.35, 0.05, 0.0))
	fire.color_ramp = fire_grad
	bird.add_child(fire)

	cam = Camera2D.new()
	cam.position = vr * 0.5
	add_child(cam)

func _relayout() -> void:
	vr = get_viewport().get_visible_rect().size
	sky.size = vr
	sky_tex.width = int(vr.x)
	sky_tex.height = int(vr.y)
	for h in hills:
		var poly: Polygon2D = h["node"]
		poly.polygon = _hill_points(float(h["amp"]), float(h["base"]), float(h["phase"]))
	ground.size = Vector2(vr.x, maxf(vr.y - GROUND_Y, 0.0))
	cam.position = vr * 0.5
	score_lbl.size.x = vr.x
	score_lbl.pivot_offset.x = vr.x * 0.5
	tap_lbl.size.x = vr.x
	flash.size = vr
	panel.position.x = (vr.x - panel.size.x) * 0.5
	if state != State.GAME_OVER:
		panel.position.y = vr.y + 20.0
	var i := 0
	for b in bands:
		var node: Node2D = b
		if state != State.PLAYING:
			node.position = Vector2(vr.x * float(i), GROUND_Y)
		i += 1
	for s in scrollers:
		var n: Node2D = s["node"]
		while n.position.x <= -vr.x:
			n.position.x += vr.x * 2.0


func _hill_points(amp: float, base_y: float, phase: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 20
	for i in steps + 1:
		var t := float(i) / float(steps)
		pts.append(Vector2(t * vr.x, base_y - amp * (0.5 + 0.5 * sin(t * TAU + phase))))
	pts.append(Vector2(vr.x, vr.y))
	pts.append(Vector2(0.0, vr.y))
	return pts

# ---------- ui ----------

func _big(size: int, outline: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.12))
	l.add_theme_constant_override("outline_size", outline)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	score_lbl = _big(44, 8)
	score_lbl.position = Vector2(0.0, 26.0)
	score_lbl.size = Vector2(vr.x, 56.0)
	score_lbl.pivot_offset = Vector2(vr.x * 0.5, 28.0)
	score_lbl.text = "0"
	layer.add_child(score_lbl)

	tap_lbl = _big(18, 5)
	tap_lbl.position = Vector2(0.0, 280.0)
	tap_lbl.size = Vector2(vr.x, 30.0)
	tap_lbl.text = "TAP TO START"
	layer.add_child(tap_lbl)

	panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.99, 0.95, 0.80)
	sb.border_color = Color(0.55, 0.45, 0.28)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	panel.size = Vector2(208.0, 182.0)
	panel.position = Vector2((vr.x - 208.0) * 0.5, vr.y + 20.0)
	layer.add_child(panel)

	var title := _big(20, 0)
	title.add_theme_color_override("font_color", Color(0.35, 0.28, 0.16))
	title.position = Vector2(0.0, 10.0)
	title.size = Vector2(208.0, 26.0)
	title.text = "GAME OVER"
	panel.add_child(title)

	score_val = _big(16, 0)
	score_val.add_theme_color_override("font_color", Color(0.35, 0.28, 0.16))
	score_val.position = Vector2(0.0, 44.0)
	score_val.size = Vector2(208.0, 22.0)
	panel.add_child(score_val)

	best_val = _big(16, 0)
	best_val.add_theme_color_override("font_color", Color(0.35, 0.28, 0.16))
	best_val.position = Vector2(0.0, 66.0)
	best_val.size = Vector2(208.0, 22.0)
	panel.add_child(best_val)

	medal_lbl = _big(16, 0)
	medal_lbl.add_theme_color_override("font_color", Color(0.72, 0.45, 0.10))
	medal_lbl.position = Vector2(0.0, 90.0)
	medal_lbl.size = Vector2(208.0, 22.0)
	panel.add_child(medal_lbl)

	new_lbl = _big(14, 0)
	new_lbl.add_theme_color_override("font_color", Color(0.85, 0.20, 0.20))
	new_lbl.position = Vector2(0.0, 110.0)
	new_lbl.size = Vector2(208.0, 20.0)
	new_lbl.text = "NEW!"
	new_lbl.visible = false
	panel.add_child(new_lbl)

	btn = Button.new()
	btn.text = "RESTART"
	btn.position = Vector2(44.0, 136.0)
	btn.size = Vector2(120.0, 34.0)
	btn.pressed.connect(_on_restart)
	panel.add_child(btn)

	perfect_lbl = _big(13, 4)
	perfect_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	perfect_lbl.size = Vector2(80.0, 18.0)
	perfect_lbl.pivot_offset = Vector2(40.0, 9.0)
	perfect_lbl.text = "PERFECT"
	perfect_lbl.modulate.a = 0.0
	perfect_lbl.z_index = 10
	add_child(perfect_lbl)

	flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.position = Vector2.ZERO
	flash.size = vr
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)

# ---------- state ----------

func _enter_ready() -> void:
	state = State.READY
	score = 0
	spawn_t = 0.0
	bob_t = 0.0
	over_t = 0.0
	shake_t = 0.0
	die_played = false
	is_new_best = false
	last_gap = 220.0
	_end_fire()
	streak = 0
	perfect_lbl.modulate.a = 0.0
	score_lbl.text = "0"
	score_lbl.visible = true
	tap_lbl.visible = true
	new_lbl.visible = false
	panel.position = Vector2((vr.x - panel.size.x) * 0.5, vr.y + 20.0)
	flash.color = Color(1, 1, 1, 0)
	for p in pipes.get_children():
		p.queue_free()
	bird.reset(BIRD_START_Y)

func _start() -> void:
	state = State.PLAYING
	tap_lbl.visible = false
	bird.active = true
	bird.flap()
	sfx.play("flap")

func _die() -> void:
	if state != State.PLAYING:
		return
	state = State.DEAD
	_end_fire()
	streak = 0
	sfx.play("hit")
	shake_t = 0.25
	flash.color = Color(1, 1, 1, 0.8)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.2)
	for p in pipes.get_children():
		p.moving = false

func _enter_game_over() -> void:
	state = State.GAME_OVER
	over_t = 0.0
	if score > best:
		best = score
		is_new_best = true
		_save_best()
	score_val.text = "SCORE  %d" % score
	best_val.text = "BEST  %d" % best
	medal_lbl.text = _medal(score)
	new_lbl.visible = is_new_best
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(panel, "position:y", 150.0, 0.4)

func _medal(s: int) -> String:
	if s >= 40:
		return "PLATINUM"
	if s >= 30:
		return "GOLD"
	if s >= 20:
		return "SILVER"
	if s >= 10:
		return "BRONZE"
	return "NO MEDAL"

func _on_restart() -> void:
	if state == State.GAME_OVER and over_t >= 0.5:
		_enter_ready()

# ---------- loop ----------

func _process(delta: float) -> void:
	if shake_t > 0.0:
		shake_t -= delta
		cam.offset = Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
	elif cam.offset != Vector2.ZERO:
		cam.offset = Vector2.ZERO

	if state == State.READY:
		bob_t += delta
		bird.position = Vector2(BIRD_X, BIRD_START_Y + sin(bob_t * 3.0) * 4.0)
	elif state == State.PLAYING:
		_scroll(delta)
		spawn_t += delta
		if spawn_t >= SPAWN_INTERVAL:
			spawn_t -= SPAWN_INTERVAL
			_spawn_pipe()
		if bird.position.y >= GROUND_Y - 10.0 or bird.position.y < 0.0:
			_die()
	elif state == State.DEAD:
		if bird.position.y >= GROUND_Y - 12.0:
			bird.position.y = GROUND_Y - 12.0
			bird.active = false
			if not die_played:
				die_played = true
				sfx.play("die")
				_enter_game_over()
	elif state == State.GAME_OVER:
		over_t += delta

func _scroll(delta: float) -> void:
	for s in scrollers:
		var n: Node2D = s["node"]
		n.position.x -= float(s["speed"]) * delta
		if n.position.x <= -vr.x:
			n.position.x += vr.x * 2.0

func _spawn_pipe() -> void:
	var target := randf_range(140.0, 300.0)
	var gap_center := clampf(target, last_gap - 120.0, last_gap + 120.0)
	last_gap = gap_center
	var p = PipeScript.new()
	p.position = Vector2(vr.x + 30.0, 0.0)
	pipes.add_child(p)
	p.setup(gap_center)
	p.scored.connect(_on_scored)
	p.ring_taken.connect(_on_ring_taken)
	p.body_entered.connect(_on_pipe_hit)

func _on_pipe_hit(_body: Node2D) -> void:
	_die()

func _on_scored(perfect: bool) -> void:
	if perfect:
		streak += 1
		_show_perfect()
	else:
		streak = 0
		_end_fire()
	if streak >= FIRE_STREAK and not on_fire:
		_start_fire()
	score += FIRE_SCORE if on_fire else 1
	score_lbl.text = str(score)
	sfx.play("point", PERFECT_PITCH if perfect else 1.0)
	score_lbl.scale = Vector2(1.25, 1.25)
	var tw := create_tween()
	tw.tween_property(score_lbl, "scale", Vector2.ONE, 0.15)

func _on_ring_taken() -> void:
	score += RING_SCORE
	score_lbl.text = str(score)
	sfx.play("chime")
	score_lbl.scale = Vector2(1.25, 1.25)
	var tw := create_tween()
	tw.tween_property(score_lbl, "scale", Vector2.ONE, 0.15)

func _show_perfect() -> void:
	perfect_lbl.position = bird.position + PERFECT_OFFSET - perfect_lbl.pivot_offset
	perfect_lbl.modulate.a = 1.0
	perfect_lbl.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(perfect_lbl, "scale", Vector2(PERFECT_POP, PERFECT_POP), 0.12)
	tw.chain().tween_property(perfect_lbl, "scale", Vector2.ONE, 0.1)
	tw.parallel().tween_property(perfect_lbl, "modulate:a", 0.0, PERFECT_FADE)
	tw.parallel().tween_property(perfect_lbl, "position:y",
		perfect_lbl.position.y - PERFECT_RISE, PERFECT_FADE)

func _start_fire() -> void:
	on_fire = true
	fire.emitting = true
	bird.modulate = FIRE_TINT
	sfx.play("whoosh")

func _end_fire() -> void:
	if not on_fire:
		return
	on_fire = false
	fire.emitting = false
	bird.modulate = Color.WHITE

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("flap"):
		return
	if state == State.READY:
		_start()
	elif state == State.PLAYING:
		bird.flap()
		sfx.play("flap")
	elif state == State.GAME_OVER and over_t >= 0.5:
		_enter_ready()

# ---------- save ----------

func _load_best() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		best = int(cf.get_value("score", "best", 0))

func _save_best() -> void:
	var cf := ConfigFile.new()
	cf.set_value("score", "best", best)
	cf.save(SAVE_PATH)
