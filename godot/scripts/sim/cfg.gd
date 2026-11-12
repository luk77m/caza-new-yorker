## Constantes del juego. Todos los números de equilibrio están aquí.
class_name Cfg
extends RefCounted

const TS := 32
const W := 44
const H := 30

# Tipos de casilla (iguales que en src/core.js)
const T_VOID := 0
const T_WALL := 1
const T_MARBLE := 2
const T_CARPET := 3
const T_CONC := 4
const T_DOOR := 5
const T_ELEV := 6
const T_UP := 7
const T_DOWN := 8
const T_ROOF := 10
const T_WOOD := 11
const T_TERR := 12
const T_RAIL := 13
const T_HALL := 14

# Zonas
const ZONE_PUB := 0
const ZONE_ROOM := 1
const ZONE_STAFF := 2

const FIRE_CD := 0.9            # s entre disparos del cazador
const KILL_RANGE := 7.5         # casillas de alcance del arma con silenciador
const WITNESS_RADIUS := 9.0     # casillas: un PNJ con visión dentro de este radio es testigo
const SIGHT_TILES := 8.0        # casillas de visión de los PNJ para la sospecha
const AIM_NOTICE_RADIUS := 7.0  # casillas: un PNJ dentro percibe poco a poco el arma
const AIM_RATE := 2.2           # sospecha/s por PNJ que ve el arma (a distancia máxima)
const AIM_NEAR := 12.0          # sospecha/s extra cuando el PNJ está pegado al arma
const BLOOD_RADIUS := 7.0
const BLOOD_RATE := 9.0         # sospecha/s por PNJ que ve un traje manchado
const RESTRICTED_STAFF := 14.0  # sospecha/s si te ve un trabajador en zona prohibida
const RESTRICTED_GUEST := 4.0   # sospecha/s si te ve un huésped en zona prohibida
const SUS_DECAY := 3.0          # sospecha/s que baja cuando nadie te ve
const WARN_AT := 35.0           # los trabajadores te avisan
const CALL_AT := 80.0           # si sigues, llaman a la policía
const POLICE_DELAY := 9.0       # s entre la llamada y la llegada
const POLICE_COUNT := 2
const POLICE_STAY := 80.0       # s que se quedan buscando
const POLICE_SIGHT := 9.0       # casillas
const POLICE_REACT := 0.7       # s entre que ve al cazador y dispara

const SPEED_WALK := 118.0
const SPEED_RUN := 180.0
const SPEED_AIM := 66.0
const LEAN_PX := 13.0          # cuánto te asomas con Q/E en primera persona
const SPEED_NPC := 62.0
const SPEED_BOT := 108.0
const SPEED_BOT_RUN := 160.0
const SPEED_POLICE := 125.0

const HOLD_STRIP := 3.0
const HOLD_WARD := 3.0
const HOLD_WASH := 6.0
const HOLD_SINK := 5.0

const SCRAP_NEEDED := 4
const TASKS_MIN := 8            # encargos personales de cada corredor
const TASKS_MAX := 10
const FORCE_DUR := 5.5          # s para forzar una cerradura
const UNLOCK_FOR := 75.0        # s que una puerta forzada queda abierta para todos
const STRIKES := 3              # denuncias a partir de las cuales el corredor queda fichado
const CLIENT_DELAY := 30.0      # s que se retrasa el cliente por cada denuncia desde la tercera
const ARREST_DUR := 9.0         # s que la policía retiene a un corredor fichado
const SAB_BLACKOUT := 40.0      # s de duración de cada sabotaje
const SAB_ALARM := 45.0
const SAB_ELEV := 50.0
const BLACKOUT_SIGHT := 0.5     # multiplicador de la visión durante el apagón
const MELEE_RANGE := 40.0
const MELEE_CD := 1.1

const BOT_IDLE_MIN := 34        # s que un bot corredor se mezcla antes de la siguiente tarea
const BOT_IDLE_MAX := 80
const BOT_PATIENCE := 22.0      # s que un bot cazador espera a que no haya testigos
const BOT_SIGHT := 5.5          # casillas a las que un bot cazador reconoce un objetivo
const BOT_RECOGNIZE := 1.9      # s mirando a un objetivo antes de reconocerlo
const BOT_AIM_TIME := 1.3       # s apuntando antes de disparar

const SIGHT_PX := 330.0         # radio de visión del jugador en píxeles

# Tanda 2: economía, munición, ascensor y conversaciones
const AMMO := 8                 # balas del cazador
const AMMO_PERK := 12           # con la ventaja "munición extra"
const KNIFE_RANGE := 34.0       # alcance del cuchillo del cazador
const KNIFE_CD := 1.4
const SILENCER_PERK := 0.7      # radio de testigos de tus disparos con "silenciador mejorado"
const MONEY_RUNNER := 40        # dinero inicial
const MONEY_HUNTER := 120
const MONEY_RICH := 150         # extra con la ventaja "fondos reservados"
const MONEY_TASK := 0           # los encargos ya no se pagan (ver trabajos extra)
const MONEY_TARGET := 100       # por objetivo eliminado
const MONEY_REPORT := 20        # a los cazadores, por cada denuncia contra un corredor
const MONEY_SNITCH := 60        # por dar la descripción de un cazador a la policía
const SCRAP_PRICE := 15         # por pieza vendida (una vez hecha la llave inglesa)
const CASH_SPOTS := 2           # carteras sueltas por el hotel (raro encontrarlas)
const INTEL_DUR := 25.0         # s que dura un chivatazo o un rastro
const ELEV_WAIT := 2.0          # s hasta que llega el ascensor
const ELEV_CD := 5.0            # s de espera entre viajes
const SAB_ELEV_CUT := 70.0      # s de avería si rompes el ascensor con la cizalla
const HOLD_CUT := 3.5
const HOLD_TALK := 1.0
const TALK_CD := 25.0           # s antes de que un PNJ vuelva a darte información
const RUMOR_CHANCE := 0.4
const TALK_RANGE := 58.0        # distancia para hablar o comprar (sin mantener)
const TASK_RANGE := 46.0

# v0.6: trabajos extra, recompensa y alarmas
const JOB_PAY_MIN := 50
const JOB_PAY_MAX := 90
const HOLD_JOB := 2.5
const BONUS_AMMO := 6           # balas de la pistola que recibe el primer corredor en terminar
const BONUS_INTEL := 45.0       # s que ve al cazador delatado
const COP_EVENT_CHANCE := 0.15  # evento raro: el policía del café
const BRIBE_COP := 250          # soborno para soltar a un detenido
const CUFF_TIME := 90.0         # s esposado antes de quedar fuera de la partida
const CUFF_SPEED := 70.0        # velocidad esposado sin vigilancia
const FRISK_RANGE := 6.0        # casillas a las que un policía decide cachearte
const UNLOCK_PINS := 5          # aciertos del minijuego de la ganzúa
const HOLD_UNLOCK_BOT := 12.0
const ALARM_L2 := 2             # policías muertos para el nivel 2
const ALARM_L3 := 4             # y para el Bluegeddon
const REINFORCE := 2            # refuerzos en el nivel 1
const FED_COUNT := 6            # agentes federales en el nivel 2
const BLUE_COUNT := 16          # policías en el Bluegeddon
const ALARM_TIME_SHIFT := 90.0  # s que el nivel 2 adelanta o retrasa al cliente
const HOLD_ESCAPE := 3.0
const SPEED_FED := 120.0

# v0.7
const HP := 3                   # impactos de bala de la policía que aguanta un jugador
const HP_REGEN := 30.0          # s para recuperar un punto de salud
const POLICE_FIRE_CD := 0.85    # s entre disparos de un policía
const POLICE_SPREAD := 0.12     # rad de dispersión de la policía
const BULLET_SPEED := 900.0
const PUNCH_RANGE := 32.0
const PUNCH_CD := 0.9
const KO_TIME := 4.0            # s noqueado tras un puñetazo
const KO_POLICE := 3.0
const CUFF_RANGE := 34.0
const CUFF_CD := 20.0           # s entre intentos de esposar
const QTE_TIME := 3.0           # s para meter la combinación y zafarse
const QTE_LEN := 4
const QTE_BOT_ESCAPE := 0.45    # probabilidad de que un bot corredor se zafe
const ARREST_AWAY := 10.0       # s fuera de la partida tras ser esposado por un cazador
const CUFF_INTEL := 10.0        # s que el cazador ve a todos los corredores
const HEARSE_AFTER := 35.0      # s desde la muerte hasta que el coche fúnebre se lleva el cuerpo
const INNOCENT_L1 := 2         # inocentes muertos y descubiertos para cada nivel de alarma
const INNOCENT_L2 := 4
const INNOCENT_L3 := 5          # Bluegeddon del tirón
const STREET_Y := 28.4          # fila (en casillas) del carril de la calle frente al hotel

static func is_solid(t: int) -> bool:
	return t == T_VOID or t == T_WALL or t == T_RAIL or t == T_ELEV

## Los ascensores ya no tapan la vista (antes quedaban siempre en sombra).
static func blocks_sight(t: int) -> bool:
	return t == T_VOID or t == T_WALL
