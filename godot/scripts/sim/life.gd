## v0.12 «El hotel vivo» (resto de propuestas del tester):
##  - ciclo de día (5 min) y noche (4 min) con rutinas: desayuno, almuerzo, ocio, cena, copas y dormir
##  - pánico (más policía y durante más tiempo) y sospecha general (todos más atentos)
##  - dos guardias de seguridad que van donde está la gente y avisan por radio
##  - conductos de ventilación para moverse por la planta (con minijuego de tornillos)
##  - perros de los huéspedes: buscan a su dueño aunque esté escondido, no abren puertas, se pueden coger
##  - deshacerse de la pistola colocándosela a alguien inconsciente
class_name Life
extends RefCounted

const TS := Cfg.TS
const DAY := 300.0              # s de día
const NIGHT := 240.0            # s de noche
const CYCLE := 540.0
const START := 100.0            # la partida empieza a media mañana
const HOLDS := ["plant"]
const PRESS := ["vent", "pet_take", "pet_drop"]
const VENT_TIME := 2.5
const PET_SPEED := 96.0
# franjas: [hasta el segundo, nombre, aviso]
const SLOTS := [
	[70.0, "desayuno", "Hora del desayuno: los huéspedes van a la cafetería y al restaurante."],
	[170.0, "mañana", ""],
	[240.0, "almuerzo", "Hora de almorzar: el restaurante se llena."],
	[300.0, "tarde", "Cae la tarde: la gente se reparte por los salones."],
	[370.0, "cena", "Anochece. Hora de la cena."],
	[430.0, "copas", "Copas en el bar y en el Gran Salón."],
	[540.0, "dormir", "Los huéspedes se retiran a dormir. Los pasillos se quedan vacíos."],
]

static var _mask := PackedByteArray()

# ---------------------------------------------------------------- reloj del hotel

static func phase(w: World) -> float:
	return fmod(w.time + START, CYCLE)

static func slot_of(ph: float) -> Array:
	for s in SLOTS:
		if ph < float(s[0]):
			return s
	return SLOTS[SLOTS.size() - 1]

static func is_night(w: World) -> bool:
	return phase(w) >= DAY

## Hora del hotel para el HUD: el día va de 07:00 a 21:00 y la noche de 21:00 a 07:00.
static func hour_text(w: World) -> String:
	var ph := phase(w)
	var h := 7.0 + ph / DAY * 14.0 if ph < DAY else 21.0 + (ph - DAY) / NIGHT * 10.0
	h = fmod(h, 24.0)
	return "%02d:%02d" % [int(h), int(fmod(h, 1.0) * 60.0)]

# ---------------------------------------------------------------- inicio de partida

static func setup(w: World) -> void:
	w.panic = 0.0
	w.gsus = 0.0
	w.slot = ""
	w.pets.clear()
	for fv in Sim.floors():
		_setup_vents(fv)
	if w.tutorial:
		return
	# rutinas: cada PNJ que se mueve recuerda su zona habitual
	var guests: Array = []
	for e in w.ents:
		if e.type != "npc" or e.role != "civil" or e.fixed:
			continue
		e.home_tiles = e.tiles
		e.home_fl = e.fl
		e.rt_fl = e.fl
		if not e.staff:
			guests.append(e)
	# dos guardias de seguridad
	for i in 2:
		var g := Sim.new_ent(w)
		var f := Sim.fdat(1 + i)
		var t: Vector2i = Rng.pick(f.tiles_pub)
		g.nm = "Guardia de seguridad"; g.type = "npc"; g.role = "civil"; g.fl = 1 + i
		g.x = (t.x + 0.5) * TS; g.y = (t.y + 0.5) * TS
		g.outfit = Outfit.new_staff("guard")
		g.staff = true; g.guard = true; g.tiles = f.tiles_pub
		g.home_tiles = f.tiles_pub; g.home_fl = g.fl; g.rt_fl = g.fl
		g.ai_mode = "idle"; g.ai_wait = Rng.rnd() * 3.0
		w.ents.append(g)
	# perros de tres huéspedes
	guests = Rng.shuffle(guests)
	for i in mini(3, guests.size()):
		var o: Ent = guests[i]
		w.pets.append({"id": i + 1, "owner": o.id, "fl": o.fl, "x": o.x + 12.0, "y": o.y + 6.0, "dir": 1.0, "walk": 0.0,
			"state": "follow", "bark": 0.0, "path": [], "pi": 0, "repath": 0.0, "carried": 0, "near": true, "msg": "", "msg_t": 0.0,
			"col": Rng.pick(["#8a5a32", "#d9c9a8", "#3a2e26", "#b98a52"])})

## Rejillas de ventilación: casillas libres con muro al norte, repartidas por la planta (siempre las mismas).
static func _setup_vents(fv) -> void:
	var f: FloorData = fv
	f.vents.clear()
	f.vent_open.clear()
	if f.sky or f.roof:
		return
	var cands: Array = []
	for ty in range(2, Cfg.H - 1):
		for tx in range(1, Cfg.W - 1):
			if ty >= f.open_from:
				continue
			var i := ty * Cfg.W + tx
			var t := f.at(tx, ty)
			if f.walkable[i] == 0 or f.blk[i] != 0 or t == Cfg.T_DOOR or t == Cfg.T_ELEV or t == Cfg.T_UP or t == Cfg.T_DOWN:
				continue
			if f.at(tx, ty - 1) != Cfg.T_WALL:
				continue
			cands.append(Vector2i(tx, ty))
	cands.sort_custom(func(a, b): return ((a.x * 7919 + a.y * 104729 + f.fi * 31) % 1009) < ((b.x * 7919 + b.y * 104729 + f.fi * 31) % 1009))
	for c in cands:
		var ok := true
		for v in f.vents:
			if absi(v.x - c.x) + absi(v.y - c.y) < 10:
				ok = false
				break
		if ok:
			f.vents.append(c)
			f.vent_open.append(false)
		if f.vents.size() >= 5:
			break
	if f.vents.size() < 2:
		f.vents.clear()
		f.vent_open.clear()

# ---------------------------------------------------------------- pánico y sospecha general

static func add_panic(w: World, a: float) -> void:
	w.panic = clampf(w.panic + a, 0.0, 100.0)

static func add_gsus(w: World, a: float) -> void:
	w.gsus = clampf(w.gsus + a, 0.0, 100.0)

## Con sospecha general los PNJ ven más lejos y se mosquean antes.
static func sight_mul(w: World) -> float:
	return 1.0 + w.gsus / 250.0

static func rate_mul(w: World) -> float:
	return 1.0 + w.gsus / 100.0

## Con pánico llegan más agentes y se quedan más tiempo.
static func police_extra(w: World) -> int:
	return int(w.panic / 35.0)

static func stay_mul(w: World) -> float:
	return 1.0 + w.panic / 100.0

# ---------------------------------------------------------------- rutinas

static func _room(fl: int, nm: String) -> Array:
	var f := Sim.fdat(fl)
	var t: Array = f.room_tiles.get(nm, [])
	return t if not t.is_empty() else f.tiles_pub

static func _go(e: Ent, fl: int, tiles: Array) -> void:
	if tiles.is_empty():
		return
	e.tiles = tiles
	e.rt_fl = fl
	if e.state == "idle" and e.ai_mode != "clean":
		e.goal = null
		e.ai_wait = Rng.rnd() * 6.0   # no salen todos a la vez

static func _bedroom(e: Ent) -> Array:
	if e.room != "" and e.room_floor >= 0:
		return [e.room_floor, _room(e.room_floor, e.room)]
	var fl := 3 + (e.id % 2)
	var rooms: Array = Sim.fdat(fl).rooms.filter(func(r): return r.zone == Cfg.ZONE_ROOM)
	if rooms.is_empty():
		return [e.home_fl, e.home_tiles]
	var r: Room = rooms[e.id % rooms.size()]
	return [fl, _room(fl, r.nm)]

static func _assign(w: World, e: Ent, slot: String) -> void:
	var k := e.id % 3
	e.asleep = false
	if e.guard:
		# los guardias van donde hay gente
		var spots := {"desayuno": [[1, "Cafetería"], [2, "Restaurante Terrace"]], "almuerzo": [[2, "Restaurante Terrace"], [2, "Gran Salón"]],
			"tarde": [[2, "Gran Salón"], [5, "Terraza"]], "cena": [[2, "Restaurante Terrace"], [1, "Cafetería"]], "copas": [[2, "Bar"], [2, "Gran Salón"]]}
		if spots.has(slot):
			var s: Array = spots[slot][e.id % 2]
			_go(e, int(s[0]), _room(int(s[0]), str(s[1])))
		else:
			_go(e, 1 + e.id % 2, Sim.fdat(1 + e.id % 2).tiles_pub)
		return
	if e.staff:
		if e.outfit.staff_role == "waiter" and (slot == "desayuno" or slot == "almuerzo" or slot == "cena"):
			_go(e, 2, _room(2, "Restaurante Terrace"))
		else:
			_go(e, e.home_fl, e.home_tiles)
		return
	match slot:
		"desayuno":
			if k == 0:
				_go(e, 1, _room(1, "Cafetería"))
			else:
				_go(e, 2, _room(2, "Restaurante Terrace"))
		"almuerzo":
			_go(e, 2, _room(2, "Restaurante Terrace") if k != 1 else _room(2, "Gran Salón"))
		"tarde":
			var places := [[2, "Gran Salón"], [5, "Biblioteca"], [5, "Terraza"]]
			var p: Array = places[k]
			_go(e, int(p[0]), _room(int(p[0]), str(p[1])))
		"cena":
			if k == 2:
				_go(e, 1, _room(1, "Cafetería"))
			else:
				_go(e, 2, _room(2, "Restaurante Terrace"))
		"copas":
			_go(e, 2, _room(2, "Bar") if k != 0 else _room(2, "Gran Salón"))
		"dormir":
			var b := _bedroom(e)
			_go(e, int(b[0]), b[1])
		_:
			_go(e, e.home_fl, e.home_tiles)

## IA de rutina: quien ha llegado a su cama duerme (no ve ni oye nada). Los guardias avisan por radio.
static func npc_ai(w: World, e: Ent, dt: float) -> bool:
	if e.guard and e.state == "call":
		e.state = "calling"
		e.ai_t = 1.2
		e.moving = false
		e.goal = null
		e.say("¡Central, aquí seguridad del hotel!", 2.0)
		return true
	if e.state != "idle" or e.ko_t > 0:
		e.asleep = false
		return false
	if w.slot == "dormir" and not e.staff and not e.fixed and e.home_fl >= 0:
		if e.asleep:
			e.moving = false
			return true
		if e.fl == e.rt_fl and e.goal == null and e.tile() in e.tiles:
			e.asleep = true
			e.moving = false
			e.dir = "down"
			return true
	return false

# ---------------------------------------------------------------- paso

static func update(w: World, dt: float) -> void:
	w.panic = maxf(0.0, w.panic - 0.12 * dt)
	w.gsus = maxf(0.0, w.gsus - 0.07 * dt)
	if not w.tutorial:
		var s := slot_of(phase(w))
		if str(s[1]) != w.slot:
			var first := w.slot == ""
			w.slot = str(s[1])
			for e in w.ents:
				if e.type == "npc" and e.role == "civil" and e.alive and not e.fixed and e.home_fl >= 0:
					_assign(w, e, w.slot)
			if not first and str(s[2]) != "":
				Sim.wlog(w, str(s[2]))
	# conducto: el jugador tarda unos segundos en salir por la otra rejilla
	for e in w.ents:
		if e.vent_t > 0.0:
			e.vent_t -= dt
			e.moving = false
			if e.vent_t <= 0.0:
				e.x = e.vent_to.x
				e.y = e.vent_to.y
				e.hidden = false
				Sim.ev(w, "door", e.fl, e.x, e.y)
				if not Sim.civils_seeing(w, e, null, Stealth.SEE * TS).is_empty():
					e.sus = minf(100.0, e.sus + 40.0)
					if e == w.human:
						Sim.wlog(w, "Te han visto salir del conducto de ventilación.", "report", e.id)
		# a quien le colocaron una pistola: cuando despierta y hay policía, se lo llevan
		if e.planted_gun >= 0 and e.alive and e.ko_t <= 0:
			e.planted_t += dt
			if e.planted_t > 4.0:
				for p in w.ents:
					if p.role == "police" and p.alive:
						_frame(w, e, p)
						break
	_pets(w, dt)

static func _frame(w: World, v: Ent, cop: Ent) -> void:
	v.planted_gun = -1
	v.say("¡Yo no he hecho nada! ¡Esa pistola no es mía!", 3.0)
	cop.say("¡Queda detenido!", 2.4)
	v.alive = false
	v.remove = true
	w.wanted.clear()
	w.posters.clear()
	add_panic(w, -30.0)
	add_gsus(w, -25.0)
	Sim.wlog(w, "La policía detiene a un huésped que llevaba una pistola encima. La búsqueda se relaja.", "alarm")

# ---------------------------------------------------------------- conductos de ventilación

static func use_vent(w: World, e: Ent, idx: int) -> void:
	var f := Sim.fdat(e.fl)
	if idx < 0 or idx >= f.vents.size():
		return
	var to := (idx + 1) % f.vents.size()
	if not f.vent_open[idx]:
		f.vent_open[idx] = true
		add_gsus(w, 4.0)
	if not f.vent_open[to]:
		f.vent_open[to] = true
		add_gsus(w, 4.0)
	if not Sim.civils_seeing(w, e, null, Stealth.SEE * TS).is_empty():
		e.sus = minf(100.0, e.sus + 40.0)
		if e == w.human:
			Sim.wlog(w, "Te han visto meterte en el conducto.", "report", e.id)
	if e.dragging != null:
		Stealth.drop(w, e)
	var d: Vector2i = f.vents[to]
	e.hidden = true
	e.hide_ward = null
	e.vent_t = VENT_TIME
	e.vent_to = Vector2((d.x + 0.5) * TS, (d.y + 0.5) * TS)
	e.aim = false
	Sim.ev(w, "door", e.fl, e.x, e.y)
	if e == w.human:
		Sim.wlog(w, "Te arrastras por el conducto hasta la siguiente rejilla. Las rejillas quedan abiertas: alguien lo notará.")

# ---------------------------------------------------------------- interacción

static func candidates(w: World, e: Ent, f: FloorData, cand: Callable) -> void:
	if e.pet_id != 0:
		cand.call("pet_drop", null, e.x, e.y, 999.0, "Soltar al perro", 0.0)
		return
	for i in f.vents.size():
		var v: Vector2i = f.vents[i]
		cand.call("vent", i, (v.x + 0.5) * TS, (v.y + 0.5) * TS - 6.0, 34.0, "Entrar en el conducto de ventilación", 0.0)
	for p in w.pets:
		if int(p["fl"]) == e.fl and int(p["carried"]) == 0:
			cand.call("pet_take", p, float(p["x"]), float(p["y"]), 34.0, "Coger al perro en brazos", 0.0)

static func press(w: World, e: Ent, hint: Dictionary) -> String:
	match String(hint["type"]):
		"vent":
			return "minigame"
		"pet_take":
			var p: Dictionary = hint["ref"]
			p["carried"] = e.id
			p["state"] = "carried"
			e.pet_id = int(p["id"])
			Heat.pet_taken(w, e, p)
			if e == w.human:
				Sim.wlog(w, "Llevas al perro en brazos. Suéltalo (E) dentro de una habitación: no sabe abrir puertas.")
			return "ok"
		"pet_drop":
			for p2 in w.pets:
				if int(p2["id"]) == e.pet_id:
					p2["carried"] = 0
					p2["state"] = "follow"
					p2["fl"] = e.fl
					p2["x"] = e.x
					p2["y"] = e.y + 8.0
					p2["path"] = []
					Heat.pet_dropped(w, e, p2)
			e.pet_id = 0
			return "ok"
	return ""

static func finish_hold(w: World, e: Ent, h: Hold) -> void:
	if h.type == "plant":
		var v: Ent = h.ref
		v.planted_gun = e.ammo
		v.planted_t = 0.0
		e.gun = false
		e.ammo = 0
		e.equip = "fist"
		e.aim = false
		if e == w.human:
			Sim.wlog(w, "Le has colocado la pistola. Cuando despierte y lo vea la policía, cargará con la culpa… pero tú te quedas sin arma.")

# ---------------------------------------------------------------- perros

static func _pet_say(p: Dictionary, s: String) -> void:
	p["msg"] = s
	p["msg_t"] = 1.4

static func _pets(w: World, dt: float) -> void:
	if _mask.size() != Cfg.W * Cfg.H:
		_mask.resize(Cfg.W * Cfg.H)
		_mask.fill(0)
	for p in w.pets:
		if float(p["msg_t"]) > 0.0:
			p["msg_t"] = float(p["msg_t"]) - dt
		var carrier: Ent = null
		if int(p["carried"]) != 0:
			carrier = w.ent_by_id(int(p["carried"]))
		if carrier != null:
			if not carrier.alive or carrier.pet_id != int(p["id"]):
				p["carried"] = 0
				p["state"] = "follow"
			else:
				p["fl"] = carrier.fl
				p["x"] = carrier.x + 6.0
				p["y"] = carrier.y - 6.0
				continue
		var owner := w.ent_by_id(int(p["owner"]))
		var fl: int = p["fl"]
		var f := Sim.fdat(fl)
		var px: float = p["x"]
		var py: float = p["y"]
		var target := Vector2(px, py)
		var seeking := false
		var body: Items.Corpse = null
		if owner != null and owner.alive:
			if owner.fl != fl:
				if p["near"]:
					p["fl"] = owner.fl
					p["x"] = owner.x + 10.0
					p["y"] = owner.y + 4.0
					p["path"] = []
				continue
			target = Vector2(owner.x, owner.y)
			p["near"] = target.distance_to(Vector2(px, py)) < 3.5 * TS
		else:
			for c in w.corpses:
				if c.victim_id == int(p["owner"]) and not c.chalk:
					body = c
			if body == null or body.fl != fl:
				continue
			target = Vector2(body.x, body.y)
			seeking = true
		var d := target.distance_to(Vector2(px, py))
		var stop := 1.3 * TS if seeking else 1.1 * TS
		var blocked := false
		if d > stop:
			var step := PET_SPEED * dt
			var nxt := target
			if not Nav.los(f, px, py, target.x, target.y) or not Sim.free_at(f, px + (target.x - px) / d * 10.0, py + (target.y - py) / d * 10.0):
				p["repath"] = float(p["repath"]) - dt
				var path: Array = p["path"]
				if float(p["repath"]) <= 0.0 or path.is_empty():
					p["repath"] = 1.0
					var res = Nav.bfs(f, floori(px / TS), floori(py / TS), floori(target.x / TS), floori(target.y / TS), _mask)
					path = res if res != null else []
					p["path"] = path
					p["pi"] = 0
				var pi: int = p["pi"]
				if pi < path.size():
					var n: Vector2i = path[pi]
					# no sabe abrir puertas: si está cerrada se queda delante
					if f.at(n.x, n.y) == Cfg.T_DOOR and not f.door_open(n.x, n.y):
						blocked = true
					else:
						nxt = Vector2((n.x + 0.5) * TS, (n.y + 0.5) * TS)
						if nxt.distance_to(Vector2(px, py)) < 4.0:
							p["pi"] = pi + 1
				else:
					blocked = true
			if not blocked:
				var dv := nxt - Vector2(px, py)
				var dl := dv.length()
				if dl > 0.5:
					px += dv.x / dl * minf(step, dl)
					py += dv.y / dl * minf(step, dl)
					p["dir"] = 1.0 if dv.x >= 0 else -1.0
					p["walk"] = float(p["walk"]) + dt * 14.0
				p["x"] = px
				p["y"] = py
		# ladra junto al cuerpo de su dueño (o ante la puerta que no puede cruzar)
		if seeking and (d <= stop + 4.0 or blocked):
			p["bark"] = float(p["bark"]) - dt
			if float(p["bark"]) <= 0.0:
				p["bark"] = 3.0
				_pet_say(p, "¡Guau! ¡Guau!")
				_bark(w, p, body)

## Un ladrido atrae a la gente cercana; si el cuerpo está escondido al lado, alguien acaba abriendo el armario.
static func _bark(w: World, p: Dictionary, body: Items.Corpse) -> void:
	var fl: int = p["fl"]
	var px: float = p["x"]
	var py: float = p["y"]
	for n in w.ents:
		if n.role != "civil" or not n.alive or n.fl != fl or n.state != "idle" or n.asleep or n.ko_t > 0 or n.fixed:
			continue
		var d := Sim.dist(n.x, n.y, px, py)
		if d > 7.0 * TS:
			continue
		n.dir = Sim.dir_of(px - n.x, py - n.y)
		if d > 2.0 * TS:
			if n.ai_mode != "clean":
				Sim.nav_to(w, n, fl, floori(px / TS), floori(py / TS))
				n.ai_wait = 0.0
		elif body != null and not body.found and Sim.dist(px, py, body.x, body.y) < 3.0 * TS and Rng.rnd() < 0.5:
			body.hidden = false
			body.found = true
			Alarm.innocent_found(w, body)
			n.say("¿Qué le pasa a este perro? … ¡Dios mío, hay un cuerpo!", 3.0)
			Sim.alert_npc(w, n, "", "body", fl, floori(body.x / TS), floori(body.y / TS))
			add_panic(w, 20.0)
			return
