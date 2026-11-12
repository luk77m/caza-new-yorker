## Objetos sueltos, cadáveres y carteles.
class_name Items
extends RefCounted

class Pick:
	var id := 0
	var kind := ""   # masterkey, badge, scrap
	var fl := 0
	var x := 0
	var y := 0
	var nm := ""
	var value := 0
	var job_owner := 0
	var box := ""    # dónde está guardado: "f:planta:x:y" (mueble), "c:id" (cadáver) o "" (suelto)
	var by := 0      # jugador que lo dejó ahí
	var t := 0.0     # cuándo

class Corpse:
	var id := 0
	var x := 0.0
	var y := 0.0
	var fl := 0
	var outfit: Outfit
	var stripped := false
	var found := false
	var nm := ""
	var role := ""
	var t := 0.0
	var victim_id := 0
	var ang := 0.0
	var chalk := false
	var killer_id := 0
	var killer_role := ""
	var counted := false
	var hidden := false         # escondido en un armario
	var drag_acc := 0.0
	var stripped_clean := false

class Poster:
	var outfit_id := ""
	var hunter_id := 0
	var outfit: Outfit
	var state := "active"
	var t := 0.0

class LogEntry:
	var id := 0
	var t := 0.0
	var msg := ""
	var kind := "info"
	var who := 0
