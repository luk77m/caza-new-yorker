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
	# cielo nocturno degradado
	var bands := 24
	for i in bands:
		var k := float(i) / bands
		draw_rect(Rect2(0, s.y * k, s.x, s.y / bands + 1), Color(0.02 + k * 0.05, 0.03 + k * 0.04, 0.07 + k * 0.08))
	for i in 90:
		var sx := fmod(i * 137.7, s.x)
		var sy := fmod(i * 71.3, s.y * 0.7)
		draw_rect(Rect2(sx, sy, 2, 2), Color(1, 1, 0.9, 0.25 + 0.25 * sin(t * 1.3 + i)))
	# rayos art déco detrás de la torre
	var c := Vector2(s.x * 0.28, s.y * 0.35)
	var n := 28
	for i in n:
		var a0 := TAU * i / n + t * 0.02
		var a1 := a0 + TAU / n * 0.5
		var far := s.length()
		draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * far, c + Vector2(cos(a1), sin(a1)) * far]), Color(0.79, 0.64, 0.29, 0.045))
	# skyline lejano
	var x := 0.0
	var i2 := 0
	while x < s.x:
		var bw := 40.0 + fmod(i2 * 37.0, 70.0)
		var bh := 50.0 + fmod(i2 * 53.0, 140.0)
		var top := s.y - bh
		draw_rect(Rect2(x, top, bw, bh), Color("#0a0e16"))
		var wy := top + 10.0
		while wy < s.y - 8:
			var wx := x + 6.0
			while wx < x + bw - 6:
				if fmod(wx * 3.1 + wy * 7.7 + i2, 5.0) < 1.4:
					draw_rect(Rect2(wx, wy, 3, 4), Color(1.0, 0.82, 0.45, 0.45 + 0.2 * sin(t + wx)))
				wx += 9
			wy += 12
		x += bw + 4
		i2 += 1
	# marco doble con abanicos en las esquinas
	draw_rect(Rect2(18, 18, s.x - 36, s.y - 36), gold, false, 2.0)
	draw_rect(Rect2(26, 26, s.x - 52, s.y - 52), Color(0.79, 0.64, 0.29, 0.5), false, 1.0)
	var corners := [[Vector2(26, 26), 0.0], [Vector2(s.x - 26, 26), PI / 2], [Vector2(s.x - 26, s.y - 26), PI], [Vector2(26, s.y - 26), PI * 1.5]]
	for cn in corners:
		for k in 3:
			draw_arc(cn[0], 16.0 + k * 10.0, cn[1], cn[1] + PI / 2, 12, gold, 1.5)
