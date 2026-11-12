## Minijuegos de los encargos, cerraduras y esposas. Dificultad media y cortos (unos 3-8 s).
##  timing:   para la aguja en la zona verde (E o Espacio) varias veces
##  sequence: memoriza una secuencia de flechas y repítela
##  balance:  mantén el indicador dentro de la zona con A/D o ←/→ hasta llenar la barra
##  wires:    conecta cada cable con su color pulsando 1, 2 o 3
##  lockpick: ganzúa: busca el punto con A/D y gira el bombín manteniendo E; si fuerzas, se rompe
##  mic:      coloca el micrófono cuando nadie mira (←/→ y E) y después conecta sus cables
##  stash:    empuja el paquete debajo del mueble cuando pase por el hueco (E)
class_name PickGame
extends Control

signal finished(ok: bool)
signal pick_broken

const ARROW := {"up": "↑", "down": "↓", "left": "←", "right": "→"}
const DIRS := ["up", "right", "down", "left"]
const WIRE_COLS := [Color("#d6453c"), Color("#4f86d8"), Color("#e2c04a")]

var mode := "timing"
var title := ""
var active := false
var t := 0.0
var limit := 10.0
var fail_msg := ""
var result_t := 0.0
var result_ok := false
# timing
var pins := 0
var need := 3
var pos := 0.0
var dir := 1.0
var speed := 1.3
var zone := 0.5
var zone_w := 0.14
# sequence
var seq: Array = []
var idx := 0
var show_t := 0.0
var tries := 0
# balance
var bpos := 0.5
var bvel := 0.0
var bzone := 0.5
var fill := 0.0
# wires
var left_cols: Array = []
var right_cols: Array = []
var wire_i := 0
# lockpick
var tough := 1.0          # aguante de la ganzúa (habilidad «dedos de seda»: 2)
var lp_pos := 0.5
var lp_spot := 0.5
var lp_turn := 0.0
var lp_hp := 1.0
var lp_left := 1
var lp_jam := false
var lp_flash := 0.0
# mic
var mic_phase := 0
var mic_spot := 1
const MIC_SPOTS := ["la lámpara", "el cuadro", "el teléfono"]

func start(m: String, ttl: String, pins_needed: int = 3) -> void:
	mode = m
	title = ttl
	active = true
	visible = true
	t = 0.0
	fail_msg = ""
	result_t = 0.0
	match mode:
		"timing", "stash":
			pins = 0
			need = pins_needed
			pos = 0.0
			dir = 1.0
			limit = 4.0 + need * 2.0
			_new_zone()
		"lockpick":
			lp_left = maxi(1, pins_needed)
			lp_pos = 0.5
			lp_spot = randf_range(0.08, 0.92)
			lp_turn = 0.0
			lp_hp = 1.0
			lp_jam = false
			lp_flash = 0.0
			limit = 30.0
		"mic":
			mic_phase = 0
			mic_spot = 1
			left_cols = [0, 1, 2]
			left_cols.shuffle()
			right_cols = [0, 1, 2]
			right_cols.shuffle()
			wire_i = 0
			limit = 14.0
		"sequence":
			seq = []
			for i in 5:
				seq.append(DIRS[randi_range(0, 3)])
			idx = 0
			show_t = 2.4
			tries = 0
			limit = 12.0
		"balance":
			bpos = 0.5
			bvel = 0.0
			bzone = 0.5
			fill = 0.0
			limit = 9.0
		"wires":
			left_cols = [0, 1, 2]
			left_cols.shuffle()
			right_cols = [0, 1, 2]
			right_cols.shuffle()
			wire_i = 0
			limit = 7.0

func _new_zone() -> void:
	zone = randf_range(0.15, 0.85)
	zone_w = maxf(0.08, 0.16 - pins * 0.02)
	speed = 1.25 + pins * 0.3

func _process(delta: float) -> void:
	if result_t > 0:
		result_t -= delta
		queue_redraw()
		if result_t <= 0:
			visible = false
			finished.emit(result_ok)
		return
	if not active:
		return
	t += delta
	if t > limit:
		_end(false, "Se acabó el tiempo")
		return
	match mode:
		"timing", "stash":
			pos += dir * speed * delta
			if pos > 1.0:
				pos = 1.0
				dir = -1.0
			elif pos < 0.0:
				pos = 0.0
				dir = 1.0
		"lockpick":
			_lockpick(delta)
		"sequence":
			if show_t > 0:
				show_t -= delta
		"balance":
			var push := 0.0
			if Input.is_action_pressed("move_left"):
				push -= 1.0
			if Input.is_action_pressed("move_right"):
				push += 1.0
			# el indicador se va solo hacia un lado y la zona se mueve despacio
			bvel += (push * 2.6 + sin(t * 2.3) * 1.4 + sin(t * 5.1) * 0.6) * delta
			bvel *= 0.92
			bpos = clampf(bpos + bvel * delta, 0.0, 1.0)
			bzone = 0.5 + sin(t * 0.9) * 0.25
			if absf(bpos - bzone) < 0.09:
				fill += delta / 3.0
			else:
				fill = maxf(0.0, fill - delta * 0.15)
			if fill >= 1.0:
				_end(true, "")
	queue_redraw()

## Tecla pulsada: "use", "up", "down", "left", "right", "1", "2", "3".
func press(k: String) -> void:
	if not active:
		return
	match mode:
		"mic":
			if mic_phase == 1:
				_wire_press(k)
			elif k == "left":
				mic_spot = maxi(0, mic_spot - 1)
			elif k == "right":
				mic_spot = mini(2, mic_spot + 1)
			elif k == "use":
				if _watched():
					_end(false, "Te han visto: espera a que no mire")
				else:
					mic_phase = 1
		"timing", "stash":
			if k != "use":
				return
			if absf(pos - zone) <= zone_w / 2.0:
				pins += 1
				if pins >= need:
					_end(true, "")
					return
			else:
				pins = maxi(0, pins - 1)
			_new_zone()
		"sequence":
			if show_t > 0 or not (k in DIRS):
				return
			if seq[idx] == k:
				idx += 1
				if idx >= seq.size():
					_end(true, "")
			else:
				tries += 1
				if tries >= 2:
					_end(false, "Te has equivocado")
				else:
					idx = 0
					show_t = 1.8
		"wires":
			_wire_press(k)

func _wire_press(k: String) -> void:
	if not (k in ["1", "2", "3"]):
		return
	var slot := int(k) - 1
	if right_cols[slot] == left_cols[wire_i]:
		wire_i += 1
		if wire_i >= 3:
			_end(true, "")
	else:
		_end(false, "Cable equivocado: ¡chispazo!")

## Micrófono: ¿está mirando el huésped del pasillo?
func _watched() -> bool:
	return fmod(t, 3.2) < 1.5

## Ganzúa: A/D mueven la ganzúa; mantener E gira el bombín. Cuanto más lejos del punto bueno,
## menos gira antes de atascarse, y atascada la ganzúa se va doblando hasta romperse.
func _lockpick(delta: float) -> void:
	if lp_flash > 0.0:
		lp_flash -= delta
	var turning := Input.is_action_pressed("use") and t > 0.45
	lp_jam = false
	if not turning:
		var mv := 0.0
		if Input.is_action_pressed("move_left"):
			mv -= 1.0
		if Input.is_action_pressed("move_right"):
			mv += 1.0
		lp_pos = clampf(lp_pos + mv * 0.5 * delta, 0.0, 1.0)
		lp_turn = maxf(0.0, lp_turn - delta * 2.0)
		return
	var off := absf(lp_pos - lp_spot)
	var max_turn := 1.0 if off <= 0.035 else clampf(0.9 - (off - 0.035) / 0.28, 0.0, 0.9)
	if lp_turn < max_turn:
		lp_turn = minf(max_turn, lp_turn + delta * 1.25)
		if lp_turn >= 0.999:
			_end(true, "")
	else:
		lp_jam = true
		lp_hp -= delta * 0.85 / maxf(tough, 0.1)
		if lp_hp <= 0.0:
			lp_left -= 1
			pick_broken.emit()
			if lp_left <= 0:
				_end(false, "Se te ha roto la última ganzúa")
			else:
				lp_hp = 1.0
				lp_turn = 0.0
				lp_flash = 0.9

func cancel() -> void:
	if active:
		_end(false, "Lo dejas a medias")

func _end(ok: bool, msg: String) -> void:
	active = false
	result_ok = ok
	fail_msg = msg
	result_t = 0.6

func _draw() -> void:
	var f := Painter.font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.06, 0.09, 0.97))
	draw_rect(Rect2(Vector2.ZERO, size), Color("#ebd08a"), false, 2.0)
	draw_string(f, Vector2(18, 30), title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 18, Color("#ebd08a"))
	var help := ""
	var dm := "wires" if (mode == "mic" and mic_phase == 1) else mode
	match mode:
		"lockpick":
			help = "A/D mueven la ganzúa · mantén E para girar · si se atasca, suelta"
		"mic":
			help = "Conecta el micrófono: pulsa 1, 2 o 3" if mic_phase == 1 else "←/→ eliges el escondite · E lo colocas cuando no mire nadie"
		"stash":
			help = "Pulsa E cuando el paquete pase por el hueco (" + str(need) + " empujones)"
		"timing":
			help = "Pulsa E cuando la aguja esté en la zona verde (" + str(need) + " aciertos)"
		"sequence":
			help = "Memoriza las flechas y repítelas (flechas o WASD)" if show_t <= 0 else "Memoriza…"
		"balance":
			help = "Mantén el indicador en la zona con A/D o ←/→"
		"wires":
			help = "Conecta cada cable de la izquierda con su color: pulsa 1, 2 o 3"
	draw_string(f, Vector2(18, 50), help + " · Esc para dejarlo", HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 12, Color("#a9b2b8"))
	# tiempo restante
	var tl := clampf(1.0 - t / limit, 0.0, 1.0)
	draw_rect(Rect2(18, size.y - 14, (size.x - 36) * tl, 4), Color("#ebd08a") if tl > 0.3 else Color("#ff6a78"))
	match dm:
		"lockpick":
			_draw_lockpick(f)
		"mic":
			_draw_mic(f)
		"stash":
			_draw_stash()
		"timing":
			var bar := Rect2(18, 70, size.x - 36, 26)
			draw_rect(bar, Color("#1a1f27"))
			draw_rect(Rect2(bar.position.x + bar.size.x * (zone - zone_w / 2.0), bar.position.y, bar.size.x * zone_w, bar.size.y), Color("#4caf6a"))
			var px := bar.position.x + bar.size.x * pos
			draw_rect(Rect2(px - 2, bar.position.y - 6, 4, bar.size.y + 12), Color("#efe8d4"))
			for i in need:
				draw_circle(Vector2(30 + i * 26, 118), 8, Color("#ebd08a") if i < pins else Color("#2f4152"))
		"sequence":
			for i in seq.size():
				var cx := 40.0 + i * 64.0
				draw_rect(Rect2(cx - 24, 70, 48, 48), Color("#1a1f27"))
				var shown: bool = show_t > 0 or i < idx
				if shown:
					var col := Color("#4caf6a") if i < idx else Color("#efe8d4")
					draw_arrow(self, Vector2(cx, 94), str(seq[i]), 16.0, col)
		"balance":
			var bar := Rect2(18, 74, size.x - 36, 22)
			draw_rect(bar, Color("#1a1f27"))
			draw_rect(Rect2(bar.position.x + bar.size.x * (bzone - 0.09), bar.position.y, bar.size.x * 0.18, bar.size.y), Color(0.3, 0.69, 0.42, 0.8))
			draw_rect(Rect2(bar.position.x + bar.size.x * bpos - 3, bar.position.y - 6, 6, bar.size.y + 12), Color("#efe8d4"))
			draw_rect(Rect2(18, 110, (size.x - 36), 8), Color("#1a1f27"))
			draw_rect(Rect2(18, 110, (size.x - 36) * fill, 8), Color("#ebd08a"))
		"wires":
			for i in 3:
				var ly := 76.0 + i * 22.0
				var lc: Color = WIRE_COLS[left_cols[i]]
				draw_rect(Rect2(24, ly, 40, 10), lc if i >= wire_i else lc.darkened(0.6))
				var rc: Color = WIRE_COLS[right_cols[i]]
				draw_rect(Rect2(size.x - 64, ly, 40, 10), rc)
				draw_string(f, Vector2(size.x - 84, ly + 10), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#efe8d4"))
				if i < wire_i:
					var target_slot: int = right_cols.find(left_cols[i])
					draw_line(Vector2(64, ly + 5), Vector2(size.x - 64, 76.0 + target_slot * 22.0 + 5), lc, 3.0)
			if wire_i < 3:
				draw_arc(Vector2(18, 81 + wire_i * 22.0), 5, 0, TAU, 10, Color("#efe8d4"), 2.0)
	if result_t > 0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
		var msg := "¡HECHO!" if result_ok else fail_msg.to_upper()
		var tw2 := f.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_string(f, Vector2((size.x - tw2) / 2, size.y / 2 + 8), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#7ee08a") if result_ok else Color("#ff6a78"))


func _draw_lockpick(f: Font) -> void:
	var c := Vector2(96, 96)
	var jit := Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5)) if lp_jam else Vector2.ZERO
	draw_circle(c, 36, Color("#3a2c14"))
	draw_circle(c, 33, Color("#c9a24b"))
	draw_circle(c, 25, Color("#8f7330"))
	# bombín que gira con la ranura
	var a := lp_turn * PI / 2.0
	var d := Vector2(cos(a - PI / 2.0), sin(a - PI / 2.0))
	draw_circle(c, 20, Color("#d9b862"))
	draw_line(c - d * 13.0, c + d * 13.0, Color("#1a1208"), 5.0)
	# ganzúa: entra por la ranura con el ángulo que le des
	var pa := lerpf(-1.25, 1.25, lp_pos) - PI / 2.0
	var tip := c + jit
	var hand := c + Vector2(cos(pa), sin(pa)) * -44.0 + jit
	hand.y = c.y + absf(hand.y - c.y) * 0.9 + 6.0
	draw_line(tip, hand, Color("#b9c2c9"), 2.5)
	draw_line(hand, hand + Vector2(-12, 14), Color("#5a3b28"), 6.0)
	# tensor
	draw_line(c + d.rotated(PI / 2.0) * 4.0 + d * 12.0, c + d * 12.0 + Vector2(46, 8).rotated(a), Color("#7d848c"), 3.0)
	var x0 := 190.0
	draw_string(f, Vector2(x0, 80), "Giro del bombín", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#a9b2b8"))
	draw_rect(Rect2(x0, 85, 228, 9), Color("#1a1f27"))
	draw_rect(Rect2(x0, 85, 228 * lp_turn, 9), Color("#4caf6a"))
	draw_string(f, Vector2(x0, 110), "Ganzúa" + ("  ¡se dobla!" if lp_jam else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ff6a78") if lp_jam else Color("#a9b2b8"))
	draw_rect(Rect2(x0, 115, 228, 9), Color("#1a1f27"))
	draw_rect(Rect2(x0, 115, 228 * clampf(lp_hp, 0.0, 1.0), 9), Color("#ebd08a") if lp_hp > 0.35 else Color("#ff6a78"))
	for i in lp_left:
		var px := x0 + 150.0 + i * 14.0
		draw_line(Vector2(px, 66), Vector2(px + 8, 74), Color("#b9c2c9"), 2.0)
	draw_string(f, Vector2(x0, 74), "Ganzúas: " + str(lp_left), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#efe8d4"))
	if lp_flash > 0.0:
		draw_string(f, Vector2(x0, 62), "¡GANZÚA ROTA!", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#ff6a78"))

func _draw_mic(f: Font) -> void:
	var base := 122.0
	draw_rect(Rect2(18, 62, size.x - 36, 66), Color("#1a1f27"))
	draw_rect(Rect2(18, base - 6, size.x - 36, 12), Color("#3b2618"))
	# lámpara, cuadro y teléfono
	var xs: Array[float] = [90.0, 220.0, 350.0]
	draw_rect(Rect2(xs[0] - 3, 84, 6, 32), Color("#b8923f"))
	Painter.poly(self, [Vector2(xs[0] - 16, 86), Vector2(xs[0] + 16, 86), Vector2(xs[0] + 9, 68), Vector2(xs[0] - 9, 68)], Color("#e9dfc4"))
	draw_rect(Rect2(xs[1] - 24, 68, 48, 34), Color("#c9a24b"))
	draw_rect(Rect2(xs[1] - 20, 72, 40, 26), Color("#2e4a6b"))
	draw_rect(Rect2(xs[2] - 16, 100, 32, 16), Color("#15181d"))
	draw_rect(Rect2(xs[2] - 20, 94, 40, 6), Color("#15181d"))
	for i in 3:
		var sel: bool = i == mic_spot
		draw_string(f, Vector2(xs[i] - 34, 140), "tras " + str(MIC_SPOTS[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#ebd08a") if sel else Color("#6a7279"))
		if sel:
			draw_arc(Vector2(xs[i], 92), 30, 0, TAU, 20, Color("#ebd08a"), 1.5)
			draw_circle(Vector2(xs[i] + 14, 108), 4, Color("#22262b"))
			draw_circle(Vector2(xs[i] + 14, 108), 2, Color("#7d848c"))
	# el huésped del pasillo: ojo abierto o cerrado
	var eye := Vector2(size.x - 44, 44)
	var open := _watched()
	draw_string(f, Vector2(size.x - 150, 48), "te miran" if open else "no mira nadie", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#ff6a78") if open else Color("#7ee08a"))
	if open:
		Painter.ellipse(self, eye.x, eye.y, 12, 7, Color("#efe8d4"))
		draw_circle(eye, 4, Color("#15181d"))
	else:
		draw_line(eye - Vector2(12, 0), eye + Vector2(12, 0), Color("#efe8d4"), 2.0)

func _draw_stash() -> void:
	var bar := Rect2(18, 66, size.x - 36, 62)
	draw_rect(bar, Color("#1a1f27"))
	var floor_y := bar.position.y + 50.0
	draw_rect(Rect2(bar.position.x, floor_y, bar.size.x, 12), Color("#3b2618"))
	# sofá con las patas a los lados del hueco
	var gx := bar.position.x + bar.size.x * (zone - zone_w / 2.0)
	var gw := bar.size.x * zone_w
	draw_rect(Rect2(gx - 60, bar.position.y + 8, gw + 120, 26), Color("#6e2731"))
	draw_rect(Rect2(gx - 60, bar.position.y + 2, 14, 32), Color("#57202a"))
	draw_rect(Rect2(gx + gw + 46, bar.position.y + 2, 14, 32), Color("#57202a"))
	draw_rect(Rect2(gx - 60, bar.position.y + 34, 60, 16), Color("#3e2616"))
	draw_rect(Rect2(gx + gw, bar.position.y + 34, 60, 16), Color("#3e2616"))
	draw_rect(Rect2(gx, bar.position.y + 34, gw, 16), Color("#0b0d10"))
	# el paquete
	var px := bar.position.x + bar.size.x * pos
	draw_rect(Rect2(px - 9, floor_y - 12, 18, 12), Color("#b98a52"))
	draw_line(Vector2(px, floor_y - 12), Vector2(px, floor_y), Color("#5a3b28"), 1.5)
	draw_line(Vector2(px - 9, floor_y - 6), Vector2(px + 9, floor_y - 6), Color("#5a3b28"), 1.5)
	for i in need:
		draw_circle(Vector2(30 + i * 26, 142), 6, Color("#ebd08a") if i < pins else Color("#2f4152"))

## Flecha dibujada (no depende de que la fuente tenga los símbolos).
static func draw_arrow(ci: CanvasItem, c: Vector2, d: String, k: float, col: Color) -> void:
	var a: float = {"up": -PI / 2, "right": 0.0, "down": PI / 2, "left": PI}.get(d, 0.0)
	var pts := [Vector2(1, 0), Vector2(0.1, -0.8), Vector2(0.1, -0.35), Vector2(-0.9, -0.35), Vector2(-0.9, 0.35), Vector2(0.1, 0.35), Vector2(0.1, 0.8)]
	var poly := PackedVector2Array()
	for p in pts:
		poly.append(c + (p as Vector2).rotated(a) * k)
	ci.draw_colored_polygon(poly, col)
