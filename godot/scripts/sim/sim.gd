## Simulación: reglas, IA y estado. No toca nodos ni pantalla, así que puede
## ejecutarse igual en un servidor dedicado. Portado de src/sim.js.
class_name Sim
extends RefCounted

const TS := Cfg.TS
const W := Cfg.W
const HUNTER_NAMES := ["Agente Cole", "Agente Dunn"]
const RUNNER_NAMES := ["Vinnie", "Sal", "Mickey", "Lou"]
const PERKS := ["silencer", "master", "ammo", "rich"]
const PERK_NAMES := {"silencer": "Silenciador mejorado", "master": "Copia de la llave maestra", "ammo": "Munición extra", "rich": "Fondos reservados"}
const FLOOR_SHORT := ["Sótano", "PB", "P2", "P10", "P20", "P30", "Azotea"]
# home: "pub", "rooms", "roomOne", "fixed" o el nombre de una sala
const NPC_SPECS := [
	{"f": 0, "staff": "tech", "home": "Sala de calderas"}, {"f": 0, "staff": "maid", "home": "Lavandería"}, {"f": 0, "staff": "chef", "home": "Cocina de servicio"}, {"f": 0, "staff": "tech", "home": "Sala eléctrica"},
	{"f": 1, "staff": "recep", "home": "fixed", "at": Vector2i(22, 12)}, {"f": 1, "staff": "bell", "home": "pub"}, {"f": 1, "staff": "bell", "home": "pub"}, {"f": 1, "home": "pub"}, {"f": 1, "home": "pub"}, {"f": 1, "home": "pub"},
	{"f": 2, "staff": "waiter", "home": "Restaurante Terrace"}, {"f": 2, "staff": "waiter", "home": "Gran Salón"}, {"f": 2, "staff": "waiter", "home": "fixed", "at": Vector2i(32, 7)}, {"f": 2, "home": "pub"}, {"f": 2, "home": "pub"}, {"f": 2, "home": "pub"},
	{"f": 3, "staff": "maid", "home": "rooms"}, {"f": 3, "home": "pub"}, {"f": 3, "home": "roomOne"},
	{"f": 4, "staff": "maid", "home": "rooms"}, {"f": 4, "home": "pub"}, {"f": 4, "home": "roomOne"},
	{"f": 5, "home": "pub"}, {"f": 5, "home": "pub"},
	{"f": 1, "staff": "guard", "home": "fixed", "at": Vector2i(24, 25)},
]
const PRESS_TYPES := ["elev", "elevx", "shop", "talk", "bribe", "free_key", "unlock", "task", "force", "job"]

static var _lockm := PackedByteArray()

# ---------------------------------------------------------------- utilidades

static func floors() -> Array:
	return Hotel.floors

static func fdat(i: int) -> FloorData:
	return Hotel.floors[i]

static func dist(ax: float, ay: float, bx: float, by: float) -> float:
	return Vector2(ax - bx, ay - by).length()

static func new_ent(w: World) -> Ent:
	var e := Ent.new()
	e.id = w.next_id
	w.next_id += 1
	e.ai_mode = "idle"
	e.ai_t = Rng.rnd() * 3.0
	e.ai_scan = Rng.rnd() * 0.3
	return e

static func wlog(w: World, msg: String, kind: String = "info", who: int = 0) -> void:
	var l := Items.LogEntry.new()
	w.log_id += 1
	l.id = w.log_id; l.t = w.time; l.msg = msg; l.kind = kind; l.who = who
	w.logs.append(l)
	if w.logs.size() > 300:
		w.logs.remove_at(0)

# ---------------------------------------------------------------- partida nueva

## opt: {role: "hunter"/"runner"/"spectator", hunters: 1-2, runners: 2-4, minutes: float, seed: int}
static func new_world(opt: Dictionary) -> World:
	Hotel.load_data()
	Rng.seed_with(int(opt.get("seed", Time.get_ticks_usec() & 0xffffff)))
	Outfit.reset()
	var w := World.new()
	w.role = opt.get("role", "runner")
	w.limit = float(opt.get("minutes", 12)) * 60.0
	for f in floors():
		for wd in f.wards:
			wd.looted = false
	var n_h := clampi(int(opt.get("hunters", 2)), 1, 2)
	var n_r := clampi(int(opt.get("runners", 4)), 2, 4)
	var h_spawn := [Vector2i(21, 24), Vector2i(23, 24)]
	for i in n_h:
		var is_h: bool = w.role == "hunter" and i == 0
		var e := new_ent(w)
		e.nm = HUNTER_NAMES[i]; e.type = "human" if is_h else "bot"; e.role = "hunter"; e.fl = 1
		e.x = (h_spawn[i].x + 0.5) * TS; e.y = (h_spawn[i].y + 0.5) * TS; e.outfit = Outfit.new_guest(false); e.dir = "up"
		e.ai_mode = "patrol"; e.ai_scan = 0; e.ai_wait = Rng.ri(12, 22); e.ai_t = 0; e.ai_patience = 0; e.ai_aim_t = 0; e.ai_rec = 0
		e.perk = str(opt.get("perk", "silencer")) if is_h else str(Rng.pick(PERKS))
		apply_perk(e)
		if is_h:
			w.human = e
		w.ents.append(e)
	var r_spawn := Rng.shuffle([Vector3i(2, 30, 15), Vector3i(2, 12, 15), Vector3i(3, 30, 14), Vector3i(3, 12, 15), Vector3i(4, 14, 15), Vector3i(5, 20, 19)])
	var runners: Array = []
	for i in n_r:
		var is_r: bool = w.role == "runner" and i == 0
		var sp: Vector3i = r_spawn[i]
		var e := new_ent(w)
		e.nm = RUNNER_NAMES[i]; e.type = "human" if is_r else "bot"; e.role = "runner"; e.fl = sp.x
		e.x = (sp.y + 0.5) * TS; e.y = (sp.z + 0.5) * TS; e.outfit = Outfit.new_guest(Rng.rnd() < 0.2)
		e.ai_mode = "blend"; e.ai_scan = 0; e.ai_t = Rng.ri(8, 22); e.ai_wait = 0
		e.money = Cfg.MONEY_RUNNER
		if is_r:
			w.human = e
		w.ents.append(e)
		runners.append(e)
	var pool := Rng.shuffle(Hotel.room_pool.duplicate())
	for r in runners:
		var rm: Room = pool.pop_back()
		r.room = rm.nm; r.room_floor = rm.fi
	var taken := {}
	for r in runners:
		r.tasks = assign_tasks(r, taken)
	Rng.shuffle(runners)
	w.targets = [runners[0].id, runners[1].id]
	for x in w.ents:
		if x.role == "hunter":
			x.target_ids = w.targets.duplicate()
	# PNJ
	for sp in NPC_SPECS:
		var fi: int = sp["f"]
		var f := fdat(fi)
		var home: String = sp["home"]
		var tiles: Array = []
		var room_one := ""
		if home == "pub":
			tiles = f.tiles_pub
		elif home == "rooms":
			for r in f.rooms:
				if r.zone == Cfg.ZONE_ROOM:
					tiles += f.room_tiles.get(r.nm, [])
			tiles += f.tiles_pub
		elif home == "roomOne":
			var rr: Array = f.rooms.filter(func(r): return r.zone == Cfg.ZONE_ROOM and r.nm != "Despacho del gerente")
			var pr: Room = Rng.pick(rr)
			tiles = f.room_tiles.get(pr.nm, []).duplicate()
			room_one = pr.nm
		elif home == "fixed":
			tiles = [sp["at"]]
		else:
			tiles = f.room_tiles.get(home, f.tiles_pub)
		var t0: Vector2i = sp["at"] if home == "fixed" else Rng.pick(tiles)
		var staff_role: String = sp.get("staff", "")
		var o: Outfit = Outfit.new_staff(staff_role) if staff_role != "" else Outfit.new_guest(Rng.rnd() < 0.4)
		var n := new_ent(w)
		n.room = room_one; n.room_floor = fi
		n.nm = str(Outfit.STAFF[staff_role]["label"]) if staff_role != "" else "Huésped"
		n.type = "npc"; n.role = "civil"; n.fl = fi
		n.x = (t0.x + 0.5) * TS; n.y = (t0.y + 0.5) * TS; n.outfit = o
		n.staff = staff_role != ""; n.tiles = tiles; n.fixed = home == "fixed"
		if n.fixed:
			n.shop = str({"guard": "hunter", "waiter": "runner"}.get(staff_role, ""))
		n.ai_mode = "idle"; n.ai_wait = Rng.rnd() * 4.0
		w.ents.append(n)
	# objetos
	var pid := 0
	var mk: Vector3i = Rng.pick(Hotel.key_masterkey)
	var bd: Vector3i = Rng.pick(Hotel.key_badge)
	pid += 1
	w.picks.append(_mk_pick(pid, "masterkey", mk, "llave maestra"))
	pid += 1
	w.picks.append(_mk_pick(pid, "badge", bd, "insignia de botones"))
	var spots := Rng.shuffle(Hotel.scrap_spots.duplicate())
	for i in mini(8, spots.size()):
		pid += 1
		w.picks.append(_mk_pick(pid, "scrap", spots[i], Rng.pick(Hotel.scrap_names)))
	# la cizalla (rara: una por partida) y carteras sueltas
	var cut_spot: Vector3i = spots[8] if spots.size() > 8 else Vector3i(0, 30, 20)
	pid += 1
	w.picks.append(_mk_pick(pid, "cutter", cut_spot, "cizalla"))
	for i in Cfg.CASH_SPOTS:
		var cf := Rng.ri(0, 5)
		var ct: Vector2i = Rng.pick(fdat(cf).tiles_pub)
		pid += 1
		var cp := _mk_pick(pid, "cash", Vector3i(cf, ct.x, ct.y), "cartera")
		cp.value = Rng.ri(2, 5) * 10
		w.picks.append(cp)
	if opt.get("tutorial", false):
		_setup_tutorial(w)
	refresh_tasks(w)
	if w.tutorial:
		return w
	if w.role == "runner":
		var me := w.human
		wlog(w, "Tu cartel de corredor: " + str(task_units(me).y) + " encargos propios. Tu habitación es la " + me.room.split(" ")[me.room.split(" ").size() - 1] + ". Las demás puertas están cerradas: fuerza la cerradura (mantén la tecla de interactuar) o busca la llave maestra, pero si alguien te ve te denunciará.")
		wlog(w, "Tus compañeros corredores se ven con el nombre en azul.")
		wlog(w, "Tu contacto está en la barra del bar (Planta 2): vende ganzúas, sobornos y chivatazos, te compra soplos y te ofrece trabajos extra por dinero. Pulsa E o haz clic sobre él.")
	elif w.role == "hunter":
		wlog(w, "Tu cartel tiene dos rostros. Encuéntralos y elimínalos sin que nadie lo vea.")
		wlog(w, "Ventaja: " + str(PERK_NAMES[w.human.perk]) + ". Tienes " + str(w.human.ammo) + " balas y un cuchillo (Q para cambiar). El vigilante de la entrada (planta baja) es amigo de la policía: te vende balas, trajes y rastros, y te da trabajillos.")

	else:
		wlog(w, "Observas una partida entre bots.")
	return w

## Tutorial: sin cazadores activos ni reloj, y un encargo de práctica cerca.
static func _setup_tutorial(w: World) -> void:
	w.tutorial = true
	w.limit = 1e6
	for e in w.ents:
		if e.role == "hunter":
			e.type = "frozen"
			e.fl = 0
			e.x = 6.5 * TS
			e.y = 9.5 * TS
	var me := w.human
	if me == null:
		return
	var f := fdat(me.fl)
	var mt := me.tile()
	var best: Vector2i = f.tiles_pub[0]
	var bd := 1e9
	for t in f.tiles_pub:
		var d := absf(Vector2(t.x - mt.x, t.y - mt.y).length() - 7.0)
		if d < bd:
			bd = d
			best = t
	var tk := Task.new()
	tk.id = "practica"
	tk.nm = "Encargo de práctica"
	tk.fl = me.fl
	tk.x = best.x
	tk.y = best.y
	tk.dur = 3.0
	me.tasks.push_front(tk)

static func _mk_pick(id: int, kind: String, s: Vector3i, nm: String) -> Items.Pick:
	var p := Items.Pick.new()
	p.id = id; p.kind = kind; p.fl = s.x; p.x = s.y; p.y = s.z; p.nm = nm
	return p

# ---------------------------------------------------------------- reglas

static func has_staff_access(e: Ent) -> bool:
	if e.role == "runner" or e.role == "police":
		return true
	if e.outfit.staff_role != "":
		return true
	return e.badge

static func apply_perk(e: Ent) -> void:
	e.ammo_max = Cfg.AMMO_PERK if e.perk == "ammo" else Cfg.AMMO
	e.ammo = e.ammo_max
	e.money = Cfg.MONEY_HUNTER + (Cfg.MONEY_RICH if e.perk == "rich" else 0)
	e.masterkey = e.perk == "master"
	e.gun = true
	e.knife = false
	e.cuffs = true
	e.equip = "gun"

## Evento para sonidos y efectos (la escena los consume y vacía la lista).
static func ev(w: World, type: String, fl: int, x: float, y: float, extra: Dictionary = {}) -> void:
	var d := {"type": type, "fl": fl, "x": x, "y": y}
	for k in extra:
		d[k] = extra[k]
	w.events.append(d)

static func near_elevator(e: Ent) -> bool:
	var f := fdat(e.fl)
	var t := e.tile()
	for j in range(t.y - 2, t.y + 3):
		for i in range(t.x - 2, t.x + 3):
			if f.at(i, j) == Cfg.T_ELEV:
				return true
	return false

static func floor_list(w: World, ids_or_role, only_alive: bool = true) -> String:
	var fls: Array = []
	for e in w.ents:
		var ok: bool = (e.id in ids_or_role) if ids_or_role is Array else e.role == ids_or_role
		if ok and (e.alive or not only_alive) and not (e.fl in fls):
			fls.append(e.fl)
	fls.sort()
	var names: Array = []
	for f in fls:
		names.append(FLOOR_SHORT[f])
	return " · ".join(PackedStringArray(names)) if not names.is_empty() else "—"

## Hunter conocido por un corredor que aún se puede delatar.
static func snitch_target(w: World, e: Ent) -> Ent:
	for h in w.ents:
		if h.role == "hunter" and h.alive and e.knows.has(h.outfit.id) and not w.snitched.has(h.outfit.id) and not w.wanted.has(h.outfit.id):
			return h
	return null

## Lo que vende el contacto (corredores) o el conserje (cazadores).
## Cada elemento: {id, name, desc, price (negativo = te pagan), ok, why}
static func shop_items(w: World, e: Ent) -> Array:
	var out: Array = []
	if e.role == "runner":
		out.append({"id": "ganzua", "name": "Ganzúa", "desc": "Fuerzas cerraduras en la mitad de tiempo.", "price": 70, "ok": not e.lockpick, "why": "Ya la tienes"})
		out.append({"id": "soborno", "name": "Soborno", "desc": "Borra una denuncia (y el fichado si bajas de " + str(Cfg.STRIKES) + ").", "price": 90, "ok": e.reports > 0, "why": "No tienes denuncias"})
		out.append({"id": "chivatazo", "name": "Chivatazo", "desc": "Durante " + str(int(Cfg.INTEL_DUR)) + " s sabes en qué planta está cada cazador.", "price": 110, "ok": true, "why": ""})
		out.append({"id": "llave", "name": "Llave inglesa montada", "desc": "Sin buscar piezas: un golpe abate a un cazador.", "price": 120, "ok": not e.melee, "why": "Ya tienes una"})
		var h := snitch_target(w, e)
		out.append({"id": "soplo", "name": "Vender un soplo", "desc": "Das a la policía la descripción de un cazador que has visto.", "price": -Cfg.MONEY_SNITCH, "ok": h != null, "why": "No conoces a ningún cazador"})
		out.append({"id": "trabajo", "name": "Pedir un trabajo extra", "desc": "Un recado por el hotel a cambio de $" + str(Cfg.JOB_PAY_MIN) + "-" + str(Cfg.JOB_PAY_MAX) + ".", "price": 0, "ok": e.job == null, "why": "Ya tienes un trabajo pendiente"})
		out.append({"id": "chatarra", "name": "Vender chatarra", "desc": "Piezas que ya no necesitas: $" + str(Cfg.SCRAP_PRICE) + " cada una.", "price": -Cfg.SCRAP_PRICE * e.scrap, "ok": e.melee and e.scrap > 0, "why": "No te sobran piezas"})
	elif e.role == "hunter":
		out.append({"id": "balas", "name": "Munición", "desc": "+4 balas (máximo " + str(e.ammo_max) + ").", "price": 60, "ok": e.ammo < e.ammo_max, "why": "Cargador lleno"})
		out.append({"id": "traje", "name": "Traje limpio", "desc": "Te cambias de ropa al momento: el cartel deja de valer.", "price": 90, "ok": true, "why": ""})
		out.append({"id": "rastro", "name": "Rastro", "desc": "Durante " + str(int(Cfg.INTEL_DUR)) + " s sabes en qué planta está cada objetivo.", "price": 110, "ok": true, "why": ""})
		out.append({"id": "trabajo", "name": "Pedir un trabajillo", "desc": "Un recado para el vigilante a cambio de $" + str(Cfg.JOB_PAY_MIN) + "-" + str(Cfg.JOB_PAY_MAX) + ".", "price": 0, "ok": e.job == null, "why": "Ya tienes un trabajo pendiente"})
		out.append({"id": "insignia", "name": "Insignia de botones", "desc": "Entras en las zonas del personal.", "price": 70, "ok": not e.badge, "why": "Ya la tienes"})
	return out

static func buy(w: World, e: Ent, id: String) -> String:
	var item := {}
	for it in shop_items(w, e):
		if it["id"] == id:
			item = it
	if item.is_empty():
		return ""
	if not item["ok"]:
		return str(item["why"])
	var price: int = item["price"]
	if price > 0 and e.money < price:
		return "No tienes dinero suficiente ($" + str(price) + ")."
	e.money -= price
	var msg := ""
	match id:
		"ganzua":
			e.lockpick = true
			msg = "Has comprado una ganzúa."
		"soborno":
			e.reports -= 1
			if e.reports < Cfg.STRIKES:
				e.marked = false
			msg = "El soborno funciona: una denuncia menos (" + str(e.reports) + "/" + str(Cfg.STRIKES) + ")."
		"chivatazo":
			e.intel_until = w.time + Cfg.INTEL_DUR
			msg = "Chivatazo: cazadores en " + floor_list(w, "hunter") + "."
		"llave":
			e.melee = true
			e.equip = "wrench"
			msg = "Tienes una llave inglesa (Q para equiparla, clic izquierdo para golpear)."
		"soplo":
			var h := snitch_target(w, e)
			w.snitched[h.outfit.id] = true
			w.wanted[h.outfit.id] = true
			var ht := h.tile()
			send_police(w, {"fl": h.fl, "x": ht.x, "y": ht.y}, Cfg.POLICE_STAY)
			wlog(w, "Alguien ha dado tu descripción a la policía.", "hunt")
			msg = "Has vendido el soplo: la policía ya busca a ese tipo. +$" + str(Cfg.MONEY_SNITCH) + "."
		"chatarra":
			msg = "Vendes " + str(e.scrap) + " piezas por $" + str(-price) + "."
			e.scrap = 0
		"balas":
			e.ammo = mini(e.ammo + 4, e.ammo_max)
			msg = "Munición: " + str(e.ammo) + "/" + str(e.ammo_max) + "."
		"traje":
			swap_outfit(w, e, Outfit.new_guest(false))
			msg = "Te cambias de ropa: " + e.outfit.describe() + "."
		"rastro":
			e.intel_until = w.time + Cfg.INTEL_DUR
			msg = "Rastro: objetivos en " + floor_list(w, w.targets) + "."
		"insignia":
			e.badge = true
			msg = "Tienes una insignia de botones."
		"trabajo":
			e.job = Reward.new_job(w, e)
			msg = "Trabajo: " + e.job.nm + ". Lo tienes en el bloc de notas (Tab)."
	ev(w, "buy", e.fl, e.x, e.y)
	if e == w.human:
		wlog(w, msg)
	return msg

const TALK_GUEST := ["¿Ha visto qué ascensores? Puro art déco.", "Dicen que esta noche viene alguien importante.", "El restaurante de la segunda planta es carísimo.", "No encuentro mi habitación, este hotel es un laberinto.", "¿Usted también se aloja aquí?", "Hace una noche estupenda para pasear por la azotea."]
const TALK_STAFF := ["Si necesita algo, pregunte en recepción.", "No puedo entretenerme, tengo trabajo.", "Las habitaciones se limpian por la mañana, señor.", "La lavandería está en el sótano.", "Con tanto huésped no damos abasto."]

static func talk(w: World, e: Ent, n: Ent) -> void:
	n.dir = dir_of(e.x - n.x, e.y - n.y)
	if w.time < n.talk_cd:
		n.say("Ya le he contado todo lo que sé.", 2.4)
		return
	n.talk_cd = w.time + Cfg.TALK_CD
	if e.role == "runner":
		# solo hay rumores si algún cazador ha llamado la atención
		var seen: Array = w.ents.filter(func(h): return h.role == "hunter" and h.alive and (h.sus > 30 or h.outfit.blood or w.wanted.has(h.outfit.id)))
		if not seen.is_empty() and Rng.rnd() < Cfg.RUMOR_CHANCE + 0.3:
			var h: Ent = Rng.pick(seen)
			e.knows[h.outfit.id] = true
			n.say("Hay un tipo raro por " + FLOOR_SHORT[h.fl] + ": " + h.outfit.describe().to_lower() + ".", 4.0)
			if e == w.human:
				wlog(w, "Rumor: alguien sospechoso en " + fdat(h.fl).label + " (" + h.outfit.describe().to_lower() + "). Ya puedes venderle el soplo a tu contacto.")
			return
	elif e.role == "hunter":
		var alive: Array = w.ents.filter(func(t): return t.alive and t.id in w.targets)
		if not alive.is_empty() and Rng.rnd() < Cfg.RUMOR_CHANCE:
			var t: Ent = Rng.pick(alive)
			n.say("Un huésped de " + FLOOR_SHORT[t.fl] + " no paraba de mirar a todos lados.", 4.0)
			if e == w.human:
				wlog(w, "Rumor: uno de tus objetivos estaba hace poco en " + fdat(t.fl).label + ".")
			return
	n.say(Rng.pick(TALK_STAFF if n.staff else TALK_GUEST), 3.0)

## Encargos personales: 1 en tu habitación, 2 en habitaciones ajenas y el resto del catálogo.
static func assign_tasks(r: Ent, taken: Dictionary) -> Array:
	var n := Rng.ri(Cfg.TASKS_MIN, Cfg.TASKS_MAX)
	var out: Array = []
	var own := Hotel.room_by(r.room_floor, r.room)
	var tpl := Rng.shuffle(Hotel.room_tasks.duplicate())
	var o0: Dictionary = tpl.pop_back()
	var sp0 := Hotel.room_spot(own)
	var t := Task.new()
	t.id = "own_" + str(o0["id"]); t.nm = str(o0["name"]).replace("la {r}", "tu " + own.label())
	t.fl = own.fi; t.x = sp0.x; t.y = sp0.y; t.dur = float(o0["dur"]); t.room_name = own.nm; t.own = true
	out.append(t)
	var others := Rng.shuffle(Hotel.room_pool.filter(func(q): return q != own and not taken.has(q.key())))
	for i in 2:
		if others.is_empty():
			break
		var q: Room = others.pop_back()
		var t1: Dictionary = tpl.pop_back()
		var sp := Hotel.room_spot(q)
		taken[q.key()] = true
		var tr := Task.new()
		tr.id = "room" + str(i) + "_" + str(t1["id"]); tr.nm = str(t1["name"]).replace("{r}", q.label())
		tr.fl = q.fi; tr.x = sp.x; tr.y = sp.y; tr.dur = float(t1["dur"]); tr.room_name = q.nm
		out.append(tr)
	# el resto, del catálogo (las parejas recoger/entregar cuentan como un encargo)
	var units: Array = []
	for d in Hotel.task_defs:
		if d.kind == "pick":
			var pair: Task = null
			for x in Hotel.task_defs:
				if x.id == d.pair:
					pair = x
			units.append([d, pair])
		elif d.kind != "drop":
			units.append([d])
	Rng.shuffle(units)
	var need := n - out.size()
	var n_sab := 0
	for u in units:
		if need <= 0:
			break
		if u[0].sab != "" and n_sab >= 2:
			continue
		if u[0].sab != "":
			n_sab += 1
		for d in u:
			out.append(d.copy())
		need -= 1
	return out

static func refresh_tasks(w: World) -> void:
	var d := 0
	var t := 0
	for e in w.ents:
		if e.role == "runner" and e.alive:
			for k in e.tasks:
				if k.kind == "pick":
					continue
				t += 1
				if k.done:
					d += 1
	w.tasks_done = d
	w.quota = t

## x = hechos, y = total (las recogidas no cuentan).
static func task_units(e: Ent) -> Vector2i:
	var d := 0
	var t := 0
	for k in e.tasks:
		if k.kind == "pick":
			continue
		t += 1
		if k.done:
			d += 1
	return Vector2i(d, t)

static func has_key(e: Ent, r: Room) -> bool:
	if r.zone != Cfg.ZONE_ROOM:
		return true
	if e.role == "police" or (e.outfit != null and e.outfit.staff_role != "") or e.masterkey:
		return true
	return e.room != "" and e.room == r.nm and e.room_floor == r.fi

static func door_open(w: World, r: Room) -> bool:
	return float(w.unlocked.get(r.key(), 0.0)) > w.time

static func can_pass(w: World, e: Ent, r: Room) -> bool:
	return has_key(e, r) or door_open(w, r)

static func inside_room(e: Ent, r: Room) -> bool:
	var t := e.tile()
	return e.fl == r.fi and r.contains(t.x, t.y)

static func lock_mask(w: World, e: Ent) -> PackedByteArray:
	var f := fdat(e.fl)
	var used := false
	for k in f.lock_at:
		var r: Room = f.lock_at[k]
		if can_pass(w, e, r) or inside_room(e, r):
			continue
		if not used:
			if _lockm.size() != Cfg.W * Cfg.H:
				_lockm.resize(Cfg.W * Cfg.H)
			_lockm.fill(0)
			used = true
		_lockm[k] = 1
	return _lockm if used else PackedByteArray()

static func free_for(w: World, e: Ent, f: FloorData, px: float, py: float) -> bool:
	if not free_at(f, px, py):
		return false
	for c in 4:
		var qx := px + (9.0 if (c & 1) else -9.0)
		var qy := py + (9.0 if (c & 2) else -9.0)
		var idx := floori(qy / TS) * W + floori(qx / TS)
		if f.lock_at.has(idx):
			var rm: Room = f.lock_at[idx]
			if not can_pass(w, e, rm) and not inside_room(e, rm):
				return false
	return true

static func sight_scale(w: World) -> float:
	return Cfg.BLACKOUT_SIGHT if w.sab_blackout > w.time else 1.0

static func elev_out(w: World) -> bool:
	return w.sab_elev > w.time or w.sab_alarm > w.time

static func report_by(w: World, culprit: Ent, msg: String) -> bool:
	if culprit.undercover:
		return false
	var wit := civils_seeing(w, culprit, null, Cfg.WITNESS_RADIUS * TS * sight_scale(w))
	if wit.is_empty():
		return false
	var c: Ent = wit[0]
	for x in wit:
		if x.staff:
			c = x
			break
	var t := culprit.tile()
	alert_npc(w, c, "", "report", culprit.fl, t.x, t.y, {"rep": culprit.id, "msg": msg})
	return true

static func apply_sab(w: World, e: Ent, t: Task) -> void:
	var now := w.time
	report_by(w, e, "¡Ha sido ese! ¡Ha tocado algo que no debía! Aviso a seguridad.")
	ev(w, "sab_" + t.sab, e.fl, e.x, e.y)
	if t.sab == "blackout":
		w.sab_blackout = now + Cfg.SAB_BLACKOUT
		wlog(w, "Se ha ido la luz en todo el hotel.", "alarm")
	elif t.sab == "alarm":
		w.sab_alarm = now + Cfg.SAB_ALARM
		wlog(w, "¡Suena la alarma de incendios! Los huéspedes evacúan.", "alarm")
	elif t.sab == "elev":
		w.sab_elev = now + Cfg.SAB_ELEV
		wlog(w, "Los ascensores han quedado fuera de servicio.", "alarm")

static func arrest(w: World, r: Ent, p: Ent) -> void:
	r.arrest = Cfg.ARREST_DUR; r.marked = false
	cancel_hold(w, r)
	r.goal = null; r.has_path = false; r.path_key = ""; r.moving = false
	w.stats["arrests"] += 1
	if r.carry != "":
		for t in r.tasks:
			if t.pair == r.carry:
				t.done = false
		r.carry = ""
	r.ai_mode = "blend"; r.ai_t = 6
	if r == w.human:
		wlog(w, "La policía te detiene: pierdes el encargo que llevabas y quedas retenido " + str(int(Cfg.ARREST_DUR)) + " s.", "report", r.id)
	else:
		wlog(w, r.nm + " ha sido detenido por la policía.", "team", r.id)
	if p != null:
		p.stay_until = maxf(p.stay_until, w.time + 12.0)

static func callers_for(w: World, oid: String) -> bool:
	for c in w.ents:
		if c.alive and c.role == "civil" and (c.state == "call" or c.state == "calling") and c.call_ctx.get("outfit", "") == oid:
			return true
	return false

static func is_hot(w: World, h: Ent) -> bool:
	return w.wanted.has(h.outfit.id) or callers_for(w, h.outfit.id)

static func civils_seeing(w: World, a: Ent, b: Ent, rad: float) -> Array:
	var out: Array = []
	var f := fdat(a.fl)
	for c in w.ents:
		if not c.alive or c.role != "civil" or c.fl != a.fl or c.ko_t > 0:
			continue
		if (dist(c.x, c.y, a.x, a.y) <= rad and Nav.los(f, c.x, c.y, a.x, a.y)) or (b != null and dist(c.x, c.y, b.x, b.y) <= rad and Nav.los(f, c.x, c.y, b.x, b.y)):
			out.append(c)
	return out

static func alert_npc(w: World, npc: Ent, culprit_outfit: String, why: String, fl: int, tx: int, ty: int, extra: Dictionary = {}) -> void:
	if not npc.alive or npc.state == "call" or npc.state == "calling" or npc.state == "stun":
		return
	npc.state = "call"
	npc.call_ctx = {"outfit": culprit_outfit, "fl": fl, "x": tx, "y": ty, "why": why, "rep": 0, "msg": ""}
	for k in extra:
		npc.call_ctx[k] = extra[k]
	npc.goal = null; npc.path_key = ""; npc.ai_mode = "call"
	var line := "¡Esto no me gusta! Llamo a la policía."
	if why == "report":
		line = extra.get("msg", "¡Alguien está forzando una puerta! Aviso a seguridad.")
	elif why == "crime":
		line = "¡Un crimen! ¡Voy a llamar a la policía!"
	elif why == "body":
		line = "¡Un cadáver! ¡Policía!"
	npc.say(line, 3)

static func send_police(w: World, ctx: Dictionary, stay: float) -> void:
	var active: Array = w.ents.filter(func(p): return p.role == "police" and p.alive)
	if not active.is_empty():
		for p in active:
			p.target = Vector3i(ctx["fl"], ctx["x"], ctx["y"])
			p.ai_mode = "go"; p.goal = null
			p.stay_until = maxf(p.stay_until, w.time + stay)
	else:
		for d in w.dispatch:
			if not d["done"]:
				return
		w.dispatch.append({"t": w.time + Cfg.POLICE_DELAY, "fl": ctx["fl"], "x": ctx["x"], "y": ctx["y"], "done": false, "stay": stay})

static func police_call(w: World, ctx: Dictionary) -> void:
	if int(ctx.get("rep", 0)) != 0:
		report_runner(w, ctx)
		return
	w.stats["calls"] += 1
	if ctx.get("outfit", "") != "":
		w.wanted[ctx["outfit"]] = true
	wlog(w, "Un testigo ha llamado a la policía.", "call")
	send_police(w, ctx, Cfg.POLICE_STAY)

static func report_runner(w: World, ctx: Dictionary) -> void:
	var r := w.ent_by_id(int(ctx["rep"]))
	w.stats["reports"] += 1
	send_police(w, ctx, 45.0)
	if r == null or not r.alive:
		return
	r.reports += 1
	for h in w.ents:
		if h.role == "hunter" and h.alive:
			h.money += Cfg.MONEY_REPORT
	var left := Cfg.STRIKES - r.reports
	if r == w.human:
		wlog(w, "Te han denunciado (" + str(r.reports) + "). " + ("La policía va a rondar por la zona. Con " + str(Cfg.STRIKES) + " denuncias quedarás fichado." if left > 0 else "Estás fichado: si la policía te ve, te detiene, y el cliente se retrasa."), "report", r.id)
	else:
		wlog(w, "Denuncian a " + r.nm + " (" + str(r.reports) + ").", "team", r.id)
	wlog(w, "Una denuncia: alguien sospechoso en " + fdat(int(ctx["fl"])).label + ".", "hunt")
	if r.reports >= Cfg.STRIKES:
		r.marked = true
		w.limit += Cfg.CLIENT_DELAY
		if r != w.human:
			wlog(w, r.nm + " queda fichado.", "team", r.id)

## La policía llega en coche: aparca delante del hotel y entra por la puerta.
static func spawn_police(w: World, d: Dictionary) -> void:
	Combat.add_car(w, "police", Combat.park_slot(w), d)

static func spawn_police_now(w: World, d: Dictionary, car_x: float) -> void:
	var sp := [Vector2i(21, 25), Vector2i(23, 25), Vector2i(22, 24)]
	for i in Cfg.POLICE_COUNT:
		var p := new_ent(w)
		p.nm = "Policía"; p.type = "police"; p.role = "police"; p.fl = 1
		p.x = (sp[i].x + 0.5) * TS; p.y = (sp[i].y + 0.5) * TS; p.outfit = Outfit.new_police(); p.dir = "up"
		p.target = Vector3i(d["fl"], d["x"], d["y"]); p.ai_mode = "go"; p.ai_t = 0
		p.stay_until = w.time + float(d.get("stay", Cfg.POLICE_STAY))
		w.ents.append(p)
	wlog(w, "Un coche de policía aparca en la puerta: los agentes entran en el hotel.", "alarm")

# ---------------------------------------------------------------- acciones

static func teleport(w: World, e: Ent, fl: int) -> void:
	var f := fdat(fl)
	e.fl = fl; e.x = (f.spawn.x + 0.5) * TS; e.y = (f.spawn.y + 0.5) * TS
	e.has_path = false; e.path_key = ""; e.moving = false; e.stair_cd = 0.6; e.goal = null

static func use_stairs(w: World, e: Ent, d: int) -> void:
	var nf := e.fl + d
	if nf < 0 or nf >= floors().size():
		return
	var f := fdat(nf)
	e.fl = nf
	if d > 0:
		e.x = (f.down.x - 0.5) * TS; e.y = (f.down.y + 0.5) * TS
	else:
		e.x = (f.up.x + 1.5) * TS; e.y = (f.up.y + 0.5) * TS
	e.stair_cd = 0.7; e.has_path = false; e.path_key = ""

static func swap_outfit(w: World, e: Ent, o: Outfit) -> void:
	e.outfit = o
	if e.role == "hunter":
		e.sus = minf(e.sus, 30.0)
	e.has_path = false

static func kill(w: World, killer: Ent, victim: Ent, how: String) -> void:
	if not victim.alive:
		return
	victim.alive = false; victim.state = "dead"; victim.moving = false; victim.aim = false
	if victim.hold != null:
		cancel_hold(w, victim)
	var c := Items.Corpse.new()
	c.id = w.next_id; w.next_id += 1
	c.x = victim.x; c.y = victim.y; c.fl = victim.fl; c.outfit = victim.outfit; c.nm = victim.nm; c.role = victim.role
	c.t = w.time; c.victim_id = victim.id; c.ang = fmod(victim.id * 1.7, 6.28)
	c.killer_id = killer.id
	c.killer_role = killer.role
	w.corpses.append(c)
	if victim.role == "civil":
		w.stats["civ_kills"] += 1
	else:
		w.stats["kills"] += 1
	if victim.role == "police" and killer.role != "police":
		Alarm.cop_killed(w, killer, victim)
	if killer.role == "hunter" and victim.id in w.targets:
		killer.money += Cfg.MONEY_TARGET
		if killer == w.human:
			wlog(w, "Objetivo eliminado: +$" + str(Cfg.MONEY_TARGET) + ".")
	if how == "gun":
		# un disparo con silenciador se oye de cerca aunque no se vea
		for npc in w.ents:
			if npc.role == "civil" and npc.alive and npc != victim and npc.fl == killer.fl and npc.state == "idle" and dist(npc.x, npc.y, killer.x, killer.y) < 4.5 * TS and Rng.rnd() < 0.6:
				npc.dir = dir_of(killer.x - npc.x, killer.y - npc.y)
				npc.say("¿Ha oído eso?", 2.0)
	if how == "gun" or how == "knife":
		var wr := Cfg.WITNESS_RADIUS * TS * sight_scale(w) * (Cfg.SILENCER_PERK if (how == "gun" and killer.perk == "silencer") else 1.0) * (0.75 if how == "knife" else 1.0)
		var wit: Array = civils_seeing(w, killer, victim, wr).filter(func(x): return x != victim)
		if not wit.is_empty():
			killer.sus = 100
			if victim.role == "civil":
				c.found = true
				Alarm.innocent_found(w, c)
			var kt := killer.tile()
			for x in wit:
				alert_npc(w, x, killer.outfit.id, "crime", killer.fl, kt.x, kt.y)
		for r in w.ents:
			if r.role == "runner" and r.alive and r != victim and r.fl == killer.fl and dist(r.x, r.y, killer.x, killer.y) < Cfg.WITNESS_RADIUS * TS * sight_scale(w) and Nav.los(fdat(r.fl), r.x, r.y, killer.x, killer.y):
				r.knows[killer.outfit.id] = true
	if how == "police":
		w.fx.append({"type": "flash", "fl": killer.fl, "x": killer.x, "y": killer.y, "t": 0.3, "big": true})
		w.fx.append({"type": "tracer", "fl": killer.fl, "x": killer.x, "y": killer.y - 14, "x2": victim.x, "y2": victim.y - 10, "t": 0.22, "loud": true})
		ev(w, "shot_police", killer.fl, killer.x, killer.y)
		# los disparos de la policía asustan a todo el que esté cerca
		for npc in w.ents:
			if npc.role == "civil" and npc.alive and npc.fl == killer.fl and (npc.state == "idle" or npc.state == "evac") and dist(npc.x, npc.y, killer.x, killer.y) < 10 * TS:
				npc.state = "scared"; npc.ai_t = Rng.ri(4, 8); npc.goal = null; npc.moving = false
				npc.dir = dir_of(killer.x - npc.x, killer.y - npc.y)
				if Rng.rnd() < 0.4:
					npc.say(Rng.pick(["¡Disparos!", "¡Al suelo!", "¡Dios mío!"]), 2.0)
		wlog(w, "La policía abate a un sospechoso." if victim.role == "hunter" else "La policía abate a " + victim.nm + ".", "alarm")
	elif victim.role == "hunter":
		wlog(w, victim.nm + " ha caído.", "hunt")
	elif victim.role == "runner":
		wlog(w, victim.nm + " ha sido eliminado.")
	w.fx.append({"type": "blood", "fl": victim.fl, "x": victim.x, "y": victim.y, "t": 0.6})
	check_win(w)

static func try_shoot(w: World, e: Ent) -> bool:
	if e.cd > 0:
		return false
	if e.ammo <= 0:
		e.cd = 0.4
		ev(w, "empty", e.fl, e.x, e.y)
		var nm := "Sin balas. Usa las esposas o los puños (Q) o compra munición al vigilante de la entrada."
		if e == w.human and (w.logs.is_empty() or w.logs[w.logs.size() - 1].msg != nm):
			wlog(w, nm)
		return false
	e.cd = Cfg.FIRE_CD
	e.ammo -= 1
	var tx := e.aim_x
	var ty := e.aim_y
	var best: Ent = null
	var bd := 20.0
	for v in w.ents:
		if v == e or not v.alive or v.fl != e.fl or v.escaped:
			continue
		var d := dist(v.x, v.y - 2, e.aim_x, e.aim_y)
		if d < bd and dist(e.x, e.y, v.x, v.y) <= Cfg.KILL_RANGE * TS and Nav.los(fdat(e.fl), e.x, e.y, v.x, v.y):
			bd = d
			best = v
	if best != null:
		tx = best.x
		ty = best.y - 10
	var a := atan2(ty - (e.y - 14), tx - e.x)
	w.fx.append({"type": "flash", "fl": e.fl, "x": e.x + cos(a) * 14, "y": e.y - 14 + sin(a) * 14, "t": 0.08})
	w.fx.append({"type": "tracer", "fl": e.fl, "x": e.x + cos(a) * 14, "y": e.y - 14 + sin(a) * 14, "x2": tx, "y2": ty, "t": 0.12, "loud": false})
	ev(w, "shot", e.fl, e.x, e.y)
	Combat.muzzle(w, e)
	if best != null:
		kill(w, e, best, "gun")
		return true
	return false

## Cuchillo del cazador: silencioso y a quemarropa.
static func try_knife(w: World, e: Ent) -> bool:
	if e.cd > 0:
		return false
	e.cd = Cfg.KNIFE_CD
	e.fx_swing = 0.2
	ev(w, "swing", e.fl, e.x, e.y)
	var ax := e.aim_x - e.x
	var ay := e.aim_y - e.y
	var al := maxf(Vector2(ax, ay).length(), 1.0)
	for v in w.ents:
		if v == e or not v.alive or v.fl != e.fl or v.role == "hunter" or v.escaped:
			continue
		var dx: float = v.x - e.x
		var dy: float = v.y - e.y
		var d := Vector2(dx, dy).length()
		if d > Cfg.KNIFE_RANGE or (dx * ax + dy * ay) / (d * al + 0.001) < 0.3:
			continue
		ev(w, "stab", e.fl, v.x, v.y)
		kill(w, e, v, "knife")
		return true
	return false

static func try_melee(w: World, e: Ent) -> void:
	if e.cd > 0 or not e.melee:
		return
	e.cd = Cfg.MELEE_CD
	var ax := e.aim_x - e.x
	var ay := e.aim_y - e.y
	var al := maxf(Vector2(ax, ay).length(), 1.0)
	e.fx_swing = 0.2
	for v in w.ents:
		if v == e or not v.alive or v.fl != e.fl or v.role == "runner" or v.escaped:
			continue
		var dx: float = v.x - e.x
		var dy: float = v.y - e.y
		var d := Vector2(dx, dy).length()
		if d > Cfg.MELEE_RANGE or (dx * ax + dy * ay) / (d * al + 0.001) < 0.2:
			continue
		if v.role == "hunter" or v.role == "police":
			kill(w, e, v, "melee")
			return
		var et := e.tile()
		alert_npc(w, v, "", "sospecha", e.fl, et.x, et.y)
		if v.state == "call":
			v.state = "stun"; v.ai_stun = 2.2; v.goal = null
			v.say("¡Eh! ¿Qué hace?", 2)
		return

static func task_avail(w: World, t: Task, e: Ent) -> bool:
	if t.done:
		return false
	if t.kind == "drop":
		return e.carry == t.id
	if t.kind == "pick":
		return e.carry == ""
	return true

static func start_hold(w: World, e: Ent, type: String, ref, dur: float) -> void:
	var h := Hold.new()
	h.type = type; h.ref = ref; h.t = 0; h.dur = dur
	e.hold = h
	if type == "task":
		ref.busy = e.id
	e.moving = false; e.aim = false

static func cancel_hold(w: World, e: Ent) -> void:
	if e.hold != null and e.hold.type == "task" and e.hold.ref.busy == e.id:
		e.hold.ref.busy = 0
	e.hold = null

static func hold_valid(w: World, e: Ent, h: Hold) -> bool:
	match h.type:
		"strip":
			return not h.ref.stripped and h.ref.outfit.kind != "under"
		"ward":
			return not h.ref.looted
		"task":
			return task_avail(w, h.ref, e)
		"force":
			return not can_pass(w, e, h.ref) and not inside_room(e, h.ref)
		"talk":
			return h.ref.alive and h.ref.state != "call" and h.ref.state != "calling" and dist(e.x, e.y, h.ref.x, h.ref.y) < 60
		"cut":
			return e.cutter and near_elevator(e)
		"job":
			return e.job != null
		"escape":
			return w.alarm >= 3
		"unlock":
			return h.ref.alive and h.ref.cuffed and dist(e.x, e.y, h.ref.x, h.ref.y) < 70
	return true

static func finish_hold(w: World, e: Ent, h: Hold) -> void:
	var human := e == w.human
	if h.type == "task":
		var t: Task = h.ref
		t.done = true
		if t.kind == "pick":
			e.carry = t.pair
			if human:
				var dn := ""
				for x in e.tasks:
					if x.id == t.pair:
						dn = x.nm
				wlog(w, "Llevas el encargo. Entrégalo: " + dn + ".")
		else:
			if t.kind == "drop":
				e.carry = ""
			w.stats["tasks"] += 1
			var owner := task_owner(w, t)
			refresh_tasks(w)
			ev(w, "task", e.fl, e.x, e.y, {"who": e.id})
			var mine := task_units(e)
			if human:
				if owner != null and owner != e:
					wlog(w, "Ayudas a " + owner.nm + ": " + t.nm + ". Equipo " + str(w.tasks_done) + "/" + str(w.quota), "task")
				else:
					wlog(w, "Hecho: " + t.nm + ". Tus encargos " + str(mine.x) + "/" + str(mine.y) + " · equipo " + str(w.tasks_done) + "/" + str(w.quota), "task")
			else:
				wlog(w, e.nm + " completa: " + t.nm + ". Equipo " + str(w.tasks_done) + "/" + str(w.quota), "task")
			if t.sab != "":
				apply_sab(w, e, t)
			if owner != null:
				Reward.check_finish(w, owner)
		if e.type == "bot":
			e.ai_mode = "blend"; e.ai_t = Rng.ri(Cfg.BOT_IDLE_MIN, Cfg.BOT_IDLE_MAX); e.goal = null
		check_win(w)
	elif h.type == "force":
		var rm: Room = h.ref
		w.unlocked[rm.key()] = w.time + Cfg.UNLOCK_FOR
		w.stats["forced"] += 1
		ev(w, "door", e.fl, e.x, e.y)
		e.goal = null; e.has_path = false; e.path_key = ""
		if e.role == "runner":
			if report_by(w, e, "¡Está forzando la cerradura de una habitación! Aviso a seguridad.") and human:
				wlog(w, "Alguien te ha visto forzar la puerta y va a avisar a seguridad.", "report", e.id)
		elif not civils_seeing(w, e, null, Cfg.WITNESS_RADIUS * TS * sight_scale(w)).is_empty():
			e.sus = minf(100.0, maxf(e.sus, 55.0))
			if human:
				wlog(w, "Te han visto forzar la puerta: tu sospecha se dispara.")
		if human:
			wlog(w, "Has forzado la cerradura de la " + rm.label() + ". Queda abierta unos segundos.")
	elif h.type == "strip":
		var c: Items.Corpse = h.ref
		var o := c.outfit.clone()
		o.blood = true
		swap_outfit(w, e, o)
		c.outfit = Outfit.new_under(o)
		c.stripped = true
		if human:
			wlog(w, "Llevas su ropa, pero está manchada de sangre. Lávala antes de que alguien lo note.")
	elif h.type == "ward":
		h.ref.looted = true
		var no: Outfit = Outfit.new_guest(Rng.rnd() < 0.3) if Rng.rnd() < 0.5 else Outfit.new_staff(Rng.pick(["bell", "tech", "waiter", "maid", "chef"]))
		swap_outfit(w, e, no)
		if human:
			wlog(w, "Te has cambiado de ropa: " + no.describe() + ".")
	elif h.type == "wash":
		e.outfit.blood = false
		if human:
			wlog(w, "El traje está limpio.")
	elif h.type == "job":
		Reward.finish_job(w, e)
	elif h.type == "escape":
		e.escaped = true
		e.moving = false
		e.fl = -1
		ev(w, "door", 0, 0, 0)
		wlog(w, (("¡Has escapado del hotel!" if e == w.human else e.nm + " ha escapado del hotel.")), "team", e.id)
		check_win(w)
	elif h.type == "unlock":
		Alarm.free_prisoner(w, h.ref, "ganzúa")
	elif h.type == "cut":
		e.cutter = false
		w.sab_elev = maxf(w.sab_elev, w.time + Cfg.SAB_ELEV_CUT)
		w.fx.append({"type": "sparks", "fl": e.fl, "x": e.x, "y": e.y - 20, "t": 1.4})
		ev(w, "sparks", e.fl, e.x, e.y)
		report_by(w, e, "¡Ese hombre ha roto el ascensor! Aviso a seguridad.")
		wlog(w, "¡Alguien ha roto los ascensores! Fuera de servicio un buen rato.", "alarm")
	if e.type == "bot" and e.role == "hunter":
		e.ai_mode = "patrol"; e.goal = null

static func hold_update(w: World, e: Ent, dt: float) -> void:
	var h := e.hold
	if h == null:
		return
	if not hold_valid(w, e, h):
		cancel_hold(w, e)
		return
	h.t += dt
	if h.t >= h.dur:
		e.hold = null
		if h.type == "task" and h.ref.busy == e.id:
			h.ref.busy = 0
		finish_hold(w, e, h)

static func check_win(w: World) -> void:
	if w.is_over():
		return
	var t_a := 0
	var h_a := 0
	refresh_tasks(w)
	var r_in := 0
	var r_out := 0
	for e in w.ents:
		if e.alive and e.id in w.targets:
			t_a += 1
		if e.alive and e.role == "hunter":
			h_a += 1
		if e.alive and e.role == "runner":
			if e.escaped:
				r_out += 1
			else:
				r_in += 1
	if w.alarm >= 3 and r_out > 0 and r_in == 0:
		w.over = {"winner": "runners", "reason": "Los corredores que quedaban han escapado del Bluegeddon."}
	elif t_a == 0:
		w.over = {"winner": "hunters", "reason": "Los dos objetivos han sido eliminados."}
	elif h_a == 0:
		w.over = {"winner": "runners", "reason": "Todos los cazadores han caído."}
	elif w.quota > 0 and w.tasks_done >= w.quota:
		w.over = {"winner": "runners", "reason": "Trato cerrado: todos los corredores han terminado sus encargos antes de que llegue el cliente."}
	elif w.time >= w.limit:
		w.over = {"winner": "runners", "reason": "El cliente ha llegado y al menos un objetivo sigue con vida."}

# ---------------------------------------------------------------- movimiento

static func solid_px(f: FloorData, px: float, py: float) -> bool:
	var tx := floori(px / TS)
	var ty := floori(py / TS)
	if Cfg.is_solid(f.at(tx, ty)):
		return true
	return f.blk[ty * W + tx] != 0

static func free_at(f: FloorData, px: float, py: float) -> bool:
	var r := 9.0
	return not solid_px(f, px - r, py - r) and not solid_px(f, px + r, py - r) and not solid_px(f, px - r, py + r) and not solid_px(f, px + r, py + r)

static func dir_of(dx: float, dy: float) -> String:
	if absf(dx) > absf(dy):
		return "left" if dx < 0 else "right"
	return "up" if dy < 0 else "down"

static func nav_to(w: World, e: Ent, fl: int, tx: int, ty: int) -> void:
	e.goal = Goal.make(fl, tx, ty)
	e.path_key = ""; e.has_path = false; e.unreach = false

static func walk_to(w: World, e: Ent, dt: float, speed: float, tx: int, ty: int) -> bool:
	var key := str(e.fl) + ":" + str(tx) + "," + str(ty)
	if e.path_key != key or not e.has_path:
		var t := e.tile()
		var p = Nav.bfs(fdat(e.fl), t.x, t.y, tx, ty, lock_mask(w, e))
		e.path_key = key; e.pi = 0; e.has_path = true
		if p == null:
			e.path = []; e.unreach = true
			return true
		e.path = p
		e.unreach = false
	if e.pi >= e.path.size():
		e.moving = false
		return true
	var n: Vector2i = e.path[e.pi]
	var nx := (n.x + 0.5) * TS
	var ny := (n.y + 0.5) * TS
	var dx := nx - e.x
	var dy := ny - e.y
	var d := Vector2(dx, dy).length()
	if d < 3:
		e.pi += 1
		return e.pi >= e.path.size()
	var st := minf(d, speed * dt)
	e.x += dx / d * st; e.y += dy / d * st
	e.moving = true; e.walk += dt * 9; e.dir = dir_of(dx, dy)
	return false

static func nav_update(w: World, e: Ent, dt: float, speed: float) -> bool:
	var g := e.goal
	if g == null:
		return true
	var f := fdat(e.fl)
	if e.fl != g.fl:
		if elev_out(w) and e.state != "evac" and e.role != "police":
			e.moving = false
			return false
		var fx := f.spawn.x
		var fy := f.spawn.y - 1
		if absf(e.x - (fx + 0.5) * TS) < 14 and absf(e.y - (fy + 0.5) * TS) < 14:
			e.moving = false
			e.elev_t += dt
			if e.elev_t >= 1.1:
				e.elev_t = 0
				teleport(w, e, g.fl)
				e.goal = g
		else:
			e.elev_t = 0
			walk_to(w, e, dt, speed, fx, fy)
			if e.unreach:
				return true
		return false
	return walk_to(w, e, dt, speed, g.x, g.y)

# ---------------------------------------------------------------- IA: civiles

static func npc_ai(w: World, e: Ent, dt: float) -> void:
	if Reward.npc_ai(w, e, dt):
		return
	if w.alarm >= 3:
		if e.state != "flee":
			e.state = "flee"
			e.goal = null
		if e.goal == null:
			nav_to(w, e, 1, 21, 25)
		if nav_update(w, e, dt, Cfg.SPEED_NPC * 1.9):
			e.alive = false
			e.remove = true
		return
	if e.state == "stun":
		e.ai_stun -= dt; e.moving = false
		if e.ai_stun <= 0:
			e.state = "call"
		return
	if e.state == "call":
		var ph := fdat(e.fl).phone
		if e.goal == null:
			nav_to(w, e, e.fl, ph.x, ph.y)
		if nav_update(w, e, dt, Cfg.SPEED_NPC * 1.8):
			e.state = "calling"; e.ai_t = 2.4; e.moving = false
			e.say("¡Operadora! ¡Policía, por favor!", 2.4)
		return
	if e.state == "calling":
		e.ai_t -= dt; e.moving = false
		if e.ai_t <= 0:
			police_call(w, e.call_ctx)
			e.state = "scared"; e.ai_t = 12; e.goal = null
		return
	if e.state == "scared":
		e.ai_t -= dt; e.moving = false
		if e.ai_t <= 0:
			e.state = "idle"; e.ai_wait = 1
		return
	if w.sab_alarm > w.time:
		if e.state != "evac":
			e.state = "evac"; e.goal = null; e.path_key = ""
			var a: Vector2i = Rng.pick(Hotel.assembly)
			nav_to(w, e, 1, a.x, a.y)
			if Rng.rnd() < 0.5:
				e.say("¡Fuego! ¡Todos fuera!", 2.6)
		if e.goal != null:
			if nav_update(w, e, dt, Cfg.SPEED_NPC * 1.6):
				e.goal = null; e.moving = false
		else:
			e.moving = false
		return
	if e.state == "evac":
		e.state = "idle"; e.ai_wait = Rng.ri(1, 5); e.goal = null; e.moving = false
		return
	if e.fixed:
		e.ai_wait -= dt
		if e.ai_wait <= 0:
			e.ai_wait = Rng.ri(3, 7)
			e.dir = Rng.pick(["down", "left", "right", "down"])
		e.moving = false
		return
	if e.ai_wait > 0:
		e.ai_wait -= dt; e.moving = false
		return
	if e.goal == null:
		var t: Vector2i = Rng.pick(e.tiles)
		nav_to(w, e, e.fl, t.x, t.y)
	if nav_update(w, e, dt, Cfg.SPEED_NPC):
		e.goal = null; e.moving = false; e.ai_wait = Rng.ri(2, 8)

# ---------------------------------------------------------------- IA: policía

static func police_ai(w: World, e: Ent, dt: float) -> void:
	if e.freeze:
		e.moving = false
		return
	if w.alarm >= 1:
		e.stay_until = maxf(e.stay_until, w.time + 60.0)
	if Alarm.police_ai(w, e, dt):
		return
	if e.ai_mode == "go":
		if e.goal == null:
			nav_to(w, e, e.target.x, e.target.y, e.target.z)
		if nav_update(w, e, dt, Cfg.SPEED_POLICE):
			e.ai_mode = "search"; e.ai_t = 0; e.goal = null
	elif e.ai_mode == "search":
		e.ai_t -= dt
		if e.goal == null or e.ai_t <= 0:
			var tiles := fdat(e.fl).tiles_pub
			var c = null
			for k in 8:
				var t: Vector2i = Rng.pick(tiles)
				if e.fl != e.target.x or dist(t.x, t.y, e.target.y, e.target.z) < 12:
					c = t
					break
			if c == null:
				c = Rng.pick(tiles)
			nav_to(w, e, e.fl, c.x, c.y)
			e.ai_t = Rng.ri(5, 9)
		if nav_update(w, e, dt, Cfg.SPEED_POLICE * 0.7):
			e.goal = null; e.ai_t = minf(e.ai_t, 1.5)
		if w.time > e.stay_until:
			e.ai_mode = "leave"
			nav_to(w, e, 1, 22, 24)
	elif e.ai_mode == "leave":
		if nav_update(w, e, dt, Cfg.SPEED_POLICE):
			e.alive = false; e.remove = true

# ---------------------------------------------------------------- IA: corredores bot

static func poster_known(w: World, h: Ent) -> bool:
	return w.poster_active.has(h.outfit.id)

static func choose_task(w: World, e: Ent) -> Task:
	var best: Task = null
	var bs := 1e9
	var pool: Array = e.tasks.duplicate()
	if Reward.all_done(e):
		for o in w.ents:
			if o != e and o.role == "runner" and o.alive and not o.escaped:
				for t in o.tasks:
					if t.kind == "":
						pool.append(t)
	for t in pool:
		if not task_avail(w, t, e):
			continue
		var s := absi(t.fl - e.fl) * 22.0 + absf(t.x - e.x / TS) + absf(t.y - e.y / TS) + Rng.rnd() * 30.0
		if e.carry != "" and t.id == e.carry:
			s -= 200
		if s < bs:
			bs = s
			best = t
	return best

## El jugador ha superado el minijuego de un encargo, cerradura o trabajo.
static func complete_action(w: World, e: Ent, hint: Dictionary) -> void:
	var h := Hold.new()
	h.type = hint["type"]
	h.ref = hint["ref"]
	h.dur = 0.0
	if not hold_valid(w, e, h):
		return
	if h.type == "task":
		h.ref.busy = 0
	finish_hold(w, e, h)

## Corredor dueño de un encargo.
static func task_owner(w: World, t: Task) -> Ent:
	for e in w.ents:
		if e.role == "runner" and t in e.tasks:
			return e
	return null

## Acciones de pulsar (sin mantener): hablar, sobornar, soltar a un compañero...
static func press(w: World, e: Ent, hint: Dictionary) -> String:
	var t: String = hint.get("type", "")
	match t:
		"talk":
			talk(w, e, hint["ref"])
			return "ok"
		"bribe":
			var p: Ent = hint["ref"]
			if e.money < Cfg.BRIBE_COP:
				if e == w.human:
					wlog(w, "El policía quiere $" + str(Cfg.BRIBE_COP) + " por hacer la vista gorda.")
				return "no"
			e.money -= Cfg.BRIBE_COP
			ev(w, "cash", e.fl, e.x, e.y)
			Alarm.free_prisoner(w, p, "soborno")
			return "ok"
		"free_key":
			e.cuffkey = false
			Alarm.free_prisoner(w, hint["ref"], "llave de las esposas")
			return "ok"
		"unlock", "task", "force", "job":
			return "minigame"
	return ""

## Bluegeddon (buscar material y salida) y rescate de compañeros esposados.
static func _bot_special(w: World, e: Ent, dt: float) -> bool:
	if w.alarm >= 3:
		var ex := {}
		for x in w.exits:
			if (x["item"] == "rope" and e.rope) or (x["item"] == "dockkey" and e.dockkey):
				ex = x
		if not ex.is_empty():
			if e.goal == null:
				nav_to(w, e, ex["fl"], ex["x"], ex["y"])
			if nav_update(w, e, dt, Cfg.SPEED_BOT_RUN) and e.fl == int(ex["fl"]):
				start_hold(w, e, "escape", null, Cfg.HOLD_ESCAPE)
			return true
		var best = null
		for p in w.picks:
			if p.kind == "rope" or p.kind == "dockkey":
				best = p
		if best != null:
			if e.goal == null or e.goal.x != best.x or e.goal.y != best.y or e.goal.fl != best.fl:
				nav_to(w, e, best.fl, best.x, best.y)
			nav_update(w, e, dt, Cfg.SPEED_BOT_RUN)
			return true
		return false
	var pr: Array = Alarm.prisoners(w).filter(func(x): return x.role == "runner" and x != e)
	if pr.is_empty() or e.ai_mode == "flee":
		return false
	var p0: Ent = pr[0]
	var guard := Alarm.guard_of(w)
	if guard != null and e.money < Cfg.BRIBE_COP:
		return false
	if e.goal == null or e.goal.fl != p0.fl:
		var pt := p0.tile()
		nav_to(w, e, p0.fl, pt.x, pt.y + 1)
	nav_update(w, e, dt, Cfg.SPEED_BOT)
	if e.fl == p0.fl and dist(e.x, e.y, p0.x, p0.y) < 50:
		e.goal = null
		if guard != null:
			press(w, e, {"type": "bribe", "ref": p0})
		else:
			start_hold(w, e, "unlock", p0, Cfg.HOLD_UNLOCK_BOT)
	return true

static func runner_ai(w: World, e: Ent, dt: float) -> void:
	e.cd = maxf(0, e.cd - dt)
	if e.fx_swing > 0:
		e.fx_swing -= dt
	if e.arrest > 0:
		e.arrest -= dt; e.moving = false
		return
	if e.hold == null and _bot_special(w, e, dt):
		return
	e.ai_scan -= dt
	if e.ai_scan <= 0:
		e.ai_scan = 0.3
		for h in w.ents:
			if h.role != "hunter" or not h.alive or h.fl != e.fl:
				continue
			var d := dist(e.x, e.y, h.x, h.y)
			if d > 6 * TS * sight_scale(w) or not Nav.los(fdat(e.fl), e.x, e.y, h.x, h.y):
				continue
			var danger: bool = h.aim or e.knows.has(h.outfit.id) or poster_known(w, h)
			if not danger:
				continue
			if not e.gun and not e.melee and d < 1.1 * TS and e.cd <= 0 and h.ko_t <= 0:
				cancel_hold(w, e)
				e.aim_x = h.x; e.aim_y = h.y; e.dir = dir_of(h.x - e.x, h.y - e.y)
				Combat.punch(w, e)
			if e.gun and e.ammo > 0 and d < 6 * TS and e.cd <= 0:
				cancel_hold(w, e)
				e.aim_x = h.x; e.aim_y = h.y - 2; e.dir = dir_of(h.x - e.x, h.y - e.y)
				try_shoot(w, e)
				e.moving = false
				return
			if e.melee and d < 2.6 * TS:
				cancel_hold(w, e)
				e.aim_x = h.x; e.aim_y = h.y; e.dir = dir_of(h.x - e.x, h.y - e.y)
				try_melee(w, e)
				e.moving = false
				return
			if e.ai_mode != "flee":
				cancel_hold(w, e)
				e.ai_mode = "flee"; e.ai_t = 8
				var nf := e.fl
				while nf == e.fl:
					nf = Rng.ri(0, floors().size() - 1)
				nav_to(w, e, nf, fdat(nf).spawn.x, fdat(nf).spawn.y)
	if e.hold != null:
		e.moving = false
		return
	if e.ai_mode == "flee":
		e.ai_t -= dt
		if nav_update(w, e, dt, Cfg.SPEED_BOT_RUN) or e.ai_t <= 0:
			e.ai_mode = "blend"; e.ai_t = Rng.ri(8, 18); e.goal = null; e.ai_wait = 1
		return
	if e.ai_mode == "task":
		var t := e.ai_task
		if t == null or not task_avail(w, t, e):
			e.ai_mode = "blend"; e.ai_t = 6; e.goal = null
			return
		var rm: Room = Hotel.room_by(t.fl, t.room_name) if t.room_name != "" else null
		if rm != null and not can_pass(w, e, rm) and not inside_room(e, rm):
			# habitación cerrada: ir a la puerta y forzar la cerradura
			if e.goal == null or not e.goal.force:
				nav_to(w, e, t.fl, rm.out.x, rm.out.y)
				e.goal.force = true
			if nav_update(w, e, dt, Cfg.SPEED_BOT):
				if e.fl == t.fl:
					start_hold(w, e, "force", rm, Cfg.FORCE_DUR)
				else:
					e.ai_mode = "blend"; e.ai_t = 5; e.goal = null
			return
		if e.goal != null and e.goal.force:
			e.goal = null
		if e.goal == null:
			nav_to(w, e, t.fl, t.x, t.y)
		if nav_update(w, e, dt, Cfg.SPEED_BOT):
			if e.fl == t.fl:
				start_hold(w, e, "task", t, t.dur)
			else:
				e.ai_mode = "blend"; e.ai_t = 5; e.goal = null
		return
	if e.ai_mode == "scrap":
		var p = e.ai_pick
		if p == null or not (p in w.picks):
			e.ai_mode = "blend"; e.ai_t = 2; e.goal = null
			return
		if e.goal == null:
			nav_to(w, e, p.fl, p.x, p.y)
		if nav_update(w, e, dt, Cfg.SPEED_BOT):
			e.ai_mode = "blend"; e.ai_t = 2; e.goal = null
		return
	# mezclarse con la gente
	e.ai_t -= dt
	if e.ai_t <= 0:
		if not e.melee and Rng.rnd() < 0.35:
			var ps: Array = w.picks.filter(func(q): return q.kind == "scrap")
			if not ps.is_empty():
				e.ai_pick = Rng.pick(ps); e.ai_mode = "scrap"; e.goal = null
				return
		var tk := choose_task(w, e)
		if tk != null:
			e.ai_mode = "task"; e.ai_task = tk; e.goal = null
			return
		e.ai_t = 8
	if e.ai_wait > 0:
		e.ai_wait -= dt; e.moving = false
		return
	if e.goal == null:
		var fl := Rng.ri(0, floors().size() - 1) if Rng.rnd() < 0.15 else e.fl
		var tt: Vector2i = Rng.pick(fdat(fl).tiles_pub)
		nav_to(w, e, fl, tt.x, tt.y)
	if nav_update(w, e, dt, Cfg.SPEED_BOT * 0.85):
		e.goal = null; e.ai_wait = Rng.ri(1, 5)

# ---------------------------------------------------------------- IA: cazadores bot

static func hunter_ai(w: World, e: Ent, dt: float) -> void:
	e.cd = maxf(0, e.cd - dt)
	if e.hold != null:
		e.moving = false
		return
	e.ai_scan -= dt
	if e.ai_mode == "patrol" or e.ai_mode == "stalk":
		if e.ai_scan <= 0:
			e.ai_scan = 0.2
			var seen: Ent = null
			for t in w.ents:
				if not t.alive or not (t.id in e.target_ids) or t.fl != e.fl:
					continue
				if dist(e.x, e.y, t.x, t.y) <= Cfg.BOT_SIGHT * TS * sight_scale(w) and Nav.los(fdat(e.fl), e.x, e.y, t.x, t.y):
					seen = t
					break
			if seen != null:
				e.ai_rec += 0.2
				if e.ai_rec >= Cfg.BOT_RECOGNIZE:
					e.ai_target = seen; e.ai_lost = 0
					if e.ai_mode == "patrol":
						e.ai_mode = "stalk"; e.ai_patience = 0; e.ai_aim_t = 0; e.goal = null
			else:
				e.ai_rec = 0
				if e.ai_mode == "stalk":
					e.ai_lost += 0.2
					if e.ai_lost > 4:
						e.ai_mode = "patrol"; e.aim = false; e.goal = null; e.ai_wait = 0
	if is_hot(w, e) and e.ai_mode != "disguise":
		var ward: Fixture = null
		var bs := 1e9
		for f in floors():
			for wd in f.wards:
				if wd.looted or not wd.has_stand:
					continue
				var s := absi(wd.fi - e.fl) * 20.0 + absf(wd.x - e.x / TS) + absf(wd.y - e.y / TS) + Rng.rnd() * 8.0
				if s < bs:
					bs = s
					ward = wd
		if ward != null:
			e.ai_mode = "disguise"; e.ai_ward = ward; e.goal = null; e.aim = false
	if e.ai_mode == "disguise":
		var wd := e.ai_ward
		if wd == null or wd.looted:
			e.ai_mode = "patrol"; e.goal = null
			return
		if e.goal == null:
			nav_to(w, e, wd.fi, wd.stand.x, wd.stand.y)
		if nav_update(w, e, dt, Cfg.SPEED_BOT_RUN):
			if e.fl == wd.fi:
				start_hold(w, e, "ward", wd, Cfg.HOLD_WARD)
			else:
				e.ai_mode = "patrol"; e.goal = null
		return
	if e.ai_mode == "stalk":
		var tg := e.ai_target
		if tg == null or not tg.alive:
			e.ai_mode = "patrol"; e.aim = false; e.goal = null; e.ai_wait = 0
			return
		var d := dist(e.x, e.y, tg.x, tg.y)
		var vis := tg.fl == e.fl and Nav.los(fdat(e.fl), e.x, e.y, tg.x, tg.y)
		var reach := 5.5 * TS if e.ammo > 0 else Cfg.CUFF_RANGE - 6.0
		if not vis or d > reach:
			e.aim = false; e.ai_aim_t = 0
			if tg.fl == e.fl:
				var tt := tg.tile()
				if e.goal == null or e.goal.x != tt.x or e.goal.y != tt.y:
					nav_to(w, e, e.fl, tt.x, tt.y)
				nav_update(w, e, dt, Cfg.SPEED_BOT)
			return
		e.moving = false; e.dir = dir_of(tg.x - e.x, tg.y - e.y)
		var safe := civils_seeing(w, e, tg, Cfg.WITNESS_RADIUS * TS * sight_scale(w)).is_empty()
		if safe or e.ai_patience >= Cfg.BOT_PATIENCE:
			if e.ammo <= 0:
				e.aim_x = tg.x; e.aim_y = tg.y
				if e.cd <= 0 and e.cuffs_cd <= 0:
					Combat.try_cuff(w, e)
					e.ai_mode = "patrol"; e.goal = null; e.ai_wait = 1.5; e.ai_patience = 0
				return
			e.aim = true; e.aim_x = tg.x; e.aim_y = tg.y - 2; e.ai_aim_t += dt
			if e.ai_aim_t >= Cfg.BOT_AIM_TIME and e.cd <= 0:
				try_shoot(w, e)
				e.aim = false; e.ai_aim_t = 0; e.ai_mode = "patrol"; e.goal = null; e.ai_wait = 1.5; e.ai_patience = 0
		else:
			e.aim = false; e.ai_aim_t = 0; e.ai_patience += dt
		return
	# sin balas: ir a comprar al vigilante de la entrada
	if e.ammo <= 0 and e.money >= 60:
		if e.goal == null or e.goal.fl != 1:
			nav_to(w, e, 1, 23, 24)
		if nav_update(w, e, dt, Cfg.SPEED_BOT) and e.fl == 1:
			buy(w, e, "balas")
			e.goal = null
		return
	# patrulla
	e.aim = false
	if e.ai_wait > 0:
		e.ai_wait -= dt; e.moving = false
		return
	if e.goal == null:
		var fl := Rng.ri(0, floors().size() - 1) if Rng.rnd() < 0.55 else e.fl
		var tt: Vector2i = Rng.pick(fdat(fl).tiles_pub)
		nav_to(w, e, fl, tt.x, tt.y)
	if nav_update(w, e, dt, Cfg.SPEED_BOT * 0.9):
		e.goal = null; e.ai_wait = Rng.ri(1, 3)

# ---------------------------------------------------------------- percepción (10 veces por segundo)

static func perceive(w: World, dt: float) -> void:
	var sc := sight_scale(w)
	var civils: Array = w.ents.filter(func(c): return c.alive and c.role == "civil")
	for h in w.ents:
		if h.role != "hunter" or not h.alive:
			continue
		var f := fdat(h.fl)
		var ht: Vector2i = h.tile()
		var z := f.zone[ht.y * W + ht.x] if ht.x >= 0 and ht.y >= 0 and ht.x < W and ht.y < Cfg.H else 0
		var rm_here := f.room_at(ht.x, ht.y)
		var restricted: bool = (z == Cfg.ZONE_ROOM and rm_here != null and not has_key(h, rm_here)) or (z == Cfg.ZONE_STAFF and not has_staff_access(h))
		var view: Array = []
		for c in civils:
			if c.fl == h.fl and c.state != "dead":
				var d := dist(c.x, c.y, h.x, h.y)
				if d <= Cfg.SIGHT_TILES * TS * sc and Nav.los(f, c.x, c.y, h.x, h.y):
					view.append([c, d])
		if is_hot(w, h):
			h.sus = 100
		else:
			var rate := 0.0
			var staff_v: Ent = null
			if restricted:
				if not h.was_restricted and not view.is_empty():
					h.sus = minf(100.0, h.sus + 6.0)
				for v in view:
					rate += Cfg.RESTRICTED_STAFF if v[0].staff else Cfg.RESTRICTED_GUEST
					if v[0].staff and staff_v == null:
						staff_v = v[0]
			if h.aim:
				var aim_r := Cfg.AIM_NOTICE_RADIUS * TS * sc
				var nearest = null
				for v in view:
					if v[1] <= aim_r:
						rate += Cfg.AIM_RATE + Cfg.AIM_NEAR * (1.0 - v[1] / aim_r)
						if nearest == null or v[1] < nearest[1]:
							nearest = v
				if nearest != null and h.sus >= 20 and w.time - nearest[0].last_aim > 6:
					nearest[0].last_aim = w.time
					nearest[0].say("¿Eso que lleva en la mano es un arma?" if h.sus >= Cfg.WARN_AT else "¿Qué esconde ese tipo?", 2.6)
			if h.outfit.blood:
				for v in view:
					if v[1] <= Cfg.BLOOD_RADIUS * TS:
						rate += Cfg.BLOOD_RATE
			if rate == 0:
				rate = -Cfg.SUS_DECAY
			h.sus = clampf(h.sus + rate * dt, 0, 100)
			if restricted and staff_v != null and h.sus >= Cfg.WARN_AT and h.sus < Cfg.CALL_AT and w.time - staff_v.last_warn > 6:
				staff_v.last_warn = w.time
				staff_v.say("¡Esa zona es solo para el personal!", 3)
			if h.sus >= Cfg.CALL_AT and not view.is_empty():
				var caller: Ent = staff_v if staff_v != null else view[0][0]
				alert_npc(w, caller, h.outfit.id, "sospecha", h.fl, ht.x, ht.y)
		h.was_restricted = restricted
		h.restricted = restricted
	# corredores: un intruso en una habitación ajena provoca denuncias
	for r in w.ents:
		if r.role != "runner" or not r.alive or r.escaped or r.undercover or r.cuffed:
			continue
		var f := fdat(r.fl)
		var rt: Vector2i = r.tile()
		var rm := f.room_at(rt.x, rt.y)
		var intr: bool = rm != null and rm.zone == Cfg.ZONE_ROOM and not has_key(r, rm)
		var rate := 0.0
		var staff_v: Ent = null
		if intr:
			for c in civils:
				if c.fl != r.fl or c.state == "dead" or c.state == "evac":
					continue
				var d := dist(c.x, c.y, r.x, r.y)
				if d <= Cfg.SIGHT_TILES * TS * sc and Nav.los(f, c.x, c.y, r.x, r.y):
					rate += Cfg.RESTRICTED_STAFF if c.staff else Cfg.RESTRICTED_GUEST
					if c.staff and staff_v == null:
						staff_v = c
		if rate == 0:
			rate = -Cfg.SUS_DECAY
		if intr and rate > 0 and not r.was_intr:
			r.sus = minf(100.0, r.sus + 6.0)
		r.sus = clampf(r.sus + rate * dt, 0, 100)
		r.was_intr = intr
		r.restricted = intr and rate > 0
		if intr and staff_v != null and r.sus >= Cfg.WARN_AT and r.sus < Cfg.CALL_AT and w.time - staff_v.last_warn > 6:
			staff_v.last_warn = w.time
			staff_v.say("¿Quién es usted? Esta habitación no es suya.", 3)
		if r.sus >= Cfg.CALL_AT and w.time > r.rep_lock:
			if report_by(w, r, "Hay un desconocido en una habitación que no es suya. Aviso a seguridad."):
				r.rep_lock = w.time + 25; r.sus = 55
				if r == w.human:
					wlog(w, "Te han visto donde no debes: alguien va a avisar a seguridad.", "report", r.id)
	# policía
	for p in w.ents:
		if p.role != "police" or not p.alive or p.ko_t > 0:
			continue
		var spotted: Ent = null
		var spot_r: Ent = null
		var chase_t: Ent = null
		var frisk_t: Ent = null
		var bp := Alarm.bench_pos(w)
		for h in w.ents:
			if not h.alive or h.fl != p.fl or h == p or h.escaped or h.undercover:
				continue
			var hd := dist(p.x, p.y, h.x, h.y)
			var in_r := hd <= Cfg.POLICE_SIGHT * TS * sc and Nav.los(fdat(p.fl), p.x, p.y, h.x, h.y)
			if not in_r:
				continue
			var player: bool = h.role == "hunter" or h.role == "runner"
			if h.cuffed:
				if not h.shackled and (h.fl != w.bench.x or Vector2(h.x, h.y).distance_to(bp) > 3 * TS):
					chase_t = h
			elif h.role == "hunter" and (w.wanted.has(h.outfit.id) or h.outfit.blood):
				spotted = h
			elif player and (w.cop_killers.has(h.id) or w.alarm >= 3):
				spotted = h
			elif h.role == "runner" and h.marked and not (h.arrest > 0):
				spot_r = h
			elif player and w.alarm >= 1 and not h.frisked and hd <= Cfg.FRISK_RANGE * TS:
				frisk_t = h
		if chase_t != null and spotted == null:
			if p.ai_mode != "chase":
				p.ai_mode = "chase"
				p.chase_id = chase_t.id
				p.goal = null
				p.say("¡Alto! ¡Se escapa un detenido!", 2.0)
		elif frisk_t != null and spotted == null and spot_r == null and (p.ai_mode == "search" or p.ai_mode == "sweep" or p.ai_mode == "hunt" or p.ai_mode == "go"):
			p.ai_mode = "frisk"
			p.frisk_id = frisk_t.id
			p.goal = null
		if spotted != null:
			p.freeze = true; p.dir = dir_of(spotted.x - p.x, spotted.y - p.y)
			p.spot[spotted.id] = float(p.spot.get(spotted.id, 0.0)) + dt; p.spotting = true
			if p.spot[spotted.id] >= Cfg.POLICE_REACT:
				Combat.police_fire(w, p, spotted)
				p.stay_until = maxf(p.stay_until, w.time + 20)
		elif spot_r != null:
			p.freeze = true; p.dir = dir_of(spot_r.x - p.x, spot_r.y - p.y)
			p.spot[spot_r.id] = float(p.spot.get(spot_r.id, 0.0)) + dt; p.spotting = true
			if p.spot[spot_r.id] >= Cfg.POLICE_REACT * 1.5:
				arrest(w, spot_r, p)
				p.spot = {}; p.freeze = false; p.spotting = false
		else:
			p.freeze = false; p.spotting = false; p.spot = {}
	# cadáveres
	w.acc2 += dt
	if w.acc2 >= 0.5:
		w.acc2 = 0
		for c in w.corpses:
			if c.found or c.chalk:
				continue
			for n in civils:
				if n.fl != c.fl or not n.alive or n.state == "call" or n.state == "calling":
					continue
				if dist(n.x, n.y, c.x, c.y) <= 6 * TS and Nav.los(fdat(c.fl), n.x, n.y, c.x, c.y):
					c.found = true
					Alarm.innocent_found(w, c)
					alert_npc(w, n, "", "body", c.fl, floori(c.x / TS), floori(c.y / TS))
					break
	# carteles de busca y captura (solo con policía en el hotel y la descripción ya dada)
	var police := false
	for p in w.ents:
		if p.role == "police" and p.alive:
			police = true
	if police:
		for h in w.ents:
			if h.role != "hunter" or not h.alive or not w.wanted.has(h.outfit.id):
				continue
			var exists := false
			for pp in w.posters:
				if pp.outfit_id == h.outfit.id:
					exists = true
			if not exists:
				var ps := Items.Poster.new()
				ps.outfit_id = h.outfit.id; ps.hunter_id = h.id; ps.outfit = h.outfit.clone()
				w.posters.append(ps)
				wlog(w, "La policía reparte un cartel de busca y captura.", "alarm")
	w.poster_active = {}
	var keep: Array = []
	for p in w.posters:
		var h := w.ent_by_id(p.hunter_id)
		if h == null or not h.alive:
			continue
		if p.state == "active" and h.outfit.id != p.outfit_id:
			p.state = "changed"; p.t = 0
			wlog(w, "El sospechoso ha cambiado de apariencia.", "poster")
		if p.state == "changed":
			p.t += dt
			if p.t > 6:
				continue
		else:
			w.poster_active[p.outfit_id] = true
		keep.append(p)
	w.posters = keep

# ---------------------------------------------------------------- jugador humano

## Lo más cercano con lo que puedes interactuar: {type, ref, label, dur, x, y}, o {}.
## Con pt (posición del ratón) busca lo que hay bajo el cursor, aunque esté un poco más lejos.
static func find_interact(w: World, e: Ent, pt: Vector2 = Vector2.INF) -> Dictionary:
	var f := fdat(e.fl)
	var best := {}
	var bd := [1e9]
	var use_pt := pt != Vector2.INF
	var cand := func(type: String, ref, px: float, py: float, rng: float, label: String, dur: float):
		var d := dist(e.x, e.y, px, py)
		if use_pt:
			if d > rng * 1.8:
				return
			d = dist(pt.x, pt.y, px, py)
			if d > 30.0:
				return
		elif d >= rng:
			return
		if d < bd[0]:
			bd[0] = d
			best["type"] = type; best["ref"] = ref; best["label"] = label; best["dur"] = dur
			best["x"] = px; best["y"] = py
	var t := e.tile()
	# esposado: solo puedes sobornar al guardia
	if e.cuffed:
		var g := Alarm.guard_of(w)
		if g != null and g.fl == e.fl:
			cand.call("bribe", e, g.x, g.y, Cfg.TALK_RANGE * 1.4, "Sobornar al policía ($" + str(Cfg.BRIBE_COP) + ")", 0.0)
		return best
	for j in range(t.y - 2, t.y + 3):
		for i in range(t.x - 2, t.x + 3):
			if f.at(i, j) == Cfg.T_ELEV:
				if elev_out(w):
					cand.call("elevx", null, (i + 0.5) * TS, (j + 0.5) * TS, 56.0, "Ascensor fuera de servicio", 0.0)
				else:
					cand.call("elev", null, (i + 0.5) * TS, (j + 0.5) * TS, 56.0, "Llamar al ascensor", 0.0)
	for k in f.lock_at:
		var lr: Room = f.lock_at[k]
		if not can_pass(w, e, lr) and not inside_room(e, lr):
			cand.call("force", lr, (lr.door.x + 0.5) * TS, (lr.door.y + 0.5) * TS, 54.0, "Forzar la cerradura · " + lr.label(), Cfg.FORCE_DUR * (0.5 if e.lockpick else 1.0))
	for c in w.ents:
		if not c.alive or c.fl != e.fl or c == e:
			continue
		if c.role == "civil" and c.state != "call" and c.state != "calling" and c.state != "evac" and c.state != "flee" and c.ai_mode != "deliver":
			if c.shop != "" and c.shop == e.role:
				cand.call("shop", c, c.x, c.y, Cfg.TALK_RANGE, "Hablar con el " + ("contacto" if e.role == "runner" else "vigilante") + " (comprar, vender, trabajos)", 0.0)
			else:
				cand.call("talk", c, c.x, c.y, Cfg.TALK_RANGE * 0.8, "Hablar con " + c.nm.to_lower(), 0.0)
		# compañero esposado
		if c.cuffed and c.role == e.role:
			if e.cuffkey:
				cand.call("free_key", c, c.x, c.y, Cfg.TALK_RANGE, "Abrir las esposas de " + c.nm + " con la llave", 0.0)
			else:
				var g2 := Alarm.guard_of(w)
				if g2 != null:
					cand.call("bribe", c, c.x, c.y, Cfg.TALK_RANGE, "Sobornar al policía para soltar a " + c.nm + " ($" + str(Cfg.BRIBE_COP) + ")", 0.0)
				else:
					cand.call("unlock", c, c.x, c.y, Cfg.TALK_RANGE, "Forzar las esposas de " + c.nm + " (ganzúa)", 0.0)
	if e.job != null and e.job.fl == e.fl:
		cand.call("job", e.job, (e.job.x + 0.5) * TS, (e.job.y + 0.5) * TS, Cfg.TASK_RANGE, e.job.nm, e.job.dur)
	if w.alarm >= 3 and e.role == "runner":
		for x in w.exits:
			if int(x["fl"]) == e.fl and ((x["item"] == "rope" and e.rope) or (x["item"] == "dockkey" and e.dockkey)):
				cand.call("escape", null, (x["x"] + 0.5) * TS, (x["y"] + 0.5) * TS, Cfg.TASK_RANGE, str(x["name"]), Cfg.HOLD_ESCAPE)
	if e.role == "hunter":
		for c in w.corpses:
			if c.fl == e.fl and not c.stripped and not c.chalk and c.outfit.kind != "under":
				cand.call("strip", c, c.x, c.y, 44.0, "Coger su ropa", Cfg.HOLD_STRIP)
		for wd in f.wards:
			if not wd.looted:
				var cc: Vector2 = wd.center()
				cand.call("ward", wd, cc.x, cc.y, 54.0, "Registrar el armario", Cfg.HOLD_WARD)
		if e.outfit.blood:
			for s in f.washers:
				var cw: Vector2 = s.center()
				cand.call("wash", s, cw.x, cw.y, 58.0, "Lavar el traje", Cfg.HOLD_WASH)
			for s in f.sinks:
				cand.call("wash", s, (s.x + 0.5) * TS, (s.y + 0.5) * TS, 50.0, "Lavar el traje", Cfg.HOLD_SINK)
	elif e.role == "runner":
		var pool: Array = e.tasks.duplicate()
		if Reward.all_done(e):
			for o in w.ents:
				if o != e and o.role == "runner" and o.alive:
					for k2 in o.tasks:
						if k2.kind == "":
							pool.append(k2)
		for tk in pool:
			if tk.fl != e.fl or not task_avail(w, tk, e):
				continue
			if tk.room_name != "" and not inside_room(e, Hotel.room_by(tk.fl, tk.room_name)):
				continue
			var lbl: String = tk.nm
			if not (tk in e.tasks):
				var ow := task_owner(w, tk)
				lbl = "Ayudar a " + (ow.nm if ow != null else "un compañero") + ": " + tk.nm
			cand.call("task", tk, (tk.x + 0.5) * TS, (tk.y + 0.5) * TS, Cfg.TASK_RANGE, lbl, tk.dur)
	return best

static func auto_pickup(w: World, e: Ent) -> void:
	for i in w.picks.size():
		var p: Items.Pick = w.picks[i]
		if p.fl != e.fl or dist(e.x, e.y, (p.x + 0.5) * TS, (p.y + 0.5) * TS) > 22:
			continue
		if (p.kind == "scrap" or p.kind == "cutter" or p.kind == "rope" or p.kind == "dockkey") and e.role != "runner":
			continue
		if p.kind == "badge" and e.role != "hunter":
			continue
		if e.cuffed and p.kind != "cuffkey":
			continue
		w.picks.remove_at(i)
		ev(w, "cash" if p.kind == "cash" else "pick", e.fl, e.x, e.y)
		if p.kind == "cuffkey":
			if e.cuffed:
				Alarm.free_prisoner(w, e, "llave de las esposas")
			else:
				e.cuffkey = true
				if e == w.human:
					wlog(w, "Has cogido una llave de esposas: sirve para liberar a un compañero detenido.")
		elif p.kind == "rope":
			e.rope = true
			if e == w.human:
				wlog(w, "Tienes una cuerda: la salida está en la azotea, junto a la barandilla oeste.", "team")
		elif p.kind == "dockkey":
			e.dockkey = true
			if e == w.human:
				wlog(w, "Tienes la llave del muelle: la salida está en el almacén del sótano.", "team")
		elif p.kind == "cash":
			e.money += p.value
			if e == w.human:
				wlog(w, "Has encontrado una cartera: +$" + str(p.value) + ".")
		elif p.kind == "cutter":
			e.cutter = true
			if e == w.human:
				wlog(w, "Has cogido una cizalla. En el ascensor puedes romperlo, pero si te ven te denuncian.")
		elif p.kind == "masterkey":
			e.masterkey = true
			if e == w.human:
				wlog(w, "Has cogido una llave maestra: abre cualquier habitación sin forzarla.")
		elif p.kind == "badge":
			e.badge = true
			if e == w.human:
				wlog(w, "Has cogido una insignia de botones: te deja pasar a las zonas del personal.")
		else:
			e.scrap += 1
			if e == w.human:
				if e.melee:
					wlog(w, "Has cogido: " + p.nm + ". Tu contacto te compra la chatarra.")
				else:
					wlog(w, "Has cogido: " + p.nm + " (" + str(mini(e.scrap, Cfg.SCRAP_NEEDED)) + "/" + str(Cfg.SCRAP_NEEDED) + ")")
			if e.scrap >= Cfg.SCRAP_NEEDED and not e.melee:
				e.melee = true
				e.scrap = 0
				if e.equip == "fist":
					e.equip = "wrench"
				if e == w.human:
					wlog(w, "Has fabricado una llave inglesa (Q para equiparla, clic izquierdo para golpear).")
		return

## Lo que puedes llevar en la mano (Q cambia entre ellos).
static func equip_list(e: Ent) -> Array:
	var out: Array = ["fist"]
	if e.gun:
		out.append("gun")
	if e.cuffs:
		out.append("cuffs")
	if e.knife:
		out.append("knife")
	if e.melee:
		out.append("wrench")
	if e.cutter or e.lockpick:
		out.append("tool")
	return out

static func cycle_equip(e: Ent) -> void:
	var l := equip_list(e)
	var i := l.find(e.equip)
	e.equip = l[(i + 1) % l.size()]
	e.aim = false

## inp: {mx, my, run, aim, aim_x, aim_y, fire, interact}
static func human_control(w: World, e: Ent, dt: float, inp: Dictionary) -> void:
	var f := fdat(e.fl)
	e.cd = maxf(0, e.cd - dt)
	if e.fx_swing > 0:
		e.fx_swing -= dt
	if not (e.equip in equip_list(e)):
		e.equip = "fist"
	e.aim_x = inp.get("aim_x", e.x); e.aim_y = inp.get("aim_y", e.y)
	e.aim = e.gun and e.equip == "gun" and inp.get("aim", false) and e.hold == null and not e.cuffed
	var mx: float = inp.get("mx", 0.0)
	var my: float = inp.get("my", 0.0)
	var can_move := true
	if e.cuffed and (e.shackled or Alarm.guard_of(w) != null):
		can_move = false
	if not w.cine.is_empty():
		can_move = false
	if e.aim:
		e.aim_ang = atan2(e.aim_y - e.y, e.aim_x - e.x)
		e.dir = dir_of(e.aim_x - e.x, e.aim_y - e.y)
	if can_move and (mx != 0 or my != 0):
		if e.hold != null:
			cancel_hold(w, e)
		var l := Vector2(mx, my).length()
		var sp := Cfg.SPEED_AIM if e.aim else (Cfg.SPEED_RUN if inp.get("run", false) else Cfg.SPEED_WALK)
		if e.cuffed:
			sp = Cfg.CUFF_SPEED
		var vx := mx / l * sp * dt
		var vy := my / l * sp * dt
		if free_for(w, e, f, e.x + vx, e.y):
			e.x += vx
		if free_for(w, e, f, e.x, e.y + vy):
			e.y += vy
		e.walk += dt * 10; e.moving = true
		if not e.aim:
			e.dir = dir_of(mx, my)
	else:
		e.moving = false
	if e.stair_cd > 0:
		e.stair_cd -= dt
	elif not e.cuffed:
		var tt := f.at(floori(e.x / TS), floori(e.y / TS))
		if tt == Cfg.T_UP and e.fl < floors().size() - 1:
			use_stairs(w, e, 1)
		elif tt == Cfg.T_DOWN and e.fl > 0:
			use_stairs(w, e, -1)
	var hint := {} if e.hold != null else find_interact(w, e)
	w.hint = hint
	var interact: bool = inp.get("interact", false) and w.cine.is_empty()
	if interact and e.hold == null and not hint.is_empty() and not (hint["type"] in PRESS_TYPES):
		start_hold(w, e, hint["type"], hint["ref"], hint["dur"])
	if e.hold != null and not interact and not e.hold.auto:
		cancel_hold(w, e)
	if inp.get("fire", false) and not e.cuffed and w.cine.is_empty():
		match e.equip:
			"fist":
				Combat.punch(w, e)
			"cuffs":
				Combat.try_cuff(w, e)
			"gun":
				if e.aim:
					try_shoot(w, e)
			"knife":
				try_knife(w, e)
			"wrench":
				try_melee(w, e)

# ---------------------------------------------------------------- paso de simulación

static func step(w: World, dt: float, inp: Dictionary) -> void:
	if w.is_over():
		return
	w.time += dt
	var h := w.human
	Reward.update(w, dt)
	Alarm.update(w, dt)
	Combat.update(w, dt)
	if h != null and h.alive and h.arrest > 0:
		h.arrest -= dt; h.moving = false; h.aim = false; h.hold = null; w.hint = {}
	elif h != null and h.alive and (h.ko_t > 0 or h.qte_t > 0):
		h.moving = false; h.aim = false; w.hint = {}
		if h.hold != null:
			cancel_hold(w, h)
	elif h != null and h.alive and not h.escaped and h.away_t <= 0 and not inp.is_empty():
		human_control(w, h, dt, inp)
	for e in w.ents:
		if e.bt > 0:
			e.bt -= dt
			if e.bt <= 0:
				e.bubble = ""
		if not e.alive or e.type == "frozen" or e.escaped or e.away_t > 0:
			continue
		if (e.ko_t > 0 or e.qte_t > 0) and e.type != "human":
			e.moving = false
			continue
		if e.cuffed and e.type != "human":
			e.moving = false
			continue
		if e.type == "human":
			hold_update(w, e, dt)
			auto_pickup(w, e)
			continue
		if e.type == "npc":
			npc_ai(w, e, dt)
		elif e.type == "police":
			police_ai(w, e, dt)
		elif e.role == "runner":
			runner_ai(w, e, dt); hold_update(w, e, dt); auto_pickup(w, e)
		elif e.role == "hunter":
			hunter_ai(w, e, dt); hold_update(w, e, dt); auto_pickup(w, e)
	w.ents = w.ents.filter(func(x): return not x.remove)
	for d in w.dispatch:
		if not d["done"] and w.time >= d["t"]:
			d["done"] = true
			spawn_police(w, d)
	var fx_keep: Array = []
	for x in w.fx:
		x["t"] -= dt
		if x["t"] > 0:
			fx_keep.append(x)
	w.fx = fx_keep
	if w.sab_blackout > 0 and w.time >= w.sab_blackout:
		w.sab_blackout = 0
		wlog(w, "Vuelve la luz.")
	if w.sab_alarm > 0 and w.time >= w.sab_alarm:
		w.sab_alarm = 0
		wlog(w, "Cesa la alarma de incendios.")
	if w.sab_elev > 0 and w.time >= w.sab_elev:
		w.sab_elev = 0
		wlog(w, "Los ascensores vuelven a funcionar.")
	w.acc += dt
	if w.acc >= 0.1:
		var pd := w.acc
		w.acc = 0
		perceive(w, pd)
	if w.time >= w.limit or (w.quota > 0 and w.tasks_done >= w.quota):
		check_win(w)

## El jugador pulsa el botón del ascensor y elige planta.
static func ride_elevator(w: World, e: Ent, fl: int) -> bool:
	if elev_out(w) or fl == e.fl or fl < 0 or fl >= floors().size():
		return false
	teleport(w, e, fl)
	return true
