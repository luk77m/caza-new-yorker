## Una habitación o sala de una planta.
class_name Room
extends RefCounted

var nm := ""
var x := 0
var y := 0
var w := 0
var h := 0
var zone := 0
var side := ""
var fi := 0
var has_door := false
var door := Vector2i(-1, -1)
var out := Vector2i(-1, -1)

func contains(tx: int, ty: int) -> bool:
	return tx >= x and tx < x + w and ty >= y and ty < y + h

func key() -> String:
	return str(fi) + ":" + nm

## "habitación 1005", "suite 2004", "despacho del gerente"...
func label() -> String:
	if nm.begins_with("Hab."):
		return "habitación " + number()
	if nm.begins_with("Suite"):
		return "suite " + number()
	return nm.substr(0, 1).to_lower() + nm.substr(1)

## Último trozo del nombre: "Hab. 1005" -> "1005".
func number() -> String:
	var parts := nm.split(" ")
	return parts[parts.size() - 1]
