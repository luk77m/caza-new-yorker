## Fondo art déco del menú principal: rayos dorados, marco, skyline y la galería de personajes.
class_name TitleArt
extends Control

var t := 0.0
var cast: Array = []   # [Outfit, nombre, color]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hunters := [Outfit.new_guest(false), Outfit.new_guest(false)]
	var runners := [Outfit.new_guest(false), Outfit.new_guest(true), Outfit.new_guest(false), Outfit.new_guest(false)]
	hunters[0].hat_t = "fedora"
	cast = [[hunters[0], "Cazador", Color("#ff9a9a")], [runners[0], "Corredor", Color("#6fb8ff")], [runners[1], "Corredora", Color("#6fb8ff")], [Outfit.new_police(), "Policía", Color("#a9b2b8")], [runners[2], "Corredor", Color("#6fb8ff")], [hunters[1], "Cazador", Color("#ff9a9a")]]

func _process(delta: float) -> void:
	t += delta
	if is_visible_in_tree():
		queue_redraw()

func _draw() -> void:
	var s := size
	var gold := Color("#c9a24b")
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.03, 0.05, 0.82))
	# rayos de sol art déco detrás del título
	var c := Vector2(s.x / 2.0, s.y * 0.3)
	var n := 28
	for i in n:
		var a0 := TAU * i / n + t * 0.02
		var a1 := a0 + TAU / n * 0.5
		var far := s.length()
		draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * far, c + Vector2(cos(a1), sin(a1)) * far]), Color(0.79, 0.64, 0.29, 0.05))
	for k in 4:
		draw_arc(c, 120.0 + k * 22.0, PI * 1.05, PI * 1.95, 48, Color(0.79, 0.64, 0.29, 0.25 - k * 0.05), 2.0)
	# skyline
	var x := 0.0
	var i2 := 0
	while x < s.x:
		var bw := 40.0 + fmod(i2 * 37.0, 70.0)
		var bh := 60.0 + fmod(i2 * 53.0, 170.0)
		var top := s.y - bh
		draw_rect(Rect2(x, top, bw, bh), Color("#0c1018"))
		var wy := top + 10.0
		while wy < s.y - 8:
			var wx := x + 6.0
			while wx < x + bw - 6:
				if fmod(wx * 3.1 + wy * 7.7 + i2, 5.0) < 1.6:
					draw_rect(Rect2(wx, wy, 3, 4), Color(1.0, 0.82, 0.45, 0.55 + 0.2 * sin(t + wx)))
				wx += 9
			wy += 12
		x += bw + 4
		i2 += 1
	# el Empire State en el centro del skyline
	var ex := s.x * 0.8
	for k in 5:
		var w := 90.0 - k * 16.0
		draw_rect(Rect2(ex - w / 2, s.y - 260 - k * 40, w, 300), Color("#0a0d14"))
	draw_line(Vector2(ex, s.y - 470), Vector2(ex, s.y - 520), Color("#0a0d14"), 3.0)
	draw_circle(Vector2(ex, s.y - 520), 3, Color(1, 0.25, 0.25, 0.5 + 0.5 * sin(t * 3.0)))
	# marco doble con abanicos en las esquinas
	draw_rect(Rect2(18, 18, s.x - 36, s.y - 36), gold, false, 2.0)
	draw_rect(Rect2(26, 26, s.x - 52, s.y - 52), Color(0.79, 0.64, 0.29, 0.5), false, 1.0)
	for corner in [Vector2(26, 26), Vector2(s.x - 26, 26), Vector2(26, s.y - 26), Vector2(s.x - 26, s.y - 26)]:
		var sx := 1.0 if corner.x < s.x / 2 else -1.0
		var sy := 1.0 if corner.y < s.y / 2 else -1.0
		for k in 3:
			draw_arc(corner, 16.0 + k * 10.0, 0.0 if sx > 0 and sy > 0 else (PI if sx < 0 and sy < 0 else (PI / 2 if sx < 0 else -PI / 2)), (PI / 2 if sx > 0 and sy > 0 else (PI * 1.5 if sx < 0 and sy < 0 else (PI if sx < 0 else 0.0))), 12, gold, 1.5)
	# galería de personajes
	var base_y := s.y - 70.0
	var gap := 92.0
	var x0 := s.x / 2.0 - gap * (cast.size() - 1) / 2.0
	for k in cast.size():
		var who: Array = cast[k]
		var px := x0 + k * gap
		var bob := sin(t * 2.0 + k) * 2.0
		Painter.draw_actor(self, px, base_y - 30 + bob, who[0], "down", 0.0, false, 0.0, 2.2)
		var f := ThemeDB.fallback_font
		var nm: String = who[1]
		var tw := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(f, Vector2(px - tw / 2, base_y + 20), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, who[2])
