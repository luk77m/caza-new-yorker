## Recompensa del primer corredor en terminar, ayuda entre corredores y trabajos extra.
class_name Reward
extends RefCounted

const TS := Cfg.TS
const JOBS_RUNNER := ["Dejar un sobre bajo una maceta", "Cobrar una deuda a un huésped", "Recoger un paquete escondido", "Avisar a un socio en clave"]
const JOBS_HUNTER := ["Entregar un recado del vigilante", "Vigilar una puerta un momento", "Dejar un informe en un buzón"]

static func all_done(r: Ent) -> bool:
	var u := Sim.task_units(r)
	return u.y > 0 and u.x >= u.y

## Al terminar un encargo: ¿es el primer corredor en acabarlos todos?
static func check_finish(w: World, r: Ent) -> void:
	if r.role != "runner" or not all_done(r):
		return
	if w.first_done != 0:
		if r == w.human:
			Sim.wlog(w, "Has terminado tus encargos. Ahora puedes hacer los de tus compañeros para acabar antes.", "task")
		return
	w.first_done = r.id
	var cop := Rng.rnd() < Cfg.COP_EVENT_CHANCE
	Sim.wlog(w, r.nm + " ha terminado todos sus encargos.", "team", r.id)
	if r == w.human:
		var n := spawn_deliverer(w, r, cop)
		w.cine = {"type": "cop" if cop else "contact", "npc": n.id, "phase": "approach", "t": 0.0}
	else:
		give(w, r, cop)

static func spawn_deliverer(w: World, r: Ent, cop: bool) -> Ent:
	var f: FloorData = Hotel.floors[r.fl]
	var rt := r.tile()
	var best := rt
	var bd := 1e9
	for t in f.tiles_pub:
		var d := Vector2(t.x - rt.x, t.y - rt.y).length()
		var score := absf(d - 6.0)
		if score < bd:
			bd = score
			best = t
	var n := Sim.new_ent(w)
	n.type = "npc"; n.role = "civil"; n.fl = r.fl
	n.x = (best.x + 0.5) * TS; n.y = (best.y + 0.5) * TS
	n.tiles = f.tiles_pub
	if cop:
		n.outfit = Outfit.new_police()
		n.nm = "Policía"
		n.coffee = true
	else:
		n.outfit = Outfit.new_guest(false)
		n.outfit.hat_t = "fedora"; n.outfit.hat_c = Color("#1c1c22")
		n.nm = "El Contacto"
	n.ai_mode = "deliver"
	n.deliver_to = r.id
	w.ents.append(n)
	return n

## El premio: pistola y, o bien la identidad de un cazador, o bien la placa de policía (evento raro).
static func give(w: World, r: Ent, cop: bool) -> void:
	r.gun = true
	r.ammo = Cfg.BONUS_AMMO
	r.ammo_max = Cfg.BONUS_AMMO
	r.equip = "gun"
	if cop:
		r.undercover = true
		r.marked = false
		r.reports = 0
		Sim.swap_outfit(w, r, Outfit.new_police())
		if r == w.human:
			Sim.wlog(w, "Ahora llevas uniforme y placa: la policía no te cachea ni te detiene, y tienes una pistola con " + str(Cfg.BONUS_AMMO) + " balas (Q para equiparla, clic derecho para apuntar).", "task")
		return
	var best: Ent = null
	var bd := 1e9
	for h in w.ents:
		if h.role == "hunter" and h.alive:
			var d: float = absi(h.fl - r.fl) * 2000.0 + Vector2(h.x - r.x, h.y - r.y).length()
			if d < bd:
				bd = d
				best = h
	if best != null:
		r.knows[best.outfit.id] = true
		r.hunter_mark = best.id
		r.intel_until = w.time + Cfg.BONUS_INTEL
	if r == w.human:
		Sim.wlog(w, "Tienes una pistola con " + str(Cfg.BONUS_AMMO) + " balas (Q para equiparla, clic derecho para apuntar) y el chivatazo: uno de los cazadores va " + (best.outfit.describe().to_lower() if best != null else "—") + ". Te lo marcamos " + str(int(Cfg.BONUS_INTEL)) + " s.", "task")

## IA del PNJ que trae la recompensa.
static func npc_ai(w: World, n: Ent, dt: float) -> bool:
	if n.ai_mode == "deliver":
		var r := w.ent_by_id(n.deliver_to)
		if r == null or not r.alive or r.fl != n.fl:
			n.ai_mode = "leave"
			n.ai_t = 0.5
			if not w.cine.is_empty():
				w.cine = {}
			return true
		var rt := r.tile()
		if n.goal == null or absi(n.goal.x - rt.x) + absi(n.goal.y - rt.y) > 1:
			Sim.nav_to(w, n, n.fl, rt.x, rt.y)
		Sim.nav_update(w, n, dt, Cfg.SPEED_NPC * 1.3)
		if Vector2(r.x - n.x, r.y - n.y).length() < 36:
			n.moving = false
			n.dir = Sim.dir_of(r.x - n.x, r.y - n.y)
			r.dir = Sim.dir_of(n.x - r.x, n.y - r.y)
			if n.coffee:
				n.say("Chaval, sujétame el café… Bah, quédate también la placa y la pistola. Yo me voy a casa.", 3.5)
			else:
				n.say("Buen trabajo. El jefe te manda esto… y te digo quién te busca.", 3.5)
			give(w, r, n.coffee)
			n.ai_mode = "leave"
			n.ai_t = 2.5
			if not w.cine.is_empty():
				w.cine["phase"] = "give"
				w.cine["t"] = 0.0
		return true
	if n.ai_mode == "leave":
		if n.ai_t > 0:
			n.ai_t -= dt
			n.moving = false
			return true
		var f: FloorData = Hotel.floors[n.fl]
		if n.goal == null:
			Sim.nav_to(w, n, n.fl, f.spawn.x, f.spawn.y - 1)
		if Sim.nav_update(w, n, dt, Cfg.SPEED_NPC * 1.2):
			n.alive = false
			n.remove = true
		return true
	return false

static func update(w: World, dt: float) -> void:
	if w.cine.is_empty():
		return
	w.cine["t"] = float(w.cine["t"]) + dt
	if (w.cine["phase"] == "give" and w.cine["t"] > 3.0) or w.cine["t"] > 20.0:
		w.cine = {}

# ---------------------------------------------------------------- trabajos extra

static func new_job(w: World, e: Ent) -> Task:
	var fl := Rng.ri(0, 5)
	if fl == e.fl:
		fl = (fl + 2) % 6
	var tt: Vector2i = Rng.pick(Hotel.floors[fl].tiles_pub)
	var t := Task.new()
	t.id = "job"
	t.kind = "job"
	t.fl = fl
	t.x = tt.x
	t.y = tt.y
	t.dur = Cfg.HOLD_JOB
	var pay := Rng.ri(Cfg.JOB_PAY_MIN / 10, Cfg.JOB_PAY_MAX / 10) * 10
	t.pair = str(pay)
	t.nm = str(Rng.pick(JOBS_RUNNER if e.role == "runner" else JOBS_HUNTER)) + " · " + Hotel.floors[fl].label + " · $" + str(pay)
	return t

static func finish_job(w: World, e: Ent) -> void:
	if e.job == null:
		return
	var pay := int(e.job.pair)
	e.money += pay
	Sim.ev(w, "cash", e.fl, e.x, e.y)
	if e == w.human:
		Sim.wlog(w, "Trabajo hecho: +$" + str(pay) + ". Puedes pedir otro.", "task")
	e.job = null
