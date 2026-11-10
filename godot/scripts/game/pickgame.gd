## Minijuegos de los encargos, cerraduras y esposas. Dificultad media y cortos (unos 3-8 s).
##  timing:   para la aguja en la zona verde (E o Espacio) varias veces
##  sequence: memoriza una secuencia de flechas y repítela
##  balance:  mantén el indicador dentro de la zona con A/D o ←/→ hasta llenar la barra
##  wires:    conecta cada cable con su color pulsando 1, 2 o 3
class_name PickGame
extends Control

signal finished(ok: bool)

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

func start(m: String, ttl: String, pins_needed: int = 3) -> void:
	mode = m
	title = ttl
	active = true
	visible = true
	t = 0.0
	fail_msg = ""
	result_t = 0.0
	match mode:
		"timing":
			pins = 0
			need = pins_needed
			pos = 0.0
			dir = 1.0
			limit = 4.0 + need * 2.0
			_new_zone()
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
		"timing":
			pos += dir * speed * delta
			if pos > 1.0:
				pos = 1.0
				dir = -1.0
			elif pos < 0.0:
				pos = 0.0
				dir = 1.0
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
		"timing":
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
			if not (k in ["1", "2", "3"]):
				return
			var slot := int(k) - 1
			if right_cols[slot] == left_cols[wire_i]:
				wire_i += 1
				if wire_i >= 3:
					_end(true, "")
			else:
				_end(false, "Cable equivocado: ¡chispazo!")

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
	match mode:
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
	match mode:
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


## Flecha dibujada (no depende de que la fuente tenga los símbolos).
static func draw_arrow(ci: CanvasItem, c: Vector2, d: String, k: float, col: Color) -> void:
	var a: float = {"up": -PI / 2, "right": 0.0, "down": PI / 2, "left": PI}.get(d, 0.0)
	var pts := [Vector2(1, 0), Vector2(0.1, -0.8), Vector2(0.1, -0.35), Vector2(-0.9, -0.35), Vector2(-0.9, 0.35), Vector2(0.1, 0.35), Vector2(0.1, 0.8)]
	var poly := PackedVector2Array()
	for p in pts:
		poly.append(c + (p as Vector2).rotated(a) * k)
	ci.draw_colored_polygon(poly, col)
