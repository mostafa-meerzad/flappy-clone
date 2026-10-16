extends Node

const RATE := 22050

var streams: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var idx: int = 0

func _ready() -> void:
	for i in 4:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	streams["flap"] = _make_flap()
	streams["point"] = _make_point()
	streams["hit"] = _make_hit()
	streams["die"] = _make_die()
	streams["whoosh"] = _make_whoosh()
	streams["chime"] = _make_chime()

func play(id: String, pitch: float = 1.0) -> void:
	if not streams.has(id):
		return
	var p: AudioStreamPlayer = players[idx]
	idx = (idx + 1) % players.size()
	p.stream = streams[id]
	p.pitch_scale = pitch
	p.play()

func _wav(s: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

func _n(dur: float) -> int:
	return int(dur * float(RATE))

func _make_flap() -> AudioStreamWAV:
	var total := _n(0.08)
	var s := PackedFloat32Array()
	s.resize(total)
	var phase := 0.0
	var held := 0.0
	for i in total:
		var t := float(i) / float(total)
		var freq := 200.0 + 700.0 * t
		phase += freq / float(RATE)
		if phase >= 1.0:
			phase -= 1.0
			held = randf_range(-1.0, 1.0)
		s[i] = held * (1.0 - t) * 0.5
	return _wav(s)

func _make_point() -> AudioStreamWAV:
	var seg := _n(0.07)
	var s := PackedFloat32Array()
	s.resize(seg * 2)
	var freqs := [988.0, 1319.0]
	for k in 2:
		var f: float = freqs[k]
		var phase := 0.0
		for i in seg:
			var t := float(i) / float(seg)
			phase += f / float(RATE)
			var sq := 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			s[k * seg + i] = sq * (1.0 - t * 0.8) * 0.28
	return _wav(s)

func _make_hit() -> AudioStreamWAV:
	var total := _n(0.15)
	var s := PackedFloat32Array()
	s.resize(total)
	var phase := 0.0
	for i in total:
		var t := float(i) / float(total)
		var freq := 120.0 - 60.0 * t
		phase += freq / float(RATE)
		var ph := fmod(phase, 1.0)
		var tri := 2.0 * absf(2.0 * (ph - 0.5)) - 1.0
		var env := pow(1.0 - t, 1.5)
		s[i] = (tri * 0.6 + randf_range(-1.0, 1.0) * 0.4) * env * 0.6
	return _wav(s)

func _make_chime() -> AudioStreamWAV:
	var total := _n(0.3)
	var s := PackedFloat32Array()
	s.resize(total)
	var partials := [1568.0, 2349.0, 3136.0]
	var gains := [0.5, 0.3, 0.18]
	for i in total:
		var t := float(i) / float(total)
		var v := 0.0
		for k in partials.size():
			var f: float = partials[k]
			v += sin(float(i) * f / float(RATE) * TAU) * float(gains[k])
		s[i] = v * pow(1.0 - t, 2.2) * 0.6
	return _wav(s)

func _make_whoosh() -> AudioStreamWAV:
	var total := _n(0.25)
	var s := PackedFloat32Array()
	s.resize(total)
	var lp := 0.0
	for i in total:
		var t := float(i) / float(total)
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.06 + 0.5 * t)
		var env := sin(t * PI)
		s[i] = lp * env * 0.7
	return _wav(s)

func _make_die() -> AudioStreamWAV:
	var total := _n(0.4)
	var s := PackedFloat32Array()
	s.resize(total)
	var phase := 0.0
	for i in total:
		var t := float(i) / float(total)
		var freq := 600.0 - 450.0 * t
		phase += freq / float(RATE)
		s[i] = sin(phase * TAU) * pow(1.0 - t, 0.8) * 0.45
	return _wav(s)
