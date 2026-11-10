## Inventario rápido (abajo a la izquierda): lo que llevas en la mano y Q para cambiar.
class_name QuickBar
extends Control

var items: Array = []
var current := "fist"
var ammo := -1
var money := 0
var hp := 3
var cuffs_cd := 0.0
const NAMES := {"fist": "Puños (noquear)", "gun": "Pistola con silenciador", "knife": "Cuchillo", "wrench": "Llave inglesa", "tool": "Herramienta", "cuffs": "Esposas"}

func _draw() -> void:
	var f := ThemeDB.fallback_font
	var x := 0.0
	var y := size.y - 58
	for it in items:
		var sel: bool = it == current
		draw_rect(Rect2(x, y, 54, 54), Color(0.03, 0.05, 0.07, 0.85))
		draw_rect(Rect2(x, y, 54, 54), Color("#ebd08a") if sel else Color("#2f4152"), false, 2.0 if sel else 1.0)
		_icon(str(it), Vector2(x + 27, y + 25), sel)
		if it == "gun" and ammo >= 0:
			draw_string(f, Vector2(x + 4, y + 50), str(ammo), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#efe8d4"))
		if it == "cuffs" and cuffs_cd > 0:
			draw_rect(Rect2(x, y + 54 * (1.0 - cuffs_cd / Cfg.CUFF_CD), 54, 54 * cuffs_cd / Cfg.CUFF_CD), Color(0, 0, 0, 0.55))
			draw_string(f, Vector2(x + 4, y + 50), str(ceili(cuffs_cd)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#ff9a9a"))
		x += 60
	for i in Cfg.HP:
		var hc := Vector2(130 + i * 18, y - 32)
		draw_circle(hc + Vector2(-3, 0), 4.5, Color("#c0392b") if i < hp else Color(0.25, 0.25, 0.28))
		draw_circle(hc + Vector2(3, 0), 4.5, Color("#c0392b") if i < hp else Color(0.25, 0.25, 0.28))
		draw_colored_polygon(PackedVector2Array([hc + Vector2(-7.5, 1), hc + Vector2(7.5, 1), hc + Vector2(0, 9)]), Color("#c0392b") if i < hp else Color(0.25, 0.25, 0.28))
	draw_string_outline(f, Vector2(0, y - 26), "$ " + str(money), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color(0, 0, 0, 0.8))
	draw_string(f, Vector2(0, y - 26), "$ " + str(money), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#ebd08a"))
	var nm: String = NAMES.get(current, "")
	draw_string_outline(f, Vector2(0, y - 8), nm + "   ·   Q cambiar", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color(0, 0, 0, 0.8))
	draw_string(f, Vector2(0, y - 8), nm + "   ·   Q cambiar", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#a9b2b8"))

func _icon(k: String, c: Vector2, sel: bool) -> void:
	var col := Color("#efe8d4") if sel else Color("#a9b2b8")
	match k:
		"fist":
			draw_rect(Rect2(c.x - 9, c.y - 6, 18, 14), col)
			for i in 4:
				draw_line(Vector2(c.x - 9 + i * 4.5, c.y - 6), Vector2(c.x - 9 + i * 4.5, c.y + 1), Color(0, 0, 0, 0.5), 1.0)
			draw_rect(Rect2(c.x - 12, c.y - 2, 4, 7), col)
		"gun":
			# pistola antigua con silenciador largo
			draw_rect(Rect2(c.x - 20, c.y - 6, 18, 7), col)
			draw_rect(Rect2(c.x - 2, c.y - 5, 20, 5), col.darkened(0.25))
			for j in 3:
				draw_line(Vector2(c.x + 2 + j * 5, c.y - 5), Vector2(c.x + 2 + j * 5, c.y), Color(0, 0, 0, 0.4), 1.0)
			draw_colored_polygon(PackedVector2Array([Vector2(c.x - 19, c.y + 1), Vector2(c.x - 11, c.y + 1), Vector2(c.x - 13, c.y + 12), Vector2(c.x - 21, c.y + 12)]), Color("#6b4a2a"))
			draw_arc(Vector2(c.x - 8, c.y + 3), 3.0, 0, PI, 6, col, 1.2)
		"cuffs":
			draw_arc(Vector2(c.x - 7, c.y + 2), 7, 0, TAU, 14, col, 2.5)
			draw_arc(Vector2(c.x + 7, c.y + 2), 7, 0, TAU, 14, col, 2.5)
			draw_line(Vector2(c.x - 1, c.y + 2), Vector2(c.x + 1, c.y + 2), col, 2.0)
		"knife":
			draw_colored_polygon(PackedVector2Array([Vector2(c.x - 12, c.y + 8), Vector2(c.x + 12, c.y - 10), Vector2(c.x + 4, c.y + 2)]), col)
			draw_line(Vector2(c.x - 12, c.y + 8), Vector2(c.x - 6, c.y + 12), Color("#8a5c37"), 4.0)
		"wrench":
			draw_line(Vector2(c.x - 10, c.y + 10), Vector2(c.x + 6, c.y - 6), col, 4.0)
			draw_arc(Vector2(c.x + 8, c.y - 8), 6, 0.6, 5.0, 10, col, 3.0)
		"tool":
			draw_line(Vector2(c.x - 11, c.y + 9), Vector2(c.x + 2, c.y - 4), Color("#b8392f"), 3.0)
			draw_line(Vector2(c.x + 11, c.y + 9), Vector2(c.x - 2, c.y - 4), Color("#b8392f"), 3.0)
			draw_line(Vector2(c.x, c.y - 2), Vector2(c.x, c.y - 12), col, 2.0)
