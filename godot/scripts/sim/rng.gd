## Generador aleatorio con semilla, compartido por toda la simulación.
class_name Rng
extends RefCounted

static var gen: RandomNumberGenerator = RandomNumberGenerator.new()

static func seed_with(n: int) -> void:
	gen.seed = n if n != 0 else 1

static func rnd() -> float:
	return gen.randf()

static func ri(a: int, b: int) -> int:
	return gen.randi_range(a, b)

static func pick(a: Array) -> Variant:
	if a.is_empty():
		return null
	return a[gen.randi_range(0, a.size() - 1)]

static func shuffle(a: Array) -> Array:
	for i in range(a.size() - 1, 0, -1):
		var j := gen.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp
	return a
