## Datos de una planta (cargados desde data/hotel.json).
class_name FloorData
extends RefCounted

var fi := 0
var label := ""
var sub := ""
var dark := 0.3
var sky := false
var roof := false
var g := PackedByteArray()     # tipo de casilla
var blk := PackedByteArray()   # muebles sólidos
var zone := PackedByteArray()
var walkable := PackedByteArray()  # casillas transitables
var rooms: Array = []          # Room
var furn: Array = []           # Dictionary {k, x, y, w, h, solid}
var lamps: Array = []          # Dictionary {x, y, r, tint}
var wards: Array = []          # Fixture
var sinks: Array = []
var washers: Array = []
var up := Vector2i.ZERO
var down := Vector2i.ZERO
var spawn := Vector2i.ZERO
var phone := Vector2i.ZERO
var tiles_pub: Array = []      # Vector2i
var room_tiles := {}           # nombre -> Array[Vector2i]
var lock_at := {}              # índice de casilla de puerta -> Room

var open_from := 999          # filas desde las que se ve "hacia fuera" (la calle del vestíbulo)
var door_t := PackedFloat32Array()   # s que le quedan abierta a cada puerta (se abren al pasar alguien)
var door_ver := 0                    # cambia cuando alguna puerta se abre o se cierra
var door_idx := PackedInt32Array()   # casillas de puerta de la planta

func reset_doors() -> void:
	door_t.resize(Cfg.W * Cfg.H)
	door_t.fill(0.0)
	door_idx.clear()
	for i in Cfg.W * Cfg.H:
		if g[i] == Cfg.T_DOOR:
			door_idx.append(i)
	door_ver += 1

func door_open(tx: int, ty: int) -> bool:
	if tx < 0 or ty < 0 or tx >= Cfg.W or ty >= Cfg.H or door_t.size() != Cfg.W * Cfg.H:
		return false
	return door_t[ty * Cfg.W + tx] > 0.0

## ¿Tapa la vista esta casilla?
func blocks(tx: int, ty: int) -> bool:
	if ty >= open_from:
		return false
	var t := at(tx, ty)
	if t == Cfg.T_DOOR:
		return not door_open(tx, ty)   # las puertas cerradas tapan la vista
	return Cfg.blocks_sight(t)

func at(tx: int, ty: int) -> int:
	if tx < 0 or ty < 0 or tx >= Cfg.W or ty >= Cfg.H:
		return Cfg.T_VOID
	return g[ty * Cfg.W + tx]

func room_at(tx: int, ty: int) -> Room:
	var best: Room = null
	var ba := 1 << 30
	for r in rooms:
		if r.contains(tx, ty) and r.w * r.h < ba:
			ba = r.w * r.h
			best = r
	return best

func room_by(nm: String) -> Room:
	for r in rooms:
		if r.nm == nm:
			return r
	return null
