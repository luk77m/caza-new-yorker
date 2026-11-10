## Música del menú: si existe res://assets/music/menu.ogg la usa; si no, compone
## en segundo plano un swing de piano al estilo de los años 30 (composición propia).
class_name Music
extends Node

const RATE := 22050
const BPM := 132.0
const FILE := "res://assets/music/menu.ogg"
# acordes por compás (clases de nota MIDI) y su nota grave
const PROG := [["F6", 41, [5, 9, 0, 2]], ["D7", 38, [2, 6, 9, 0]], ["G7", 43, [7, 11, 2, 5]], ["C7", 36, [0, 4, 7, 10]],
	["F6", 41, [5, 9, 0, 2]], ["D7", 38, [2, 6, 9, 0]], ["G7", 43, [7, 11, 2, 5]], ["C7", 36, [0, 4, 7, 10]],
	["Bb6", 46, [10, 2, 5, 7]], ["Bbm6", 46, [10, 1, 5, 7]], ["F6", 41, [5, 9, 0, 2]], ["D7", 38, [2, 6, 9, 0]],
	["Gm7", 43, [7, 10, 2, 5]], ["C7", 36, [0, 4, 7, 10]], ["F6", 41, [5, 9, 0, 2]], ["C7", 36, [0, 4, 7, 10]]]
# ritmos de la melodía: [inicio en pulsos, duración]
const RHYTHMS := [[[0.0, 1.0], [1.0, 0.5], [1.5, 0.5], [2.0, 1.5], [3.5, 0.5]],
	[[0.0, 0.5], [0.5, 0.5], [1.0, 1.0], [2.5, 0.5], [3.0, 1.0]],
	[[0.0, 2.0], [2.0, 0.5], [2.5, 0.5], [3.0, 1.0]],
	[[0.5, 0.5], [1.0, 0.5], [1.5, 0.5], [2.0, 0.5], [2.5, 1.5]]]

var player: AudioStreamPlayer
var stream: AudioStream
var want := false

func _ready() -> void:
	player = AudioStreamPlayer.new()
	add_child(player)
	if ResourceLoader.exists(FILE):
		var s = load(FILE)
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		stream = s
	else:
		WorkerThreadPool.add_task(_generate)

func set_playing(on: bool) -> void:
	want = on
	if on and stream != null and not player.playing:
		player.stream = stream
		player.volume_db = linear_to_db(0.001)
		player.play()

func _process(delta: float) -> void:
	if not player.playing:
		return
	var target := Settings.music if want else 0.0
	var cur := db_to_linear(player.volume_db)
	cur = move_toward(cur, target, delta * 0.6)
	player.volume_db = linear_to_db(maxf(cur, 0.0005))
	if not want and cur <= 0.001:
		player.stop()

func _on_ready(s: AudioStream) -> void:
	stream = s
	set_playing(want)

func _generate() -> void:
	var s := compose()
	call_deferred("_on_ready", s)

static func _f(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)

var _cache := {}

## Una nota de piano: la onda se calcula una vez por altura y se mezcla con su volumen y duración.
func _note(buf: PackedFloat32Array, start: float, dur: float, midi: float, amp: float, decay: float) -> void:
	var key := str(midi) + ":" + str(decay)
	if not _cache.has(key):
		var f := _f(midi)
		var w := TAU * f / RATE
		var det := w * 1.003
		var wave := PackedFloat32Array()
		wave.resize(int(1.4 * RATE))
		for i in wave.size():
			var t := float(i) / RATE
			var ph := w * i
			wave[i] = (1.0 - exp(-t * 160.0)) * exp(-t * decay) * (sin(ph) * 0.6 + sin(det * i) * 0.25 + sin(ph * 2.0) * 0.28 + sin(ph * 3.0) * 0.1)
		_cache[key] = wave
	var wv: PackedFloat32Array = _cache[key]
	var i0 := int(start * RATE)
	var n := mini(int((dur + 0.25) * RATE), wv.size())
	var nd := int(dur * RATE)
	for i in n:
		var k := i0 + i
		if k >= buf.size():
			break
		var rel := 1.0 if i <= nd else exp(-float(i - nd) / RATE * 14.0)
		buf[k] += amp * wv[i] * rel

func compose() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1930
	var beat := 60.0 / BPM
	var bars := PROG.size()
	var total := bars * 4 * beat
	var buf := PackedFloat32Array()
	buf.resize(int(total * RATE) + RATE)
	var swing := func(b: float) -> float:
		# corcheas con swing: la segunda de cada pulso llega más tarde
		var fb := floorf(b)
		return (fb + (0.66 if b - fb >= 0.5 else b - fb)) * beat
	var last := 77
	for bi in bars:
		var ch: Array = PROG[bi]
		var root: int = ch[1]
		var pcs: Array = ch[2]
		var t0 := bi * 4 * beat
		# mano izquierda "stride": bajo en 1 y 3, acorde en 2 y 4
		_note(buf, t0, beat * 0.9, root, 0.32, 3.5)
		_note(buf, t0 + 2 * beat, beat * 0.9, root + 7 if root + 7 <= 52 else root - 5, 0.3, 3.5)
		for b2 in [1, 3]:
			for pc in pcs.slice(0, 3):
				var m: int = 53 + ((int(pc) - 53) % 12 + 12) % 12
				_note(buf, t0 + b2 * beat, beat * 0.45, m, 0.13, 6.0)
		# melodía con notas del acorde y alguna de paso
		var rh: Array = RHYTHMS[rng.randi_range(0, RHYTHMS.size() - 1)] if bi % 4 != 3 else RHYTHMS[2]
		for nt in rh:
			var cands: Array = []
			for pc in pcs:
				for octv in [72, 84]:
					var m2: int = octv + ((int(pc) - octv) % 12 + 12) % 12
					if m2 >= 70 and m2 <= 86:
						cands.append(m2)
			cands.sort_custom(func(a, b): return absi(a - last) < absi(b - last))
			var pick_m: int = cands[mini(rng.randi_range(0, 2), cands.size() - 1)]
			if rng.randf() < 0.18:
				pick_m += 1 if rng.randf() < 0.5 else -1
			last = pick_m
			var st: float = t0 + swing.call(float(nt[0]))
			_note(buf, st, float(nt[1]) * beat * 0.95, pick_m, 0.22, 2.2)
	# gramófono: un poco de siseo y algún chasquido
	var crackle := 0.0
	var peak := 0.001
	for i in buf.size():
		if rng.randf() < 0.0004:
			crackle = rng.randf_range(-0.12, 0.12)
		crackle *= 0.86
		buf[i] += crackle + rng.randf_range(-0.006, 0.006)
		peak = maxf(peak, absf(buf[i]))
	var n := int(total * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var g := 0.8 / peak
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i] * g, -1.0, 1.0) * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = n
	return s
