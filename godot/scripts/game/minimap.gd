## Plano de una planta: minimapa del HUD y mapa grande de la tecla Tab.
class_name Minimap
extends Control

var w: World
var fl := 1
var view_ent: Ent
var role := "runner"
var labels := false

func _process(_d: float) -> void:
	if is_visible_in_tree():
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#070b10"))
	if w == null:
		return
	var f: FloorData = Hotel.floors[fl]
	var s := minf(size.x / Cfg.W, size.y / Cfg.H)
	var off := Vector2((size.x - s * Cfg.W) / 2.0, (size.y - s * Cfg.H) / 2.0)
	for ty in Cfg.H:
		for tx in Cfg.W:
			var t := f.at(tx, ty)
			if t == Cfg.T_VOID:
				continue
			draw_rect(Rect2(off + Vector2(tx * s, ty * s), Vector2(s + 0.3, s + 0.3)), Painter.map_color(t))
	if labels:
		var font := Painter.font()
		var fs := maxi(8, int(s * 0.7))
		for r in f.rooms:
			if r.w < 5:
				continue
			var nm: String = r.nm.replace("Núcleo de ascensores", "Ascensores").to_upper()
			var c := off + Vector2((r.x + r.w / 2.0) * s, (r.y + r.h / 2.0) * s)
			var tw := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, c + Vector2(-tw / 2 + 1, fs * 0.4 + 1), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.6))
			draw_string(font, c + Vector2(-tw / 2, fs * 0.4), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.96, 0.93, 0.86, 0.92))
	for p in w.picks:
		if p.fl == fl:
			draw_rect(Rect2(off + Vector2((p.x + 0.2) * s, (p.y + 0.2) * s), Vector2(s * 0.6, s * 0.6)), Painter.GOLD)
	var me := view_ent
	if me != null and me.role == "runner" and me == w.human:
		for t in me.tasks:
			if t.fl == fl and not t.done:
				var c := off + Vector2((t.x + 0.5) * s, (t.y + 0.5) * s)
				var k := maxf(2.5, s * 0.6)
				var col := Painter.GOLD if Sim.task_avail(w, t, me) else Color(0.92, 0.82, 0.54, 0.35)
				Painter.poly(self, [c + Vector2(0, -k), c + Vector2(k, 0), c + Vector2(0, k), c + Vector2(-k, 0)], col)
	for e in w.ents:
		if not e.alive or e.fl != fl:
			continue
		var c := off + Vector2(e.x / Cfg.TS * s, e.y / Cfg.TS * s)
		if e == me:
			draw_rect(Rect2(c - Vector2(3, 3), Vector2(6, 6)), Color.WHITE)
			draw_rect(Rect2(c - Vector2(3, 3), Vector2(6, 6)), Color.BLACK, false, 1.0)
		elif role == "spectator":
			var col := Color("#ff6a6a") if e.role == "hunter" else (Painter.BLUE if e.role == "runner" else (Color("#8aa8ff") if e.role == "police" else Color(0.7, 0.7, 0.7, 0.5)))
			draw_circle(c, 2.2, col)
		elif me != null and e.role == me.role and (e.role == "runner" or e.role == "hunter"):
			draw_circle(c, 2.6, Color("#5aa8ff") if e.role == "runner" else Color("#ff9a9a"))
	var hm := w.human
	if hm != null and hm.job != null and hm.job.fl == fl:
		var jc := off + Vector2((hm.job.x + 0.5) * s, (hm.job.y + 0.5) * s)
		draw_arc(jc, 4.0, 0, TAU, 12, Color("#7ee08a"), 2.0)
	if hm != null and w.alarm >= 3 and hm.role == "runner":
		for x in w.exits:
			if int(x["fl"]) == fl:
				var xc := off + Vector2((x["x"] + 0.5) * s, (x["y"] + 0.5) * s)
				draw_rect(Rect2(xc - Vector2(4, 4), Vector2(8, 8)), Color("#7ee08a"), false, 2.0)
	if hm != null and hm.alive and hm.intel_until > w.time:
		for e in w.ents:
			if not e.alive or e.fl != fl:
				continue
			var show: bool = (hm.role == "runner" and e.role == "hunter") or (hm.role == "hunter" and (e.id in w.targets or (hm.intel_kind == "runners" and e.role == "runner")))
			if show:
				var c := off + Vector2(e.x / Cfg.TS * s, e.y / Cfg.TS * s)
				draw_arc(c, 5.0, 0, TAU, 16, Color("#ff5a64"), 2.0)
	for c in w.corpses:
		if c.fl == fl and (role == "spectator" or c.found):
			draw_rect(Rect2(off + Vector2(c.x / Cfg.TS * s - 2, c.y / Cfg.TS * s - 2), Vector2(4, 4)), Color("#c0392b"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("#2a3a4a"), false, 1.0)
