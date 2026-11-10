## Minijuego de la ganzúa: pulsa E cuando la aguja esté en la zona verde.
class_name PickGame
extends Control

signal finished(ok: bool)

var pins := 0
var pos := 0.0
var speed := 1.3
var zone := 0.5
var zone_w := 0.14
var dir := 1.0
var active := false

func start() -> void:
	pins = 0
	pos = 0.0
	dir = 1.0
	_new_zone()
	active = true
	visible = true

func _new_zone() -> void:
	zone = randf_range(0.15, 0.85)
	zone_w = maxf(0.07, 0.15 - pins * 0.015)
	speed = 1.2 + pins * 0.25

func _process(delta: float) -> void:
	if not active:
		return
	pos += dir * speed * delta
	if pos > 1.0:
		pos = 1.0
		dir = -1.0
	elif pos < 0.0:
		pos = 0.0
		dir = 1.0
	queue_redraw()

func hit() -> void:
	if not active:
		return
	if absf(pos - zone) <= zone_w / 2.0:
		pins += 1
		if pins >= Cfg.UNLOCK_PINS:
			active = false
			finished.emit(true)
			return
	else:
		pins = maxi(0, pins - 1)
	_new_zone()

func cancel() -> void:
	if active:
		active = false
		finished.emit(false)

func _draw() -> void:
	var f := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.06, 0.09, 0.96))
	draw_rect(Rect2(Vector2.ZERO, size), Color("#ebd08a"), false, 2.0)
	draw_string(f, Vector2(18, 32), "FORZAR LAS ESPOSAS", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#ebd08a"))
	draw_string(f, Vector2(18, 54), "Pulsa E cuando la aguja esté en la zona verde · Esc para dejarlo", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#a9b2b8"))
	var bar := Rect2(18, 74, size.x - 36, 26)
	draw_rect(bar, Color("#1a1f27"))
	draw_rect(Rect2(bar.position.x + bar.size.x * (zone - zone_w / 2.0), bar.position.y, bar.size.x * zone_w, bar.size.y), Color("#4caf6a"))
	var px := bar.position.x + bar.size.x * pos
	draw_rect(Rect2(px - 2, bar.position.y - 6, 4, bar.size.y + 12), Color("#efe8d4"))
	for i in Cfg.UNLOCK_PINS:
		draw_circle(Vector2(30 + i * 26, 124), 8, Color("#ebd08a") if i < pins else Color("#2f4152"))
