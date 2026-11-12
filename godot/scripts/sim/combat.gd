## v0.7: puñetazos, esposas del cazador (con combinación de flechas para zafarse),
## balas visibles de la policía con salud, y la calle: coches de policía y coche fúnebre.
class_name Combat
extends RefCounted

const TS := Cfg.TS
const DIRS := ["up", "right", "down", "left"]

# ---------------------------------------------------------------- puñetazo

## Primer personaje delante de e dentro de un alcance y un cono.
static func _front(w: World, e: Ent, rng: float, cone: float, filter: Callable) -> Ent:
	var ax := e.aim_x - e.x
	var ay := e.aim_y - e.y
	var al := Vector2(ax, ay).length()
	if al < 1.0:
		var dv := {"up": Vector2(0, -1), "down": Vector2(0, 1), "left": Vector2(-1, 0), "right": Vector2(1, 0)}
		var d0: Vector2 = dv.get(e.dir, Vector2(0, 1))
		ax = d0.x; ay = d0.y; al = 1.0
	var best: Ent = null
	var bd := 1e9
	for v in w.ents:
		if v == e or not v.alive or v.fl != e.fl or v.escaped or v.away_t > 0 or v.hidden:
			continue
		if not filter.call(v):
			continue
		var dx: float = v.x - e.x
		var dy: float = v.y - e.y
		var d := Vector2(dx, dy).length()
		if d > rng or (dx * ax + dy * ay) / (d * al + 0.001) < cone:
			continue
		if d < bd:
			bd = d
			best = v
	return best

static func punch(w: World, e: Ent) -> bool:
	if e.cd > 0:
		return false
	e.cd = Cfg.PUNCH_CD
	e.fx_swing = 0.15
	Sim.ev(w, "swing", e.fl, e.x, e.y)
	var v := _front(w, e, Cfg.PUNCH_RANGE, 0.25, func(x): return true)
	if v == null:
		return false
	if v.shop != "" and Heat.vendor_punched(w, e, v):
		Sim.ev(w, "punch", v.fl, v.x, v.y)
		return true
	knock_out(w, v, Cfg.KO_POLICE if v.role == "police" else Cfg.KO_TIME)
	Stealth.on_punch(w, e, v)
	if e.rperk == "pugil":
		v.ko_t *= 2.0
	Sim.ev(w, "punch", v.fl, v.x, v.y)
	v.say(Rng.pick(["¡Uf!", "¡Ay!", "…"]), 1.5)
	# quien lo vea se lo toma mal
	var wit := Sim.civils_seeing(w, e, null, Cfg.WITNESS_RADIUS * TS * Sim.sight_scale(w))
	if not wit.is_empty() and v.role != "police":
		if e.role == "hunter":
			e.sus = minf(100.0, e.sus + 35.0)
		elif e.role == "runner":
			Sim.report_by(w, e, "¡Le ha dado un puñetazo a alguien! Aviso a seguridad.")
	if v.role == "police" and e.role != "police":
		w.cop_killers[e.id] = true
	if e == w.human:
		Sim.wlog(w, "Has dejado KO a " + v.nm.to_lower() + " unos segundos.")
	elif v == w.human:
		Sim.wlog(w, "¡Te han dejado KO de un puñetazo!", "report", v.id)
	return true

static func knock_out(w: World, v: Ent, t: float) -> void:
	v.ko_t = maxf(v.ko_t, t)
	v.moving = false
	v.aim = false
	v.goal = null
	v.has_path = false
	Sim.cancel_hold(w, v)
	if v.role == "civil" and (v.state == "call" or v.state == "calling"):
		v.state = "stun"
		v.ai_stun = t

# ---------------------------------------------------------------- esposas del cazador

static func try_cuff(w: World, e: Ent) -> bool:
	if e.cuffs_cd > 0 or not e.cuffs or e.cd > 0:
		return false
	var v := _front(w, e, Cfg.CUFF_RANGE, 0.2, func(x): return x.role == "runner" and not x.cuffed and x.qte_t <= 0 and not x.undercover)
	e.cd = 0.5
	if v == null:
		if e == w.human:
			Sim.wlog(w, "No hay ningún sospechoso a tu alcance.")
		return false
	e.cuffs_cd = Cfg.CUFF_CD
	var combo: Array = []
	for i in Cfg.QTE_LEN:
		combo.append(DIRS[Rng.ri(0, 3)])
	var lock := Cfg.QTE_TIME + 0.4
	e.qte_t = lock
	v.qte_t = lock
	e.moving = false
	v.moving = false
	Sim.cancel_hold(w, v)
	Sim.cancel_hold(w, e)
	w.qtes.append({"hunter": e.id, "runner": v.id, "t": Cfg.QTE_TIME, "combo": combo, "idx": 0, "human": v == w.human, "bot_ok": Rng.rnd() < Cfg.QTE_BOT_ESCAPE})
	e.say("Policía. Queda detenido.", 2.0)
	Sim.ev(w, "cuff", v.fl, v.x, v.y)
	return true

## La combinación de flechas del corredor humano.
static func qte_for(w: World, runner_id: int) -> Dictionary:
	for q in w.qtes:
		if q["runner"] == runner_id:
			return q
	return {}

static func qte_input(w: World, dirn: String) -> void:
	var h := w.human
	if h == null:
		return
	var q := qte_for(w, h.id)
	if q.is_empty():
		return
	var combo: Array = q["combo"]
	if combo[q["idx"]] == dirn:
		q["idx"] = int(q["idx"]) + 1
		if q["idx"] >= combo.size():
			_resolve(w, q, true)
	else:
		q["idx"] = 0

static func _resolve(w: World, q: Dictionary, escaped: bool) -> void:
	w.qtes.erase(q)
	var hn := w.ent_by_id(q["hunter"])
	var r := w.ent_by_id(q["runner"])
	if hn != null:
		hn.qte_t = 0
	if r == null or not r.alive:
		return
	r.qte_t = 0
	if escaped:
		if hn != null:
			knock_out(w, hn, 1.5)
		r.say("¡Suélteme!", 1.6)
		if r == w.human:
			Sim.wlog(w, "¡Te has zafado de las esposas! Corre.", "task")
		elif hn == w.human:
			Sim.wlog(w, r.nm + " se te ha escapado.")
		return
	# detenido: se va un momento de la partida y vuelve en otro sitio
	if r.carry != "":
		for k in r.tasks:
			if k.pair == r.carry:
				k.done = false
		r.carry = ""
	r.away_t = Cfg.ARREST_AWAY
	r.fl = -1
	r.moving = false
	r.goal = null
	if hn != null:
		hn.intel_until = w.time + Cfg.CUFF_INTEL
		hn.intel_kind = "runners"
		if hn == w.human:
			Sim.wlog(w, "Has esposado a " + r.nm + ". Durante " + str(int(Cfg.CUFF_INTEL)) + " s ves dónde están todos los corredores.")
	if r == w.human:
		Sim.wlog(w, "Te han esposado. Reapareces en otro sitio en " + str(int(Cfg.ARREST_AWAY)) + " s.", "report", r.id)
	Sim.wlog(w, r.nm + " ha sido arrestado por un cazador: vuestras posiciones han quedado al descubierto unos segundos.", "team", r.id)

static func _respawn(w: World, r: Ent) -> void:
	var fl := Rng.ri(0, 5)
	var t: Vector2i = Rng.pick(Hotel.floors[fl].tiles_pub)
	r.fl = fl
	r.x = (t.x + 0.5) * TS
	r.y = (t.y + 0.5) * TS
	r.has_path = false
	r.goal = null
	if r == w.human:
		Sim.wlog(w, "Has vuelto: estás en " + Hotel.floors[fl].label + ".", "task")

# ---------------------------------------------------------------- balas de la policía

static func police_fire(w: World, p: Ent, t: Ent) -> void:
	if p.fire_cd > 0:
		return
	p.fire_cd = Cfg.POLICE_FIRE_CD
	var a := atan2(t.y - 8 - (p.y - 14), t.x - p.x) + Rng.rnd() * Cfg.POLICE_SPREAD * 2.0 - Cfg.POLICE_SPREAD
	var ox := p.x + cos(a) * 14
	var oy := p.y - 14 + sin(a) * 14
	w.bullets.append({"fl": p.fl, "x": ox, "y": oy, "vx": cos(a) * Cfg.BULLET_SPEED, "vy": sin(a) * Cfg.BULLET_SPEED, "t": 0.9, "owner": p.id})
	w.fx.append({"type": "flash", "fl": p.fl, "x": ox, "y": oy, "t": 0.12, "big": true})
	_muzzle(w, p.fl, ox, oy, a)
	Sim.ev(w, "shot_police", p.fl, p.x, p.y)

## Chispas y humo del disparo.
static func _muzzle(w: World, fl: int, x: float, y: float, a: float) -> void:
	for i in 7:
		var sa := a + Rng.rnd() * 0.9 - 0.45
		var sp := 80.0 + Rng.rnd() * 160.0
		w.fx.append({"type": "spark", "fl": fl, "x": x, "y": y, "vx": cos(sa) * sp, "vy": sin(sa) * sp, "t": 0.25 + Rng.rnd() * 0.15, "t0": 0.4})
	w.fx.append({"type": "smoke", "fl": fl, "x": x + cos(a) * 6, "y": y + sin(a) * 6, "t": 0.9, "t0": 0.9})

static func muzzle(w: World, e: Ent) -> void:
	var a := atan2(e.aim_y - (e.y - 14), e.aim_x - e.x)
	_muzzle(w, e.fl, e.x + cos(a) * 22, e.y - 14 + sin(a) * 22, a)

static func hurt(w: World, v: Ent, shooter: Ent) -> void:
	if v.role == "hunter" or v.role == "runner":
		v.hp -= 1
		v.hp_t = Cfg.HP_REGEN
		w.fx.append({"type": "blood", "fl": v.fl, "x": v.x, "y": v.y, "t": 0.4})
		if v == w.human:
			Sim.wlog(w, "¡Te han dado! Salud " + str(maxi(v.hp, 0)) + "/" + str(Cfg.HP) + ".", "report", v.id)
		if v.hp <= 0:
			Sim.kill(w, shooter, v, "police")
	else:
		Sim.kill(w, shooter, v, "police")

static func _update_bullets(w: World, dt: float) -> void:
	var keep: Array = []
	for b in w.bullets:
		b["t"] = float(b["t"]) - dt
		if b["t"] <= 0:
			continue
		var f: FloorData = Hotel.floors[b["fl"]]
		var hit := false
		var steps := 4
		for s in steps:
			b["x"] = float(b["x"]) + float(b["vx"]) * dt / steps
			b["y"] = float(b["y"]) + float(b["vy"]) * dt / steps
			var bx: float = b["x"]
			var by: float = b["y"]
			if f.blocks(floori(bx / TS), floori(by / TS)) or Cfg.is_solid(f.at(floori(bx / TS), floori(by / TS))):
				hit = true
				w.fx.append({"type": "spark", "fl": b["fl"], "x": bx, "y": by, "vx": 0.0, "vy": -40.0, "t": 0.2, "t0": 0.2})
				break
			for v in w.ents:
				if not v.alive or v.fl != int(b["fl"]) or v.id == int(b["owner"]) or v.role == "police" or v.escaped or v.away_t > 0:
					continue
				if Vector2(v.x - bx, v.y - 10 - by).length() < 11:
					hurt(w, v, w.ent_by_id(b["owner"]) if w.ent_by_id(b["owner"]) != null else v)
					hit = true
					break
			if hit:
				break
		if not hit:
			keep.append(b)
	w.bullets = keep

# ---------------------------------------------------------------- la calle: coches

static func add_car(w: World, kind: String, tx_tile: float, payload: Dictionary = {}) -> void:
	var lane := Cfg.STREET_Y + (0.0 if kind != "hearse" else 0.0)
	w.cars.append({"kind": kind, "x": -160.0, "y": lane * TS, "tx": tx_tile * TS, "state": "arrive", "t": 0.0, "payload": payload})

static func _update_cars(w: World, dt: float) -> void:
	var keep: Array = []
	for c in w.cars:
		match c["state"]:
			"arrive":
				var dx: float = float(c["tx"]) - float(c["x"])
				var sp := clampf(absf(dx) * 1.6, 40.0, 260.0)
				c["x"] = float(c["x"]) + signf(dx) * minf(absf(dx), sp * dt)
				if absf(dx) < 1.0:
					c["state"] = "parked"
					c["t"] = 0.0
			"parked":
				c["t"] = float(c["t"]) + dt
				if c["kind"] == "police" and not c["payload"].is_empty() and c["t"] > 0.8:
					var d: Dictionary = c["payload"]
					c["payload"] = {}
					Sim.spawn_police_now(w, d, float(c["x"]) / TS)
				if c["kind"] == "hearse" and c["t"] > 4.0 and c["payload"].has("go"):
					c["payload"] = {}
					var n := 0
					for k in w.corpses:
						if not k.chalk and k.found and w.time - k.t > Cfg.HEARSE_AFTER:
							k.chalk = true
							n += 1
					if n > 0:
						Sim.wlog(w, "El coche fúnebre de la policía se lleva " + ("el cadáver." if n == 1 else str(n) + " cadáveres."), "info")
				if c["kind"] == "hearse" and c["t"] > 8.0:
					c["state"] = "leave"
			"leave":
				c["x"] = float(c["x"]) + 200.0 * dt
				if float(c["x"]) > Cfg.W * TS + 200:
					continue
		keep.append(c)
	w.cars = keep
	# coche fúnebre cuando hay cadáveres descubiertos desde hace rato
	var need := false
	for k in w.corpses:
		if not k.chalk and k.found and w.time - k.t > Cfg.HEARSE_AFTER:
			need = true
	if need:
		var busy := false
		for c in w.cars:
			if c["kind"] == "hearse":
				busy = true
		if not busy:
			add_car(w, "hearse", 14.0, {"go": true})

## Hueco libre para aparcar delante del hotel.
static func park_slot(w: World) -> float:
	var used: Array = []
	for c in w.cars:
		if c["state"] != "leave":
			used.append(roundi(float(c["tx"]) / TS))
	for x in [19, 25, 16, 28, 13, 31, 10, 34]:
		if not (x in used):
			return float(x)
	return 37.0

# ---------------------------------------------------------------- paso

static func update(w: World, dt: float) -> void:
	for q in w.qtes.duplicate():
		q["t"] = float(q["t"]) - dt
		if not q["human"] and float(q["t"]) < Cfg.QTE_TIME - 1.5:
			_resolve(w, q, q["bot_ok"])
		elif float(q["t"]) <= 0:
			_resolve(w, q, false)
	for e in w.ents:
		if not e.alive:
			continue
		if e.ko_t > 0:
			e.ko_t -= dt
		if e.qte_t > 0:
			e.qte_t -= dt
		if e.cuffs_cd > 0:
			e.cuffs_cd -= dt
		if e.fire_cd > 0:
			e.fire_cd -= dt
		if e.away_t > 0:
			e.away_t -= dt
			if e.away_t <= 0:
				_respawn(w, e)
		if (e.role == "hunter" or e.role == "runner") and e.hp < Cfg.HP:
			e.hp_t -= dt
			if e.hp_t <= 0:
				e.hp += 1
				e.hp_t = Cfg.HP_REGEN
	_update_bullets(w, dt)
	_update_cars(w, dt)
