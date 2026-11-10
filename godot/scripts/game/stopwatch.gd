## Reloj tipo cronómetro (arriba a la derecha): tiempo hasta que llega el cliente.
class_name Stopwatch
extends Control

var left := 0.0
var total := 720.0
var label := "EL CLIENTE"
var alarm_col := Color(0, 0, 0, 0)

func _draw() -> void:
	var c := Vector2(size.x / 2.0, 54)
	var r := 44.0
	# corona y botón del cronómetro
	draw_rect(Rect2(c.x - 6, c.y - r - 12, 12, 8), Color("#b8923f"))
	draw_rect(Rect2(c.x - 9, c.y - r - 16, 18, 5), Color("#ebd08a"))
	draw_circle(c, r + 5, Color("#3a2c14"))
	draw_circle(c, r + 3, Color("#c9a24b"))
	draw_circle(c, r, Color("#f1e8d0"))
	# parte que queda (sector dorado)
	var frac := clampf(left / maxf(total, 1.0), 0.0, 1.0)
	if frac > 0:
		var pts := PackedVector2Array([c])
		var n := 48
		for i in n + 1:
			var a := -PI / 2 + TAU * frac * i / n
			pts.append(c + Vector2(cos(a), sin(a)) * (r - 4))
		draw_colored_polygon(pts, Color(0.86, 0.71, 0.33, 0.35) if left > 60 else Color(0.85, 0.2, 0.2, 0.35))
	for i in 60:
		var a := -PI / 2 + TAU * i / 60.0
		var l := 7.0 if i % 5 == 0 else 3.0
		draw_line(c + Vector2(cos(a), sin(a)) * (r - 2), c + Vector2(cos(a), sin(a)) * (r - 2 - l), Color("#2a1e0a"), 2.0 if i % 5 == 0 else 1.0)
	# aguja de minutos restantes (vuelta = 15 min) y de segundos
	var am := -PI / 2 + TAU * fmod(left / 900.0, 1.0)
	var as_ := -PI / 2 + TAU * fmod(left, 60.0) / 60.0
	draw_line(c, c + Vector2(cos(am), sin(am)) * (r * 0.55), Color("#2a1e0a"), 4.0)
	draw_line(c, c + Vector2(cos(as_), sin(as_)) * (r * 0.85), Color("#8c2f39"), 1.6)
	draw_circle(c, 3.5, Color("#2a1e0a"))
	var f := ThemeDB.fallback_font
	var s := maxi(0, ceili(left))
	var txt := str(s / 60) + ":" + ("%02d" % (s % 60))
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string_outline(f, Vector2(c.x - tw / 2, c.y + r + 30), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 4, Color(0, 0, 0, 0.8))
	draw_string(f, Vector2(c.x - tw / 2, c.y + r + 30), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#ff7a7a") if left < 60 else Color("#efe8d4"))
	var lw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string_outline(f, Vector2(c.x - lw / 2, c.y + r + 46), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0, 0, 0, 0.8))
	draw_string(f, Vector2(c.x - lw / 2, c.y + r + 46), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ebd08a"))
