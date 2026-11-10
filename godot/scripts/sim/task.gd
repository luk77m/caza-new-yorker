## Un encargo de un corredor (copia personal).
class_name Task
extends RefCounted

var id := ""
var nm := ""
var fl := 0
var x := 0
var y := 0
var dur := 5.0
var kind := ""        # "", "pick" o "drop"
var pair := ""        # para "pick": id del "drop"
var room_name := ""   # si está dentro de una habitación con llave
var sab := ""         # "blackout", "alarm" o "elev"
var own := false      # está en tu propia habitación
var done := false
var busy := 0

func copy() -> Task:
	var c := Task.new()
	c.id = id; c.nm = nm; c.fl = fl; c.x = x; c.y = y; c.dur = dur
	c.kind = kind; c.pair = pair; c.room_name = room_name; c.sab = sab; c.own = own
	return c
