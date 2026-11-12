## v0.13 «La central»: avisos por el pinganillo, interrogatorio de los botones,
## robo de mascotas y vendedores a los que se puede atacar.
class_name Heat
extends RefCounted

const TS := Cfg.TS
const WARN_SUS := 50.0          # sospecha a partir de la cual te avisa la central
const WARN_CD := 30.0
const QUIZ_CD := 45.0           # s sin interrogatorios tras pasar uno
const QUIZ_CHASE := 50.0        # s que el botones te busca antes de rendirse
const QUIZ_TIME := 14.0         # s para contestar cada pregunta
const EXPEL_TIME := 60.0        # s fuera del hotel si fallas
const PET_NOTICE := 6.0         # s que tarda el dueño en echar de menos al perro si no te vio
const PET_GRACE := 10.0         # s para soltarlo antes de la denuncia
const PET_ARREST := 15.0        # s detenido si la policía te ve con el perro
const VENDOR_DEAD := 120.0
const VENDOR_KO := 60.0
const DISCOUNT := 0.7
const AGENTS := ["Agente Hale", "Agente Brandt", "Agente Novak", "Agente Price", "Agente Shaw", "Agente Kerr"]
const CENTRAL := [
	"Aquí central. Estás llamando la atención: la operación se está torciendo.",
	"Central a agente: te están mirando demasiado. Guarda el arma y pasa desapercibido.",
	"Aquí central. Si sigues así vas a reventar la tapadera. Cálmate.",
	"Central: tenemos ojos en el vestíbulo y no nos gusta lo que vemos. Baja el perfil.",
]

static func setup(w: World) -> void:
	w.central = {}
	w.quiz = {}
	for e in w.ents:
		if e.shop != "":
			e.shop_home = Vector3(e.fl, e.x, e.y)

# ---------------------------------------------------------------- sospecha

## Multiplicador de la sospecha: disfraz penoso (ropa del otro género) y habilidad «cara de póquer».
static func sus_mul(e: Ent) -> float:
	var m := 1.0
	if e.bad_fit:
		m *= 1.6
	if e.rperk == "camaleon":
		m *= 0.6
	return m

## Sospecha extra por segundo si alguien ve de cerca un disfraz que no te queda bien.
static func fit_rate(h: Ent, view: Array) -> float:
	if not h.bad_fit:
		return 0.0
	var r := 0.0
	for v in view:
		if float(v[1]) <= 4.0 * TS:
			r += 2.5
	return r

## La central avisa al cazador por el pinganillo cuando la sospecha sube demasiado.
static func warn(w: World, h: Ent) -> void:
	if w.tutorial or h.sus < WARN_SUS or w.time - h.warned_t < WARN_CD or h.quiz_id != 0:
		return
	h.warned_t = w.time
	if h == w.human:
		var msg: String = Rng.pick(CENTRAL)
		w.central = {"t": 7.0, "msg": msg}
		Sim.ev(w, "radio", h.fl, h.x, h.y)
		Sim.wlog(w, msg, "hunt")

## Con la sospecha al límite un botones va a por el cazador. Devuelve true si no hay que llamar a la policía.
static func quiz_start(w: World, h: Ent) -> bool:
	if w.tutorial:
		return true
	if h.quiz_id != 0:
		return true
	if not w.quiz.is_empty() and int(w.quiz["hunter"]) == h.id:
		return true
	if w.time < h.quiz_cd:
		return false
	var best: Ent = null
	var bd := 1e9
	for pass_i in 2:
		for n in w.ents:
			if n.type != "npc" or not n.alive or n.fixed or n.guard or n.asleep or n.ko_t > 0 or n.state != "idle" or n.quiz_id != 0 or not n.staff:
				continue
			if pass_i == 0 and n.outfit.staff_role != "bell":
				continue
			var d := Sim.dist(n.x, n.y, h.x, h.y) + absf(n.fl - h.fl) * 2000.0
			if d < bd:
				bd = d
				best = n
		if best != null:
			break
	if best == null:
		return false
	best.quiz_id = h.id
	best.quiz_t = QUIZ_CHASE
	best.ai_mode = "quiz"
	best.ai_t = 0.0
	best.goal = null
	h.quiz_id = best.id
	if h == w.human:
		var msg := "Has llamado demasiado la atención: el hotel manda a un botones a hacerte preguntas. Contesta bien o tendremos que sacarte de ahí."
		w.central = {"t": 8.0, "msg": msg}
		Sim.ev(w, "radio", h.fl, h.x, h.y)
		Sim.wlog(w, "Central: " + msg, "hunt")
	return true

static func _quiz_cancel(w: World, bell: Ent, h: Ent) -> void:
	if bell != null:
		bell.quiz_id = 0
		bell.ai_mode = "idle"
		bell.goal = null
		bell.ai_wait = 1.5
	if h != null:
		h.quiz_id = 0
	if not w.quiz.is_empty() and (h == null or int(w.quiz["hunter"]) == h.id):
		w.quiz = {}

## IA de un botones que busca a un cazador y de un vendedor ausente. true = ya está atendido.
static func npc_ai(w: World, e: Ent, dt: float) -> bool:
	if e.shop != "" and e.fl < 0:
		e.moving = false
		return true
	if e.quiz_id == 0:
		return false
	var h := w.ent_by_id(e.quiz_id)
	if h == null or not h.alive or h.role != "hunter" or h.away_t > 0 or w.alarm >= 3 or e.state != "idle":
		_quiz_cancel(w, e, h)
		return false
	if not w.quiz.is_empty() and int(w.quiz["bell"]) == e.id:
		e.moving = false
		e.dir = Sim.dir_of(h.x - e.x, h.y - e.y)
		return true
	e.quiz_t -= dt
	if e.quiz_t <= 0.0:
		e.say("¿Dónde se habrá metido ese hombre?", 2.5)
		_quiz_cancel(w, e, h)
		h.quiz_cd = w.time + 15.0
		return false
	if h.hidden:
		e.moving = false
		return true
	if e.fl == h.fl and Sim.dist(e.x, e.y, h.x, h.y) < 52.0 and Nav.los(Sim.fdat(e.fl), e.x, e.y, h.x, h.y):
		_quiz_begin(w, e, h)
		return true
	e.ai_t -= dt
	if e.goal == null or e.ai_t <= 0.0:
		e.ai_t = 1.0
		var ht := h.tile()
		Sim.nav_to(w, e, h.fl, ht.x, ht.y)
	Sim.nav_update(w, e, dt, Cfg.SPEED_NPC * 1.8)
	return true

static func _quiz_begin(w: World, bell: Ent, h: Ent) -> void:
	bell.moving = false
	bell.goal = null
	bell.dir = Sim.dir_of(h.x - bell.x, h.y - bell.y)
	bell.say("Disculpe, caballero. Unas preguntas sobre el hotel." if not h.female else "Disculpe, señora. Unas preguntas sobre el hotel.", 3.0)
	h.moving = false
	h.aim = false
	Sim.cancel_hold(w, h)
	if h == w.human:
		w.quiz = {"hunter": h.id, "bell": bell.id, "qs": make_questions(3), "i": 0, "fail": 0, "t": QUIZ_TIME, "last": -1}
		Sim.ev(w, "radio", h.fl, h.x, h.y)
	else:
		quiz_end(w, h, bell, Rng.rnd() < 0.55)

## Respuesta del jugador (idx < 0: se le acabó el tiempo).
static func answer(w: World, idx: int) -> void:
	if w.quiz.is_empty():
		return
	var qs: Array = w.quiz["qs"]
	var i: int = w.quiz["i"]
	var q: Dictionary = qs[i]
	var ok := idx == int(q["ok"])
	if not ok:
		w.quiz["fail"] = int(w.quiz["fail"]) + 1
	w.quiz["last"] = 1 if ok else 0
	w.quiz["i"] = i + 1
	w.quiz["t"] = QUIZ_TIME
	var fails: int = w.quiz["fail"]
	if fails >= 2 or i + 1 >= qs.size():
		var h := w.ent_by_id(int(w.quiz["hunter"]))
		var bell := w.ent_by_id(int(w.quiz["bell"]))
		w.quiz = {}
		if h != null:
			quiz_end(w, h, bell, fails < 2)

static func quiz_end(w: World, h: Ent, bell: Ent, passed: bool) -> void:
	if bell != null:
		bell.quiz_id = 0
		bell.ai_mode = "idle"
		bell.goal = null
		bell.ai_wait = 2.0
		bell.say("Todo en orden. Disculpe las molestias." if passed else "Usted no es huésped de este hotel. Acompáñeme a la salida.", 3.2)
	h.quiz_id = 0
	h.quiz_cd = w.time + QUIZ_CD
	if passed:
		h.sus = 20.0
		if h == w.human:
			Sim.wlog(w, "Has pasado el interrogatorio: el botones se queda tranquilo y la sospecha baja.", "task")
	else:
		expel(w, h)

## Te echan del hotel: vuelves al cabo de un minuto con otra cara, como otro agente.
static func expel(w: World, h: Ent) -> void:
	Sim.cancel_hold(w, h)
	if h.dragging != null:
		Stealth.drop(w, h)
	if h.pet_id != 0:
		Life.press(w, h, {"type": "pet_drop"})
	h.agent_n += 1
	h.away_t = EXPEL_TIME
	h.aim = false
	h.moving = false
	h.sus = 0.0
	h.pet_wanted = false
	h.outfit = Outfit.new_guest(h.female)
	h.bad_fit = false
	h.nm = AGENTS[(h.id + h.agent_n) % AGENTS.size()]
	if h == w.human:
		Sim.wlog(w, "Has fallado el interrogatorio y te echan del hotel. La central envía a otro agente (tú, con otra cara): entras en 1 min como " + h.nm + ".", "report", h.id)
	else:
		Sim.wlog(w, "Los botones han echado del hotel a un tipo sospechoso.", "alarm")

## Tres preguntas sobre el hotel: en qué planta está cada sala y un par de datos del New Yorker.
static func make_questions(n: int) -> Array:
	var pool: Array = []
	var nf: int = Hotel.floors.size()
	for fi in nf:
		var f: FloorData = Hotel.floors[fi]
		var seen := {}
		for r in f.rooms:
			var nm: String = r.nm
			if nm.begins_with("Hab.") or nm.begins_with("Suite") or nm.begins_with("Núcleo") or nm == "Azotea" or seen.has(nm):
				continue
			seen[nm] = true
			var opts: Array = [fi]
			var others: Array = []
			for k in nf:
				if k != fi:
					others.append(k)
			others = Rng.shuffle(others)
			opts.append(others[0])
			opts.append(others[1])
			opts = Rng.shuffle(opts)
			var labels: Array = []
			for k2 in opts:
				labels.append(str(Hotel.floors[int(k2)].label))
			pool.append({"q": "¿En qué planta está: " + nm + "?", "a": labels, "ok": opts.find(fi)})
	pool.append({"q": "¿En qué año abrió sus puertas el hotel New Yorker?", "a": ["1925", "1930", "1936"], "ok": 1})
	pool.append({"q": "¿En qué avenida de Manhattan está el hotel?", "a": ["Quinta Avenida", "Octava Avenida", "Avenida Madison"], "ok": 1})
	pool.append({"q": "¿Cuántas paradas tiene el ascensor, contando el sótano y la azotea?", "a": [str(nf - 2), str(nf), str(nf + 2)], "ok": 1})
	pool = Rng.shuffle(pool)
	var out: Array = []
	for i in mini(n, pool.size()):
		out.append(pool[i])
	return out

# ---------------------------------------------------------------- mascotas

static func pet_taken(w: World, e: Ent, p: Dictionary) -> void:
	var o := w.ent_by_id(int(p["owner"]))
	if o == null or not o.alive or o.id == e.id or w.tutorial:
		return
	p["thief"] = e.id
	p["alerted"] = false
	var seen: bool = o.fl == e.fl and not o.asleep and o.ko_t <= 0 and Sim.dist(o.x, o.y, e.x, e.y) < 8.0 * TS and Nav.los(Sim.fdat(e.fl), o.x, o.y, e.x, e.y)
	p["notice"] = 0.6 if seen else PET_NOTICE

static func pet_dropped(w: World, e: Ent, p: Dictionary) -> void:
	if int(p.get("thief", 0)) != e.id:
		return
	p["thief"] = 0
	var o := w.ent_by_id(int(p["owner"]))
	if bool(p.get("alerted", false)) and o != null and o.alive and o.fl == e.fl:
		o.say("¡Y no vuelva a tocarlo!", 2.5)
	e.pet_warn = 0.0
	e.pet_wanted = false

static func _pets(w: World, dt: float) -> void:
	for p in w.pets:
		var tid := int(p.get("thief", 0))
		if tid == 0:
			continue
		var e := w.ent_by_id(tid)
		var o := w.ent_by_id(int(p["owner"]))
		if e == null or not e.alive or e.pet_id != int(p["id"]) or o == null or not o.alive:
			p["thief"] = 0
			continue
		if not bool(p.get("alerted", false)):
			if o.asleep or o.ko_t > 0:
				continue
			p["notice"] = float(p["notice"]) - dt
			if float(p["notice"]) <= 0.0:
				p["alerted"] = true
				e.pet_warn = PET_GRACE
				o.say("¡Eh! ¡Ese es mi perro! ¡Suéltelo ahora mismo!", 3.5)
				if e == w.human:
					Sim.wlog(w, "El dueño se ha dado cuenta de que te llevas a su perro: suéltalo en " + str(int(PET_GRACE)) + " s o te denunciará.", "report", e.id)
		elif not e.pet_wanted:
			e.pet_warn -= dt
			if e.pet_warn <= 0.0:
				e.pet_wanted = true
				o.say("¡Policía! ¡Me han robado al perro!", 3.5)
				var t := e.tile()
				Sim.send_police(w, {"fl": e.fl, "x": t.x, "y": t.y}, Cfg.POLICE_STAY * 0.6)
				Life.add_gsus(w, 6.0)
				w.stats["calls"] += 1
				Sim.wlog(w, "Te han denunciado por robar un perro. Si la policía te ve con él, te detiene." if e == w.human else "Han denunciado el robo de un perro: viene la policía.", "report" if e == w.human else "call", e.id)
		else:
			for c in w.ents:
				if c.role != "police" or not c.alive or c.fl != e.fl or c.ko_t > 0:
					continue
				if Sim.dist(c.x, c.y, e.x, e.y) <= Cfg.POLICE_SIGHT * TS and Nav.los(Sim.fdat(e.fl), c.x, c.y, e.x, e.y):
					_pet_arrest(w, e, p, o, c)
					break

static func _pet_arrest(w: World, e: Ent, p: Dictionary, o: Ent, cop: Ent) -> void:
	e.pet_id = 0
	e.pet_wanted = false
	e.pet_warn = 0.0
	p["thief"] = 0
	p["carried"] = 0
	p["state"] = "follow"
	p["fl"] = o.fl
	p["x"] = o.x + 10.0
	p["y"] = o.y + 4.0
	p["path"] = []
	Sim.cancel_hold(w, e)
	e.arrest = PET_ARREST
	e.moving = false
	e.aim = false
	e.goal = null
	e.has_path = false
	w.stats["arrests"] += 1
	cop.say("¡Suelte al animal! Queda usted retenido.", 3.0)
	cop.stay_until = maxf(cop.stay_until, w.time + PET_ARREST + 4.0)
	if e == w.human:
		Sim.wlog(w, "La policía te ha visto con el perro robado: te retienen " + str(int(PET_ARREST)) + " s y se lo devuelven a su dueño.", "report", e.id)
	else:
		Sim.wlog(w, "La policía detiene a alguien por el robo de un perro.", "alarm")

# ---------------------------------------------------------------- vendedores

static func vendor_for(w: World, role: String) -> Ent:
	for e in w.ents:
		if e.shop == role:
			return e
	return null

static func vendor_open(v: Ent) -> bool:
	return v != null and v.alive and v.fl >= 0 and v.ko_t <= 0

static func _enemy(a: Ent, v: Ent) -> bool:
	return (a.role == "hunter" or a.role == "runner") and a.role != v.shop

static func _vendor_news(w: World, v: Ent, a: Ent, what: String, secs: float) -> void:
	var who := "vuestro contacto del bar" if v.shop == "runner" else "vuestro vigilante de la entrada"
	var hm := w.human
	if hm != null and hm.role == v.shop:
		Sim.wlog(w, "Han " + what + " a " + who + ": no podréis comprar durante " + str(int(secs / 60.0)) + " min.", "report")
	elif a == hm:
		Sim.wlog(w, "Has " + what + " al vendedor del otro bando: " + str(int(secs / 60.0)) + " min sin tienda para ellos. Solo cuela una vez.", "task")

static func _vendor_witness(w: World, a: Ent) -> void:
	var wit: Array = Sim.civils_seeing(w, a, null, Cfg.WITNESS_RADIUS * TS * Sim.sight_scale(w))
	if wit.is_empty():
		return
	if a.role == "hunter":
		a.sus = 100.0
		var kt := a.tile()
		for x in wit:
			Sim.alert_npc(w, x, a.outfit.id, "crime", a.fl, kt.x, kt.y)
	else:
		Sim.report_by(w, a, "¡Han atacado a un empleado del hotel! Aviso a seguridad.")

## Disparo o cuchillada a un vendedor: solo el bando contrario y solo una vez. Nunca muere del todo.
static func vendor_shot(w: World, a: Ent, v: Ent) -> bool:
	if not _enemy(a, v) or v.shop_hit or v.fl < 0:
		v.say("¡Eh! ¡Tranquilo!", 2.0)
		return true
	v.shop_hit = true
	v.hunter_mark = a.id
	_vendor_witness(w, a)
	w.fx.append({"type": "blood", "fl": v.fl, "x": v.x, "y": v.y, "t": 0.6})
	Stealth.add_pool(w, v.fl, v.x, v.y, 14.0)
	v.shop_back = w.time + VENDOR_DEAD
	v.fl = -1
	v.moving = false
	v.ko_t = 0.0
	v.special = "venganza" if Rng.rnd() < 0.6 else ""
	_vendor_news(w, v, a, "abatido", VENDOR_DEAD)
	return true

## Puñetazo a un vendedor. true = ya está resuelto (no se aplica el KO normal).
static func vendor_punched(w: World, a: Ent, v: Ent) -> bool:
	if not _enemy(a, v) or v.shop_hit:
		v.say("¡Quieto ahí!", 2.0)
		if a == w.human:
			Sim.wlog(w, "No puedes con él: " + ("es de los tuyos." if not _enemy(a, v) else "ya está sobre aviso."))
		return true
	v.shop_hit = true
	v.hunter_mark = a.id
	v.bandaged = true
	v.special = "venganza" if Rng.rnd() < 0.4 else ""
	Combat.knock_out(w, v, VENDOR_KO)
	_vendor_witness(w, a)
	_vendor_news(w, v, a, "noqueado", VENDOR_KO)
	return true

static func _vendors(w: World) -> void:
	for v in w.ents:
		if v.shop == "" or v.fl >= 0 or w.time < v.shop_back:
			continue
		v.fl = int(v.shop_home.x)
		v.x = v.shop_home.y
		v.y = v.shop_home.z
		v.bandaged = true
		v.say("Sigo vivo… y me acuerdo de la cara.", 3.5)
		var hm := w.human
		if hm != null and hm.role == v.shop:
			Sim.wlog(w, ("Vuestro contacto" if v.shop == "runner" else "Vuestro vigilante") + " ha vuelto, vendado y con ganas de venganza: precios rebajados." + (" Vende un soplo especial." if v.special != "" else ""), "task")

## Rebajas del vendedor vendado y su artículo especial.
static func adjust_shop(w: World, e: Ent, out: Array) -> void:
	var v := vendor_for(w, e.role)
	if v == null or not v.bandaged:
		return
	for it in out:
		var pr: int = it["price"]
		if pr > 0:
			it["price"] = maxi(5, roundi(pr * DISCOUNT / 5.0) * 5)
			it["desc"] = str(it["desc"]) + " (rebajado)"
	if v.special != "":
		out.append({"id": "venganza", "name": "Soplo de venganza", "desc": "«Sé quién me hizo esto.» Durante 45 s ves dónde está el otro bando.", "price": 40, "ok": true, "why": ""})

static func buy_special(w: World, e: Ent) -> String:
	var v := vendor_for(w, e.role)
	if v == null or v.special == "":
		return "Ya no lo tiene."
	v.special = ""
	e.intel_until = w.time + 45.0
	e.intel_kind = "hunters" if e.role == "runner" else "runners"
	if e.role == "runner":
		e.hunter_mark = v.hunter_mark
	return "Soplo de venganza: durante 45 s ves en el mapa al otro bando."

# ---------------------------------------------------------------- paso

static func update(w: World, dt: float) -> void:
	if not w.central.is_empty():
		w.central["t"] = float(w.central["t"]) - dt
		if float(w.central["t"]) <= 0.0:
			w.central = {}
	if not w.quiz.is_empty():
		var h := w.ent_by_id(int(w.quiz["hunter"]))
		var bell := w.ent_by_id(int(w.quiz["bell"]))
		if h == null or not h.alive or bell == null or not bell.alive or bell.ko_t > 0 or h.ko_t > 0:
			_quiz_cancel(w, bell, h)
		else:
			h.moving = false
			h.aim = false
			w.quiz["t"] = float(w.quiz["t"]) - dt
			if float(w.quiz["t"]) <= 0.0:
				answer(w, -1)
	for h2 in w.ents:
		if h2.role == "hunter" and h2.quiz_id != 0:
			var b := w.ent_by_id(h2.quiz_id)
			if b == null or not b.alive or b.ko_t > 0 or b.quiz_id != h2.id:
				_quiz_cancel(w, b if (b != null and b.quiz_id == h2.id) else null, h2)
				h2.quiz_cd = w.time + 20.0
	_pets(w, dt)
	_vendors(w)
