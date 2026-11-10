## Tutorial guiado: pasos cortos con un objetivo marcado en el mapa.
class_name Tutorial
extends RefCounted

var step := 0
var start_fl := 1
var target := Vector3.ZERO   # planta, x, y (en píxeles); planta < 0 = sin objetivo
var flags := {}

const STEPS := [
	"Muévete con WASD o las flechas hasta el círculo dorado.",
	"Pulsa Tab para abrir tu bloc de notas con los encargos. Vuelve a pulsar Tab para cerrarlo.",
	"Ve al rombo dorado y pulsa E (o haz clic encima) para hacer el encargo de práctica. Supera el minijuego.",
	"Habla con alguien: acércate a un huésped o a un trabajador y pulsa E. A veces sueltan rumores útiles.",
	"Pulsa Q para cambiar lo que llevas en la mano. Con los puños (clic izquierdo) puedes dejar KO a alguien y escapar.",
	"Pulsa M para ver el mapa del hotel. Ciérralo con M.",
	"Usa el ascensor: acércate a las puertas doradas, pulsa E y elige otra planta.",
	"¡Listo! Ya sabes lo básico. Pulsa Esc y vuelve al menú para jugar una partida de verdad.",
]

func begin(w: World) -> void:
	step = 0
	start_fl = w.human.fl
	var f: FloorData = Hotel.floors[start_fl]
	var me := w.human.tile()
	var best: Vector2i = f.tiles_pub[0]
	var bd := 1e9
	for t in f.tiles_pub:
		var d := absf(Vector2(t.x - me.x, t.y - me.y).length() - 5.0)
		if d < bd:
			bd = d
			best = t
	target = Vector3(start_fl, (best.x + 0.5) * Cfg.TS, (best.y + 0.5) * Cfg.TS)

func text() -> String:
	return STEPS[mini(step, STEPS.size() - 1)]

func done() -> bool:
	return step >= STEPS.size() - 1

func update(w: World, hud: Hud) -> void:
	var h := w.human
	if h == null:
		return
	match step:
		0:
			if h.fl == int(target.x) and Vector2(h.x - target.y, h.y - target.z).length() < 40:
				_next(w)
		1:
			if hud.notes_panel.visible:
				flags["notes"] = true
			elif flags.has("notes"):
				_next(w)
		2:
			var t: Task = h.tasks[0] if not h.tasks.is_empty() else null
			if t != null:
				target = Vector3(t.fl, (t.x + 0.5) * Cfg.TS, (t.y + 0.5) * Cfg.TS)
			if t == null or t.done:
				_next(w)
		3:
			target = Vector3(-1, 0, 0)
			if w.flags.has("talked"):
				_next(w)
		4:
			if h.equip != "fist" or w.flags.has("equip"):
				_next(w)
		5:
			if hud.map_panel.visible:
				flags["map"] = true
			elif flags.has("map"):
				_next(w)
		6:
			var f: FloorData = Hotel.floors[start_fl]
			target = Vector3(start_fl, (f.spawn.x + 0.5) * Cfg.TS, (f.spawn.y - 1.5) * Cfg.TS)
			if h.fl != start_fl:
				target = Vector3(-1, 0, 0)
				_next(w)

func _next(w: World) -> void:
	step += 1
	target = Vector3(-1, 0, 0)
	Sim.ev(w, "task", w.human.fl, w.human.x, w.human.y, {"who": w.human.id})
