## Cualquier personaje: jugador, bot, PNJ o policía.
class_name Ent
extends RefCounted

var id := 0
var nm := ""
var type := "npc"       # human, bot, npc, police, frozen
var role := "civil"     # hunter, runner, civil, police
var fl := 1
var x := 0.0
var y := 0.0
var dir := "down"
var walk := 0.0
var moving := false
var alive := true
var outfit: Outfit
var aim := false
var aim_x := 0.0
var aim_y := 0.0
var aim_ang := 0.0
var lean_x := 0.0       # asomarse en primera persona (Q/E): desplazamiento del ojo y del cañón
var lean_y := 0.0
var cd := 0.0
var fx_swing := 0.0
var sus := 0.0
# inventario
var masterkey := false
var badge := false
var scrap := 0
var melee := false
var carry := ""          # id del encargo "drop" que llevas
var hold: Hold = null
var bubble := ""
var bt := 0.0
# navegación
var path: Array = []     # Vector2i
var has_path := false
var path_key := ""
var pi := 0
var goal: Goal = null
var unreach := false
var elev_t := 0.0
var stair_cd := 0.0
# estado
var state := "idle"      # idle, call, calling, scared, stun, evac, dead
var knows := {}          # outfit id -> true
var spot := {}           # ent id -> s mirando (policía)
var restricted := false
var was_restricted := false
var was_intr := false
var tasks: Array = []    # Task (solo corredores)
var room := ""
var room_floor := -1
var reports := 0
var marked := false
var arrest := 0.0
var rep_lock := 0.0
var target_ids: Array = []
# tanda 2
var money := 0
var ammo := 0
var ammo_max := 0
var perk := ""            # silencer, master, ammo, rich (solo cazadores)
var lockpick := false     # ganzúa: fuerza cerraduras en la mitad de tiempo
var cutter := false       # cizalla: rompe el ascensor
var intel_until := 0.0    # chivatazo (corredor) o rastro (cazador) activo hasta
var talk_cd := -99.0      # PNJ: cuándo vuelve a dar información
var shop := ""            # PNJ: "runner" o "hunter" si vende material a ese bando
var elev_ready := 0.0     # jugador: cuándo puede volver a usar el ascensor
# v0.6
var gun := false          # pistola (cazador siempre; corredor como recompensa)
var knife := false
var equip := "fist"       # fist, gun, knife, wrench, tool
var undercover := false   # corredor con placa de policía (evento raro)
var hunter_mark := 0      # id del cazador delatado por la recompensa
var job: Task = null      # trabajo extra del vendedor
var cuffed := false
var cuff_t := 0.0
var shackled := false
var frisked := false
var escaped := false
var cuffkey := false
var rope := false
var dockkey := false
var coffee := false       # PNJ: el policía del café
var deliver_to := 0       # PNJ: a quién entrega la recompensa
var frisk_id := 0         # policía: a quién va a cachear
var chase_id := 0         # policía: a quién persigue
var is_fed := false
var sweep: Array = []     # federales: habitaciones por revisar
# v0.7
var hp := 3
var hp_t := 0.0           # s hasta recuperar salud
var ko_t := 0.0           # s noqueado
var fire_cd := 0.0        # policía
var cuffs := false        # cazador: lleva esposas
var cuffs_cd := 0.0
var qte_t := 0.0          # bloqueado mientras se resuelve un intento de esposar
var away_t := 0.0         # s fuera de la partida (esposado por un cazador)
var intel_kind := ""      # hunters, targets o runners
# PNJ
var staff := false
var tiles: Array = []
var fixed := false
var call_ctx := {}
var last_warn := -99.0
var last_aim := -99.0
# policía
var target := Vector3i.ZERO   # planta, x, y
var stay_until := 0.0
var freeze := false
var spotting := false
var remove := false
# IA (campos genéricos para todos los tipos de bot)
var ai_mode := "idle"
var ai_t := 0.0
var ai_scan := 0.0
var ai_wait := 0.0
var ai_stun := 0.0
var ai_patience := 0.0
var ai_aim_t := 0.0
var ai_rec := 0.0
var ai_lost := 0.0
var ai_task: Task = null
var ai_pick = null
var ai_ward: Fixture = null
var ai_target: Ent = null

func tile() -> Vector2i:
	return Vector2i(floori(x / Cfg.TS), floori(y / Cfg.TS))

func pos() -> Vector2:
	return Vector2(x, y)

func say(t: String, d: float = 2.4) -> void:
	bubble = t
	bt = d
