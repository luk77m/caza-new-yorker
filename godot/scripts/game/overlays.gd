## v0.13: ventanas que se dibujan encima del HUD: aviso de la central por el pinganillo,
## interrogatorio del botones, registro de muebles y cadáveres y presentación de los equipos.
class_name Overlays
extends Control

signal sound(nm: String)

const INTRO := 5.5
const C_BG := Color(0.03, 0.05, 0.07, 0.96)
const C_GOLD := Color("#ebd08a")
const C_TEXT := Color("#efe8d4")
const C_MUT := Color("#a9b2b8")
const C_RED := Color("#ff6a78")

var w: World
var quiet := false           # hay otro panel abierto: no enseñar avisos pequeños
var loot_key := ""
var loot_title := ""
var loot_col := 0
var loot_row := 0
var loot_msg := ""
var intro_t := 0.0
var anim := 0.0
var foes: Control
var _hot: Array = []         # zonas pulsables: [Rect2, acción, dato]
var _mates: Array = []
var _foes: Array = []
var _cop: Outfit = null
# avisos laterales (entran y salen deslizándose por la izquierda)
var _cards := {}             # clave -> {a, title, text, col}
var _card_order: Array = []
var _fit_t := 0.0
var _central_age := 0.0
var _central_msg := ""
# transición de escaleras y ascensor
var travel_t := 0.0
var travel_dur := 1.5
var travel_kind := ""
var _tr_from := 0
var _tr_to := 0
var _tr_outfit: Outfit = null

func _ready() -> void:
	# anclas Y márgenes: con solo las anclas el control se quedaba pequeño en una esquina
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	foes = Control.new()
	add_child(foes)
	foes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	foes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foes.modulate = Color(0, 0, 0, 1)
	foes.draw.connect(_draw_foes)

## Partida nueva. Con intro se presentan los equipos antes de empezar.
func begin(world: World, with_intro: bool) -> void:
	w = world
	loot_key = ""
	intro_t = 0.0
	travel_t = 0.0
	_cards.clear()
	_card_order.clear()
	_mates.clear()
	_foes.clear()
	if with_intro and w != null and w.human != null:
		for e in w.ents:
			if e.role == w.human.role:
				if e == w.human:
					_mates.push_front(e)
				else:
					_mates.append(e)
			elif e.role == "hunter" or e.role == "runner":
				_foes.append(e)
		intro_t = INTRO
		sound.emit("suspense")

func stop() -> void:
	w = null
	loot_key = ""
	intro_t = 0.0
	travel_t = 0.0
	_cards.clear()
	_card_order.clear()

## Animación corta al cambiar de planta: "stairs" o "elev".
func start_travel(kind: String, from_fl: int, to_fl: int, outfit: Outfit, dur: float) -> void:
	travel_kind = kind
	_tr_from = from_fl
	_tr_to = to_fl
	_tr_outfit = outfit
	travel_dur = maxf(dur, 0.5)
	travel_t = travel_dur
	loot_key = ""

## Avisos que tocan ahora mismo: [clave, título, texto, color].
func _notices() -> Array:
	var out: Array = []
	if w == null or w.human == null or intro_t > 0.0:
		return out
	var h := w.human
	var warn := Color("#f0b04a")
	if h.away_t > 0.0 and h.alive:
		if h.role == "hunter" and h.agent_n > 0:
			out.append(["expel", "EXPULSADO DEL HOTEL", "Vuelves como " + h.nm + " en " + str(ceili(h.away_t)) + " s. Mientras, sigues a tu compañero (Espacio cambia).", C_RED])
		else:
			out.append(["away", "FUERA DE JUEGO", "Vuelves en " + str(ceili(h.away_t)) + " s. Mientras, sigues a tu compañero (Espacio cambia).", C_RED])
	if h.arrest > 0.0 and h.alive:
		out.append(["arrest", "DETENIDO", "La policía te retiene " + str(ceili(h.arrest)) + " s.", C_RED])
	if h.pet_id != 0 and h.pet_wanted:
		out.append(["petw", "DENUNCIADO POR EL PERRO", "Suéltalo (E) antes de que la policía te vea con él.", C_RED])
	elif h.pet_id != 0 and h.pet_warn > 0.0:
		out.append(["pet", "¡SUELTA AL PERRO!", "El dueño te ha visto. Te quedan " + str(ceili(h.pet_warn)) + " s antes de que te denuncie.", warn])
	if h.quiz_id != 0 and w.quiz.is_empty() and h.alive:
		out.append(["bell", "TE BUSCA UN BOTONES", "Te hará tres preguntas sobre el hotel. Repasa el mapa (M).", warn])
	if h.bad_fit and h.alive and _fit_t < 9.0:
		out.append(["fit", "DISFRAZ PENOSO", "Esta ropa no es de tu género: te descubrirán antes.", warn])
	return out

func _update_cards(delta: float) -> void:
	var live := {}
	for n in _notices():
		var k: String = n[0]
		live[k] = true
		if not _cards.has(k):
			_cards[k] = {"a": 0.0}
			_card_order.append(k)
		var c: Dictionary = _cards[k]
		c["title"] = n[1]
		c["text"] = n[2]
		c["col"] = n[3]
		c["a"] = minf(1.0, float(c["a"]) + delta * 4.0)
	for k2 in _card_order.duplicate():
		if live.has(k2):
			continue
		var c2: Dictionary = _cards[k2]
		c2["a"] = float(c2["a"]) - delta * 4.0
		if float(c2["a"]) <= 0.0:
			_cards.erase(k2)
			_card_order.erase(k2)
	if w != null and w.human != null:
		_fit_t = _fit_t + delta if w.human.bad_fit else 0.0
		if w.central.is_empty():
			_central_age = 0.0
			_central_msg = ""
		else:
			if str(w.central["msg"]) != _central_msg:
				_central_msg = str(w.central["msg"])
				_central_age = 0.0
			_central_age += delta

## Hay una ventana que se queda con el teclado y el ratón.
func modal() -> bool:
	return loot_key != "" or intro_t > 0.0 or travel_t > 0.0 or (w != null and not w.quiz.is_empty())

func open_loot(d: Dictionary) -> void:
	loot_key = str(d["key"])
	loot_title = str(d["title"])
	loot_col = 0
	loot_row = 0
	loot_msg = ""
	if Loot.contents(w, loot_key).is_empty():
		loot_col = 1

func close_loot() -> void:
	loot_key = ""
	if w != null:
		w.flags["loot_closed"] = true

func _process(delta: float) -> void:
	anim += delta
	if intro_t > 0.0:
		intro_t = maxf(0.0, intro_t - delta)
	if travel_t > 0.0:
		travel_t = maxf(0.0, travel_t - delta)
	_update_cards(delta)
	if loot_key != "" and w != null:
		var near := Loot.nearest(w, w.human)
		if near.is_empty() or str(near["key"]) != loot_key:
			close_loot()
	mouse_filter = Control.MOUSE_FILTER_STOP if modal() else Control.MOUSE_FILTER_IGNORE
	queue_redraw()
	foes.queue_redraw()

## Teclas que llegan desde la escena: "1", "2", "3", "up", "down", "left", "right", "use".
func key(k: String) -> bool:
	if intro_t > 0.0:
		if k == "use" and intro_t < INTRO - 0.6:
			intro_t = minf(intro_t, 0.5)
		return true
	if travel_t > 0.0:
		return true
	if w == null:
		return false
	if not w.quiz.is_empty():
		if k in ["1", "2", "3"]:
			Heat.answer(w, int(k) - 1)
			sound.emit("ui")
		return true
	if loot_key != "":
		match k:
			"up":
				loot_row -= 1
			"down":
				loot_row += 1
			"left":
				loot_col = 0
				loot_row = 0
			"right":
				loot_col = 1
				loot_row = 0
			"use":
				_loot_act(loot_col, loot_row)
		_clamp_rows()
		return true
	return false

func _clamp_rows() -> void:
	if w == null or w.human == null:
		return
	var n: int = Loot.contents(w, loot_key).size() if loot_col == 0 else Loot.carried(w.human).size()
	loot_row = clampi(loot_row, 0, maxi(0, n - 1))

func _loot_act(col: int, row: int) -> void:
	var h := w.human
	if h == null or loot_key == "":
		return
	if col == 0:
		var items: Array = Loot.contents(w, loot_key)
		if row < items.size():
			loot_msg = Loot.take(w, h, items[row])
			if loot_msg == "":
				loot_msg = "Cogido."
	else:
		var mine: Array = Loot.carried(h)
		if row < mine.size():
			if Loot.store(w, h, loot_key, str(mine[row]["kind"])):
				loot_msg = "Guardado."
	_clamp_rows()

func _gui_input(ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	for hz in _hot:
		var r: Rect2 = hz[0]
		if r.has_point(mb.position):
			match String(hz[1]):
				"quiz":
					Heat.answer(w, int(hz[2]))
					sound.emit("ui")
				"take":
					loot_col = 0
					loot_row = int(hz[2])
					_loot_act(0, loot_row)
				"store":
					loot_col = 1
					loot_row = int(hz[2])
					_loot_act(1, loot_row)
				"close":
					close_loot()
			return

# ---------------------------------------------------------------- dibujo

func _txt(p: Vector2, s: String, fs: int, col: Color, width: float = -1.0) -> void:
	draw_string(Painter.font(), p, s, HORIZONTAL_ALIGNMENT_LEFT, width, fs, col)

func _wrap(p: Vector2, s: String, fs: int, col: Color, width: float, lines: int = 4) -> void:
	draw_multiline_string(Painter.font(), p, s, HORIZONTAL_ALIGNMENT_LEFT, width, fs, lines, col)

func _panel(r: Rect2) -> void:
	draw_rect(r.grow(3), Color(0, 0, 0, 0.55))
	draw_rect(r, C_BG)
	draw_rect(r, C_GOLD, false, 2.0)
	draw_rect(r.grow(-5), Color(0.92, 0.82, 0.54, 0.25), false, 1.0)

func _draw() -> void:
	_hot.clear()
	if intro_t > 0.0:
		_draw_intro()
		return
	if w == null or w.human == null:
		return
	var h := w.human
	# avisos a la izquierda: la central arriba y debajo las tarjetas, todos con entrada y salida deslizante
	var ny := size.y * 0.36
	if not w.central.is_empty():
		_draw_central(ny)
		ny += 140.0
	for ck in _card_order:
		var cd: Dictionary = _cards[ck]
		var ca: float = cd["a"]
		var ce := 1.0 - pow(1.0 - clampf(ca, 0.0, 1.0), 3.0)
		var cr := Rect2(14.0 - (1.0 - ce) * 420.0, ny, 392, 66)
		var ccol: Color = cd["col"]
		draw_rect(cr.grow(2), Color(0, 0, 0, 0.5))
		draw_rect(cr, C_BG)
		draw_rect(Rect2(cr.position, Vector2(6, cr.size.y)), ccol)
		draw_rect(cr, Color(ccol, 0.7), false, 1.5)
		_txt(cr.position + Vector2(18, 24), str(cd["title"]), 15, ccol, 364.0)
		_wrap(cr.position + Vector2(18, 43), str(cd["text"]), 12, C_TEXT, 364.0, 2)
		ny += 74.0
	if travel_t > 0.0:
		_draw_travel()
		return
	if not w.quiz.is_empty():
		_draw_quiz()
	elif loot_key != "":
		_draw_loot()
	elif not quiet and h.alive and h.away_t <= 0:
		var near := Loot.nearest(w, h)
		if not near.is_empty():
			var n: int = Loot.contents(w, str(near["key"])).size()
			var hint := "R · Registrar " + str(near["title"]) + ("" if n == 0 else "  (hay algo)") if str(near["key"]).begins_with("c:") else "R · Registrar " + str(near["title"])
			Painter.text(self, size.x / 2.0, size.y - 168, hint, 13, C_GOLD, 4)

## Ventanita con el policía de la sala de escuchas que te habla por el pinganillo.
func _draw_central(y0: float) -> void:
	var t: float = w.central["t"]
	var msg: String = w.central["msg"]
	var r := Rect2(14, y0, 500, 128)
	# entra deslizándose desde la izquierda y se va por donde vino
	var a := clampf(minf(_central_age, t) / 0.3, 0.0, 1.0)
	var ea := 1.0 - pow(1.0 - a, 3.0)
	draw_set_transform(Vector2((1.0 - ea) * -540.0, 0), 0.0, Vector2.ONE)
	_panel(r)
	# pantalla: sala de escuchas con el agente y sus auriculares
	var s := Rect2(r.position + Vector2(12, 12), Vector2(124, 104))
	draw_rect(s, Color("#0b1622"))
	draw_rect(Rect2(s.position.x, s.position.y + 70, s.size.x, 34), Color("#1c2b3a"))
	for i in 3:
		var bx := s.position.x + 8 + i * 12.0
		draw_rect(Rect2(bx, s.position.y + 10, 8, 26), Color("#22364a"))
		draw_circle(Vector2(bx + 4, s.position.y + 16 + i * 6.0), 2.0, Color("#7ee08a") if fmod(anim * 3.0 + i, 2.0) < 1.0 else Color("#2c5a36"))
	# magnetófono de bobinas
	for k in 2:
		var cc := Vector2(s.position.x + 86 + k * 22.0, s.position.y + 28)
		draw_circle(cc, 9.0, Color("#3a4654"))
		draw_circle(cc, 3.0, Color("#0b1622"))
		draw_line(cc, cc + Vector2(cos(anim * 4.0 + k), sin(anim * 4.0 + k)) * 8.0, Color("#9fb0c0"), 1.5)
	if _cop == null:
		_cop = Outfit.new_police()
		_cop.hat_t = "none"
	Painter.draw_actor(self, s.position.x + 56, s.position.y + 96, _cop, "down", 0.0, false, 0.0, 2.6)
	var hc := Vector2(s.position.x + 56, s.position.y + 46)
	draw_arc(hc, 15.0, PI, TAU, 12, Color("#15181d"), 3.0)
	draw_rect(Rect2(hc.x - 19, hc.y - 4, 6, 12), Color("#15181d"))
	draw_rect(Rect2(hc.x + 13, hc.y - 4, 6, 12), Color("#15181d"))
	draw_line(hc + Vector2(-16, 6), hc + Vector2(-8, 16), Color("#15181d"), 2.0)
	draw_rect(Rect2(s.position.x, s.position.y + 84, s.size.x, 20), Color("#2a1e14"))
	for y in range(0, int(s.size.y), 3):
		draw_rect(Rect2(s.position.x, s.position.y + y, s.size.x, 1), Color(0, 0, 0, 0.22))
	draw_rect(s, Color(0.5, 0.8, 1.0, 0.05 + 0.03 * sin(anim * 30.0)))
	draw_rect(s, C_GOLD, false, 1.0)
	_txt(r.position + Vector2(150, 30), "CENTRAL · LÍNEA SEGURA", 12, C_GOLD)
	draw_circle(r.position + Vector2(480, 24), 4.0, C_RED if fmod(anim, 1.0) < 0.5 else Color("#5a2228"))
	var shown := int(clampf((float(msg.length()) + 20.0) * (1.0 - (t - 1.5) / 5.5), 0.0, float(msg.length())))
	_wrap(r.position + Vector2(150, 52), msg.substr(0, shown), 14, C_TEXT, 336.0, 4)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_quiz() -> void:
	var q: Dictionary = w.quiz
	var qs: Array = q["qs"]
	var i: int = mini(int(q["i"]), qs.size() - 1)
	var cur: Dictionary = qs[i]
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
	var r := Rect2((size.x - 640.0) / 2.0, (size.y - 300.0) / 2.0, 640, 300)
	_panel(r)
	var bell := w.ent_by_id(int(q["bell"]))
	draw_rect(Rect2(r.position + Vector2(16, 16), Vector2(130, 268)), Color("#1a1f27"))
	if bell != null:
		Painter.draw_actor(self, r.position.x + 81, r.position.y + 210, bell.outfit, "down", 0.0, false, 0.0, 4.2)
	_txt(r.position + Vector2(166, 36), "INTERROGATORIO · PREGUNTA " + str(i + 1) + " DE " + str(qs.size()), 13, C_GOLD)
	var fails: int = q["fail"]
	_txt(r.position + Vector2(166, 56), "Fallos: " + str(fails) + " de 2 · si fallas dos, te echan del hotel", 12, C_RED if fails > 0 else C_MUT)
	_wrap(r.position + Vector2(166, 92), str(cur["q"]), 18, C_TEXT, 450.0, 2)
	var opts: Array = cur["a"]
	var mp := get_local_mouse_position()
	for k in opts.size():
		var br := Rect2(r.position + Vector2(166, 138 + k * 40.0), Vector2(450, 34))
		var hov := br.has_point(mp)
		draw_rect(br, Color(0.92, 0.82, 0.54, 0.22) if hov else Color(1, 1, 1, 0.06))
		draw_rect(br, Color(0.92, 0.82, 0.54, 0.5), false, 1.0)
		_txt(br.position + Vector2(12, 23), str(k + 1) + "  ·  " + str(opts[k]), 15, C_TEXT)
		_hot.append([br, "quiz", k])
	var tl := clampf(float(q["t"]) / Heat.QUIZ_TIME, 0.0, 1.0)
	draw_rect(Rect2(r.position + Vector2(166, 268), Vector2(450, 6)), Color("#1a1f27"))
	draw_rect(Rect2(r.position + Vector2(166, 268), Vector2(450 * tl, 6)), C_GOLD if tl > 0.3 else C_RED)
	_txt(r.position + Vector2(166, 290), "Pulsa 1, 2 o 3 (o haz clic). Si se acaba el tiempo, cuenta como fallo.", 11, C_MUT)

func _draw_loot() -> void:
	var h := w.human
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
	var r := Rect2((size.x - 660.0) / 2.0, (size.y - 360.0) / 2.0, 660, 360)
	_panel(r)
	_txt(r.position + Vector2(20, 34), "REGISTRAR · " + loot_title.to_upper(), 17, C_GOLD, 560.0)
	var xr := Rect2(r.position + Vector2(620, 12), Vector2(26, 26))
	draw_rect(xr, Color(1, 1, 1, 0.08))
	_txt(xr.position + Vector2(8, 19), "×", 16, C_TEXT)
	_hot.append([xr, "close", 0])
	var items: Array = Loot.contents(w, loot_key)
	var mine: Array = Loot.carried(h)
	var mp := get_local_mouse_position()
	for col in 2:
		var x0 := r.position.x + 20 + col * 320.0
		_txt(Vector2(x0, r.position.y + 66), "DENTRO" if col == 0 else "LLEVAS ENCIMA", 12, C_MUT)
		draw_rect(Rect2(x0, r.position.y + 74, 300, 1), Color(0.92, 0.82, 0.54, 0.4))
		var n: int = items.size() if col == 0 else mine.size()
		if n == 0:
			_txt(Vector2(x0, r.position.y + 100), "Vacío." if col == 0 else "No llevas nada que dejar.", 13, C_MUT)
		for k in mini(n, 7):
			var br := Rect2(x0, r.position.y + 82 + k * 32.0, 300, 28)
			var sel: bool = loot_col == col and loot_row == k
			var hov := br.has_point(mp)
			draw_rect(br, Color(0.92, 0.82, 0.54, 0.25) if sel else (Color(1, 1, 1, 0.1) if hov else Color(1, 1, 1, 0.04)))
			if sel:
				draw_rect(br, C_GOLD, false, 1.0)
			var label := ""
			var ok := true
			if col == 0:
				var p: Items.Pick = items[k]
				label = Loot.pick_label(p)
				ok = Sim.can_take(h, p)
				if p.by != 0 and p.by != h.id:
					label += "  (lo dejó alguien)"
			else:
				label = str(mine[k]["label"])
			_txt(br.position + Vector2(10, 19), label, 14, C_TEXT if ok else Color(0.6, 0.6, 0.6), 280.0)
			_hot.append([br, "take" if col == 0 else "store", k])
	var note := "Si se llevan el cadáver, se pierde lo que haya dentro." if loot_key.begins_with("c:") else "Lo que dejes en una habitación que no es la tuya se lo acabarán llevando las limpiadoras."
	_txt(r.position + Vector2(20, 318), note, 11, C_MUT, 620.0)
	_txt(r.position + Vector2(20, 340), "↑↓ elegir · ←→ cambiar de lado · E o clic: coger / dejar · R o Esc: cerrar", 11, C_MUT, 480.0)
	if loot_msg != "":
		var mw := Painter.font().get_string_size(loot_msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		_txt(r.position + Vector2(640 - mw, 340), loot_msg, 12, C_GOLD)

## Presentación de la ronda: tu equipo a la vista y el contrario en silueta.
func _draw_intro() -> void:
	var p := 1.0 - intro_t / INTRO
	var a := clampf(intro_t / 0.6, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.03, a))
	if a < 1.0:
		return
	var hunter: bool = w.human.role == "hunter"
	var cx := size.x / 2.0
	# haz de proyector y grano de película antigua
	var flick := 0.9 + 0.1 * sin(anim * 40.0) * sin(anim * 7.0)
	Painter.poly(self, [Vector2(cx - 60, 0), Vector2(cx + 60, 0), Vector2(cx + size.x * 0.42, size.y), Vector2(cx - size.x * 0.42, size.y)], Color(1.0, 0.95, 0.8, 0.045 * flick))
	for i in 5:
		var gx := fmod(absf(sin(floorf(anim * 12.0) * 12.9 + i * 78.2)) * 4375.5, 1.0) * size.x
		draw_rect(Rect2(gx, 0, 1, size.y), Color(1, 1, 1, 0.05))
	var title := "CAZADORES" if hunter else "CORREDORES"
	var tk := clampf(p / 0.12, 0.0, 1.0)
	Painter.text(self, cx, size.y * 0.16, "ERES DE LOS", 15, Color(C_MUT, tk), 0)
	Painter.text(self, cx, size.y * 0.16 + 50, title, 50, Color(C_RED if hunter else Color("#6fb8ff"), tk), 6)
	var sub := "Policía secreta. Que no quede un corredor con vida… sin que el hotel se entere." if hunter else "La banda. Terminad los encargos antes de que llegue el cliente y seguid vivos."
	Painter.text(self, cx, size.y * 0.16 + 78, sub, 14, Color(C_TEXT, tk), 0)
	# tu equipo
	var y1 := size.y * 0.55
	var gap := 150.0
	var n1 := _mates.size()
	for i in n1:
		var k := clampf((p - 0.15 - i * 0.07) / 0.1, 0.0, 1.0)
		if k <= 0.0:
			continue
		var e: Ent = _mates[i]
		var x := cx + (i - (n1 - 1) / 2.0) * gap
		Painter.ellipse(self, x, y1 + 6, 46, 12, Color(1.0, 0.92, 0.7, 0.10 * k))
		Painter.draw_actor(self, x, y1 - (1.0 - k) * 14.0, e.outfit, "down", 0.0, false, 0.0, 3.4)
		Painter.text(self, x, y1 + 30, e.nm + (" (tú)" if e == w.human else ""), 14, Color(C_GOLD if e == w.human else C_TEXT, k), 3)
		if e.rperk != "" and e == w.human:
			Painter.text(self, x, y1 + 48, str(Loot.RPERK_NAMES[e.rperk]), 11, Color(C_GOLD, k), 3)
	# el otro bando: focos rojos; las siluetas las pinta el control hijo
	var k2 := clampf((p - 0.5) / 0.12, 0.0, 1.0)
	if k2 > 0.0:
		var y2 := size.y * 0.86
		Painter.text(self, cx, y2 - 118, "CONTRA", 15, Color(C_MUT, k2), 0)
		var n2 := _foes.size()
		for i in n2:
			var x2 := cx + (i - (n2 - 1) / 2.0) * gap
			Painter.ellipse(self, x2, y2 - 40, 50, 66, Color(0.42, 0.07, 0.08, 0.5 * k2), 20)
			Painter.ellipse(self, x2, y2 + 6, 46, 12, Color(0.6, 0.1, 0.1, 0.35 * k2))
			Painter.text(self, x2, y2 + 30, "¿ ?", 14, Color(C_RED, k2), 3)
	# franjas de cine
	draw_rect(Rect2(0, 0, size.x, size.y * 0.07), Color.BLACK)
	draw_rect(Rect2(0, size.y * 0.93, size.x, size.y * 0.07), Color.BLACK)
	Painter.text(self, size.x - 110, size.y * 0.93 + 22, "E · saltar", 11, C_MUT, 0)

## Uno o dos segundos viendo al personaje subir o bajar por la escalera, o dentro del ascensor.
func _draw_travel() -> void:
	var p := 1.0 - travel_t / travel_dur
	var a := clampf(minf(p / 0.08, (1.0 - p) / 0.1), 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.03, a))
	if a < 0.5:
		return
	var up: bool = _tr_to > _tr_from
	var r := Rect2((size.x - 620.0) / 2.0, (size.y - 360.0) / 2.0, 620, 360)
	_panel(r)
	var nf: int = Hotel.floors.size()
	var from_l := str(Hotel.floors[clampi(_tr_from, 0, nf - 1)].label)
	var to_l := str(Hotel.floors[clampi(_tr_to, 0, nf - 1)].label)
	var inner := Rect2(r.position + Vector2(16, 54), Vector2(588, 290))
	if travel_kind == "stairs":
		_txt(r.position + Vector2(20, 34), ("SUBIENDO A " if up else "BAJANDO A ") + to_l.to_upper(), 17, C_GOLD, 580.0)
		draw_rect(inner, Color("#3b2618"))
		for i in 12:
			draw_rect(Rect2(inner.position.x + i * 49.0, inner.position.y, 24, inner.size.y), Color(0, 0, 0, 0.08))
		draw_rect(Rect2(inner.position.x, inner.position.y + 86, inner.size.x, 3), Color("#c9a24b"))
		# ocho peldaños que suben hacia la derecha, con su barandilla
		var sw := 62.0
		var sh := 26.0
		var bx := inner.position.x + 44.0
		var by := inner.end.y - 28.0
		for i in 8:
			var sx := bx + i * sw
			var sy := by - (i + 1) * sh
			draw_rect(Rect2(sx, sy, sw + 1.0, inner.end.y - sy), Color("#6b4526").darkened(0.04 * (i % 2)))
			draw_rect(Rect2(sx, sy, sw + 1.0, 4), Color("#c9a24b"))
			draw_rect(Rect2(sx + sw * 0.5 - 1.5, sy - 46, 3, 46), Color("#23262b"))
		draw_line(Vector2(bx + sw * 0.5, by - sh - 46), Vector2(bx + 7.5 * sw, by - 8 * sh - 46), Color("#b8923f"), 5.0)
		var q := p if up else 1.0 - p
		var si := clampf(q * 8.6 - 0.3, 0.0, 7.6)
		var fx := bx + (si + 0.5) * sw
		var fy := by - (floorf(si) + 1.0) * sh - absf(sin(si * PI)) * 5.0
		if _tr_outfit != null:
			Painter.ellipse(self, fx, fy + 2, 22, 5, Color(0, 0, 0, 0.3))
			Painter.draw_actor(self, fx, fy - 2, _tr_outfit, "right" if up else "left", anim * 12.0, false, 0.0, 2.5)
		_txt(r.position + Vector2(20, 352), "Desde " + from_l, 11, C_MUT)
		return
	# ascensor: cabina de latón, aguja del indicador y puertas que se cierran y se abren
	_txt(r.position + Vector2(20, 34), "ASCENSOR · " + from_l.to_upper() + "  →  " + to_l.to_upper(), 17, C_GOLD, 580.0)
	draw_rect(inner, Color("#2a2018"))
	var cab := Rect2(inner.position + Vector2(154, 70), Vector2(280, 214))
	var shake_y := sin(anim * 38.0) * 1.5 if (p > 0.25 and p < 0.75) else 0.0
	cab.position.y += shake_y
	draw_rect(cab.grow(8), Color("#8f7330"))
	draw_rect(cab, Color("#5a3b28"))
	draw_rect(Rect2(cab.position.x, cab.position.y + 150, cab.size.x, 4), Color("#c9a24b"))
	for i in 5:
		draw_rect(Rect2(cab.position.x + 20 + i * 56.0, cab.position.y + 14, 16, 128), Color(0, 0, 0, 0.12))
	draw_circle(cab.position + Vector2(140, 22), 9.0, Color("#ffe6a8"))
	if _tr_outfit != null:
		Painter.draw_actor(self, cab.position.x + 140, cab.end.y - 24, _tr_outfit, "down", 0.0, false, 0.0, 3.2)
	# puertas
	var open := 1.0 - clampf(p / 0.22, 0.0, 1.0) if p < 0.5 else clampf((p - 0.8) / 0.2, 0.0, 1.0)
	var dw := cab.size.x / 2.0 * (1.0 - open)
	for sd in [-1.0, 1.0]:
		var sdf: float = sd
		var dx := cab.position.x if sdf < 0 else cab.end.x - dw
		draw_rect(Rect2(dx, cab.position.y, dw, cab.size.y), Color("#b8923f"))
		if dw > 24.0:
			draw_rect(Rect2(dx + 8, cab.position.y + 10, dw - 16, cab.size.y - 20), Color("#dcc070"), false, 2.0)
			var fxc := dx + dw / 2.0
			Painter.poly(self, [Vector2(fxc, cab.position.y + 40), Vector2(fxc + minf(dw * 0.3, 34.0), cab.position.y + 150), Vector2(fxc - minf(dw * 0.3, 34.0), cab.position.y + 150)], Color("#dcc070"))
		draw_rect(Rect2(dx + (dw - 2.0 if sdf < 0 else 0.0), cab.position.y, 2, cab.size.y), Color("#3a2c14"))
	# indicador de planta: media esfera con una marca por planta y la aguja
	var ic := Vector2(inner.position.x + inner.size.x / 2.0, inner.position.y + 58)
	draw_arc(ic, 44.0, PI, TAU, 24, Color("#c9a24b"), 3.0)
	for i in nf:
		var ta := PI + PI * (i + 0.5) / nf
		draw_line(ic + Vector2(cos(ta), sin(ta)) * 38.0, ic + Vector2(cos(ta), sin(ta)) * 44.0, C_GOLD, 2.0)
		Painter.text(self, ic.x + cos(ta) * 58.0, ic.y + sin(ta) * 58.0 + 4.0, str(Sim.FLOOR_SHORT[i]), 9, C_MUT, 0)
	var mv := clampf((p - 0.22) / 0.56, 0.0, 1.0)
	var fi := lerpf(float(_tr_from), float(_tr_to), mv * mv * (3.0 - 2.0 * mv))
	var na := PI + PI * (fi + 0.5) / nf
	draw_line(ic, ic + Vector2(cos(na), sin(na)) * 36.0, C_RED, 2.5)
	draw_circle(ic, 4.0, C_GOLD)

func _draw_foes() -> void:
	if intro_t <= 0.6 or w == null or w.human == null:
		return
	var p := 1.0 - intro_t / INTRO
	if p < 0.5:
		return
	var cx := size.x / 2.0
	var y2 := size.y * 0.86
	var n2 := _foes.size()
	for i in n2:
		var e: Ent = _foes[i]
		var x2 := cx + (i - (n2 - 1) / 2.0) * 150.0
		Painter.draw_actor(foes, x2, y2, e.outfit, "down", 0.0, false, 0.0, 3.4)
