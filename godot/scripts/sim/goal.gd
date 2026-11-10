class_name Goal
extends RefCounted

var fl := 0
var x := 0
var y := 0
var force := false

static func make(f: int, tx: int, ty: int) -> Goal:
	var g := Goal.new()
	g.fl = f; g.x = tx; g.y = ty
	return g
