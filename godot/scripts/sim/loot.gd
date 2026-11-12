## v0.13 «Botín»: los objetos ya no están tirados por el suelo; se registran muebles y cadáveres.
## Cada objeto sigue siendo un Items.Pick, pero con «box» = dónde está guardado:
##   "f:planta:x:y" un mueble · "c:id" un cadáver · "" suelto en el suelo.
## También reparte las habilidades especiales de los corredores.
class_name Loot
extends RefCounted

const TS := Cfg.TS
const BOXES := ["night", "desk", "crate", "shelf", "safe", "cart", "sofa", "mail", "table", "bench", "bar", "piano"]
const BOX_NAMES := {"night": "la mesilla", "desk": "el escritorio", "crate": "la caja", "shelf": "la estantería", "safe": "la caja fuerte",
	"cart": "el carrito", "sofa": "debajo del sofá", "mail": "los casilleros", "table": "debajo de la mesa", "bench": "debajo del banco",
	"bar": "detrás de la barra", "piano": "dentro del piano"}
const MOVE := ["scrap", "cash", "cutter", "lockpick", "mop", "masterkey", "badge"]
const REACH := 30.0             # px hasta el mueble para registrarlo
const CLEAN_AFTER := 90.0       # s hasta que las limpiadoras retiran lo que dejas en una habitación ajena
const MAX_PICKS := 3
const RPERKS := ["atleta", "cerrajero", "camaleon", "pugil"]
const RPERK_NAMES := {"atleta": "Piernas ligeras", "cerrajero": "Dedos de seda", "camaleon": "Cara de póquer", "pugil": "Derecha de hierro"}
const RPERK_DESC := {
	"atleta": "corres un 15 % más rápido.",
	"cerrajero": "empiezas con dos ganzúas de más y te aguantan el doble.",
	"camaleon": "la sospecha te sube un 40 % más despacio.",
	"pugil": "tus puñetazos dejan KO el doble de tiempo.",
}

static var _acc := 0.0

static func box_key(fl: int, o: Dictionary) -> String:
	return "f:" + str(fl) + ":" + str(int(o["x"])) + ":" + str(int(o["y"]))

## Casilla libre pegada a un mueble (para los bots y para colocar lo que se guarda).
static func _stand(f: FloorData, o: Dictionary) -> Vector2i:
	var x0 := int(o["x"])
	var y0 := int(o["y"])
	var x1 := x0 + int(o["w"])
	var y1 := y0 + int(o["h"])
	for ty in range(y1, y0 - 2, -1):
		for tx in range(x0 - 1, x1 + 1):
			if tx >= x0 and tx < x1 and ty >= y0 and ty < y1:
				continue
			if Sim.free_at(f, (tx + 0.5) * TS, (ty + 0.5) * TS):
				return Vector2i(tx, ty)
	return Vector2i(-1, -1)

static func _furn_of(key: String) -> Dictionary:
	var parts := key.split(":")
	if parts.size() != 4 or parts[0] != "f":
		return {}
	var f := Sim.fdat(int(parts[1]))
	for o in f.furn:
		if int(o["x"]) == int(parts[2]) and int(o["y"]) == int(parts[3]) and o["k"] in BOXES:
			return o
	return {}

## Al empezar: lo que antes estaba tirado por el hotel pasa al mueble más cercano. Además, algo de calderilla en las mesillas.
static func setup(w: World) -> void:
	_acc = 0.0
	if w.tutorial:
		return
	for pv in w.picks:
		var p: Items.Pick = pv
		if p.box != "" or not (p.kind in MOVE) or p.job_owner != 0:
			continue
		var f := Sim.fdat(p.fl)
		var best := {}
		var best_st := Vector2i(-1, -1)
		var bd := 1e9
		for o in f.furn:
			if not (o["k"] in BOXES):
				continue
			var ox: float = float(o["x"]) + float(o["w"]) / 2.0 - p.x - 0.5
			var oy: float = float(o["y"]) + float(o["h"]) / 2.0 - p.y - 0.5
			var d: float = sqrt(ox * ox + oy * oy) + Rng.rnd() * 4.0
			if d < bd:
				var st := _stand(f, o)
				if st.x >= 0:
					bd = d
					best = o
					best_st = st
		if best.is_empty():
			continue
		p.box = box_key(p.fl, best)
		p.x = best_st.x
		p.y = best_st.y
	var pid := 2000
	for fi in [3, 4]:
		var f2 := Sim.fdat(fi)
		var nights: Array = f2.furn.filter(func(o): return o["k"] == "night" or o["k"] == "desk")
		nights = Rng.shuffle(nights)
		for i in mini(3, nights.size()):
			var st2 := _stand(f2, nights[i])
			if st2.x < 0:
				continue
			pid += 1
			var cp := Sim._mk_pick(pid, "cash", Vector3i(fi, st2.x, st2.y), "billetes sueltos")
			cp.value = Rng.ri(1, 3) * 10
			cp.box = box_key(fi, nights[i])
			w.picks.append(cp)

## Habilidad especial al azar para uno o dos corredores.
static func give_perks(w: World, runners: Array) -> void:
	var list: Array = Rng.shuffle(runners.duplicate())
	var n := 1 + (1 if (list.size() > 2 and Rng.rnd() < 0.6) else 0)
	for i in mini(n, list.size()):
		var r: Ent = list[i]
		r.rperk = Rng.pick(RPERKS)
		if r.rperk == "cerrajero":
			r.picks_n += 2
			r.lockpick = true

static func perk_text(e: Ent) -> String:
	if e.rperk == "":
		return ""
	return str(RPERK_NAMES[e.rperk]) + ": " + str(RPERK_DESC[e.rperk])

# ---------------------------------------------------------------- registrar

## Mueble o cadáver que el jugador tiene a mano: {key, title, x, y} o {}.
static func nearest(w: World, e: Ent) -> Dictionary:
	if e == null or not e.alive or e.hidden or e.cuffed or e.fl < 0 or e.ko_t > 0 or e.dragging != null:
		return {}
	var best := {}
	var bd := 1e9
	for c in w.corpses:
		if c.fl != e.fl or c.hidden or c.chalk:
			continue
		var dc := Sim.dist(e.x, e.y, c.x, c.y)
		if dc < 38.0 and dc < bd:
			bd = dc
			best = {"key": "c:" + str(c.id), "title": "el cadáver de " + c.nm, "x": c.x, "y": c.y}
	var f := Sim.fdat(e.fl)
	for o in f.furn:
		if not (o["k"] in BOXES):
			continue
		var cx := clampf(e.x, float(o["x"]) * TS, (float(o["x"]) + float(o["w"])) * TS)
		var cy := clampf(e.y, float(o["y"]) * TS, (float(o["y"]) + float(o["h"])) * TS)
		var d := Sim.dist(e.x, e.y, cx, cy)
		if d < REACH and d < bd:
			bd = d
			best = {"key": box_key(e.fl, o), "title": str(BOX_NAMES[o["k"]]), "x": (float(o["x"]) + float(o["w"]) / 2.0) * TS, "y": (float(o["y"]) + float(o["h"]) / 2.0) * TS}
	return best

static func contents(w: World, key: String) -> Array:
	return w.picks.filter(func(p): return p.box == key)

static func pick_label(p: Items.Pick) -> String:
	match p.kind:
		"cash":
			return "Dinero: $" + str(p.value)
		"lockpick":
			return "Ganzúa"
		"mop":
			return "Fregona"
		"cutter":
			return "Cizalla"
		"masterkey":
			return "Llave maestra"
		"badge":
			return "Insignia de botones"
		"cuffkey":
			return "Llave de esposas"
	return p.nm.substr(0, 1).to_upper() + p.nm.substr(1)

## Lo que el jugador puede dejar guardado: [{kind, label}]
static func carried(e: Ent) -> Array:
	var out: Array = []
	if e.picks_n > 0:
		out.append({"kind": "lockpick", "label": "Ganzúa (tienes " + str(e.picks_n) + ")"})
	if e.mop:
		out.append({"kind": "mop", "label": "Fregona"})
	if e.cutter:
		out.append({"kind": "cutter", "label": "Cizalla"})
	if e.masterkey and e.perk != "master":
		out.append({"kind": "masterkey", "label": "Llave maestra"})
	if e.badge:
		out.append({"kind": "badge", "label": "Insignia de botones"})
	if e.cuffkey:
		out.append({"kind": "cuffkey", "label": "Llave de esposas"})
	if e.scrap > 0:
		out.append({"kind": "scrap", "label": "Chatarra (tienes " + str(e.scrap) + ")"})
	if e.money >= 20:
		out.append({"kind": "cash", "label": "Dinero: $20 (tienes $" + str(e.money) + ")"})
	return out

## Coger un objeto de un mueble o un cadáver. Devuelve "" o por qué no se puede.
static func take(w: World, e: Ent, p: Items.Pick) -> String:
	if not (p in w.picks):
		return "Ya no está."
	if not Sim.can_take(e, p):
		return "Eso no te sirve o ya llevas uno."
	w.picks.erase(p)
	p.box = ""
	Sim.grant(w, e, p)
	w.flags["looted"] = true
	return ""

static func _put(w: World, key: String, fl: int, tx: int, ty: int, kind: String, nm: String, value: int, by: int) -> void:
	var p := Items.Pick.new()
	p.id = w.next_id
	w.next_id += 1
	p.kind = kind
	p.nm = nm
	p.value = value
	p.fl = fl
	p.x = tx
	p.y = ty
	p.box = key
	p.by = by
	p.t = w.time
	w.picks.append(p)

## Dejar algo tuyo en un mueble o un cadáver.
static func store(w: World, e: Ent, key: String, kind: String) -> bool:
	var fl := e.fl
	var tile := e.tile()
	if key.begins_with("f:"):
		var o := _furn_of(key)
		if o.is_empty():
			return false
		var st := _stand(Sim.fdat(fl), o)
		if st.x >= 0:
			tile = st
	var nm := kind
	var value := 0
	match kind:
		"lockpick":
			if e.picks_n <= 0:
				return false
			e.picks_n -= 1
			e.lockpick = e.picks_n > 0
			nm = "ganzúa"
		"mop":
			if not e.mop:
				return false
			e.mop = false
			nm = "fregona"
		"cutter":
			if not e.cutter:
				return false
			e.cutter = false
			nm = "cizalla"
		"masterkey":
			if not e.masterkey:
				return false
			e.masterkey = false
			nm = "llave maestra"
		"badge":
			if not e.badge:
				return false
			e.badge = false
			nm = "insignia de botones"
		"cuffkey":
			if not e.cuffkey:
				return false
			e.cuffkey = false
			nm = "llave de esposas"
		"scrap":
			if e.scrap <= 0:
				return false
			e.scrap -= 1
			nm = "pieza de chatarra"
		"cash":
			if e.money < 20:
				return false
			e.money -= 20
			value = 20
			nm = "billetes"
		_:
			return false
	if not (e.equip in Sim.equip_list(e)):
		e.equip = "fist"
	_put(w, key, fl, tile.x, tile.y, kind, nm, value, e.id)
	Sim.ev(w, "pick", e.fl, e.x, e.y)
	return true

## Lo que llevaba encima quien muere se queda en el cadáver.
static func on_kill(w: World, v: Ent, c: Items.Corpse) -> void:
	if w.tutorial:
		return
	var key := "c:" + str(c.id)
	var tx := floori(c.x / TS)
	var ty := floori(c.y / TS)
	if v.role == "civil":
		if Rng.rnd() < 0.6:
			_put(w, key, c.fl, tx, ty, "cash", "cartera", Rng.ri(1, 4) * 10, 0)
		return
	if v.role != "hunter" and v.role != "runner":
		return
	for i in mini(v.picks_n, 2):
		_put(w, key, c.fl, tx, ty, "lockpick", "ganzúa", 0, 0)
	if v.mop:
		_put(w, key, c.fl, tx, ty, "mop", "fregona", 0, 0)
	if v.cutter:
		_put(w, key, c.fl, tx, ty, "cutter", "cizalla", 0, 0)
	if v.masterkey:
		_put(w, key, c.fl, tx, ty, "masterkey", "llave maestra", 0, 0)
	if v.badge:
		_put(w, key, c.fl, tx, ty, "badge", "insignia de botones", 0, 0)
	for i in mini(v.scrap, 3):
		_put(w, key, c.fl, tx, ty, "scrap", "pieza de chatarra", 0, 0)
	if v.money >= 20:
		_put(w, key, c.fl, tx, ty, "cash", "cartera", int(v.money / 20) * 10, 0)

## Una vez por segundo: se pierde lo que había en un cadáver que ya se han llevado, y las
## limpiadoras retiran lo que un jugador dejó en una habitación que no es la suya.
static func update(w: World, dt: float) -> void:
	_acc += dt
	if _acc < 1.0:
		return
	_acc = 0.0
	var bodies := {}
	for c in w.corpses:
		if not c.chalk:
			bodies["c:" + str(c.id)] = true
	var keep: Array = []
	for pv in w.picks:
		var p: Items.Pick = pv
		if p.box.begins_with("c:") and not bodies.has(p.box):
			continue
		if p.by != 0 and p.box.begins_with("f:") and w.time - p.t > CLEAN_AFTER:
			var rm := Sim.fdat(p.fl).room_at(p.x, p.y)
			var owner := w.ent_by_id(p.by)
			var own: bool = owner != null and rm != null and owner.room == rm.nm and owner.room_floor == p.fl
			if rm != null and rm.zone == Cfg.ZONE_ROOM and not own:
				if owner != null and owner == w.human:
					Sim.wlog(w, "Las limpiadoras han pasado por la " + rm.label() + " y se han llevado lo que dejaste (" + pick_label(p).to_lower() + ").", "report")
				continue
		keep.append(p)
	if keep.size() != w.picks.size():
		w.picks = keep
