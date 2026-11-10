## Armario, pila o lavadora: objeto fijo del mapa con un sitio donde ponerse.
class_name Fixture
extends RefCounted

var x := 0
var y := 0
var w := 1
var h := 1
var stand := Vector2i(-1, -1)
var has_stand := false
var fi := 0
var looted := false

func center() -> Vector2:
	return Vector2((x + w / 2.0) * Cfg.TS, (y + h / 2.0) * Cfg.TS)
