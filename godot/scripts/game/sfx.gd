## Sonidos generados por código (no hace falta ningún fichero de audio).
class_name Sfx
extends Node

const RATE := 22050
var streams := {}
var players: Array = []
var _noise := RandomNumberGenerator.new()

func _ready() -> void:
	_noise.seed = 1930
	_build()
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)

## Reproduce un sonido; gain entre 0 y 1.
func play(nm: String, gain: float = 1.0, pitch: float = 1.0) -> void:
	if gain <= 0.01 or not streams.has(nm):
		return
	for p in players:
		var ap := p as AudioStreamPlayer
		if not ap.playing:
			ap.stream = streams[nm]
			ap.volume_db = linear_to_db(clampf(gain, 0.0, 1.5))
			ap.pitch_scale = pitch
			ap.play()
			return

func _n() -> float:
	return _noise.randf() * 2.0 - 1.0

func _wav(dur: float, fn: Callable) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var v: float = fn.call(t, float(i) / n)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s

func _build() -> void:
	streams["step"] = _wav(0.07, func(t, p): return _n() * exp(-t * 70.0) * 0.45 + sin(TAU * 90.0 * t) * exp(-t * 60.0) * 0.4)
	streams["shot"] = _wav(0.25, func(t, p): return _n() * exp(-t * 28.0) * 0.55 + sin(TAU * 85.0 * t) * exp(-t * 22.0) * 0.5)
	streams["shot_police"] = _wav(0.7, func(t, p): return _n() * exp(-t * 9.0) * 0.95 + sin(TAU * 55.0 * t) * exp(-t * 7.0) * 0.7)
	streams["swing"] = _wav(0.2, func(t, p): return _n() * sin(PI * p) * 0.35)
	streams["stab"] = _wav(0.18, func(t, p): return sin(TAU * 110.0 * t) * exp(-t * 28.0) * 0.8 + _n() * exp(-t * 55.0) * 0.3)
	streams["task"] = _wav(0.7, func(t, p): return sin(TAU * 880.0 * t) * exp(-t * 6.0) * 0.4 + sin(TAU * 1320.0 * t) * exp(-t * 8.0) * 0.22)
	streams["cash"] = _wav(0.28, func(t, p): return sin(TAU * (1250.0 if t < 0.09 else 1680.0) * t) * exp(-fmod(t, 0.09) * 25.0) * 0.35)
	streams["pick"] = _wav(0.16, func(t, p): return sin(TAU * 720.0 * t) * exp(-t * 22.0) * 0.4)
	streams["door"] = _wav(0.16, func(t, p): return _n() * exp(-t * 90.0) * 0.6 + sin(TAU * 320.0 * t) * exp(-t * 35.0) * 0.4)
	streams["empty"] = _wav(0.07, func(t, p): return sin(TAU * 2100.0 * t) * exp(-t * 110.0) * 0.5)
	streams["alarm"] = _wav(2.2, func(t, p): return (1.0 if sin(TAU * 760.0 * t) > 0 else -1.0) * 0.18 * (1.0 if fmod(t, 0.25) < 0.14 else 0.0) * (1.0 - p * 0.3))
	streams["blackout"] = _wav(1.1, func(t, p): return sin(TAU * (120.0 * t - 45.0 * t * t)) * (1.0 - p) * 0.5 + _n() * exp(-t * 30.0) * 0.4)
	streams["elev"] = _wav(1.3, func(t, p): return sin(TAU * 1046.0 * t) * exp(-t * 4.0) * 0.3 + (sin(TAU * 784.0 * t) * exp(-(t - 0.35) * 4.0) * 0.3 if t > 0.35 else 0.0))
	streams["sparks"] = _wav(1.3, func(t, p): return _n() * (1.0 if _noise.randf() < 0.25 else 0.15) * exp(-t * 1.8) * 0.6)
	streams["call"] = _wav(0.9, func(t, p): return (sin(TAU * 440.0 * t) + sin(TAU * 480.0 * t)) * 0.18 * (1.0 if fmod(t, 0.3) < 0.18 else 0.0))
	streams["ui"] = _wav(0.05, func(t, p): return sin(TAU * 1500.0 * t) * exp(-t * 90.0) * 0.3)
	streams["buy"] = streams["cash"]
