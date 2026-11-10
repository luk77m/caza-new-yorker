## Dibuja la planta que ve el jugador: casillas, muebles, personajes, niebla y luz.
class_name WorldView
extends Node2D

var w: World
var view_ent: Ent
var role := "runner"      # rol de quien mira: runner, hunter o spectator
var anim := 0.0
var sight := Cfg.SIGHT_PX
var cam_rect := Rect2(0, 0, 1408, 960)

func _process(delta: float) -> void:
	anim += delta
	queue_redraw()

func see_all() -> bool:
	return role == "spectator"

func can_see(f: FloorData, x: float, y: float, fl: int) -> bool:
	if view_ent == null or fl != view_ent.fl:
		return false
	if see_all():
		return true
	return Sim.dist(x, y, view_ent.x, view_ent.y) <= sight and Nav.los(f, view_ent.x, view_ent.y, x, y)

func _draw() -> void:
	if w == null or view_ent == null:
		return
	var TS := Cfg.TS
	var f: FloorData = Hotel.floors[view_ent.fl]
	var bo := w.sab_blackout > w.time
	var alarm := w.sab_alarm > w.time
	sight = Cfg.SIGHT_PX * (Cfg.BLACKOUT_SIGHT if bo else 1.0)
	var x0 := floori(cam_rect.position.x / TS) - 1
	var y0 := floori(cam_rect.position.y / TS) - 1
	var x1 := ceili(cam_rect.end.x / TS) + 1
	var y1 := ceili(cam_rect.end.y / TS) + 1
	draw_rect(cam_rect.grow(64), Color("#0b1a2a") if f.sky else Color("#05080b"))
	Painter.draw_floor(self, f, x0, y0, x1, y1)
	# muebles bajos (alfombras) y luego el resto
	for o in f.furn:
		if o["k"] == "rug":
			Painter.draw_furn(self, o)
	for o in f.furn:
		if o["k"] != "rug":
			Painter.draw_furn(self, o)
	_draw_plates(f)
	for p in w.picks:
		if p.fl == view_ent.fl and can_see(f, (p.x + 0.5) * TS, (p.y + 0.5) * TS, p.fl):
			Painter.draw_pick(self, p, anim)
	for c in w.corpses:
		if can_see(f, c.x, c.y, c.fl):
			Painter.draw_corpse(self, c)
	_draw_task_marks(f)
	# personajes ordenados por y
	var list: Array = []
	for e in w.ents:
		if e.alive and e.fl == view_ent.fl and (e == view_ent or can_see(f, e.x, e.y, e.fl)):
			list.append(e)
	list.sort_custom(func(a, b): return a.y < b.y)
	var names: Array = []
	for e in list:
		Painter.draw_actor(self, e.x, e.y, e.outfit, e.dir, e.walk, e.aim, atan2(e.aim_y - e.y, e.aim_x - e.x) if e.aim else 0.0)
		if e.fx_swing > 0:
			var a := atan2(e.aim_y - e.y, e.aim_x - e.x)
			draw_arc(Vector2(e.x, e.y - 6), 20, a - 0.9, a + 0.9, 10, Color(1, 1, 1, 0.7), 3)
		if e.role == "police" and e.spotting:
			Painter.text(self, e.x, e.y - 40, "!", 16, Color("#ff4a4a"))
		if e.hold != null and e == view_ent:
			var pr: float = e.hold.t / e.hold.dur
			draw_arc(Vector2(e.x, e.y - 42), 8, 0, TAU, 20, Color(0, 0, 0, 0.5), 4)
			draw_arc(Vector2(e.x, e.y - 42), 8, -PI / 2, -PI / 2 + TAU * pr, 20, Painter.GOLD, 3)
		if e != view_ent and (e.role == "runner" or e.role == "hunter") and (see_all() or e.role == role):
			names.append([e.x, e.y - 30, e.nm, Painter.BLUE if e.role == "runner" else Color("#ff9a9a")])
		if e.arrest > 0:
			names.append([e.x, e.y - 42, "DETENIDO", Painter.RED])
	for fx in w.fx:
		if fx["fl"] == view_ent.fl and fx["type"] == "flash":
			draw_circle(Vector2(fx["x"], fx["y"] - 6), 14.0 * fx["t"] / 0.25, Color(1, 0.9, 0.63, 0.8))
	# luz ambiente
	var amb := 0.62 if bo else clampf(f.dark * 0.6, 0.04, 0.32)
	draw_rect(cam_rect.grow(64), Color(0.015, 0.02, 0.05, amb))
	if not bo:
		for l in f.lamps:
			var lp := Vector2(l["x"], l["y"])
			if cam_rect.grow(l["r"]).has_point(lp):
				var tint := Color(0.55, 0.75, 1.0, 0.035) if l["tint"] == "cold" else Color(1.0, 0.82, 0.5, 0.045)
				draw_circle(lp, l["r"] * 0.55, tint)
				draw_circle(lp, l["r"] * 0.3, tint)
	# niebla de visión
	if not see_all():
		_draw_fog(f)
	for n in names:
		Painter.text(self, n[0], n[1], n[2], 10, n[3])
	for e in list:
		if e.bubble != "" and (e == view_ent or can_see(f, e.x, e.y, e.fl)):
			Painter.draw_bubble(self, e.x, e.y, e.bubble)
	if alarm:
		draw_rect(cam_rect.grow(64), Color(0.82, 0.12, 0.17, 0.05 + 0.07 * (0.5 + 0.5 * sin(anim * 7.0))))
	# mira del cazador
	if view_ent == w.human and view_ent.aim:
		var m := get_global_mouse_position()
		draw_arc(m, 11, 0, TAU, 24, Color(0.94, 0.92, 0.86, 0.9), 1.5)
		draw_line(m - Vector2(17, 0), m - Vector2(6, 0), Color(0.94, 0.92, 0.86, 0.9), 1.5)
		draw_line(m + Vector2(6, 0), m + Vector2(17, 0), Color(0.94, 0.92, 0.86, 0.9), 1.5)
		draw_line(m - Vector2(0, 17), m - Vector2(0, 6), Color(0.94, 0.92, 0.86, 0.9), 1.5)
		draw_line(m + Vector2(0, 6), m + Vector2(0, 17), Color(0.94, 0.92, 0.86, 0.9), 1.5)

func _draw_fog(f: FloorData) -> void:
	var o := Vector2(view_ent.x, view_ent.y)
	var n := 140
	var far := 4000.0
	var fog := Color(0.012, 0.02, 0.035, 0.93)
	var pts: Array = []
	var dirs: Array = []
	for i in n:
		var a := TAU * i / n
		var d := Nav.ray_dist(f, o.x, o.y, a, sight)
		var dv := Vector2(cos(a), sin(a))
		dirs.append(dv)
		pts.append(o + dv * d)
	for i in n:
		var j := (i + 1) % n
		var quad := PackedVector2Array([pts[i], pts[j], o + dirs[j] * far, o + dirs[i] * far])
		draw_colored_polygon(quad, fog)

func _draw_plates(f: FloorData) -> void:
	var TS := Cfg.TS
	var me := view_ent
	for rm in f.rooms:
		if not rm.has_door or rm.zone != Cfg.ZONE_ROOM:
			continue
		var cx: float = (rm.door.x + 0.5) * TS
		var cy: float = rm.door.y * TS + 14.0
		var own: bool = me.role == "runner" and me.room == rm.nm and me.room_floor == rm.fi
		draw_rect(Rect2(cx - 15, cy - 9, 30, 12), Color("#c9a24b"))
		draw_rect(Rect2(cx - 14, cy - 8, 28, 10), Color("#e3c47a"))
		if own:
			draw_rect(Rect2(cx - 17, cy - 11, 34, 16), Color("#5aa8ff"), false, 2.0)
		Painter.text(self, cx, cy, rm.number(), 8, Color("#2a1e0a"), 0)
		if me.role != "spectator" and w.human != null:
			var open := Sim.can_pass(w, me, rm)
			var lc := Color("#6fd08a") if open else Color("#ff5a64")
			draw_rect(Rect2(cx + 17, cy - 6, 6, 5), lc)
			draw_arc(Vector2(cx + 20, cy - 6), 2.2, PI, TAU, 8, lc, 1.2)

func _draw_task_marks(f: FloorData) -> void:
	if w.human == null or w.human.role != "runner" or view_ent != w.human:
		return
	var TS := Cfg.TS
	for t in w.human.tasks:
		if t.fl != view_ent.fl or t.done or not Sim.task_avail(w, t, w.human):
			continue
		var x: float = (t.x + 0.5) * TS
		var y: float = (t.y + 0.5) * TS
		var bob := sin(anim * 4.0) * 2.5
		draw_arc(Vector2(x, y), 13 + sin(anim * 3.0) * 2, 0, TAU, 20, Color(0.92, 0.82, 0.54, 0.75), 2)
		Painter.poly(self, [Vector2(x, y - 39 + bob), Vector2(x + 7, y - 30 + bob), Vector2(x, y - 21 + bob), Vector2(x - 7, y - 30 + bob)], Painter.GOLD)
