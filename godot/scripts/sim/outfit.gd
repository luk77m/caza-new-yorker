## Ropa y aspecto. El cartel de busca y captura se basa en el id del traje.
class_name Outfit
extends RefCounted

const SUITS := [["#2b3a4f", "azul marino"], ["#4a4a4e", "gris marengo"], ["#5a3b28", "marrón"], ["#3b5a3a", "verde botella"], ["#6a2a30", "burdeos"], ["#8a826e", "beige"], ["#1c1c22", "negro"], ["#5d4b6a", "ciruela"], ["#7a6a2c", "mostaza apagado"]]
const DRESSES := [["#8c2f39", "rojo"], ["#2f7478", "verde azulado"], ["#c0a050", "dorado"], ["#5d4b8a", "violeta"], ["#2a4a7a", "azul"]]
const TIES := ["#8c2f39", "#c9a24b", "#2f7478", "#e9e4d6", "#4a2f6a"]
const HATS := [["fedora", "sombrero de fieltro"], ["bowler", "bombín"], ["cap", "gorra plana"], ["none", "sin sombrero"]]
const HATC := [["#2a2420", "negro"], ["#6b5b45", "marrón"], ["#8a8478", "gris"], ["#1d2a38", "azul oscuro"], ["#7a5a30", "canela"]]
const HAIRS := ["#1a1410", "#3a2a1c", "#6a4a2a", "#b9a88a", "#7a7a7a"]
const SKINS := ["#e1b98f", "#c99a70", "#a8744e", "#f0cfaa"]
const HS_M := ["short", "slick", "side", "short", "bald"]
const HS_F := ["bob", "bun", "wave"]
const STAFF := {
	"bell": {"coat": "#8c2f39", "coat_n": "librea granate", "pants": "#2a1a1c", "hat": ["pill", "#8c2f39", "gorro de botones", "granate"], "label": "Botones"},
	"maid": {"coat": "#23262c", "coat_n": "uniforme negro con delantal", "pants": "#23262c", "hat": ["maidcap", "#efeadb", "cofia", "blanca"], "label": "Camarera", "dress": true, "apron": true},
	"chef": {"coat": "#efeadb", "coat_n": "chaqueta de cocinero", "pants": "#4a4f58", "hat": ["chef", "#f4f1ea", "gorro de cocinero", "blanco"], "label": "Cocinero"},
	"tech": {"coat": "#4a5f6e", "coat_n": "mono de trabajo", "pants": "#4a5f6e", "hat": ["cap", "#d6c58a", "gorra", "crema"], "label": "Técnico"},
	"waiter": {"coat": "#f1eee4", "coat_n": "chaqueta blanca de camarero", "pants": "#16161b", "hat": ["none", "#000000", "sin sombrero", ""], "label": "Camarero", "bow": true},
	"recep": {"coat": "#2c3f52", "coat_n": "traje de recepción", "pants": "#1d2a38", "hat": ["none", "#000000", "sin sombrero", ""], "label": "Recepción", "tie": "#c9a24b"},
}

static var oid := 0
static var used := {}

var id := ""
var kind := "suit"      # suit, dress, staff, police, under
var coat := Color.BLACK
var coat_n := ""
var pants := Color.BLACK
var tie := Color("#8c2f39")
var has_tie := true
var hat_t := "none"
var hat_c := Color.BLACK
var hat_n := ""
var hat_cn := ""
var hair := Color.BLACK
var skin := Color.WHITE
var staff_role := ""
var blood := false
var key := ""
var hs := "short"
var glasses := false
var stache := false
var build := 1.0
var apron := false
var bow := false

static func reset() -> void:
	oid = 0
	used = {}

static func _next_id() -> String:
	oid += 1
	return "o" + str(oid)

func _traits(female: bool, extra: float) -> void:
	hs = Rng.pick(HS_F if female else HS_M)
	glasses = Rng.rnd() < (0.2 if female else 0.28)
	stache = (not female) and Rng.rnd() < extra
	build = 0.92 + Rng.rnd() * 0.2

static func new_guest(female: bool) -> Outfit:
	var o: Outfit
	var tries := 0
	while true:
		o = Outfit.new()
		var hat: Array = ["cloche", "sombrero cloché"] if female else Rng.pick(HATS)
		var hc: Array = Rng.pick(HATC)
		var su: Array = Rng.pick(DRESSES) if female else Rng.pick(SUITS)
		var tie_s: String = Rng.pick(TIES)
		o.id = _next_id()
		o.kind = "dress" if female else "suit"
		o.coat = Color(su[0]); o.coat_n = su[1]
		o.pants = o.coat if female else o.coat.darkened(0.22)
		o.tie = Color(tie_s)
		o.hat_t = hat[0]; o.hat_n = hat[1]
		o.hat_c = Color(su[0]) if female else Color(hc[0])
		o.hat_cn = su[1] if female else hc[1]
		o.hair = Color(Rng.pick(HAIRS)); o.skin = Color(Rng.pick(SKINS))
		o._traits(female, 0.3)
		o.key = ("f" if female else "m") + su[0] + hat[0] + hc[0] + ("" if female else tie_s) + o.hs + ("g" if o.glasses else "") + ("m" if o.stache else "")
		tries += 1
		if not used.has(o.key) or tries >= 40:
			break
	used[o.key] = true
	return o

static func new_staff(role: String) -> Outfit:
	var s: Dictionary = STAFF[role]
	var o := Outfit.new()
	var dress: bool = s.get("dress", false)
	o._traits(dress, 0.25)
	if dress:
		o.hs = "bun"
	elif role == "chef":
		o.hs = "short"
	if role == "chef":
		o.glasses = false
	o.id = _next_id()
	o.kind = "dress" if dress else "staff"
	o.coat = Color(s["coat"]); o.coat_n = s["coat_n"]; o.pants = Color(s["pants"])
	o.tie = Color(s.get("tie", "#8c2f39"))
	var hat: Array = s["hat"]
	o.hat_t = hat[0]; o.hat_c = Color(hat[1]); o.hat_n = hat[2]; o.hat_cn = hat[3]
	o.hair = Color(Rng.pick(HAIRS)); o.skin = Color(Rng.pick(SKINS))
	o.staff_role = role
	o.apron = s.get("apron", false)
	o.bow = s.get("bow", false)
	o.key = "staff" + role
	return o

static func new_police() -> Outfit:
	var o := Outfit.new()
	o.hs = "short"; o.stache = Rng.rnd() < 0.55; o.build = 1.06
	o.id = _next_id(); o.kind = "police"
	o.coat = Color("#1f2f4a"); o.coat_n = "uniforme de policía"; o.pants = Color("#1a2438"); o.tie = Color("#1a1a1a")
	o.hat_t = "police"; o.hat_c = Color("#1f2f4a"); o.hat_n = "gorra de policía"; o.hat_cn = "azul"
	o.hair = Color("#2a2018"); o.skin = Color(Rng.pick(SKINS)); o.key = "police"
	return o

static func new_under(src: Outfit) -> Outfit:
	var o := Outfit.new()
	o.hs = src.hs; o.glasses = src.glasses; o.stache = src.stache; o.build = src.build
	o.id = _next_id(); o.kind = "under"
	o.coat = Color("#d8d1bd"); o.coat_n = "ropa interior"; o.pants = Color("#cfc6b0"); o.has_tie = false
	o.hat_t = "none"; o.hat_n = "sin sombrero"; o.hair = src.hair; o.skin = src.skin; o.key = "under"
	return o

func clone() -> Outfit:
	var c := Outfit.new()
	for p in ["id", "kind", "coat", "coat_n", "pants", "tie", "has_tie", "hat_t", "hat_c", "hat_n", "hat_cn", "hair", "skin", "staff_role", "blood", "key", "hs", "glasses", "stache", "build", "apron", "bow"]:
		c.set(p, get(p))
	return c

func describe() -> String:
	var s := ""
	if staff_role != "":
		s = str(STAFF[staff_role]["label"]) + ": " + coat_n
	else:
		s = ("Vestido " if kind == "dress" else "Traje ") + coat_n
	if hat_t != "none":
		s += ", " + hat_n + ((" " + hat_cn) if hat_cn != "" else "")
	if glasses:
		s += ", gafas"
	if stache:
		s += ", bigote"
	if hs == "bald":
		s += ", calvo"
	return s
