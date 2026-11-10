/* ===== core: constantes, configuración y utilidades ===== */
var TS = 32, W = 44, H = 30;
var T = { VOID: 0, WALL: 1, MARBLE: 2, CARPET: 3, CONC: 4, DOOR: 5, ELEV: 6, UP: 7, DOWN: 8, ROOF: 10, WOOD: 11, TERR: 12, RAIL: 13, HALL: 14 };
var SOLIDT = []; SOLIDT[T.VOID] = SOLIDT[T.WALL] = SOLIDT[T.RAIL] = SOLIDT[T.ELEV] = true;
var SIGHTB = []; SIGHTB[T.VOID] = SIGHTB[T.WALL] = SIGHTB[T.ELEV] = true;

/* Todos los números de equilibrio están aquí para poder tocarlos sin buscar por el código. */
var CFG = {
  fireCd: 0.9,             // s entre disparos del cazador
  killRange: 7.5,          // tiles de alcance del arma con silenciador
  witnessRadius: 9,        // tiles: un NPC con visión dentro de este radio es testigo del disparo
  sightTiles: 8,           // tiles de visión de los NPC para la sospecha
  aimNoticeRadius: 7,      // tiles: un NPC dentro de este radio percibe poco a poco el arma
  aimRate: 2.2,            // sospecha/s por NPC que ve el arma (a distancia máxima)
  aimNear: 12,            // sospecha/s extra cuando el NPC está pegado al arma (baja con la distancia)
  bloodRadius: 7,
  bloodRate: 9,            // sospecha/s por NPC que ve un traje manchado
  restrictedStaff: 14,     // sospecha/s si te ve un trabajador en zona prohibida
  restrictedGuest: 4,      // sospecha/s si te ve un huésped en zona prohibida
  susDecay: 3,             // sospecha/s que baja cuando nadie te ve
  warnAt: 35,              // los trabajadores te avisan
  callAt: 80,              // si sigues, llaman a la policía
  policeDelay: 9,          // s entre la llamada y la llegada
  policeCount: 2,
  policeStay: 80,          // s que se quedan buscando
  policeSight: 9,          // tiles
  policeReact: 0.7,        // s entre que ve al cazador y dispara
  speed: { walk: 118, run: 180, aim: 66, npc: 62, bot: 108, botRun: 160, police: 125 },
  hold: { strip: 3, ward: 3, wash: 6, sink: 5 },
  scrapNeeded: 4,
  taskCooldown: 150,       // s hasta que una tarea puede repetirse
  quotaBase: 2, quotaPerRunner: 4,
  meleeRange: 40, meleeCd: 1.1,
  botIdle: [22, 55],       // s que un bot corredor se mezcla antes de la siguiente tarea
  botPatience: 16,         // s que un bot cazador espera a que no haya testigos antes de arriesgarse
  botSight: 6,             // tiles a los que un bot cazador reconoce un objetivo
  botRecognize: 1.4,       // s mirando a un objetivo antes de reconocerlo
  botAimTime: 1.3          // s apuntando antes de disparar
};

var _s = 1;
function seed(n) { _s = (n >>> 0) || 1; }
function rnd() { _s |= 0; _s = (_s + 0x6D2B79F5) | 0; var t = Math.imul(_s ^ (_s >>> 15), 1 | _s); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }
function ri(a, b) { return a + Math.floor(rnd() * (b - a + 1)); }
function pick(a) { return a[Math.floor(rnd() * a.length)]; }
function shuffle(a) { for (var i = a.length - 1; i > 0; i--) { var j = Math.floor(rnd() * (i + 1)); var t = a[i]; a[i] = a[j]; a[j] = t; } return a; }
function dist(ax, ay, bx, by) { return Math.hypot(ax - bx, ay - by); }
function clamp(v, a, b) { return v < a ? a : (v > b ? b : v); }
