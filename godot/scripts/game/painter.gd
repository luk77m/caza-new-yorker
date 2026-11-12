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

static var _font: Font = null
static var _deco: Font = null

## Fuente del juego: MSDF para que se vea nítida a cualquier zoom. Usa assets/fonts/ui.ttf si existe
## o una fuente del sistema.
static func font() -> Font:
	if _font == null:
		_font = _make_font("res://assets/fonts/ui.ttf", ["Josefin Sans", "Montserrat", "Noto Sans", "DejaVu Sans", "Liberation Sans", "sans-serif"])
	return _font

## Fuente de los títulos (art déco si pones assets/fonts/deco.ttf; si no, una con serifa del sistema).
static func deco_font() -> Font:
	if _deco == null:
		_deco = _make_font("res://assets/fonts/deco.ttf", ["Poiret One", "Limelight", "Playfair Display", "Cinzel", "Noto Serif", "DejaVu Serif", "Liberation Serif", "serif"])
	return _deco

static func _make_font(path: String, names: Array) -> Font:
	if ResourceLoader.exists(path):
		var ff = load(path)
		if ff is FontFile:
			(ff as FontFile).multichannel_signed_distance_field = true
			return ff
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(names)
	sf.multichannel_signed_distance_field = true
	sf.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return sf

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
						var hsh := (tx * 73 + ty * 151 + f.fi * 37) % 11
						if f.at(tx, ty - 1) == Cfg.T_VOID and ty > 0:
							# ventana a la calle con la ciudad de noche
							r(ci, px + 5, py + 9, 22, 13, Color("#13203a"))
							r(ci, px + 7, py + 11, 3, 2, Color(1.0, 0.85, 0.5, 0.7))
							r(ci, px + 19, py + 15, 2, 2, Color(1.0, 0.85, 0.5, 0.6))
							r(ci, px + 15, py + 9, 2, 13, Color("#2a2112"))
							r(ci, px + 5, py + 15, 22, 1, Color("#2a2112"))
							r(ci, px + 3, py + 8, 4, 15, Color("#7a2b37"))
							r(ci, px + 25, py + 8, 4, 15, Color("#7a2b37"))
						elif hsh == 0:
							# cuadro con marco dorado
							r(ci, px + 7, py + 9, 18, 12, GOLD2)
							var canv: Color = [Color("#2f4a6b"), Color("#6b4a2a"), Color("#3d5a3a"), Color("#6a2a30")][(tx + f.fi) % 4]
							r(ci, px + 9, py + 11, 14, 8, canv)
							r(ci, px + 9, py + 16, 14, 3, canv.darkened(0.3))
							ci.draw_circle(Vector2(px + 19, py + 13), 1.6, Color("#f0d690"))
						elif hsh == 5:
							# aplique de pared con su bombilla
							r(ci, px + 14, py + 14, 4, 6, GOLD2)
							ci.draw_circle(Vector2(px + 16, py + 12), 3.0, Color("#ffe6a0"))
							ci.draw_circle(Vector2(px + 16, py + 14), 9.0, Color(1.0, 0.85, 0.5, 0.12))
						elif tx % 3 == 0:
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
					# moqueta con medallón art déco y cenefa junto a la pared
					if (tx + ty) % 2 == 0:
						poly(ci, [Vector2(px + 16, py + 5), Vector2(px + 27, py + 16), Vector2(px + 16, py + 27), Vector2(px + 5, py + 16)], c.lightened(0.09))
						poly(ci, [Vector2(px + 16, py + 11), Vector2(px + 21, py + 16), Vector2(px + 16, py + 21), Vector2(px + 11, py + 16)], GOLD2.darkened(0.45))
					else:
						ci.draw_circle(Vector2(px + 16, py + 16), 2, GOLD2.darkened(0.5))
					if f.at(tx, ty - 1) == Cfg.T_WALL or f.at(tx, ty + 1) == Cfg.T_WALL:
						r(ci, px, py + (2 if f.at(tx, ty - 1) == Cfg.T_WALL else TS - 6), TS, 4, GOLD2.darkened(0.35))
				14:
					# pasillo: alfombra central con bordes dorados
					r(ci, px, py + 3, TS, 2, GOLD2.darkened(0.2))
					r(ci, px, py + TS - 5, TS, 2, GOLD2.darkened(0.2))
					poly(ci, [Vector2(px + 16, py + 8), Vector2(px + 24, py + 16), Vector2(px + 16, py + 24), Vector2(px + 8, py + 16)], c.lightened(0.1))
					ci.draw_circle(Vector2(px + 16, py + 16), 2.5, GOLD2.darkened(0.1))
				2:
					# mármol con vetas e incrustaciones
					if (tx + ty) % 2 == 0:
						r(ci, px, py, TS, TS, Color(1, 1, 1, 0.06))
					ci.draw_line(Vector2(px + 3, py + (tx * 7 + ty * 3) % 28 + 2), Vector2(px + 29, py + (tx * 5 + ty * 11) % 28 + 2), Color(1, 1, 1, 0.07), 1.0)
					if tx % 4 == 0 and ty % 4 == 0:
						poly(ci, [Vector2(px, py - 4), Vector2(px + 4, py), Vector2(px, py + 4), Vector2(px - 4, py)], GOLD2.darkened(0.2))
					r(ci, px, py, TS, 1, Color(0, 0, 0, 0.12))
					r(ci, px, py, 1, TS, Color(0, 0, 0, 0.12))
				11:
					# parqué en espiga
					for k in 4:
						var off := 8 if (tx + k) % 2 == 0 else 0
						r(ci, px, py + k * 8 + 7, TS, 1, Color(0, 0, 0, 0.2))
						r(ci, px + off + 4, py + k * 8, 1, 8, Color(0, 0, 0, 0.16))
						r(ci, px + off + 20, py + k * 8, 1, 8, Color(0, 0, 0, 0.16))
				5:
					if f.door_open(tx, ty):
						# puerta abierta: umbral y la hoja girada contra el marco
						r(ci, px, py, TS, TS, Color("#3a2a1c"))
						r(ci, px + 2, py + 2, TS - 4, TS - 4, Color("#6a4c34"))
						r(ci, px + 1, py + 1, 5, TS - 2, Color("#5a3a22"))
						r(ci, px + 2, py + 2, 3, TS - 4, Color("#7a5232"))
					else:
						# puerta cerrada de madera con marco y pomo de latón
						r(ci, px + 2, py + 1, TS - 4, TS - 2, Color("#5a3a22"))
						r(ci, px + 4, py + 3, TS - 8, TS - 6, Color("#7a5232"))
						r(ci, px + 7, py + 6, TS - 14, 9, Color("#6a4529"))
						r(ci, px + 7, py + 18, TS - 14, 9, Color("#6a4529"))
						ci.draw_circle(Vector2(px + TS - 8, py + 17), 2, GOLD)
				6:
					# puertas del ascensor de latón con indicador
					r(ci, px + 1, py + 1, TS - 2, TS - 2, Color("#2a2112"))
					r(ci, px + 3, py + 5, TS / 2.0 - 4, TS - 7, Color("#b8923f"))
					r(ci, px + TS / 2.0 + 1, py + 5, TS / 2.0 - 4, TS - 7, Color("#b8923f"))
					r(ci, px + TS / 2.0 - 1, py + 5, 2, TS - 7, Color("#2a2112"))
					for k in 3:
						r(ci, px + 5, py + 9 + k * 7, TS / 2.0 - 8, 1, Color("#e8c76a"))
						r(ci, px + TS / 2.0 + 3, py + 9 + k * 7, TS / 2.0 - 8, 1, Color("#e8c76a"))
					poly(ci, [Vector2(px + 16, py + 1), Vector2(px + 19, py + 4), Vector2(px + 13, py + 4)], Color("#ffd27a"))
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
			r(ci, px + 2, py + 2, w - 4, 6, Color("#5e3d24"))
			r(ci, px + 4, py + 6, w - 8, h - 10, c)
			r(ci, px + 7, py + 9, w * 0.5 - 9, 9, Color("#fbf7ec"))
			r(ci, px + w * 0.5 + 2, py + 9, w * 0.5 - 9, 9, Color("#fbf7ec"))
			r(ci, px + 4, py + h * 0.45, w - 8, h * 0.55 - 4, Color("#7a2b37"))
			r(ci, px + 4, py + h * 0.45, w - 8, 4, Color("#efe4cf"))
			for j in 3:
				r(ci, px + 6, py + h * 0.55 + j * 8, w - 12, 1, Color(0, 0, 0, 0.15))
		"phone":
			r(ci, px + 8, py + 8, 16, 14, c)
			r(ci, px + 10, py + 6, 12, 4, Color("#33333a"))
		"piano":
			r(ci, px + 1, py + 1, w - 2, h - 2, c)
			r(ci, px + 4, py + 3, w - 8, h - 16, Color("#1d1d24"))
			r(ci, px + 3, py + h - 11, w - 6, 8, Color("#e9e4d6"))
			var nk := int((w - 6) / 4)
			for j in nk:
				if j % 7 != 2 and j % 7 != 6:
					r(ci, px + 5 + j * 4, py + h - 11, 2, 5, Color("#111116"))
		"table":
			r(ci, px + 1, py + 1, w - 2, h - 2, Color("#f1ece0"))
			r(ci, px + 1, py + h - 6, w - 2, 5, Color("#d8cfba"))
			ci.draw_circle(Vector2(px + w / 2, py + h / 2 - 2), minf(w, h) * 0.12, Color("#c9a24b"))
			ci.draw_circle(Vector2(px + w / 2, py + h / 2 - 2), minf(w, h) * 0.06, Color("#fff2c0"))
		"desk", "recdesk":
			r(ci, px + 1, py + 1, w - 2, h - 2, c.lightened(0.05))
			r(ci, px + 1, py + h - 9, w - 2, 8, c.darkened(0.3))
			r(ci, px + 6, py + 5, 10, 7, Color("#efe9d9"))
			ci.draw_circle(Vector2(px + w - 10, py + 9), 5, Color("#3d6b3f"))
			ci.draw_circle(Vector2(px + w - 10, py + 9), 2.5, Color("#ffe6a0"))
		"sofa":
			r(ci, px + 1, py + 1, w - 2, h - 2, c.darkened(0.2))
			r(ci, px + 4, py + 4, w - 8, h - 12, c)
			var ncu := maxi(1, int(w / 32))
			for j in ncu:
				r(ci, px + 5 + j * (w - 10) / ncu, py + 6, (w - 10) / ncu - 2, h - 16, c.lightened(0.08))
		"bar":
			r(ci, px + 1, py + 1, w - 2, h - 2, c)
			r(ci, px + 1, py + 1, w - 2, 5, Color("#8a5c37"))
			var bcs := [Color("#2f6b3a"), Color("#8c2f39"), Color("#c9a24b")]
			for j in int(w / 14):
				r(ci, px + 6 + j * 14, py + 3, 3, 8, bcs[j % 3])
		"shelf":
			r(ci, px + 1, py + 1, w - 2, h - 2, c.darkened(0.2))
			var bks := [Color("#7a2b37"), Color("#2f4a6b"), Color("#3d6b3f"), Color("#8a7a4a")]
			for j in int(w / 5):
				r(ci, px + 3 + j * 5, py + 4, 4, h - 10, bks[(j * 7) % 4])
		"crate":
			r(ci, px + 1, py + 1, w - 2, h - 2, c)
			ci.draw_rect(Rect2(px + 3, py + 3, w - 6, h - 6), c.darkened(0.3), false, 1.5)
			ci.draw_line(Vector2(px + 3, py + 3), Vector2(px + w - 3, py + h - 3), c.darkened(0.3), 1.5)
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
	# ganzúas y fregonas no llevan marca: hay que fijarse para verlas
	if p.kind == "lockpick":
		ci.draw_line(Vector2(x - 6, y + 2), Vector2(x + 5, y - 1), Color("#8a9097"), 1.4)
		ci.draw_line(Vector2(x + 5, y - 1), Vector2(x + 7, y - 3), Color("#8a9097"), 1.4)
		ci.draw_circle(Vector2(x - 6, y + 2), 1.8, Color("#6a7279"))
		return
	if p.kind == "mop":
		ci.draw_line(Vector2(x - 8, y + 7), Vector2(x + 7, y - 8), Color("#8a6a42"), 2.2)
		r(ci, x - 12, y + 5, 8, 5, Color("#cfc9b8"))
		return
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

## Perro de un huésped (v0.12).
static func draw_pet(ci: CanvasItem, p: Dictionary, x: float, y: float) -> void:
	var c := Color(str(p["col"]))
	var d: float = p["dir"]
	var wk := sin(float(p["walk"])) * 1.6
	ellipse(ci, x, y + 5, 8, 2.6, Color(0, 0, 0, 0.3))
	r(ci, x - 6, y + 1, 2.2, 4.5 + wk * 0.5, c.darkened(0.25))
	r(ci, x + 3.8, y + 1, 2.2, 4.5 - wk * 0.5, c.darkened(0.25))
	ellipse(ci, x, y - 1, 7.5, 4.2, c)
	ci.draw_circle(Vector2(x + 7.5 * d, y - 4), 3.6, c)
	poly(ci, [Vector2(x + 6 * d, y - 7), Vector2(x + 4.5 * d, y - 2.5), Vector2(x + 8 * d, y - 6)], c.darkened(0.35))
	r(ci, x + (9.5 * d if d > 0 else 9.5 * d - 2.5), y - 4, 2.5, 2, c.darkened(0.1))
	ci.draw_circle(Vector2(x + 11.6 * d, y - 3.6), 0.9, Color("#111111"))
	ci.draw_circle(Vector2(x + 8.4 * d, y - 5), 0.7, Color("#111111"))
	ci.draw_line(Vector2(x - 7 * d, y - 2), Vector2(x - 10.5 * d, y - 6 - wk), c.darkened(0.15), 1.8)
	if float(p["msg_t"]) > 0.0:
		text(ci, x, y - 14, str(p["msg"]), 9, Color("#f3efe2"))

## Rejilla de ventilación en el muro (abierta si alguien ha pasado por ella).
static func draw_vent(ci: CanvasItem, tx: int, ty: int, open: bool) -> void:
	var px := tx * TS + 7.0
	var py := ty * TS - 13.0
	r(ci, px - 1, py - 1, 20, 12, Color("#1a1c20"))
	if open:
		r(ci, px, py, 18, 10, Color("#050607"))
		poly(ci, [Vector2(px, py + 10), Vector2(px + 18, py + 10), Vector2(px + 20, py + 15), Vector2(px + 2, py + 15)], Color("#7d848c"))
	else:
		r(ci, px, py, 18, 10, Color("#6d747c"))
		for j in 4:
			r(ci, px + 1, py + 1.5 + j * 2.3, 16, 1, Color("#2a2d32"))
		for q in [Vector2(px + 1, py + 1), Vector2(px + 16, py + 1), Vector2(px + 1, py + 8), Vector2(px + 16, py + 8)]:
			ci.draw_circle(q, 0.8, Color("#c9cdd2"))

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
	# al andar de frente o de espaldas, cada pie se levanta por turnos;
	# de lado, las piernas dan zancadas y la puntera mira hacia donde camina
	var lift0 := maxf(0.0, sw) * 0.6
	var lift1 := maxf(0.0, -sw) * 0.6
	var shoe := Color("#8a8478") if under else Color("#121216")
	if dress:
		shoe = Color("#15151a")
		if side:
			var st := sw * 0.5 * fl
			r(ci, -1.6 + st, -7, 2.6, 5.4, skin)
			r(ci, -1.0 - st, -7, 2.6, 5.4, skin.darkened(0.12))
			r(ci, -1.6 + st + (0.0 if fl > 0 else -1.4), -1.8, 4.0, 2.2, shoe)
			r(ci, -1.0 - st + (0.0 if fl > 0 else -1.4), -1.8, 4.0, 2.2, shoe)
		else:
			r(ci, -3.6, -7, 2.6, 5.4 - lift0, skin)
			r(ci, 1.0, -7, 2.6, 5.4 - lift1, skin)
			r(ci, -4.0, -1.8 - lift0, 3.4, 2.2, shoe)
			r(ci, 0.6, -1.8 - lift1, 3.4, 2.2, shoe)
	elif side:
		var st2 := sw * 0.9 * fl
		r(ci, -2.4 - st2, -11, 4.4, 9.4, o.pants.darkened(0.15))
		r(ci, -2.0 + st2, -11, 4.4, 9.4, o.pants)
		# zapatos: más largos por delante (dirección de la marcha)
		var toe := 2.6 * fl
		r(ci, -2.4 - st2 + minf(toe, 0.0), -1.8, 4.4 + absf(toe), 2.3, shoe)
		r(ci, -2.0 + st2 + minf(toe, 0.0), -1.8, 4.4 + absf(toe), 2.3, shoe)
	else:
		r(ci, -5.8, -11, 4.8, 9.4 - lift0, o.pants)
		r(ci, 1.0, -11, 4.8, 9.4 - lift1, o.pants)
		r(ci, -6.0, -1.9 - lift0, 5.2, 2.4, shoe)
		r(ci, 0.8, -1.9 - lift1, 5.2, 2.4, shoe)
		if not back and not under:
			r(ci, -5.2, -1.6 - lift0, 1.6, 0.6, Color(1, 1, 1, 0.3))
			r(ci, 1.6, -1.6 - lift1, 1.6, 0.6, Color(1, 1, 1, 0.3))
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
		draw_gun(ci, Vector2(ex, ey), aim_ang, 0.55)
		ci.draw_circle(Vector2(ex, ey), 2.3, skin)
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


## Pistola de los años 30 con silenciador largo, en la dirección de apuntado.
static func draw_gun(ci: CanvasItem, p: Vector2, ang: float, k: float) -> void:
	var d := Vector2(cos(ang), sin(ang))
	var n := Vector2(-d.y, d.x)
	if d.x < 0:
		n = -n
	var steel := Color("#2a2d33")
	var hi := Color("#5b6068")
	var q := func(a: float, b: float, c: float, e: float) -> PackedVector2Array:
		return PackedVector2Array([p + d * a * k + n * c * k, p + d * b * k + n * c * k, p + d * b * k + n * e * k, p + d * a * k + n * e * k])
	# empuñadura de madera
	ci.draw_colored_polygon(PackedVector2Array([p + d * -4 * k + n * 1 * k, p + d * 4 * k + n * 1 * k, p + d * 1 * k + n * 11 * k, p + d * -7 * k + n * 10 * k]), Color("#6b4a2a"))
	# armazón y corredera
	ci.draw_colored_polygon(q.call(-6, 14, -4, 2), steel)
	ci.draw_colored_polygon(q.call(-6, 14, -4, -2.5), hi)
	# guardamonte
	ci.draw_arc(p + d * 5 * k + n * 3 * k, 3.0 * k, 0, TAU, 8, steel, 1.0)
	# silenciador largo con anillas
	ci.draw_colored_polygon(q.call(14, 40, -3.5, 1.5), Color("#3a3d44"))
	for i in 4:
		var a := 17.0 + i * 6.0
		ci.draw_colored_polygon(q.call(a, a + 1.2, -3.6, 1.6), Color("#55595f"))

## Coche visto desde arriba: policía (blanco y negro con sirena), fúnebre (largo y negro),
## federal (negro) o aparcado (color clásico).
static func draw_car(ci: CanvasItem, kind: String, x: float, y: float, time: float, tint: Color = Color("#5a2a2a")) -> void:
	var l := 92.0 if kind == "hearse" else 72.0
	var w := 30.0
	var body := tint
	match kind:
		"police":
			body = Color("#15161a")
		"hearse", "fed":
			body = Color("#0e0f12")
	var x0 := x - l / 2
	var y0 := y - w / 2
	r(ci, x0 + 4, y0 + 5, l, w, Color(0, 0, 0, 0.35))
	r(ci, x0, y0, l, w, body)
	r(ci, x0 + 2, y0, l - 4, 2, body.lightened(0.25))
	if kind == "police":
		r(ci, x0 + l * 0.32, y0, l * 0.36, w, Color("#efeee8"))
	# capó redondeado, parabrisas y techo
	ci.draw_circle(Vector2(x0 + l - 4, y), w / 2 - 1, body)
	r(ci, x0 + l * 0.55, y0 + 4, 6, w - 8, Color(0.55, 0.68, 0.8, 0.8))
	r(ci, x0 + l * (0.18 if kind == "hearse" else 0.25), y0 + 4, l * (0.36 if kind == "hearse" else 0.28), w - 8, body.lightened(0.12))
	if kind == "hearse":
		r(ci, x0 + 6, y0 + 3, l * 0.5, 1.5, Color("#c9c9c9"))
		r(ci, x0 + 6, y0 + w - 4.5, l * 0.5, 1.5, Color("#c9c9c9"))
		ci.draw_arc(Vector2(x0 + l * 0.3, y), 5, -1.2, 1.2, 8, Color("#c9c9c9"), 1.2)
	# ruedas, faros y pilotos
	for k in 2:
		r(ci, x0 + 10 + k * (l - 30), y0 - 3, 12, 4, Color("#111111"))
		r(ci, x0 + 10 + k * (l - 30), y0 + w - 1, 12, 4, Color("#111111"))
	ci.draw_circle(Vector2(x0 + l + 1, y0 + 6), 2.5, Color("#fff4c8"))
	ci.draw_circle(Vector2(x0 + l + 1, y0 + w - 6), 2.5, Color("#fff4c8"))
	r(ci, x0 - 1, y0 + 4, 2, 4, Color("#c0392b"))
	r(ci, x0 - 1, y0 + w - 8, 2, 4, Color("#c0392b"))
	if kind == "police":
		var on := fmod(time, 0.5) < 0.25
		ci.draw_circle(Vector2(x0 + l * 0.5, y), 3.5, Color("#ff3030") if on else Color("#801010"))

## Exterior del vestíbulo: acera, farolas, calle y coches aparcados.
static func draw_street(ci: CanvasItem, w: World, time: float) -> void:
	var y_side := 27.0 * TS
	var y_road := y_side + 14.0
	r(ci, -400, y_side, Cfg.W * TS + 800, 14, Color("#5a5650"))
	r(ci, -400, y_side + 13, Cfg.W * TS + 800, 2, Color("#2a2826"))
	r(ci, -400, y_road, Cfg.W * TS + 800, 200, Color("#1d1f22"))
	var x := -380.0
	while x < Cfg.W * TS + 400:
		r(ci, x, y_road + 44, 26, 3, Color("#8a8470"))
		x += 60.0
	# toldo del hotel sobre la entrada
	r(ci, 19.5 * TS, y_side - 2, 5 * TS, 10, Color("#7a2b37"))
	for k in 10:
		r(ci, 19.5 * TS + k * 16, y_side + 6, 8, 3, Color("#7a2b37") if k % 2 == 0 else Color("#efe4cf"))
	# farolas
	for fx in [8, 15, 29, 36]:
		ci.draw_circle(Vector2(fx * TS, y_side + 6), 3, Color("#2a2a2a"))
		ci.draw_circle(Vector2(fx * TS, y_side + 6), 9, Color(1.0, 0.85, 0.5, 0.18))
	# coches aparcados de los huéspedes
	var parked := [[4.0, Color("#5a2a2a")], [9.0, Color("#2a3a5a")], [33.0, Color("#3a4a2a")], [38.0, Color("#6a5a3a")]]
	for pc in parked:
		draw_car(ci, "parked", pc[0] * TS, (Cfg.STREET_Y + 1.2) * TS, time, pc[1])
	for c in w.cars:
		draw_car(ci, str(c["kind"]), c["x"], c["y"], time)

## Silueta de tiza donde estuvo un cadáver.
static func draw_chalk(ci: CanvasItem, c: Items.Corpse) -> void:
	ci.draw_set_transform(Vector2(c.x, c.y + 4), c.ang, Vector2.ONE)
	var col := Color(0.95, 0.95, 0.92, 0.75)
	ci.draw_arc(Vector2(-15, 0), 6, 0, TAU, 14, col, 1.2)
	ci.draw_polyline(PackedVector2Array([Vector2(-9, -4), Vector2(-4, -12), Vector2(0, -6), Vector2(8, -9), Vector2(18, -5), Vector2(10, -2), Vector2(18, 3), Vector2(8, 7), Vector2(0, 5), Vector2(-4, 12), Vector2(-9, 4)]), col, 1.2)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Estrellitas sobre alguien noqueado.
static func draw_ko(ci: CanvasItem, e: Ent, time: float) -> void:
	for i in 3:
		var a := time * 4.0 + i * TAU / 3.0
		var p := Vector2(e.x + cos(a) * 9, e.y - 36 + sin(a) * 3)
		poly(ci, [p + Vector2(0, -3), p + Vector2(1, -1), p + Vector2(3, 0), p + Vector2(1, 1), p + Vector2(0, 3), p + Vector2(-1, 1), p + Vector2(-3, 0), p + Vector2(-1, -1)], Color("#ffe17a"))
