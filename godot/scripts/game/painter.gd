## Dibujo procedural (sin sprites todavía): casillas, muebles, personajes y textos.
## Todas las funciones reciben el CanvasItem en el que dibujar.
class_name Painter
extends RefCounted

const TS := Cfg.TS
const GOLD := Color("#ebd08a")
const GOLD2 := Color("#c9a24b")
const BLUE := Color("#6fb8ff")
const RED := Color("#ff6a78")
const INK := Color(0.01, 0.02, 0.04, 0.9)

static func font() -> Font:
	return ThemeDB.fallback_font

static func tile_color(t: int) -> Color:
	match t:
		1: return Color("#2c3846")
		2: return Color("#8d8572")
		3: return Color("#6e2731")
		14: return Color("#2d6165")
		4: return Color("#4d555d")
		11: return Color("#7a5232")
		5: return Color("#b8923f")
		6: return Color("#c9a24b")
		7, 8: return Color("#3f8e94")
		10: return Color("#4f575f")
		12: return Color("#62736a")
		13: return Color("#a68a45")
	return Color("#05080b")

static func map_color(t: int) -> Color:
	match t:
		1: return Color("#4a5c6e")
		2: return Color("#8d8572")
		3: return Color("#7a2b37")
		14: return Color("#2d6165")
		4: return Color("#58616a")
		11: return Color("#8a5c37")
		5: return Color("#c9a24b")
		6: return Color("#ebd08a")
		7, 8: return Color("#47a0a6")
		10: return Color("#59616a")
		12: return Color("#6f8076")
		13: return Color("#a68a45")
	return Color("#070b10")

static func furn_color(k: String) -> Color:
	match k:
		"plant": return Color("#3d6b3f")
		"phone": return Color("#1c1c22")
		"rug": return Color("#5a1f2a")
		"bench", "table", "desk", "night", "shelf", "mail", "ward", "stage", "crate": return Color("#5e3d24")
		"bar", "recdesk": return Color("#43291a")
		"boiler", "gen", "steel", "vent", "antenna", "cart": return Color("#5d666e")
		"washer", "sink": return Color("#c9c6bb")
		"stove": return Color("#2b2e33")
		"column": return Color("#d8ccaa")
		"sofa": return Color("#7a2b37")
		"safe": return Color("#33373c")
		"piano": return Color("#121216")
		"bed": return Color("#e6dfcc")
		"scope", "sign": return Color("#b8923f")
	return Color("#4a3a2a")

## Texto con contorno oscuro, centrado en x.
static func text(ci: CanvasItem, cx: float, y: float, s: String, size: int, col: Color, outline: int = 3) -> void:
	var f := font()
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := Vector2(cx - w / 2.0, y)
	if outline > 0:
		ci.draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, INK)
	ci.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

static func ellipse(ci: CanvasItem, cx: float, cy: float, rx: float, ry: float, col: Color, n: int = 14) -> void:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	ci.draw_colored_polygon(pts, col)

static func poly(ci: CanvasItem, pts: Array, col: Color) -> void:
	var p := PackedVector2Array()
	for v in pts:
		p.append(v)
	ci.draw_colored_polygon(p, col)

static func r(ci: CanvasItem, x: float, y: float, w: float, h: float, col: Color) -> void:
	ci.draw_rect(Rect2(x, y, w, h), col)

# ---------------------------------------------------------------- planta

# ---------------------------------------------------------------- texturas opcionales
# Si pones PNG de 32x32 en res://assets/tiles/<nombre>.png o res://assets/furniture/<tipo>.png
# se usan en lugar del dibujo por código.
const TILE_NAMES := {1: "wall", 2: "marble", 3: "carpet", 4: "conc", 5: "door", 6: "elev", 7: "stairs", 8: "stairs", 10: "roof", 11: "wood", 12: "terrace", 13: "rail", 14: "hall"}
static var _tex := {}

static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]

## Papel pintado del muro según la planta (perspectiva 3/4: cara frontal alta).
static func wall_paper(fi: int) -> Color:
	match fi:
		0: return Color("#4a4f55")
		1: return Color("#5b4632")
		2: return Color("#4a2a2e")
		3, 4: return Color("#3e2c2a")
		5: return Color("#2f3a46")
	return Color("#5a4a3e")

static func draw_floor(ci: CanvasItem, f: FloorData, x0: int, y0: int, x1: int, y1: int) -> void:
	for ty in range(maxi(y0, 0), mini(y1 + 1, Cfg.H)):
		for tx in range(maxi(x0, 0), mini(x1 + 1, Cfg.W)):
			var t := f.at(tx, ty)
			if t == Cfg.T_VOID:
				continue
			var px := tx * TS
			var py := ty * TS
			var c := tile_color(t)
			var tt := tex("res://assets/tiles/" + str(TILE_NAMES.get(t, "x")) + ".png")
			if t == Cfg.T_WALL:
				var below := f.at(tx, ty + 1)
				var face := below != Cfg.T_WALL and below != Cfg.T_VOID
				if tt != null:
					ci.draw_texture_rect(tt, Rect2(px, py, TS, TS), false)
				else:
					# remate superior del muro
					r(ci, px, py, TS, TS, c)
					r(ci, px, py, TS, 3, c.lightened(0.1))
					if face:
						# cara frontal alta con papel pintado, zócalo y moldura dorada
						var wp := wall_paper(f.fi)
						r(ci, px, py + 6, TS, TS - 6, wp)
						for k in 4:
							r(ci, px + k * 8 + 3, py + 8, 2, TS - 18, wp.lightened(0.07))
						r(ci, px, py + 6, TS, 2, GOLD2.darkened(0.1))
						r(ci, px, py + TS - 10, TS, 10, wp.darkened(0.35))
						r(ci, px, py + TS - 11, TS, 1, GOLD2.darkened(0.3))
						if tx % 3 == 0:
							poly(ci, [Vector2(px + 16, py + 11), Vector2(px + 21, py + 16), Vector2(px + 16, py + 21), Vector2(px + 11, py + 16)], GOLD2.darkened(0.25))
				if face:
					r(ci, px, py + TS - 2, TS, 2, Color(0, 0, 0, 0.5))
				continue
			if tt != null:
				ci.draw_texture_rect(tt, Rect2(px, py, TS, TS), false)
				t = -1
			else:
				r(ci, px, py, TS, TS, c)
			match t:
				3:
					if (tx + ty) % 2 == 0:
						poly(ci, [Vector2(px + 16, py + 6), Vector2(px + 26, py + 16), Vector2(px + 16, py + 26), Vector2(px + 6, py + 16)], c.lightened(0.08))
				14:
					poly(ci, [Vector2(px + 16, py + 4), Vector2(px + 28, py + 16), Vector2(px + 16, py + 28), Vector2(px + 4, py + 16)], c.lightened(0.07))
				2:
					if (tx + ty) % 2 == 0:
						r(ci, px, py, TS, TS, Color(1, 1, 1, 0.05))
				11:
					for k in 4:
						r(ci, px, py + k * 8 + 7, TS, 1, Color(0, 0, 0, 0.18))
				5:
					r(ci, px + 3, py + 3, TS - 6, TS - 6, c.darkened(0.25))
				6:
					r(ci, px + 2, py + 2, TS - 4, TS - 4, Color("#3a2f1a"))
					r(ci, px + TS / 2.0 - 1, py + 2, 2, TS - 4, GOLD2)
				7, 8:
					for k in 4:
						r(ci, px, py + k * 8, TS, 4, Color(0, 0, 0, 0.22))
					if t == Cfg.T_UP:
						poly(ci, [Vector2(px + 16, py + 9), Vector2(px + 23, py + 21), Vector2(px + 9, py + 21)], GOLD)
					else:
						poly(ci, [Vector2(px + 9, py + 11), Vector2(px + 23, py + 11), Vector2(px + 16, py + 23)], GOLD)
			r(ci, px, py, TS, 1, Color(0, 0, 0, 0.08))
			# sombra de contacto junto a las paredes
			if f.at(tx, ty - 1) == Cfg.T_WALL:
				r(ci, px, py, TS, 8, Color(0, 0, 0, 0.3))
				r(ci, px, py + 8, TS, 5, Color(0, 0, 0, 0.12))
			if f.at(tx - 1, ty) == Cfg.T_WALL:
				r(ci, px, py, 5, TS, Color(0, 0, 0, 0.18))
			if f.at(tx + 1, ty) == Cfg.T_WALL:
				r(ci, px + TS - 5, py, 5, TS, Color(0, 0, 0, 0.18))

static func draw_furn(ci: CanvasItem, o: Dictionary) -> void:
	var k: String = o["k"]
	var px: float = o["x"] * TS
	var py: float = o["y"] * TS
	var w: float = o["w"] * TS
	var h: float = o["h"] * TS
	var c := furn_color(k)
	var ft := tex("res://assets/furniture/" + k + ".png")
	if ft != null:
		ci.draw_texture_rect(ft, Rect2(px, py, w, h), false)
		return
	# sombra en el suelo para dar volumen
	if k != "rug":
		r(ci, px + 3, py + h - 3, w - 2, 5, Color(0, 0, 0, 0.28))
	match k:
		"rug":
			r(ci, px + 2, py + 2, w - 4, h - 4, c)
			ci.draw_rect(Rect2(px + 5, py + 5, w - 10, h - 10), GOLD2.darkened(0.2), false, 1.0)
		"plant":
			r(ci, px + 10, py + 18, 12, 10, Color("#6b4a2a"))
			ci.draw_circle(Vector2(px + 16, py + 13), 10, c)
			ci.draw_circle(Vector2(px + 12, py + 10), 5, c.lightened(0.15))
		"column":
			ci.draw_circle(Vector2(px + w / 2, py + h / 2), minf(w, h) * 0.42, c)
			ci.draw_circle(Vector2(px + w / 2, py + h / 2), minf(w, h) * 0.3, c.lightened(0.12))
		"bed":
			r(ci, px + 2, py + 2, w - 4, h - 4, Color("#4a2f22"))
			r(ci, px + 4, py + 4, w - 8, h - 8, c)
			r(ci, px + 4, py + h * 0.45, w - 8, h * 0.55 - 4, Color("#7a2b37"))
			r(ci, px + 6, py + 6, w - 12, 8, Color("#f4efe2"))
		"phone":
			r(ci, px + 8, py + 8, 16, 14, c)
			r(ci, px + 10, py + 6, 12, 4, Color("#33333a"))
		"piano":
			r(ci, px + 1, py + 1, w - 2, h - 2, c)
			r(ci, px + 3, py + h - 9, w - 6, 6, Color("#e9e4d6"))
		"washer":
			r(ci, px + 2, py + 2, w - 4, h - 4, c)
			ci.draw_circle(Vector2(px + w / 2, py + h / 2), minf(w, h) * 0.3, Color("#3d4a55"))
		"sink":
			r(ci, px + 4, py + 6, w - 8, h - 12, c)
			r(ci, px + 8, py + 10, w - 16, h - 20, Color("#7d8b96"))
		_:
			# tapa y frente (perspectiva 3/4)
			var front := minf(10.0, h * 0.35)
			r(ci, px + 1, py + 1, w - 2, h - 2 - front, c.lightened(0.06))
			r(ci, px + 1, py + 1, w - 2, 2, c.lightened(0.25))
			r(ci, px + 1, py + h - 1 - front, w - 2, front, c.darkened(0.28))
			r(ci, px + 1, py + h - 1 - front, w - 2, 1, c.lightened(0.15))

static func draw_pick(ci: CanvasItem, p: Items.Pick, time: float) -> void:
	var x := (p.x + 0.5) * TS
	var y := (p.y + 0.5) * TS
	ci.draw_circle(Vector2(x, y), 12 + sin(time * 4) * 1.5, Color(0.92, 0.82, 0.54, 0.28))
	if p.kind == "masterkey":
		ci.draw_circle(Vector2(x - 4, y), 4.5, GOLD)
		r(ci, x, y - 1.5, 10, 3, GOLD)
		r(ci, x + 6, y, 2.5, 4, GOLD)
	elif p.kind == "badge":
		poly(ci, [Vector2(x, y - 7), Vector2(x + 6, y - 2), Vector2(x + 4, y + 6), Vector2(x - 4, y + 6), Vector2(x - 6, y - 2)], GOLD2)
		r(ci, x - 2, y - 2, 4, 5, Color("#8c2f39"))
	elif p.kind == "cuffkey":
		ci.draw_circle(Vector2(x - 3, y), 3.5, Color("#c0c4c8"))
		r(ci, x, y - 1, 8, 2, Color("#c0c4c8"))
		ci.draw_arc(Vector2(x + 5, y + 4), 3.0, 0, TAU, 8, Color("#9aa0a6"), 1.2)
	elif p.kind == "rope":
		ci.draw_arc(Vector2(x, y), 6.0, 0, TAU, 12, Color("#b08a52"), 2.5)
		ci.draw_arc(Vector2(x, y), 3.0, 0, TAU, 10, Color("#8a6a3a"), 2.0)
	elif p.kind == "dockkey":
		ci.draw_circle(Vector2(x - 4, y), 4.5, Color("#7fa0b8"))
		r(ci, x, y - 1.5, 10, 3, Color("#7fa0b8"))
	elif p.kind == "cash":
		r(ci, x - 7, y - 4, 14, 8, Color("#5b7a4a"))
		r(ci, x - 5, y - 2, 10, 4, Color("#8fb07a"))
		ci.draw_circle(Vector2(x, y), 1.6, Color("#5b7a4a"))
	elif p.kind == "cutter":
		ci.draw_line(Vector2(x - 7, y + 6), Vector2(x + 2, y - 3), Color("#b8392f"), 3.0)
		ci.draw_line(Vector2(x + 7, y + 6), Vector2(x - 2, y - 3), Color("#b8392f"), 3.0)
		poly(ci, [Vector2(x - 3, y - 2), Vector2(x, y - 9), Vector2(x + 3, y - 2)], Color("#9aa3ab"))
	else:
		r(ci, x - 5, y - 2, 10, 4, Color("#9aa3ab"))
		r(ci, x - 3, y + 2, 8, 2, Color("#6a7279"))

static func draw_corpse(ci: CanvasItem, c: Items.Corpse) -> void:
	ci.draw_set_transform(Vector2(c.x, c.y + 4), c.ang, Vector2.ONE)
	ellipse(ci, 0, 0, 16, 9, Color(0.45, 0.03, 0.06, 0.55))
	r(ci, -12, -5, 18, 10, c.outfit.coat)
	r(ci, 4, -4, 9, 8, c.outfit.pants)
	ci.draw_circle(Vector2(-14, 0), 5.5, c.outfit.skin)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------------------------------------------------------------- personajes

static func draw_actor(ci: CanvasItem, x: float, y: float, o: Outfit, dir: String, walk: float, aiming: bool = false, aim_ang: float = 0.0, sc: float = 1.0) -> void:
	var bd := o.build
	var sw := sin(walk) * 2.6
	var side := dir == "left" or dir == "right"
	var fl := -1.0 if dir == "left" else 1.0
	var back := dir == "up"
	var dress := o.kind == "dress"
	var under := o.kind == "under"
	var skin := o.skin
	var shade := Color(0, 0, 0, 0.18)
	var hi := Color(1, 1, 1, 0.16)
	ci.draw_set_transform(Vector2(x, y + 11), 0.0, Vector2(sc * bd, sc * (0.97 + (bd - 0.92) * 0.3)))
	ellipse(ci, 0, 0, 9.5, 3.6, Color(0, 0, 0, 0.34))
	# piernas y calzado
	if dress:
		r(ci, -3.6, -7, 2.6, 6 + sw * 0.25, skin)
		r(ci, 1, -7, 2.6, 6 - sw * 0.25, skin)
		r(ci, -4.2, -1.8 + sw * 0.25, 3.8, 2.2, Color("#15151a"))
		r(ci, 0.4, -1.8 - sw * 0.25, 3.8, 2.2, Color("#15151a"))
	else:
		var lw := 4.2 if side else 5.0
		var a := sw * fl * 0.6 if side else 0.0
		var lx0 := -2.8 if side else -6.0
		var lx1 := -0.4 if side else 1.0
		var shoe := Color("#8a8478") if under else Color("#121216")
		r(ci, lx0 + a, -11, lw, 9.6 + sw * 0.4, o.pants)
		r(ci, lx1 - a, -11, lw, 9.6 - sw * 0.4, o.pants)
		r(ci, lx0 + a, -1.8 + sw * 0.4, lw + 1, 2.3, shoe)
		r(ci, lx1 - a, -1.8 - sw * 0.4, lw + 1, 2.3, shoe)
	# torso
	var tw := 10.5 if side else 16.5
	var tx := -tw / 2.0
	if dress:
		poly(ci, [Vector2(-5.6, -22.4), Vector2(5.6, -22.4), Vector2(6.4, -15), Vector2(9.4, -7.4), Vector2(-9.4, -7.4), Vector2(-6.4, -15)], o.coat)
		r(ci, -9.4, -9, 18.8, 1.6, shade)
		if not back and not side:
			poly(ci, [Vector2(-3, -22.4), Vector2(3, -22.4), Vector2(0, -18.4)], skin)
	else:
		poly(ci, [Vector2(tx + 1, -22.6), Vector2(-tx - 1, -22.6), Vector2(-tx, -9), Vector2(tx, -9)], o.coat)
		r(ci, tx, -11.4, tw, 2.4, shade)
		r(ci, tx + 1, -22.4, tw - 2, 1.6, hi)
	if not side and not back and not under and not dress:
		poly(ci, [Vector2(-3.8, -22.4), Vector2(3.8, -22.4), Vector2(0, -14.6)], Color("#efe9d9"))
		if o.staff_role == "waiter":
			r(ci, -3.2, -21.4, 6.4, 2.6, Color("#111111"))
		elif o.kind != "police" and o.has_tie:
			r(ci, -1.1, -21.6, 2.2, 1.8, o.tie)
			poly(ci, [Vector2(-1.2, -19.8), Vector2(1.2, -19.8), Vector2(0.9, -13), Vector2(0, -12.2), Vector2(-0.9, -13)], o.tie)
		if o.staff_role == "bell":
			for k in 4:
				r(ci, -6.4, -20.4 + k * 2.8, 1.5, 1.5, Color("#e8c76a"))
				r(ci, 4.9, -20.4 + k * 2.8, 1.5, 1.5, Color("#e8c76a"))
		if o.kind == "police":
			ci.draw_circle(Vector2(4.6, -18), 1.9, Color("#e8c76a"))
			r(ci, tx + 0.5, -11.6, tw - 1, 2, Color("#0d0d12"))
		if o.staff_role == "chef":
			r(ci, -4.6, -22, 9.2, 1, Color("#c0392b"))
	if o.apron and not back:
		poly(ci, [Vector2(-5.2, -18.4), Vector2(5.2, -18.4), Vector2(5.8, -8.4), Vector2(-5.8, -8.4)], Color("#f3efe2"))
	if o.blood:
		ci.draw_circle(Vector2(-2.4, -16), 3.4, Color(0.49, 0.04, 0.06, 0.9))
		ci.draw_circle(Vector2(3, -12), 2.4, Color(0.49, 0.04, 0.06, 0.9))
		r(ci, -1.4, -14, 2.2, 6, Color(0.49, 0.04, 0.06, 0.9))
	# brazos
	var arm_c := skin if under else o.coat
	if aiming:
		var sx := 2.0 * fl if side else 6.4
		var sy := -20.4
		var ex := sx + cos(aim_ang) * 11.5
		var ey := sy + sin(aim_ang) * 11.5
		ci.draw_line(Vector2(sx, sy), Vector2(ex, ey), arm_c, 4.2)
		ci.draw_circle(Vector2(ex, ey), 2.3, skin)
		ci.draw_circle(Vector2(ex + cos(aim_ang) * 2.8, ey + sin(aim_ang) * 2.8), 1.6, Color(0.07, 0.07, 0.09))
		if not side:
			r(ci, -10.4, -21.4, 3.4, 10.4 - sw * 0.3, arm_c)
			r(ci, -10.2, -11, 3, 2.6, skin)
	elif side:
		var ax := -1.7 + sw * fl * -0.45
		r(ci, ax, -21.4, 3.4, 10.2, arm_c)
		r(ci, ax + 0.2, -10.6, 3, 2.7, skin)
	else:
		r(ci, -10.6, -21.4, 3.5, 10.4 + sw * 0.35, arm_c)
		r(ci, 7.1, -21.4, 3.5, 10.4 - sw * 0.35, arm_c)
		r(ci, -10.4, -10.4 + sw * 0.35, 3.1, 2.8, skin)
		r(ci, 7.3, -10.4 - sw * 0.35, 3.1, 2.8, skin)
	# cuello y cabeza
	r(ci, -1.8, -24.6, 3.6, 3, skin)
	var hx := 0.8 * fl if side else 0.0
	ci.draw_circle(Vector2(hx, -27.2), 5.4, skin)
	# pelo
	if o.hs != "bald" or back:
		var hc := o.hair
		if back:
			ci.draw_circle(Vector2(hx, -27.6), 5.5, hc)
		else:
			poly(ci, [Vector2(hx - 5.5, -27.5), Vector2(hx - 4.5, -31.5), Vector2(hx, -33), Vector2(hx + 4.5, -31.5), Vector2(hx + 5.5, -27.5), Vector2(hx + 3, -30), Vector2(hx - 3, -30)], hc)
			if o.hs == "bob" or o.hs == "wave":
				r(ci, hx - 6, -29, 2.5, 7, hc)
				r(ci, hx + 3.5, -29, 2.5, 7, hc)
			elif o.hs == "bun":
				ci.draw_circle(Vector2(hx, -33), 2.6, hc)
	# cara
	if not back:
		var ex2 := hx + (1.6 * fl if side else 0.0)
		if side:
			r(ci, ex2 + 1.4 * fl - 0.5, -28, 1.1, 1.3, Color("#1a1410"))
		else:
			r(ci, ex2 - 2.6, -28, 1.1, 1.3, Color("#1a1410"))
			r(ci, ex2 + 1.5, -28, 1.1, 1.3, Color("#1a1410"))
		if o.glasses:
			if side:
				ci.draw_circle(Vector2(ex2 + 1.4 * fl, -27.4), 1.7, Color(0.85, 0.9, 1, 0.35))
			else:
				ci.draw_circle(Vector2(ex2 - 2.1, -27.4), 1.8, Color(0.85, 0.9, 1, 0.35))
				ci.draw_circle(Vector2(ex2 + 2.0, -27.4), 1.8, Color(0.85, 0.9, 1, 0.35))
				r(ci, ex2 - 0.4, -27.8, 0.8, 0.5, Color("#1a1410"))
		if o.stache:
			r(ci, ex2 - 2.2 + (1.2 * fl if side else 0.0), -25.4, 4.4 if not side else 2.6, 1.2, o.hair.darkened(0.2))
	# sombrero
	_hat(ci, o, hx)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _hat(ci: CanvasItem, o: Outfit, hx: float) -> void:
	var c := o.hat_c
	match o.hat_t:
		"fedora":
			ellipse(ci, hx, -31, 8.2, 2.2, c)
			poly(ci, [Vector2(hx - 4.6, -31), Vector2(hx - 4, -36), Vector2(hx, -35), Vector2(hx + 4, -36), Vector2(hx + 4.6, -31)], c)
			r(ci, hx - 4.6, -32.4, 9.2, 1.3, Color(0, 0, 0, 0.45))
		"bowler":
			ellipse(ci, hx, -31, 7, 1.8, c)
			ellipse(ci, hx, -33.2, 4.8, 3.6, c)
		"cap":
			ellipse(ci, hx, -31.6, 6, 2.6, c)
			ellipse(ci, hx + 2.5, -30.6, 4, 1.4, c.darkened(0.2))
		"cloche":
			ellipse(ci, hx, -31, 6.4, 4.2, c)
			r(ci, hx - 6, -29.6, 12, 1.4, c.darkened(0.25))
		"pill":
			r(ci, hx - 3.4, -36, 6.8, 4.4, c)
			r(ci, hx - 3.4, -32.6, 6.8, 1, Color("#e8c76a"))
		"maidcap":
			r(ci, hx - 4.6, -33.4, 9.2, 2.4, c)
		"chef":
			r(ci, hx - 4.4, -40, 8.8, 9, c)
			ellipse(ci, hx, -40, 5.6, 3.4, c)
		"police":
			ellipse(ci, hx, -32, 6.2, 3, c)
			r(ci, hx - 6, -31, 12, 1.6, Color("#0d0d12"))
			ci.draw_circle(Vector2(hx, -33), 1.2, Color("#e8c76a"))

## Bocadillo de diálogo encima de un personaje.
static func draw_bubble(ci: CanvasItem, x: float, y: float, s: String) -> void:
	var f := font()
	var size := 9
	var w := minf(f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x, 170.0)
	var lines := f.get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, w + 2, size)
	var bh := lines.y + 8
	var bx := x - (w + 12) / 2.0
	var by := y - 46 - bh
	r(ci, bx, by, w + 12, bh, Color("#f4efe2"))
	poly(ci, [Vector2(x - 4, by + bh), Vector2(x + 4, by + bh), Vector2(x, by + bh + 5)], Color("#f4efe2"))
	ci.draw_multiline_string(f, Vector2(bx + 6, by + 4 + size), s, HORIZONTAL_ALIGNMENT_LEFT, w + 2, size, -1, Color("#1a1408"))


# ---------------------------------------------------------------- azotea: ciudad de noche y letrero

static func _hash(i: int) -> float:
	var x := (i * 374761393 + 668265263) & 0x7fffffff
	x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff
	return float(x % 10000) / 10000.0

## Manhattan de noche vista desde lo alto: azoteas con ventanas encendidas, depósitos de agua
## y calles con faros de coches, y el Empire State asomando.
static func draw_city(ci: CanvasItem, rect: Rect2, time: float) -> void:
	r(ci, rect.position.x, rect.position.y, rect.size.x, rect.size.y, Color("#070b14"))
	var bw := 230.0
	var bh := 170.0
	var st := 40.0
	var gx0 := floori(rect.position.x / bw) - 1
	var gx1 := floori(rect.end.x / bw) + 1
	var gy0 := floori(rect.position.y / bh) - 1
	var gy1 := floori(rect.end.y / bh) + 1
	for gy in range(gy0, gy1 + 1):
		for gx in range(gx0, gx1 + 1):
			var bx := gx * bw
			var by := gy * bh
			var seed_i := gx * 7919 + gy * 104729
			# edificios de la manzana
			var n := 2 + int(_hash(seed_i) * 3)
			var cw := (bw - st) / n
			for i in n:
				var hh := _hash(seed_i + i * 31)
				var ex := bx + st / 2 + i * cw + 2
				var ey := by + st / 2 + hh * 18
				var ew := cw - 4
				var eh := bh - st - hh * 30
				var roof := Color(0.09 + hh * 0.06, 0.1 + hh * 0.05, 0.13 + hh * 0.05)
				r(ci, ex + 6, ey + 6, ew, eh, Color(0, 0, 0, 0.5))
				r(ci, ex, ey, ew, eh, roof)
				r(ci, ex, ey, ew, 2, roof.lightened(0.15))
				# ventanas encendidas en el borde (vista muy inclinada)
				var wx := ex + 4.0
				var k := 0
				while wx < ex + ew - 6:
					if _hash(seed_i + i * 97 + k) < 0.45:
						var flick := 0.75 + 0.25 * sin(time * 0.7 + k + i)
						r(ci, wx, ey + eh - 7, 4, 3, Color(1.0, 0.82, 0.45, 0.8 * flick))
					wx += 9
					k += 1
				if hh > 0.6:
					ci.draw_circle(Vector2(ex + ew * 0.7, ey + eh * 0.3), 7, Color("#3a2e22"))
					ci.draw_circle(Vector2(ex + ew * 0.7, ey + eh * 0.3), 5, Color("#4f3d2c"))
			# coches por las calles
			for c in 2:
				var ph := fmod(time * (40.0 + c * 25.0) + _hash(seed_i + c) * bw, bw)
				var cy := by + (8.0 if c == 0 else st - 10.0)
				ci.draw_circle(Vector2(bx + ph, cy), 1.6, Color(1, 0.95, 0.7, 0.9) if c == 0 else Color(1, 0.25, 0.2, 0.9))
				ci.draw_circle(Vector2(bx + ph + 4, cy), 1.6, Color(1, 0.95, 0.7, 0.9) if c == 0 else Color(1, 0.25, 0.2, 0.9))
	# el Empire State, al sur-oeste
	var es := Vector2(-260, 1180)
	if rect.grow(400).has_point(es):
		for k in 6:
			var sz := 200.0 - k * 30.0
			r(ci, es.x - sz / 2, es.y - sz / 2 - k * 6, sz, sz, Color(0.12 + k * 0.02, 0.13 + k * 0.02, 0.17 + k * 0.02))
		ci.draw_circle(es + Vector2(0, -40), 6, Color(1, 0.2, 0.2, 0.6 + 0.4 * sin(time * 3.0)))

## Letrero luminoso del hotel sobre la azotea.
static func draw_sign(ci: CanvasItem, x: float, y: float, w: float, time: float) -> void:
	var f := font()
	var on := 0.85 + 0.15 * sin(time * 9.0) * (1.0 if fmod(time, 7.0) < 0.4 else 0.0)
	r(ci, x, y, w, 52, Color("#1c1a1a"))
	for k in int(w / 16):
		r(ci, x + 6 + k * 16, y + 44, 3, 12, Color("#3a3434"))
	var txt := "NEW YORKER"
	var fs := 40
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := Vector2(x + (w - tw) / 2.0, y + 40)
	ci.draw_string_outline(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0.9, 0.1, 0.1, 0.25 * on))
	ci.draw_string_outline(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(1, 0.3, 0.3, 0.6 * on))
	ci.draw_string(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.75, 0.7, on))
	var t2 := "HOTEL"
	var tw2 := f.get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	ci.draw_string(f, Vector2(x + (w - tw2) / 2.0, y + 14), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.85, 0.6, on))

## Esposas, grilletes y café sobre un personaje.
static func draw_extras(ci: CanvasItem, e: Ent) -> void:
	if e.cuffed:
		ci.draw_arc(Vector2(e.x - 4, e.y + 1), 2.5, 0, TAU, 8, Color("#c0c4c8"), 1.2)
		ci.draw_arc(Vector2(e.x + 4, e.y + 1), 2.5, 0, TAU, 8, Color("#c0c4c8"), 1.2)
		ci.draw_line(Vector2(e.x - 2, e.y + 1), Vector2(e.x + 2, e.y + 1), Color("#c0c4c8"), 1.0)
		if e.shackled:
			ci.draw_line(Vector2(e.x - 6, e.y + 11), Vector2(e.x + 6, e.y + 11), Color("#9aa0a6"), 1.5)
			ci.draw_arc(Vector2(e.x - 6, e.y + 11), 2.0, 0, TAU, 8, Color("#9aa0a6"), 1.2)
			ci.draw_arc(Vector2(e.x + 6, e.y + 11), 2.0, 0, TAU, 8, Color("#9aa0a6"), 1.2)
	if e.coffee:
		r(ci, e.x + 8, e.y - 6, 5, 6, Color("#efe9d9"))
		r(ci, e.x + 8, e.y - 6, 5, 1, Color("#5a3b28"))
		ci.draw_line(Vector2(e.x + 10, e.y - 9), Vector2(e.x + 11, e.y - 13), Color(1, 1, 1, 0.35), 1.0)
