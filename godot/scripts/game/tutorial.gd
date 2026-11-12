## Partida de práctica guiada: pasos cortos con un objetivo marcado en el mapa.
## Tiene dos partes, una por bando: primero corredor y después cazador. No hay reloj ni consecuencias.
class_name Tutorial
extends RefCounted

var role := "runner"
var step := 0
var start_fl := 1
var target := Vector3(-1, 0, 0)   # planta, x, y (en píxeles); planta < 0 = sin objetivo
var flags := {}
var steps: Array = []

const RUNNER := [
	"PRÁCTICA DE CORREDOR (parte 1 de 2). Aquí no hay reloj ni consecuencias. Muévete con WASD o las flechas hasta el círculo dorado.",
	"Pulsa Tab para abrir tu bloc de notas con los encargos. Vuelve a pulsar Tab para cerrarlo.",
	"Ve al rombo dorado y pulsa E (o haz clic encima) para hacer el encargo de práctica. Cada tipo de encargo tiene su minijuego.",
	"Habla con alguien: acércate a un huésped o a un trabajador y pulsa E. A veces sueltan rumores útiles.",
	"Pulsa Q para cambiar lo que llevas en la mano. Con los puños (clic izquierdo) puedes dejar KO a alguien y escapar.",
	"Los objetos se guardan y se encuentran en los muebles y en los cadáveres. Acércate a un sofá, una mesa o un escritorio y pulsa R. Prueba a dejar una ganzúa y a cogerla otra vez.",
	"Pulsa M para ver el mapa del hotel: el símbolo $ marca a los vendedores (el dorado es el tuyo). Ciérralo con M.",
	"Usa el ascensor: acércate a las puertas doradas, pulsa E y elige otra planta. Las habitaciones ajenas están cerradas: con E en la puerta usas la ganzúa (A/D busca el punto, mantén E para girar; si se atasca, suelta o se rompe).",
	"¡Práctica de corredor terminada! Pulsa Intro para pasar a la práctica de cazador, o Esc para volver al menú.",
]
const HUNTER := [
	"PRÁCTICA DE CAZADOR (parte 2 de 2). Eres policía secreta y tu cartel (arriba a la derecha) enseña a quién buscas. Sigue el círculo dorado hasta tu objetivo.",
	"Mantén el clic derecho para apuntar: pasas a primera persona. Mira la barra de sospecha: sube si alguien te ve con el arma. Suelta el botón para guardarla.",
	"Elimina al objetivo: apunta (clic derecho) y dispara (clic izquierdo). En una partida de verdad hazlo sin testigos, o llamarán a la policía.",
	"Los cuerpos delatan. Pulsa F junto al cadáver para arrastrarlo y F otra vez para soltarlo lejos de las miradas (o E junto a un armario para esconderlo).",
	"Registra el cadáver con R: lo que llevaba encima se queda en él. Cierra con R.",
	"Tu vendedor es el vigilante de la entrada (símbolo $ dorado en el mapa, planta baja). Ve con él y pulsa E: vende balas, ganzúas y trajes limpios.",
	"Si llamas la atención, la central te avisa por el pinganillo; al límite, un botones te hará 3 preguntas sobre el hotel y, si fallas 2, te echan un minuto. Pulsa M y repasa en qué planta está cada sala.",
	"¡Práctica terminada! Pulsa Intro para volver al menú y jugar una partida de verdad.",
]

func begin(w: World, practice: String = "runner") -> void:
	role = practice
	steps = HUNTER if role == "hunter" else RUNNER
	step = 0
	flags = {}
	start_fl = w.human.fl
	if role == "hunter":
		_aim_at_target(w)
		return
	var f: FloorData = Hotel.floors[start_fl]
	var best := Sim._tile_near(f, w.human.tile(), 5.0)
	target = Vector3(start_fl, (best.x + 0.5) * Cfg.TS, (best.y + 0.5) * Cfg.TS)

func text() -> String:
	return steps[mini(step, steps.size() - 1)]

func done() -> bool:
	return step >= steps.size() - 1

func _dummy(w: World) -> Ent:
	if w.targets.is_empty():
		return null
	return w.ent_by_id(int(w.targets[0]))

func _aim_at_target(w: World) -> void:
	var t := _dummy(w)
	target = Vector3(t.fl, t.x, t.y) if t != null else Vector3(-1, 0, 0)

func _body(w: World) -> Items.Corpse:
	for c in w.corpses:
		if not c.chalk:
			return c
	return null

func update(w: World, hud: Hud) -> void:
	var h := w.human
	if h == null or done():
		return
	if role == "hunter":
		_update_hunter(w, hud, h)
	else:
		_update_runner(w, hud, h)

func _update_runner(w: World, hud: Hud, h: Ent) -> void:
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
			if w.flags.has("talked"):
				_next(w)
		4:
			if h.equip != "fist" or w.flags.has("equip"):
				_next(w)
		5:
			if w.flags.has("loot_open"):
				flags["loot"] = true
			if flags.has("loot") and w.flags.has("loot_closed"):
				_next(w)
		6:
			if hud.map_panel.visible:
				flags["map"] = true
			elif flags.has("map"):
				_next(w)
		7:
			var f: FloorData = Hotel.floors[start_fl]
			target = Vector3(start_fl, (f.spawn.x + 0.5) * Cfg.TS, (f.spawn.y - 1.5) * Cfg.TS)
			if h.fl != start_fl:
				_next(w)

func _update_hunter(w: World, hud: Hud, h: Ent) -> void:
	match step:
		0:
			_aim_at_target(w)
			var t := _dummy(w)
			if t == null or not t.alive:
				step = 3
			elif h.fl == t.fl and Vector2(h.x - t.x, h.y - t.y).length() < 6.0 * Cfg.TS:
				_next(w)
		1:
			_aim_at_target(w)
			if h.aim:
				flags["aim"] = int(flags.get("aim", 0)) + 1
			elif int(flags.get("aim", 0)) > 20:
				_next(w)
			var t1 := _dummy(w)
			if t1 == null or not t1.alive:
				step = 3
		2:
			_aim_at_target(w)
			var t2 := _dummy(w)
			if t2 == null or not t2.alive:
				_next(w)
		3:
			var c := _body(w)
			if c == null:
				_next(w)
				return
			target = Vector3(c.fl, c.x, c.y)
			if h.dragging != null:
				flags["drag"] = true
			elif flags.has("drag"):
				w.flags.erase("loot_open")
				w.flags.erase("loot_closed")
				_next(w)
		4:
			var c2 := _body(w)
			if c2 == null or c2.hidden:
				_next(w)
				return
			target = Vector3(c2.fl, c2.x, c2.y)
			if w.flags.has("loot_open") and w.flags.has("loot_closed"):
				_next(w)
		5:
			var v := Heat.vendor_for(w, "hunter")
			if v == null or v.fl < 0:
				_next(w)
				return
			target = Vector3(v.fl, v.x, v.y)
			if w.flags.has("shop"):
				_next(w)
		6:
			if hud.map_panel.visible:
				flags["map"] = true
			elif flags.has("map"):
				_next(w)

func _next(w: World) -> void:
	step += 1
	target = Vector3(-1, 0, 0)
	Sim.ev(w, "task", w.human.fl, w.human.x, w.human.y, {"who": w.human.id})
