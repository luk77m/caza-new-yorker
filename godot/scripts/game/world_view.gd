## Dibuja la planta que ve el jugador en tres capas:
##  base: casillas, muebles, personajes, efectos y oscuridad ambiente
##  glow: luces de lámparas y fogonazos (mezcla aditiva)
##  top:  niebla de visión, nombres, bocadillos, flechas y mira
class_name WorldView
extends Node2D

var w: World
var view_ent: Ent
var role := "runner"      # rol de quien mira: runner, hunter o spectator
var anim := 0.0
var sight := Cfg.SIGHT_PX
var cam_rect := Rect2(0, 0, 1408, 960)
var zoom := 2.0
var base: Node2D
var glow: Node2D
var top: Node2D
var light_tex: GradientTexture2D
var tut_target := Vector3(-1, 0, 0)
var _poly_key := ""
var _poly := PackedVector2Array()

func _ready() -> void:
	base = Node2D.new()
	glow = Node2D.new()
	top = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	add_child(base)
	add_child(glow)
	add_child(top)
	base.draw.connect(_draw_base)
	glow.draw.connect(_draw_glow)
	top.draw.connect(_draw_top)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.35))
	light_tex = GradientTexture2D.new()
	light_tex.gradient = g
	light_tex.fill = GradientTexture2D.FILL_RADIAL
	light_tex.fill_from = Vector2(0.5, 0.5)
	light_tex.fill_to = Vector2(1.0, 0.5)
	light_tex.width = 128
	light_tex.height = 128

func _process(delta: float) -> void:
	anim += delta
	base.queue_redraw()
	glow.queue_redraw()
	top.queue_redraw()

func see_all() -> bool:
	return role == "spectator"

func can_see(f: FloorData, x: float, y: float, fl: int) -> bool:
	if view_ent == null or fl != view_ent.fl:
		return false
	if see_all():
		return true
	return Sim.dist(x, y, view_ent.x, view_ent.y) <= sight and Nav.los(f, view_ent.x, view_ent.y, x, y)

func _ready_to_draw() -> bool:
	return w != null and view_ent != null

func _visible_ents(f: FloorData) -> Array:
	var list: Array = []
	for e in w.ents:
		if e.alive and not e.hidden and e.fl == view_ent.fl and (e == view_ent or can_see(f, e.x, e.y, e.fl)):
			list.append(e)
	list.sort_custom(func(a, b): return a.y < b.y)
	return list

# ---------------------------------------------------------------- capa base

func _draw_base() -> void:
	if not _ready_to_draw():
		return
	var ci := base
	var TS := Cfg.TS
	var f: FloorData = Hotel.floors[view_ent.fl]
	var bo := w.sab_blackout > w.time
	sight = Cfg.SIGHT_PX * (Cfg.BLACKOUT_SIGHT if bo else 1.0)
	var x0 := floori(cam_rect.position.x / TS) - 1
	var y0 := floori(cam_rect.position.y / TS) - 1
	var x1 := ceili(cam_rect.end.x / TS) + 1
	var y1 := ceili(cam_rect.end.y / TS) + 1
	if f.roof:
		Painter.draw_city(ci, cam_rect.grow(64), anim)
	else:
		ci.draw_rect(cam_rect.grow(64), Color("#0b1a2a") if f.sky else Color("#05080b"))
	if f.sky and not f.roof:
		# estrellas del cielo de Manhattan
		for i in 60:
			var sx := fmod(i * 97.13, 1408.0)
			var sy := fmod(i * 53.71, 960.0)
			var tw := 0.4 + 0.4 * sin(anim * 1.5 + i)
			ci.draw_rect(Rect2(sx, sy, 2, 2), Color(1, 1, 0.9, tw * 0.6))
	if f.fi == 1:
		Painter.draw_street(ci, w, anim)
	Painter.draw_floor(ci, f, x0, y0, x1, y1)
	for o in f.furn:
		if o["k"] == "rug":
			Painter.draw_furn(ci, o)
	for o in f.furn:
		if o["k"] == "sign" and f.roof:
			Painter.draw_sign(ci, o["x"] * TS, o["y"] * TS - 12, o["w"] * TS, anim)
		elif o["k"] != "rug":
			Painter.draw_furn(ci, o)
	_draw_plates(ci, f)
	# placas de latón con el nombre de las salas
	for rm in f.rooms:
		if rm.zone == Cfg.ZONE_ROOM or rm.w < 5 or rm.nm == "Núcleo de ascensores" or rm.nm == "Azotea" or rm.nm == "Vestíbulo":
			continue
		var nm: String = rm.nm.to_upper()
		var cx: float = (rm.x + rm.w / 2.0) * Cfg.TS
		var cy: float = (rm.y + 1) * Cfg.TS + 12
		var tw := Painter.font().get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		ci.draw_rect(Rect2(cx - tw / 2 - 6, cy - 10, tw + 12, 14), Color("#8f7330"))
		ci.draw_rect(Rect2(cx - tw / 2 - 5, cy - 9, tw + 10, 12), Color("#d9b862"))
		Painter.text(ci, cx, cy, nm, 9, Color("#2a1e0a"), 0)
	for p in w.picks:
		if p.fl == view_ent.fl and can_see(f, (p.x + 0.5) * TS, (p.y + 0.5) * TS, p.fl):
			Painter.draw_pick(ci, p, anim)
	# charcos de sangre, huellas y rastros de arrastre
	for bp in w.pools:
		if int(bp["fl"]) == view_ent.fl and can_see(f, bp["x"], bp["y"], view_ent.fl):
			var grow: float = clampf((w.time - float(bp["t"])) / 4.0, 0.35, 1.0)
			var pr: float = float(bp["r"]) * grow
			Painter.ellipse(ci, bp["x"], bp["y"], pr * 1.35, pr * 0.8, Color(0.38, 0.02, 0.05, 0.78))
			Painter.ellipse(ci, float(bp["x"]) - pr * 0.3, float(bp["y"]) - pr * 0.15, pr * 0.5, pr * 0.25, Color(0.55, 0.05, 0.08, 0.5))
	for ft in w.prints:
		if int(ft["fl"]) != view_ent.fl or not can_see(f, ft["x"], ft["y"], view_ent.fl):
			continue
		var fade: float = clampf(1.0 - (w.time - float(ft["t"])) / Stealth.PRINT_LIFE, 0.0, 1.0)
		var fa: float = ft["a"]
		var fpos := Vector2(ft["x"], ft["y"])
		if ft["drag"]:
			ci.draw_set_transform(fpos, fa, Vector2.ONE)
			ci.draw_rect(Rect2(-10, -4, 20, 8), Color(0.4, 0.03, 0.06, 0.5 * fade))
		else:
			var side: float = 3.5 if int(ft["s"]) == 0 else -3.5
			ci.draw_set_transform(fpos, fa, Vector2.ONE)
			ci.draw_rect(Rect2(-3.5, side - 1.6, 6, 3.2), Color(0.42, 0.03, 0.06, 0.75 * fade))
			ci.draw_rect(Rect2(-6, side - 1.4, 2, 2.8), Color(0.42, 0.03, 0.06, 0.6 * fade))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for c in w.corpses:
		if c.hidden:
			continue
		if can_see(f, c.x, c.y, c.fl):
			if c.chalk:
				Painter.draw_chalk(ci, c)
				continue
			Painter.draw_corpse(ci, c)
	_draw_task_marks(ci, f)
	for e in _visible_ents(f):
		# quien se asoma en primera persona se ve desplazado hacia ese lado
		Painter.draw_actor(ci, e.x + e.lean_x * 0.7, e.y + e.lean_y * 0.7, e.outfit, e.dir, e.walk, e.aim, atan2(e.aim_y - e.y, e.aim_x - e.x) if e.aim else 0.0)
		Painter.draw_extras(ci, e)
		if e.ko_t > 0:
			Painter.draw_ko(ci, e, anim)
		if e.fx_swing > 0:
			var a := atan2(e.aim_y - e.y, e.aim_x - e.x)
			ci.draw_arc(Vector2(e.x, e.y - 6), 20, a - 0.9, a + 0.9, 10, Color(1, 1, 1, 0.7), 3)
		if e.role == "police" and e.spotting:
			Painter.text(ci, e.x, e.y - 40, "!", 16, Color("#ff4a4a"))
		if e.hold != null and e == view_ent:
			var pr: float = e.hold.t / e.hold.dur
			ci.draw_arc(Vector2(e.x, e.y - 42), 8, 0, TAU, 20, Color(0, 0, 0, 0.5), 4)
			ci.draw_arc(Vector2(e.x, e.y - 42), 8, -PI / 2, -PI / 2 + TAU * pr, 20, Painter.GOLD, 3)
	for fx in w.fx:
		if fx["fl"] != view_ent.fl:
			continue
		var fp := Vector2(fx["x"], fx["y"])
		match fx["type"]:
			"flash":
				var big: bool = fx.get("big", false)
				ci.draw_circle(fp + Vector2(0, -6), (24.0 if big else 9.0) * clampf(fx["t"] / 0.15, 0.3, 1.0), Color(1, 0.9, 0.6, 0.85))
			"tracer":
				var loud: bool = fx["loud"]
				ci.draw_line(fp, Vector2(fx["x2"], fx["y2"]), Color(1, 0.88, 0.55, clampf(fx["t"] * 6.0, 0, 0.9)), 2.5 if loud else 1.3)
			"sparks":
				for k in 14:
					var a2 := k * 2.4 + anim * 9.0
					var r2 := fmod(k * 7.3 + anim * 60.0, 26.0)
					var sp := fp + Vector2(cos(a2), sin(a2)) * r2
					ci.draw_line(sp, sp + Vector2(cos(a2), sin(a2) + 0.6) * 5, Color(1, 0.8, 0.3, clampf(fx["t"], 0, 1)), 1.5)
			"spark":
				var age2: float = float(fx["t0"]) - float(fx["t"])
				var sp2 := fp + Vector2(fx["vx"], fx["vy"]) * age2
				ci.draw_line(sp2, sp2 - Vector2(fx["vx"], fx["vy"]) * 0.02, Color(1, 0.85, 0.4, clampf(fx["t"] * 5.0, 0, 1)), 1.5)
			"smoke":
				var k2: float = 1.0 - float(fx["t"]) / float(fx["t0"])
				ci.draw_circle(fp + Vector2(0, -k2 * 10), 4.0 + k2 * 9.0, Color(0.75, 0.75, 0.75, 0.35 * (1.0 - k2)))
			"blood":
				for k in 6:
					var a3 := k * 1.05
					ci.draw_circle(fp + Vector2(cos(a3), sin(a3)) * (10.0 * (1.0 - fx["t"] / 0.6) + 3), 2.4, Color(0.6, 0.04, 0.08, 0.85))
	for b in w.bullets:
		if int(b["fl"]) == view_ent.fl:
			var bp := Vector2(b["x"], b["y"])
			var bv := Vector2(b["vx"], b["vy"]).normalized()
			ci.draw_line(bp - bv * 14, bp, Color(1, 0.9, 0.55, 0.95), 2.0)
	# oscuridad ambiente (las luces de la capa glow la compensan)
	var amb := 0.72 if bo else (0.18 if f.roof else clampf(0.2 + f.dark * 0.7, 0.22, 0.5))
	ci.draw_rect(cam_rect.grow(64), Color(0.012, 0.016, 0.04, amb))

# ---------------------------------------------------------------- capa de luz (aditiva)

func _light(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	ci.draw_texture_rect(light_tex, Rect2(p - Vector2(r, r), Vector2(r * 2, r * 2)), false, col)

func _draw_glow() -> void:
	if not _ready_to_draw():
		return
	var ci := glow
	var f: FloorData = Hotel.floors[view_ent.fl]
	var bo := w.sab_blackout > w.time
	if not bo:
		for l in f.lamps:
			var lp := Vector2(l["x"], l["y"])
			var lr: float = l["r"]
			if not cam_rect.grow(lr).has_point(lp):
				continue
			var flick := 1.0 + 0.03 * sin(anim * 3.0 + lp.x)
			var tint := Color(0.25, 0.32, 0.42) if l["tint"] == "cold" else Color(0.42, 0.33, 0.18)
			_light(ci, lp, lr * 0.85 * flick, tint)
	if f.roof:
		for o in f.furn:
			if o["k"] == "sign":
				_light(ci, Vector2((o["x"] + o["w"] / 2.0) * Cfg.TS, o["y"] * Cfg.TS + 14), 260.0, Color(0.55, 0.08, 0.06))
	if f.fi == 1:
		for lx in [8, 15, 29, 36]:
			_light(ci, Vector2(lx * Cfg.TS, 27.0 * Cfg.TS + 6), 110.0, Color(0.4, 0.32, 0.16))
		for c in w.cars:
			if c["kind"] == "police" and fmod(anim, 0.5) < 0.25:
				_light(ci, Vector2(c["x"], c["y"]), 90.0, Color(0.6, 0.05, 0.05))
	# luz propia (linterna en el apagón)
	_light(ci, Vector2(view_ent.x, view_ent.y - 8), 70.0 if bo else 110.0, Color(0.22, 0.2, 0.16) if bo else Color(0.16, 0.15, 0.12))
	if w.sab_alarm > w.time:
		_light(ci, Vector2(view_ent.x, view_ent.y), 900.0, Color(0.25 * (0.5 + 0.5 * sin(anim * 7.0)), 0.0, 0.02))
	for fx in w.fx:
		if fx["fl"] == view_ent.fl and (fx["type"] == "flash" or fx["type"] == "sparks"):
			if fx["type"] == "flash" and w.sab_blackout > w.time:
				_light(ci, Vector2(fx["x"], fx["y"]), 220.0, Color(1.0, 0.85, 0.5))
			var big: bool = fx.get("big", false)
			_light(ci, Vector2(fx["x"], fx["y"]), 160.0 if big else 70.0, Color(0.9, 0.7, 0.35) * clampf(fx["t"] * 5.0, 0.0, 1.0))

# ---------------------------------------------------------------- capa superior

func _draw_top() -> void:
	if not _ready_to_draw():
		return
	var ci := top
	var f: FloorData = Hotel.floors[view_ent.fl]
	var list := _visible_ents(f)
	if not see_all() and not f.roof:
		_draw_fog(ci, f)
	_draw_marks_top(ci, f)
	for fx in w.fx:
		if fx["fl"] == view_ent.fl and fx["type"] == "flash":
			var big: bool = fx.get("big", false)
			var fp2 := Vector2(fx["x"], fx["y"])
			ci.draw_circle(fp2, (10.0 if big else 6.0), Color(1, 0.95, 0.7, 0.9))
			ci.draw_circle(fp2, (22.0 if big else 14.0), Color(1, 0.8, 0.4, 0.25))
	for e in list:
		if e != view_ent and (e.role == "runner" or e.role == "hunter") and (see_all() or e.role == role):
			Painter.text(ci, e.x, e.y - 30, e.nm, 10, Painter.BLUE if e.role == "runner" else Color("#ff9a9a"))
		if e.arrest > 0:
			Painter.text(ci, e.x, e.y - 42, "DETENIDO", 10, Painter.RED)
	for e in list:
		if e.bubble != "":
			Painter.draw_bubble(ci, e.x, e.y, e.bubble)
	# objeto con el que puedes interactuar
	if view_ent == w.human and view_ent.hidden:
		Painter.text(ci, view_ent.x, view_ent.y - 26, "ESCONDIDO · E para salir", 10, Painter.GOLD)
	elif view_ent == w.human and view_ent.dragging == null and not view_ent.cuffed:
		var dg = Stealth.find_draggable(w, view_ent)
		if dg != null:
			Painter.text(ci, dg.x, dg.y + 26, "F · arrastrar", 9, Painter.GOLD)
	if view_ent == w.human and not w.hint.is_empty() and w.hint.has("x") and view_ent.hold == null:
		var hp := Vector2(w.hint["x"], w.hint["y"])
		ci.draw_arc(hp, 15 + sin(anim * 5.0) * 2, 0, TAU, 24, Color(0.92, 0.82, 0.54, 0.8), 1.5)
	if Settings.arrows:
		_draw_arrows(ci)
	# objetivo del tutorial: anillo y flecha que rebota
	if int(tut_target.x) == view_ent.fl:
		var tp := Vector2(tut_target.y, tut_target.z)
		var bob := sin(anim * 5.0) * 5.0
		ci.draw_arc(tp, 18 + sin(anim * 4.0) * 3, 0, TAU, 28, Color(0.92, 0.82, 0.54, 0.9), 3.0)
		Painter.poly(ci, [tp + Vector2(0, -26 + bob), tp + Vector2(-9, -40 + bob), tp + Vector2(9, -40 + bob)], Painter.GOLD)
	# mira del cazador
	if view_ent == w.human and view_ent.aim:
		var m := ci.get_global_mouse_position()
		var col := Color(0.94, 0.92, 0.86, 0.9) if view_ent.ammo > 0 else Color(1, 0.4, 0.4, 0.9)
		ci.draw_arc(m, 11, 0, TAU, 24, col, 1.5)
		ci.draw_line(m - Vector2(17, 0), m - Vector2(6, 0), col, 1.5)
		ci.draw_line(m + Vector2(6, 0), m + Vector2(17, 0), col, 1.5)
		ci.draw_line(m - Vector2(0, 17), m - Vector2(0, 6), col, 1.5)
		ci.draw_line(m + Vector2(0, 6), m + Vector2(0, 17), col, 1.5)

## Niebla con el polígono de visión exacto (bordes rectos junto a las paredes) y un borde suave
## solo donde se acaba el alcance de la vista.
func _draw_fog(ci: CanvasItem, f: FloorData) -> void:
	var o := Vector2(view_ent.x, view_ent.y)
	var key := str(f.fi) + ":" + str(roundi(o.x * 2)) + ":" + str(roundi(o.y * 2)) + ":" + str(roundi(sight)) + ":" + str(f.door_ver)
	if key != _poly_key:
		_poly_key = key
		_poly = Nav.vis_poly(f, o.x, o.y, sight)
	var n := _poly.size()
	if n < 3:
		return
	var far := 4000.0
	var soft := 40.0
	var full := Color(0.012, 0.02, 0.035, Settings.fog)
	var clear := Color(full.r, full.g, full.b, 0.0)
	for i in n:
		var j := (i + 1) % n
		var pi: Vector2 = _poly[i]
		var pj: Vector2 = _poly[j]
		var di := (pi - o).normalized()
		var dj := (pj - o).normalized()
		var at_edge_i := pi.distance_to(o) >= sight - 1.0
		var at_edge_j := pj.distance_to(o) >= sight - 1.0
		if at_edge_i and at_edge_j:
			ci.draw_polygon(PackedVector2Array([pi, pj, pj + dj * soft, pi + di * soft]), PackedColorArray([clear, clear, full, full]))
			ci.draw_colored_polygon(PackedVector2Array([pi + di * soft, pj + dj * soft, o + dj * far, o + di * far]), full)
		else:
			ci.draw_colored_polygon(PackedVector2Array([pi, pj, o + dj * far, o + di * far]), full)

## Marcas que se ven a través de la niebla: el cazador delatado, la salida y el trabajo extra.
func _draw_marks_top(ci: CanvasItem, f: FloorData) -> void:
	var hm := w.human
	if hm == null or view_ent != hm:
		return
	var pulse := 0.6 + 0.4 * sin(anim * 5.0)
	if hm.hunter_mark != 0 and hm.intel_until > w.time:
		var h := w.ent_by_id(hm.hunter_mark)
		if h != null and h.alive and h.fl == f.fi:
			ci.draw_arc(Vector2(h.x, h.y - 10), 22, 0, TAU, 24, Color(1, 0.25, 0.25, pulse), 2.5)
			Painter.text(ci, h.x, h.y - 48, "CAZADOR", 10, Color(1, 0.4, 0.4))
	if hm.role == "hunter" and hm.intel_kind == "runners" and hm.intel_until > w.time:
		for r in w.ents:
			if r.role == "runner" and r.alive and r.fl == f.fi:
				ci.draw_arc(Vector2(r.x, r.y - 10), 20, 0, TAU, 24, Color(1, 0.3, 0.3, pulse), 2.0)
	if hm.job != null and hm.job.fl == f.fi:
		var jp := Vector2((hm.job.x + 0.5) * Cfg.TS, (hm.job.y + 0.5) * Cfg.TS)
		ci.draw_arc(jp, 14, 0, TAU, 20, Color(0.45, 0.85, 0.5, pulse), 2.0)
		Painter.text(ci, jp.x, jp.y - 22, "$", 14, Color(0.55, 0.95, 0.6))
	if w.alarm >= 3 and hm.role == "runner":
		for x in w.exits:
			if int(x["fl"]) == f.fi:
				var ep := Vector2((x["x"] + 0.5) * Cfg.TS, (x["y"] + 0.5) * Cfg.TS)
				ci.draw_arc(ep, 18, 0, TAU, 24, Color(0.4, 1, 0.5, pulse), 2.5)
				Painter.text(ci, ep.x, ep.y - 26, "SALIDA", 10, Color(0.5, 1, 0.6))

## Flechas en el borde de la pantalla hacia tus encargos de esta planta.
func _draw_arrows(ci: CanvasItem) -> void:
	if w.human == null or view_ent != w.human:
		return
	var m := 30.0 / zoom
	var inner := cam_rect.grow(-m)
	var c := cam_rect.get_center()
	var k := 1.0 / zoom
	var n := 0
	var list: Array = w.human.tasks.duplicate()
	if w.human.job != null:
		list.push_front(w.human.job)
	for t in list:
		if n >= 3:
			break
		if t.fl != view_ent.fl or t.done or not Sim.task_avail(w, t, w.human):
			continue
		var p := Vector2((t.x + 0.5) * Cfg.TS, (t.y + 0.5) * Cfg.TS)
		if inner.has_point(p):
			continue
		var d := p - c
		var s := minf((inner.size.x / 2.0) / maxf(absf(d.x), 0.001), (inner.size.y / 2.0) / maxf(absf(d.y), 0.001))
		var ap := c + d * s
		var ang := d.angle()
		var pts: Array = [Vector2(13, 0), Vector2(-7, -9), Vector2(-3, 0), Vector2(-7, 9)]
		var poly := PackedVector2Array()
		for q in pts:
			poly.append(ap + (q as Vector2).rotated(ang) * k * 1.4)
		ci.draw_colored_polygon(poly, Painter.GOLD)
		var meters := roundi(d.length() / Cfg.TS * 1.2)
		Painter.text(ci, ap.x - cos(ang) * 26 * k, ap.y - sin(ang) * 26 * k + 4 * k, str(meters) + " m", maxi(6, roundi(11 * k)), Color("#efe8d4"), 2)
		n += 1

func _draw_plates(ci: CanvasItem, f: FloorData) -> void:
	var TS := Cfg.TS
	var me := view_ent
	for rm in f.rooms:
		if not rm.has_door or rm.zone != Cfg.ZONE_ROOM:
			continue
		var cx: float = (rm.door.x + 0.5) * TS
		var cy: float = rm.door.y * TS + 14.0
		var own: bool = me.role == "runner" and me.room == rm.nm and me.room_floor == rm.fi
		ci.draw_rect(Rect2(cx - 15, cy - 9, 30, 12), Color("#c9a24b"))
		ci.draw_rect(Rect2(cx - 14, cy - 8, 28, 10), Color("#e3c47a"))
		if own:
			ci.draw_rect(Rect2(cx - 17, cy - 11, 34, 16), Color("#5aa8ff"), false, 2.0)
		Painter.text(ci, cx, cy, rm.number(), 8, Color("#2a1e0a"), 0)
		if me.role != "spectator" and w.human != null:
			var open := Sim.can_pass(w, me, rm)
			var lc := Color("#6fd08a") if open else Color("#ff5a64")
			ci.draw_rect(Rect2(cx + 17, cy - 6, 6, 5), lc)
			ci.draw_arc(Vector2(cx + 20, cy - 6), 2.2, PI, TAU, 8, lc, 1.2)

func _draw_task_marks(ci: CanvasItem, f: FloorData) -> void:
	if w.human == null or w.human.role != "runner" or view_ent != w.human:
		return
	var TS := Cfg.TS
	for t in w.human.tasks:
		if t.fl != view_ent.fl or t.done or not Sim.task_avail(w, t, w.human):
			continue
		var x: float = (t.x + 0.5) * TS
		var y: float = (t.y + 0.5) * TS
		var bob := sin(anim * 4.0) * 2.5
		ci.draw_arc(Vector2(x, y), 13 + sin(anim * 3.0) * 2, 0, TAU, 20, Color(0.92, 0.82, 0.54, 0.75), 2)
		Painter.poly(ci, [Vector2(x, y - 39 + bob), Vector2(x + 7, y - 30 + bob), Vector2(x, y - 21 + bob), Vector2(x - 7, y - 30 + bob)], Painter.GOLD)
