## Estado completo de una partida.
class_name World
extends RefCounted

var time := 0.0
var limit := 720.0
var ents: Array = []        # Ent
var corpses: Array = []     # Items.Corpse
var picks: Array = []       # Items.Pick
var dispatch: Array = []    # Dictionary {t, fl, x, y, done, stay}
var wanted := {}            # outfit id -> true
var posters: Array = []     # Items.Poster
var poster_active := {}
var logs: Array = []        # Items.LogEntry
var log_id := 0
var over := {}              # {winner, reason} cuando acaba
var tasks_done := 0
var quota := 0
var next_id := 1
var human: Ent = null
var role := "runner"        # rol del jugador: hunter, runner, spectator
var sab_blackout := 0.0     # instante en que termina cada sabotaje
var sab_alarm := 0.0
var sab_elev := 0.0
var unlocked := {}          # clave de habitación -> instante en que se vuelve a cerrar
var fx: Array = []          # Dictionary {type, fl, x, y, t}
var acc := 0.0
var acc2 := 0.0
var hint := {}
var targets: Array = []     # ids de los dos retratados
var events: Array = []      # {type, fl, x, y} para sonidos y efectos; la escena los vacía
var snitched := {}          # trajes de cazador ya delatados
var cop_kills := 0
var innocents := 0          # civiles muertos cuyo cuerpo o asesinato se ha descubierto
var alarm := 0              # 0-3 (3 = Bluegeddon)
var alarm_side := ""        # "hunters" o "runners": quién provocó el nivel 2
var cop_killers := {}       # id -> true: la policía dispara a estos en cuanto los ve
var first_done := 0         # primer corredor en terminar sus encargos
var cine := {}              # cinemática en curso del jugador
var announce := {}          # {text, color, t} rótulo grande en pantalla
var exits: Array = []       # salidas del Bluegeddon {fl, x, y, item, name}
var bench := Vector3i(1, 15, 23)   # banco de detenidos (planta baja)
var bullets: Array = []     # {fl, x, y, vx, vy, t, owner}
var qtes: Array = []        # intentos de esposar en curso {hunter, runner, t, combo, idx, human}
var cars: Array = []        # coches de la calle {kind, x, y, tx, state, t, payload}
var pools: Array = []       # charcos de sangre {fl, x, y, r, corpse, cleaner, t}
var prints: Array = []      # huellas y rastros {fl, x, y, a, s, t, drag}
var sus_outfits := {}       # trajes "quemados": alguien vio a un jugador ponérselos
var panic := 0.0            # 0-100: más policía y durante más tiempo
var gsus := 0.0             # 0-100 sospecha general: los PNJ ven más y se mosquean antes
var slot := ""              # franja del día: desayuno, mañana, almuerzo, tarde, cena, copas, dormir
var pets: Array = []        # perros {id, owner, fl, x, y, ...}
var tutorial := false
var flags := {}             # cosas que ha hecho el jugador (para el tutorial)
var stats := {"kills": 0, "civ_kills": 0, "calls": 0, "tasks": 0, "reports": 0, "arrests": 0, "forced": 0}

func is_over() -> bool:
	return not over.is_empty()

func ent_by_id(i: int) -> Ent:
	for e in ents:
		if e.id == i:
			return e
	return null
