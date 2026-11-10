## Retrato de un personaje (cartel del cazador o de busca y captura).
class_name Portrait
extends Control

var outfit: Outfit
var dead := false
var grey := false
var caption := ""

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#e9dfc4") if not grey else Color("#9a968c"))
	draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), Color("#1a1f27"))
	if outfit != null:
		var sc := size.y / 50.0
		Painter.draw_actor(self, size.x / 2.0, size.y * 0.66, outfit, "down", 0.0, false, 0.0, sc)
	if grey:
		draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), Color(0.5, 0.5, 0.5, 0.55))
	if dead:
		draw_line(Vector2(8, 8), size - Vector2(8, 8), Color("#c0392b"), 3)
		draw_line(Vector2(size.x - 8, 8), Vector2(8, size.y - 8), Color("#c0392b"), 3)
	if caption != "":
		Painter.text(self, size.x / 2.0, size.y - 6, caption, 11, Color("#efe8d4"))
