## v0.11 «Sigilo» (propuestas del tester):
##  - sangre: charcos que se pisan (huellas), salpicaduras a quien esté cerca, fregona para limpiar
##  - los PNJ esquivan los cadáveres; correr delante de la gente levanta sospechas
##  - cambiarte delante de testigos vuelve sospechoso ese traje; el personal no reconoce a un "compañero" nuevo
##  - noquear para quitar la ropa o vaciar los bolsillos; al despertar, avisan
##  - arrastrar cuerpos (cadáveres o noqueados) y esconderlos en armarios; esconderte tú también
##  - ganzúas limitadas por partida (el anfitrión tiene una); forzar una puerta hace ruido
##  - el personal limpia la sangre cuando la policía se lleva el cuerpo y va a lavar el uniforme
##  - tabla de puntuación al final
class_name Stealth
extends RefCounted

const TS := Cfg.TS
const RUN_RATE := 10.0          # sospecha/s si te ven correr
const SUSOUT_RATE := 6.0        # sospecha/s con un traje "quemado" (te vieron cambiarte con él)
const STAFF_RATE := 8.0         # sospecha/s si un empleado con tu mismo uniforme no te reconoce
const DRAG_KO_RATE := 40.0      # sospecha/s si te ven arrastrando a alguien inconsciente
const CLEAN_RATE := 25.0        # sospecha/s si te ven fregando sangre
const SEE := 7.0                # casillas a las que se fijan en estas cosas
const KO_CIVIL := 22.0          # s inconsciente un civil tras un puñetazo (da tiempo a desvestirlo)
const PRINTS := 10              # huellas que deja un zapato manchado
const PRINT_EVERY := 15.0       # px entre huellas
const PRINT_LIFE := 120.0
const HOLD_STRIP_KO := 3.0
const HOLD_LOOT := 1.6
const HOLD_CLEAN := 3.0
const SPEED_DRAG := 0.5         # multiplicador de velocidad arrastrando un cuerpo
const PRESS := ["drop", "stash", "hide", "unhide"]
const HOLDS := ["strip_ko", "loot", "clean"]

# ---------------------------------------------------------------- inicio de partida

## Ganzúas limitadas: la del anfitrión (el jugador) y el resto repartidas sin marcar. Fregonas por el hotel.
static func setup(w: World, n_players: int) -> void:
	var picks := maxi(1, n_players - 1)
	var h := w.human
	if h != null and (h.role == "runner" or h.role == "hunter"):
		h.lockpick = true
		picks -= 1
	var spots: Array = []
	for fi in range(0, 6):
		var f := Sim.fdat(fi)
		for i in 6:
			if f.tiles_pub.is_empty():
				break
			var t: Vector2i = Rng.pick(f.tiles_pub)
			spots.append(Vector3i(fi, t.x, t.y))
	spots = Rng.shuffle(spots)
	var pid := 900
	for i in mini(picks, spots.size()):
		pid += 1
		w.picks.append(Sim._mk_pick(pid, "lockpick", spots[i], "ganzúa"))
	for i in 3:
		var k := picks + i
		if k < spots.size():
			pid += 1
			w.picks.append(Sim._mk_pick(pid, "mop", spots[k], "fregona"))

# ---------------------------------------------------------------- sangre

static func add_pool(w: World, fl: int, x: float, y: float, r: float, corpse_id: int = 0) -> void:
	w.pools.append({"fl": fl, "x": x, "y": y, "r": r, "corpse": corpse_id, "cleaner": 0, "t": w.time})

## Al matar: charco, y la sangre salpica a quien esté muy cerca (también al asesino si fue cuerpo a cuerpo).
static func on_kill(w: World, killer: Ent, victim: Ent, how: String, c: Items.Corpse) -> void:
	add_pool(w, victim.fl, victim.x + 4, victim.y + 6, 18.0, c.id)
	var close := Sim.dist(killer.x, killer.y, victim.x, victim.y) < 1.6 * TS
	if (how == "knife" or how == "melee" or close) and killer.role != "police" and killer.outfit.kind != "under":
		killer.outfit.blood = true
		if killer == w.human:
			Sim.wlog(w, "Te ha salpicado la sangre. Lava la ropa o cámbiate antes de que alguien lo vea.")
	for n in w.ents:
		if n == victim or n == killer or not n.alive or n.role != "civil" or n.fl != victim.fl:
			continue
		if Sim.dist(n.x, n.y, victim.x, victim.y) < 1.7 * TS:
			n.outfit = n.outfit.clone()
			n.outfit.blood = true
			n.state = "scared"; n.ai_t = Rng.ri(5, 9); n.goal = null; n.moving = false
			Life.add_panic(w, 5.0)
			n.say(Rng.pick(["¡Me ha salpicado!", "¡Sangre! ¡Sangre!", "¡Dios santo!"]), 2.4)

static func _pool_at(w: World, fl: int, x: float, y: float, extra: float = 0.0) -> Dictionary:
	for p in w.pools:
		if int(p["fl"]) == fl and Vector2(float(p["x"]) - x, float(p["y"]) - y).length() < float(p["r"]) + extra:
			return p
	return {}

static func _clean_spot(w: World, fl: int, x: float, y: float, r: float) -> void:
	w.pools = w.pools.filter(func(p): return not (int(p["fl"]) == fl and Vector2(float(p["x"]) - x, float(p["y"]) - y).length() < float(p["r"]) + r))
	w.prints = w.prints.filter(func(p): return not (int(p["fl"]) == fl and Vector2(float(p["x"]) - x, float(p["y"]) - y).length() < r + 26.0))

# ---------------------------------------------------------------- paso

static func update(w: World, dt: float) -> void:
	# huellas: quien pisa un charco va dejando marcas un rato
	for e in w.ents:
		if not e.alive or e.escaped or e.hidden or e.away_t > 0:
			continue
		var moved := Vector2(e.x - e.lx, e.y - e.ly).length()
		if moved > 40.0:
			moved = 0.0     # teletransporte (ascensor, escaleras)
		e.lx = e.x
		e.ly = e.y
		if not e.moving:
			continue
		if not _pool_at(w, e.fl, e.x, e.y).is_empty():
			e.shoe_blood = PRINTS
		if e.shoe_blood > 0:
			e.print_acc += moved
			if e.print_acc >= PRINT_EVERY:
				e.print_acc = 0.0
				e.shoe_blood -= 1
				e.print_side = 1 - e.print_side
				var dv := {"up": -PI / 2.0, "down": PI / 2.0, "left": PI, "right": 0.0}
				w.prints.append({"fl": e.fl, "x": e.x, "y": e.y + 9, "a": float(dv.get(e.dir, 0.0)), "s": e.print_side, "t": w.time, "drag": false})
	if w.prints.size() > 0 and Engine.get_process_frames() % 30 == 0:
		w.prints = w.prints.filter(func(p): return w.time - float(p["t"]) < PRINT_LIFE)
	# cuerpos arrastrados
	for e in w.ents:
		if e.dragging == null:
			continue
		if not e.alive or e.ko_t > 0 or e.cuffed or e.escaped:
			drop(w, e)
			continue
		var dv2 := {"up": Vector2(0, 1), "down": Vector2(0, -1), "left": Vector2(1, 0), "right": Vector2(-1, 0)}
		var back: Vector2 = dv2.get(e.dir, Vector2(0, -1))
		var tx: float = e.x + back.x * 18.0
		var ty: float = e.y + back.y * 18.0
		if e.dragging is Ent and not (e.dragging as Ent).alive:
			# lo han matado mientras lo arrastrabas: sigues con el cadáver
			var dead: Ent = e.dragging
			e.dragging = null
			for k in w.corpses:
				if k.victim_id == dead.id:
					e.dragging = k
			if e.dragging == null:
				continue
		if e.dragging is Items.Corpse:
			var c: Items.Corpse = e.dragging
			if c.chalk or c.hidden:
				drop(w, e)
				continue
			if c.fl != e.fl:
				c.fl = e.fl
			var dm := Vector2(tx - c.x, ty - c.y).length()
			c.drag_acc += dm
			c.x = tx
			c.y = ty
			c.ang = atan2(back.y, back.x)
			if c.drag_acc >= 18.0 and not c.stripped_clean:
				c.drag_acc = 0.0
				w.prints.append({"fl": c.fl, "x": c.x, "y": c.y + 4, "a": c.ang, "s": 0, "t": w.time, "drag": true})
		elif e.dragging is Ent:
			var v: Ent = e.dragging
			v.fl = e.fl
			v.x = tx
			v.y = ty
			v.ko_t = maxf(v.ko_t, 1.5)
	# despertar de los noqueados: si les quitaron algo o los movieron, avisan
	for v in w.ents:
		if not v.alive:
			continue
		if v.ko_t > 0:
			v.was_ko = true
			continue
		if v.was_ko:
			v.was_ko = false
			_on_wake(w, v)
	# limpiadores tras el coche fúnebre
	for p in w.pools:
		var cid: int = p["corpse"]
		if cid == 0 or int(p["cleaner"]) != 0:
			continue
		var gone := true
		for c in w.corpses:
			if c.id == cid and not c.chalk:
				gone = false
		if gone:
			var cl := _pick_cleaner(w, int(p["fl"]), float(p["x"]), float(p["y"]))
			if cl != null:
				p["cleaner"] = cl.id
				cl.ai_mode = "clean"; cl.clean_pool = p; cl.ai_t = 0.0; cl.goal = null
	# la policía que pasa junto a un armario con un cuerpo puede abrirlo
	if Engine.get_process_frames() % 20 == 0:
		for c in w.corpses:
			if not c.hidden:
				continue
			for p2 in w.ents:
				if p2.role == "police" and p2.alive and p2.fl == c.fl and Sim.dist(p2.x, p2.y, c.x, c.y) < 1.4 * TS and Rng.rnd() < 0.08:
					c.hidden = false
					c.found = true
					Alarm.innocent_found(w, c)
					p2.say("¡Hay un cuerpo en el armario!", 2.6)
					Sim.wlog(w, "La policía ha encontrado un cuerpo escondido en un armario.", "alarm")
					break

static func _pick_cleaner(w: World, fl: int, x: float, y: float) -> Ent:
	var best: Ent = null
	var bd := 1e9
	for n in w.ents:
		if not n.alive or n.role != "civil" or not n.staff or n.fixed or n.fl != fl or n.state != "idle" or n.ai_mode == "clean":
			continue
		if n.outfit.staff_role != "maid" and n.outfit.staff_role != "tech" and n.outfit.staff_role != "bell":
			continue
		var d := Sim.dist(n.x, n.y, x, y)
		if d < bd:
			bd = d
			best = n
	return best

static func _on_wake(w: World, v: Ent) -> void:
	if v.role != "civil" or v.ko_by == "":
		v.ko_by = ""
		return
	var why := "¡Me han dejado sin ropa!" if v.outfit.kind == "under" else ("¡Me han robado la cartera!" if v.ko_looted else "¡Me han atacado!")
	v.say(why, 3.0)
	if v.hide_ward != null:
		v.say("¡Socorro! ¡Sacadme de aquí!", 3.0)
		v.hide_ward.occupant = null
		v.hide_ward = null
		v.hidden = false
		v.x = v.hide_from.x
		v.y = v.hide_from.y
	var t := v.tile()
	Sim.alert_npc(w, v, v.ko_by, "sospecha", v.fl, t.x, t.y)
	v.ko_by = ""
	v.ko_looted = false

# ---------------------------------------------------------------- IA de los PNJ

## Limpieza tras retirar un cuerpo y evitar los cadáveres. Devuelve true si se ha encargado del PNJ.
static func npc_ai(w: World, e: Ent, dt: float) -> bool:
	if e.hidden:
		e.moving = false
		return true
	if e.ai_mode == "clean":
		_cleaner(w, e, dt)
		return true
	# esquivar cadáveres (salvo si huye o le están apuntando)
	if e.state == "idle" and e.goal != null and e.ai_rec < 6:
		for c in w.corpses:
			if c.hidden or c.chalk or c.fl != e.goal.fl:
				continue
			var gx := (e.goal.x + 0.5) * TS
			var gy := (e.goal.y + 0.5) * TS
			if Sim.dist(gx, gy, c.x, c.y) < 3.0 * TS or (c.found and Sim.dist(e.x, e.y, c.x, c.y) < 1.6 * TS):
				e.goal = null
				e.ai_rec += 1
				return false
	if e.goal == null:
		e.ai_rec = 0
	return false

## Fases del limpiador: 0 ir al charco, 1 fregar, 2 ir a la lavandería, 3 lavar el uniforme.
static func _cleaner(w: World, e: Ent, dt: float) -> void:
	var p: Dictionary = e.clean_pool
	match e.clean_phase:
		0:
			if e.goal == null:
				Sim.nav_to(w, e, int(p["fl"]), floori(float(p["x"]) / TS), floori(float(p["y"]) / TS))
			if Sim.nav_update(w, e, dt, Cfg.SPEED_NPC) or e.unreach:
				e.goal = null
				e.clean_phase = 1
				e.ai_t = 4.0
				e.say("Qué desastre… voy a fregar esto.", 2.2)
		1:
			e.moving = false
			e.ai_t -= dt
			if e.ai_t <= 0.0:
				_clean_spot(w, int(p["fl"]), float(p["x"]), float(p["y"]), 20.0)
				e.outfit = e.outfit.clone()
				e.outfit.blood = true
				e.clean_phase = 2
				e.goal = null
		2:
			var f0 := Sim.fdat(0)
			if f0.washers.is_empty():
				e.clean_phase = 3
				e.ai_t = 0.0
				return
			if e.goal == null:
				var wsh: Fixture = f0.washers[0]
				var st := wsh.stand if wsh.has_stand else Vector2i(wsh.x, wsh.y + wsh.h)
				Sim.nav_to(w, e, 0, st.x, st.y)
			if Sim.nav_update(w, e, dt, Cfg.SPEED_NPC) or e.unreach:
				e.goal = null
				e.clean_phase = 3
				e.ai_t = 5.0
		3:
			e.moving = false
			e.ai_t -= dt
			if e.ai_t <= 0.0:
				e.outfit.blood = false
				e.ai_mode = "idle"
				e.clean_phase = 0
				e.goal = null
				e.ai_wait = 2.0
				e.say("Como nuevo.", 1.6)

## Lo más cercano que se puede arrastrar con F (cadáver o alguien inconsciente).
static func find_draggable(w: World, e: Ent):
	var best = null
	var bd := 46.0
	for c in w.corpses:
		if c.fl == e.fl and not c.chalk and not c.hidden:
			var d := Sim.dist(e.x, e.y, c.x, c.y)
			if d < bd:
				bd = d
				best = c
	for v in w.ents:
		if v != e and v.alive and v.fl == e.fl and v.ko_t > 0 and not v.cuffed and not v.hidden and v.dragged_by == 0 and (v.role == "civil" or v.role == "police"):
			var d2 := Sim.dist(e.x, e.y, v.x, v.y)
			if d2 < bd:
				bd = d2
				best = v
	return best

# ---------------------------------------------------------------- percepción

static func perceive(w: World, dt: float) -> void:
	var sc := Sim.sight_scale(w)
	var found_any := w.innocents > 0
	if not found_any:
		for c in w.corpses:
			if c.found:
				found_any = true
				break
	for p in w.ents:
		if not p.alive or p.escaped or p.hidden or p.undercover or (p.role != "hunter" and p.role != "runner"):
			continue
		var f := Sim.fdat(p.fl)
		var add := 0.0
		var seer: Ent = null
		var staff_seer: Ent = null
		for c in w.ents:
			if c.role != "civil" or not c.alive or c.fl != p.fl or c.ko_t > 0 or c.hidden or c.asleep or c.state == "dead":
				continue
			var d := Sim.dist(c.x, c.y, p.x, p.y)
			if d > SEE * TS * sc or not Nav.los(f, c.x, c.y, p.x, p.y):
				continue
			if seer == null:
				seer = c
			if p.running:
				add += RUN_RATE
			if w.sus_outfits.has(p.outfit.id):
				add += SUSOUT_RATE
			if found_any and c.staff and p.outfit.staff_role != "" and c.outfit.staff_role == p.outfit.staff_role and d < 4.0 * TS:
				add += STAFF_RATE
				staff_seer = c
			if p.dragging != null:
				if p.dragging is Items.Corpse:
					p.sus = 100.0
					var t: Vector2i = p.tile()
					Sim.alert_npc(w, c, p.outfit.id, "crime", p.fl, t.x, t.y)
					var cp: Items.Corpse = p.dragging
					if not cp.found:
						cp.found = true
						Alarm.innocent_found(w, cp)
				else:
					add += DRAG_KO_RATE
			if p.hold != null and p.hold.type == "clean":
				add += CLEAN_RATE
		if add <= 0.0 or seer == null:
			continue
		p.sus = clampf(p.sus + add * Life.rate_mul(w) * dt, 0.0, 100.0)
		if w.time - seer.last_warn > 7.0:
			if staff_seer != null:
				staff_seer.last_warn = w.time
				staff_seer.say("Usted no trabaja aquí… no le había visto nunca.", 2.6)
			elif p.running and Rng.rnd() < 0.5:
				seer.last_warn = w.time
				seer.say(Rng.pick(["¿Por qué corre ese?", "¡Eh, sin correr por los pasillos!", "¿Qué prisa tendrá?"]), 2.2)
			elif w.sus_outfits.has(p.outfit.id) and Rng.rnd() < 0.4:
				seer.last_warn = w.time
				seer.say("Ese traje… ¿no es el del que se cambió antes?", 2.6)

## Cambiarse delante de testigos "quema" el traje nuevo.
static func on_change(w: World, e: Ent) -> void:
	e.sus = e.sus * 0.4
	var wit := Sim.civils_seeing(w, e, null, SEE * TS * Sim.sight_scale(w))
	if wit.is_empty():
		return
	w.sus_outfits[e.outfit.id] = true
	e.sus = minf(100.0, e.sus + 30.0)
	(wit[0] as Ent).say("¿Se está cambiando de ropa aquí mismo?", 2.6)
	if e == w.human:
		Sim.wlog(w, "Te han visto cambiarte: ese traje ya es sospechoso. Busca otro donde nadie mire.", "report", e.id)

## Forzar una cerradura hace ruido: quien esté dentro de la habitación lo oye y avisa.
static func on_force(w: World, e: Ent, rm: Room) -> void:
	for c in w.ents:
		if c.role != "civil" or not c.alive or c.fl != e.fl or c.ko_t > 0:
			continue
		if Sim.inside_room(c, rm):
			c.say("¿Quién anda ahí? ¡Están forzando la puerta!", 2.6)
			var t := e.tile()
			Sim.alert_npc(w, c, e.outfit.id, "sospecha", e.fl, t.x, t.y)
			e.sus = minf(100.0, e.sus + 25.0)
			break
		elif Sim.dist(c.x, c.y, e.x, e.y) < 4.0 * TS:
			c.dir = Sim.dir_of(e.x - c.x, e.y - c.y)

# ---------------------------------------------------------------- interacción

## Añade las acciones de sigilo a la búsqueda de interacciones (cand es la función de Sim.find_interact).
static func candidates(w: World, e: Ent, f: FloorData, cand: Callable) -> void:
	if e.dragging != null:
		cand.call("drop", null, e.x, e.y, 999.0, "Soltar el cuerpo (o F)", 0.0)
		for wd in f.wards:
			if wd.body == null and wd.occupant == null:
				var cc: Vector2 = wd.center()
				cand.call("stash", wd, cc.x, cc.y, 60.0, "Esconder el cuerpo en el armario", 0.0)
		return
	# alguien inconsciente: primero los bolsillos, luego la ropa (F para arrastrarlo)
	for v in w.ents:
		if v == e or not v.alive or v.fl != e.fl or v.ko_t <= 0 or v.cuffed or v.hidden or (v.role != "civil" and v.role != "police"):
			continue
		if e.gun and e.equip == "gun" and v.role == "civil" and v.planted_gun < 0:
			# con la pistola en la mano: deshacerte de ella cargándole el muerto
			cand.call("plant", v, v.x, v.y, 44.0, "Colocarle tu pistola", 2.0)
		elif not v.ko_looted and v.role == "civil":
			cand.call("loot", v, v.x, v.y, 44.0, "Vaciarle los bolsillos", HOLD_LOOT)
		elif v.outfit.kind != "under":
			cand.call("strip_ko", v, v.x, v.y, 44.0, "Quitarle la ropa", HOLD_STRIP_KO)
	for wd in f.wards:
		if wd.looted and wd.occupant == null and wd.body == null:
			var c2: Vector2 = wd.center()
			cand.call("hide", wd, c2.x, c2.y, 54.0, "Esconderte en el armario", 0.0)
	if e.mop:
		for p in w.pools:
			if int(p["fl"]) == e.fl:
				cand.call("clean", p, float(p["x"]), float(p["y"]), float(p["r"]) + 30.0, "Fregar la sangre", HOLD_CLEAN)
		for p in w.prints:
			if int(p["fl"]) == e.fl:
				cand.call("clean", p, float(p["x"]), float(p["y"]), 34.0, "Fregar las huellas", HOLD_CLEAN * 0.5)

static func press(w: World, e: Ent, hint: Dictionary) -> String:
	match String(hint["type"]):
		"drag":
			e.dragging = hint["ref"]
			if e.dragging is Ent:
				(e.dragging as Ent).dragged_by = e.id
			e.aim = false
			if e == w.human:
				Sim.wlog(w, "Arrastras el cuerpo (vas más despacio). Pulsa E para soltarlo o junto a un armario para esconderlo.")
			return "ok"
		"drop":
			drop(w, e)
			return "ok"
		"stash":
			var wd: Fixture = hint["ref"]
			var body = e.dragging
			drop(w, e)
			var cc := wd.center()
			if body is Items.Corpse:
				var c: Items.Corpse = body
				c.hidden = true
				c.x = cc.x
				c.y = cc.y
				wd.body = c
				if e == w.human:
					Sim.wlog(w, "El cuerpo está en el armario. Nadie lo verá… salvo que lo abran.")
			elif body is Ent:
				var v: Ent = body
				v.hidden = true
				v.hide_ward = wd
				v.hide_from = Vector2(e.x, e.y)
				v.x = cc.x
				v.y = cc.y
				v.ko_t = maxf(v.ko_t, 12.0)
				wd.occupant = v
				if e == w.human:
					Sim.wlog(w, "Lo has encerrado en el armario. Cuando despierte, golpeará la puerta.")
			Sim.ev(w, "door", e.fl, e.x, e.y)
			return "ok"
		"hide":
			var wd2: Fixture = hint["ref"]
			e.hidden = true
			e.hide_ward = wd2
			e.hide_from = Vector2(e.x, e.y)
			var c3 := wd2.center()
			e.x = c3.x
			e.y = c3.y
			e.aim = false
			e.moving = false
			wd2.occupant = e
			Sim.ev(w, "door", e.fl, e.x, e.y)
			if not Sim.civils_seeing(w, e, null, SEE * TS).is_empty():
				e.sus = minf(100.0, e.sus + 40.0)
			if e == w.human:
				Sim.wlog(w, "Te escondes en el armario. Nadie te ve; pulsa E para salir.")
			return "ok"
		"unhide":
			unhide(w, e)
			return "ok"
	return ""

static func unhide(w: World, e: Ent) -> void:
	if e.hide_ward != null:
		e.hide_ward.occupant = null
	e.hide_ward = null
	e.hidden = false
	e.x = e.hide_from.x
	e.y = e.hide_from.y
	Sim.ev(w, "door", e.fl, e.x, e.y)
	if not Sim.civils_seeing(w, e, null, SEE * TS).is_empty():
		e.sus = minf(100.0, e.sus + 35.0)
		if e == w.human:
			Sim.wlog(w, "Te han visto salir del armario.", "report", e.id)

static func drop(w: World, e: Ent) -> void:
	if e.dragging is Ent:
		(e.dragging as Ent).dragged_by = 0
	e.dragging = null

static func hold_valid(w: World, e: Ent, h: Hold) -> bool:
	match h.type:
		"strip_ko":
			return h.ref.alive and h.ref.ko_t > 0 and h.ref.outfit.kind != "under"
		"loot":
			return h.ref.alive and h.ref.ko_t > 0 and not h.ref.ko_looted
		"clean":
			return e.mop
	return true

static func finish_hold(w: World, e: Ent, h: Hold) -> void:
	var human := e == w.human
	match h.type:
		"strip_ko":
			var v: Ent = h.ref
			var o := v.outfit.clone()
			Sim.swap_outfit(w, e, o)
			v.outfit = Outfit.new_under(o)
			v.ko_by = e.outfit.id
			v.ko_t = maxf(v.ko_t, 8.0)
			on_change(w, e)
			if human:
				Sim.wlog(w, "Llevas su ropa (limpia). Cuando despierte, avisará de lo que le ha pasado.")
		"loot":
			var v2: Ent = h.ref
			v2.ko_looted = true
			v2.ko_by = e.outfit.id if v2.ko_by == "" else v2.ko_by
			var cash := Rng.ri(2, 6) * 10
			e.money += cash
			Sim.ev(w, "cash", e.fl, e.x, e.y)
			if human:
				Sim.wlog(w, "Le vacías los bolsillos: +$" + str(cash) + ".")
		"clean":
			var p: Dictionary = h.ref
			_clean_spot(w, e.fl, float(p["x"]), float(p["y"]), float(p.get("r", 8.0)))
			if human:
				Sim.wlog(w, "Sangre fregada. Ni rastro.")

## Puñetazo de un jugador: el civil queda inconsciente más tiempo y sabe quién fue.
static func on_punch(w: World, e: Ent, v: Ent) -> void:
	if v.role == "civil" and (e.role == "hunter" or e.role == "runner"):
		v.ko_t = maxf(v.ko_t, KO_CIVIL)
		v.ko_by = e.outfit.id

# ---------------------------------------------------------------- puntuación

## Tabla de puntos de un jugador: [[concepto, puntos], ...]
static func score(w: World, p: Ent) -> Array:
	var out: Array = []
	var win: String = w.over.get("winner", "")
	var side := "hunters" if p.role == "hunter" else "runners"
	out.append(["Victoria del equipo" if win == side else "Derrota del equipo", 500 if win == side else 0])
	if p.role == "runner":
		if p.escaped:
			out.append(["Has escapado del hotel", 300])
		elif not p.alive:
			out.append(["No has salido con vida", -300])
		var mine := 0
		for t in p.tasks:
			if t.done:
				mine += 1
		out.append(["Encargos hechos (" + str(mine) + ")", mine * 25])
	else:
		var tk := 0
		for c in w.corpses:
			if c.killer_id == p.id and c.victim_id in w.targets:
				tk += 1
		out.append(["Objetivos eliminados (" + str(tk) + ")", tk * 250])
		out.append(["Sigues con vida" if p.alive else "Has caído", 200 if p.alive else -200])
	if w.time >= w.limit:
		out.append(["Se acabó el tiempo", -150])
	out.append(["Sospecha a cero" if p.sus <= 0.5 else "Sospecha al final (" + str(int(p.sus)) + ")", 100 if p.sus <= 0.5 else -int(p.sus)])
	out.append(["Sin pánico en el hotel" if w.panic < 1.0 else "Pánico al final (" + str(int(w.panic)) + ")", 100 if w.panic < 1.0 else -int(w.panic)])
	out.append(["Sin alarma en el hotel" if w.alarm == 0 else "Nivel de alarma " + str(w.alarm), 100 if w.alarm == 0 else -100 * w.alarm])
	var inn := 0
	for c in w.corpses:
		if c.killer_id == p.id and c.role == "civil":
			inn += 1
	out.append(["Ningún inocente muerto" if inn == 0 else "Inocentes muertos (" + str(inn) + ")", 100 if inn == 0 else -150 * inn])
	out.append(["Ropa limpia" if not p.outfit.blood else "Ropa manchada de sangre", 50 if not p.outfit.blood else -100])
	var burnt: bool = w.sus_outfits.has(p.outfit.id) or w.wanted.has(p.outfit.id)
	out.append(["Traje sin sospechas" if not burnt else "Traje fichado o quemado", 50 if not burnt else -100])
	return out

static func total(rows: Array) -> int:
	var s := 0
	for r in rows:
		s += int(r[1])
	return s
