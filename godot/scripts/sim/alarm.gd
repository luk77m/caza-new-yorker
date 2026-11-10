## Niveles de alarma por matar policías: cacheos y esposas (1), federales (2) y Bluegeddon (3).
class_name Alarm
extends RefCounted

const TS := Cfg.TS
const SIDE_NAME := {"hunters": "CAZADOR", "runners": "CORREDOR"}

static func is_player(e: Ent) -> bool:
	return e.role == "hunter" or e.role == "runner"

## Lo que te delata en un cacheo.
static func contraband(e: Ent) -> bool:
	if e.role == "hunter":
		return (e.gun and e.ammo > 0) or e.knife
	return e.melee or e.gun or e.lockpick or e.cutter or e.carry != "" or e.masterkey

static func bench_pos(w: World, i: int = 0) -> Vector2:
	return Vector2((w.bench.y + 0.5 + i * 0.9) * TS, (w.bench.z + 0.5) * TS)

static func announce(w: World, text: String, sub: String, col: String, t: float = 4.5) -> void:
	w.announce = {"text": text, "sub": sub, "color": col, "t": t}

# ---------------------------------------------------------------- policías muertos

static func cop_killed(w: World, killer: Ent, cop: Ent) -> void:
	w.cop_kills += 1
	w.cop_killers[killer.id] = true
	var kt := killer.tile()
	var lvl := 1
	if w.cop_kills >= Cfg.ALARM_L3:
		lvl = 3
	elif w.cop_kills >= Cfg.ALARM_L2:
		lvl = 2
	if lvl > w.alarm:
		set_level(w, lvl, killer)
	else:
		for i in Cfg.REINFORCE:
			spawn_cop(w, 1, Vector2i(21 + i, 24), "go", Vector3i(killer.fl, kt.x, kt.y))
	Sim.send_police(w, {"fl": killer.fl, "x": kt.x, "y": kt.y}, 9999.0)
	Sim.wlog(w, "¡Han matado a un policía! Los compañeros piden refuerzos y buscan al responsable.", "alarm")

static func set_level(w: World, lvl: int, culprit: Ent) -> void:
	var prev := w.alarm
	w.alarm = lvl
	var ct := culprit.tile()
	if lvl >= 1 and prev < 1:
		for i in Cfg.REINFORCE:
			spawn_cop(w, 1, Vector2i(21 + i, 24), "go", Vector3i(culprit.fl, ct.x, ct.y))
		Combat.add_car(w, "police", Combat.park_slot(w))
		announce(w, "ALARMA 1", "Refuerzos en camino: la policía cachea a todo el que se cruce", "#f0b04a")
		Sim.wlog(w, "Alarma 1: la policía cachea a todo el mundo. Si llevas algo encima, te esposan.", "alarm")
	if lvl >= 2 and prev < 2:
		w.alarm_side = "hunters" if culprit.role == "hunter" else "runners"
		if w.alarm_side == "hunters":
			w.limit = maxf(w.time + 60.0, w.limit - Cfg.ALARM_TIME_SHIFT)
		else:
			w.limit += Cfg.ALARM_TIME_SHIFT
		var order: Array = []
		for fi in [1, 2, 3, 4, 5, 0, 6]:
			for r in Hotel.floors[fi].rooms:
				if r.has_door:
					order.append(r)
		for i in Cfg.FED_COUNT:
			var f := spawn_cop(w, 1, Vector2i(20 + i % 4, 24 - i / 4), "sweep", Vector3i(1, 22, 20))
			f.is_fed = true
			f.nm = "Agente federal"
			f.outfit = Outfit.new_fed()
			# cada agente empieza por un sitio distinto de la lista
			var k := order.size() * i / Cfg.FED_COUNT
			f.sweep = order.slice(k) + order.slice(0, k)
		Combat.add_car(w, "fed", Combat.park_slot(w))
		Combat.add_car(w, "fed", Combat.park_slot(w))
		announce(w, "ALARMA 2", "Llegan los federales · causante: " + str(SIDE_NAME[w.alarm_side]), "#ff5a64")
		Sim.wlog(w, "Alarma 2: los federales registran habitación por habitación. " + ("El cliente llegará antes." if w.alarm_side == "hunters" else "El cliente se retrasa."), "alarm")
	if lvl >= 3 and prev < 3:
		bluegeddon(w)

static func spawn_cop(w: World, fl: int, t: Vector2i, mode: String, target: Vector3i) -> Ent:
	var p := Sim.new_ent(w)
	p.nm = "Policía"; p.type = "police"; p.role = "police"; p.fl = fl
	p.x = (t.x + 0.5) * TS; p.y = (t.y + 0.5) * TS
	p.outfit = Outfit.new_police(); p.dir = "up"
	p.ai_mode = mode; p.target = target; p.stay_until = 1e9
	w.ents.append(p)
	return p

static func bluegeddon(w: World) -> void:
	for i in 4:
		Combat.add_car(w, "police", Combat.park_slot(w))
	announce(w, "BLUEGEDDON", "La policía toma el hotel y dispara a cualquier sospechoso", "#3d7dff", 6.0)
	Sim.wlog(w, "BLUEGEDDON: todos los huéspedes huyen y la policía dispara a cualquiera de los dos bandos.", "alarm")
	for c in w.ents:
		if c.role == "civil" and c.alive:
			c.state = "flee"
			c.goal = null
	for i in Cfg.BLUE_COUNT:
		var fi := i % Hotel.floors.size()
		var f: FloorData = Hotel.floors[fi]
		var t: Vector2i = Rng.pick(f.tiles_pub)
		spawn_cop(w, fi, t, "hunt", Vector3i(fi, t.x, t.y))
	# salidas para los corredores, cada una con su material
	w.exits = [
		{"fl": 6, "x": 15, "y": 18, "item": "rope", "name": "Bajar por la fachada con la cuerda"},
		{"fl": 0, "x": 6, "y": 20, "item": "dockkey", "name": "Salir por el muelle de carga"},
	]
	var pid := 900
	for it in [["rope", "cuerda", [2, 3, 4]], ["dockkey", "llave del muelle", [1, 5]]]:
		var fi: int = Rng.pick(it[2])
		var t: Vector2i = Rng.pick(Hotel.floors[fi].tiles_pub)
		var p := Items.Pick.new()
		pid += 1
		p.id = pid; p.kind = it[0]; p.nm = it[1]; p.fl = fi; p.x = t.x; p.y = t.y
		w.picks.append(p)
	Sim.wlog(w, "Para escapar: una cuerda (azotea) o la llave del muelle de carga (sótano). Están en el mapa.", "team")

# ---------------------------------------------------------------- inocentes

## Un civil asesinado por un jugador se descubre: cuantos más, más sube la alarma.
static func innocent_found(w: World, c: Items.Corpse) -> void:
	if c.counted or c.role != "civil" or (c.killer_role != "hunter" and c.killer_role != "runner"):
		return
	c.counted = true
	w.innocents += 1
	var killer := w.ent_by_id(c.killer_id)
	if killer == null:
		killer = Ent.new()
		killer.role = c.killer_role
		killer.fl = c.fl
		killer.x = c.x
		killer.y = c.y
	w.cop_killers[c.killer_id] = true
	var lvl := 0
	if w.innocents >= Cfg.INNOCENT_L3:
		lvl = 3
	elif w.innocents >= Cfg.INNOCENT_L2:
		lvl = 2
	elif w.innocents >= Cfg.INNOCENT_L1:
		lvl = 1
	Sim.wlog(w, "Ya hay " + str(w.innocents) + " inocente" + ("s" if w.innocents != 1 else "") + " muerto" + ("s" if w.innocents != 1 else "") + ". " + ("¡La ciudad entera viene a por el hotel!" if lvl == 3 else "La policía se lo toma cada vez más en serio."), "alarm")
	if lvl > w.alarm:
		set_level(w, lvl, killer)

# ---------------------------------------------------------------- cacheos y esposas

static func frisk(w: World, p: Ent, t: Ent) -> void:
	p.say("Policía. Cacheo, no se mueva.", 2.2)
	p.dir = Sim.dir_of(t.x - p.x, t.y - p.y)
	if contraband(t):
		cuff(w, t, p)
	else:
		t.frisked = true
		t.say("Estoy limpio, agente.", 2.0)
		if t == w.human:
			Sim.wlog(w, "Te han cacheado: no llevabas nada. No te volverán a cachear.")

static func cuff(w: World, t: Ent, p: Ent) -> void:
	Sim.cancel_hold(w, t)
	var n := 0
	for e in w.ents:
		if e.cuffed:
			n += 1
	t.cuffed = true
	t.cuff_t = Cfg.CUFF_TIME
	t.shackled = false
	t.gun = false; t.ammo = 0; t.knife = false; t.melee = false; t.lockpick = false; t.cutter = false
	t.masterkey = false; t.equip = "fist"; t.aim = false; t.goal = null; t.has_path = false; t.moving = false
	if t.carry != "":
		for k in t.tasks:
			if k.pair == t.carry:
				k.done = false
		t.carry = ""
	var bp := bench_pos(w, n)
	t.fl = w.bench.x; t.x = bp.x; t.y = bp.y; t.dir = "down"
	w.stats["arrests"] += 1
	if p != null:
		p.ai_mode = "guard"; p.goal = null; p.frisk_id = 0
		p.say("Queda detenido. Al vestíbulo.", 2.4)
	# la llave de las esposas se le ha caído a alguien por el hotel
	var has_key := false
	for k in w.picks:
		if k.kind == "cuffkey":
			has_key = true
	for e in w.ents:
		if e.cuffkey:
			has_key = true
	if not has_key:
		var fi: int = Rng.pick([0, 3, 4, 5, 6])
		var tt: Vector2i = Rng.pick(Hotel.floors[fi].tiles_pub)
		var k2 := Items.Pick.new()
		k2.id = 800 + w.stats["arrests"]; k2.kind = "cuffkey"; k2.nm = "llave de esposas"; k2.fl = fi; k2.x = tt.x; k2.y = tt.y
		w.picks.append(k2)
	if t == w.human:
		Sim.wlog(w, "Te han esposado en el vestíbulo. Tienes 1:30 para que te liberen: soborno, ganzúa o la llave de las esposas que se le ha caído a un policía por el hotel.", "report", t.id)
	else:
		Sim.wlog(w, t.nm + " ha sido esposado en el vestíbulo.", "team" if t.role == "runner" else "hunt", t.id)

static func free_prisoner(w: World, t: Ent, how: String) -> void:
	t.cuffed = false
	t.shackled = false
	t.cuff_t = 0
	t.frisked = true
	Sim.ev(w, "door", t.fl, t.x, t.y)
	if t == w.human:
		Sim.wlog(w, "¡Libre! (" + how + ")")
	else:
		Sim.wlog(w, t.nm + " queda libre (" + how + ").", "team" if t.role == "runner" else "hunt", t.id)

static func guard_of(w: World) -> Ent:
	var bp := bench_pos(w)
	for p in w.ents:
		if p.role == "police" and p.alive and p.ai_mode == "guard" and p.fl == w.bench.x and Vector2(p.x, p.y).distance_to(bp) < 8 * TS:
			return p
	return null

static func prisoners(w: World) -> Array:
	return w.ents.filter(func(e): return e.alive and e.cuffed)

static func update(w: World, dt: float) -> void:
	for e in w.ents:
		if not e.alive or not e.cuffed:
			continue
		e.cuff_t -= dt
		e.aim = false
		if e.cuff_t <= 0:
			e.cuffed = false
			e.alive = false
			e.remove = e.type != "human"
			if e == w.human:
				Sim.wlog(w, "Nadie ha venido a por ti: te llevan a comisaría. Ahora miras la partida.", "alarm")
			else:
				Sim.wlog(w, e.nm + " se lo llevan a comisaría.", "alarm")
			Sim.check_win(w)

# ---------------------------------------------------------------- IA de policía (modos nuevos)

## Devuelve true si se ha encargado del policía en este paso.
static func police_ai(w: World, e: Ent, dt: float) -> bool:
	match e.ai_mode:
		"frisk":
			var t := w.ent_by_id(e.frisk_id)
			if t == null or not t.alive or t.cuffed or t.frisked or t.fl != e.fl or t.escaped:
				e.ai_mode = "sweep" if e.is_fed else "search"
				e.goal = null
				return true
			var tt := t.tile()
			if e.goal == null or absi(e.goal.x - tt.x) + absi(e.goal.y - tt.y) > 1:
				Sim.nav_to(w, e, e.fl, tt.x, tt.y)
			Sim.nav_update(w, e, dt, Cfg.SPEED_POLICE)
			if Vector2(t.x - e.x, t.y - e.y).length() < 28:
				e.moving = false
				frisk(w, e, t)
				if e.ai_mode == "frisk":
					e.ai_mode = "sweep" if e.is_fed else "search"
					e.goal = null
			return true
		"guard":
			if prisoners(w).is_empty():
				e.ai_mode = "search"
				e.goal = null
				return true
			var gp := Vector2i(w.bench.y + 3, w.bench.z)
			if e.fl != w.bench.x or Vector2(e.x, e.y).distance_to(Vector2((gp.x + 0.5) * TS, (gp.y + 0.5) * TS)) > 20:
				if e.goal == null:
					Sim.nav_to(w, e, w.bench.x, gp.x, gp.y)
				Sim.nav_update(w, e, dt, Cfg.SPEED_POLICE)
			else:
				e.moving = false
				e.dir = "left"
			return true
		"chase":
			var t := w.ent_by_id(e.chase_id)
			if t == null or not t.alive or not t.cuffed or t.fl != e.fl:
				e.ai_mode = "search"
				e.goal = null
				return true
			var tt := t.tile()
			if e.goal == null or absi(e.goal.x - tt.x) + absi(e.goal.y - tt.y) > 1:
				Sim.nav_to(w, e, e.fl, tt.x, tt.y)
			Sim.nav_update(w, e, dt, Cfg.SPEED_POLICE * 1.1)
			if Vector2(t.x - e.x, t.y - e.y).length() < 24:
				var bp := bench_pos(w)
				t.fl = w.bench.x; t.x = bp.x; t.y = bp.y
				t.shackled = true
				t.moving = false
				e.ai_mode = "guard"
				e.goal = null
				e.say("¡Quieto! Ahora con grilletes.", 2.4)
				if t == w.human:
					Sim.wlog(w, "Te han atrapado: ahora llevas grilletes en pies y manos. Solo un compañero puede liberarte.", "report", t.id)
			return true
		"sweep":
			if e.sweep.is_empty():
				e.ai_mode = "hunt"
				return true
			var r: Room = e.sweep[0]
			var sp := Hotel.room_spot(r)
			if e.goal == null:
				Sim.nav_to(w, e, r.fi, sp.x, sp.y)
			if Sim.nav_update(w, e, dt, Cfg.SPEED_FED):
				e.goal = null
				e.sweep.remove_at(0)
				if r.zone == Cfg.ZONE_ROOM:
					w.unlocked[r.key()] = w.time + 20.0
				for c in w.ents:
					if c.alive and c.fl == r.fi and c != e and Sim.inside_room(c, r):
						if c.role == "civil":
							c.say("¡Ya salgo, ya salgo!", 2.0)
							var out: Vector2i = Rng.pick(Hotel.floors[r.fi].tiles_pub)
							Sim.nav_to(w, c, r.fi, out.x, out.y)
						elif is_player(c) and not c.cuffed and not c.frisked and not c.undercover:
							frisk(w, e, c)
				e.say("Federales. Todo el mundo fuera.", 2.0)
			return true
		"hunt":
			if e.goal == null:
				var fl := e.fl if Rng.rnd() < 0.8 else Rng.ri(0, Hotel.floors.size() - 1)
				var t2: Vector2i = Rng.pick(Hotel.floors[fl].tiles_pub)
				Sim.nav_to(w, e, fl, t2.x, t2.y)
			if Sim.nav_update(w, e, dt, Cfg.SPEED_POLICE * 0.8):
				e.goal = null
			return true
	return false
