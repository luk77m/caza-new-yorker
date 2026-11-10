## Bloc de notas antiguo (tecla Tab): encargos tachados al completarse.
class_name Notebook
extends Control

var title := "Encargos"
var lines: Array = []   # {text, done, note, hl}

func _draw() -> void:
	var f := Painter.font()
	# hoja de papel con sombra y anillas
	draw_rect(Rect2(Vector2(8, 10), size - Vector2(8, 10)), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(Vector2.ZERO, size - Vector2(8, 10)), Color("#eee3c6"))
	var h := size.y - 10
	var lh := 30.0
	var y := 92.0
	while y < h - 10:
		draw_line(Vector2(0, y), Vector2(size.x - 8, y), Color(0.45, 0.58, 0.75, 0.35), 1.0)
		y += lh
	draw_line(Vector2(54, 0), Vector2(54, h), Color(0.75, 0.25, 0.25, 0.55), 1.5)
	for i in 8:
		draw_circle(Vector2(26, 40 + i * (h - 80) / 7.0), 7, Color("#2a2a2a"))
		draw_circle(Vector2(26, 40 + i * (h - 80) / 7.0), 4, Color("#9a9a9a"))
	draw_string(f, Vector2(68, 50), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#1d2a48"))
	draw_line(Vector2(68, 58), Vector2(68 + f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x, 58), Color("#1d2a48"), 1.5)
	y = 88.0
	for l in lines:
		if y > h - 20:
			break
		var txt: String = l.get("text", "")
		var ink := Color("#8c2f39") if l.get("hl", false) else Color("#1d2a48")
		if l.get("done", false):
			ink = Color(0.25, 0.3, 0.4, 0.55)
		var size_t := 16
		draw_string(f, Vector2(68, y), txt, HORIZONTAL_ALIGNMENT_LEFT, size.x - 90, size_t, ink)
		if l.get("done", false):
			var tw := minf(f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size_t).x, size.x - 90)
			draw_line(Vector2(64, y - 5), Vector2(72 + tw, y - 7), Color(0.55, 0.1, 0.12, 0.85), 2.0)
		var note: String = l.get("note", "")
		if note != "" and not l.get("done", false):
			y += 20
			draw_string(f, Vector2(84, y), note, HORIZONTAL_ALIGNMENT_LEFT, size.x - 110, 12, Color(0.45, 0.35, 0.2))
		y += lh
