## Carga data/hotel.json (exportado desde la versión web con tools/export_godot_data.js).
class_name Hotel
extends RefCounted

static var floors: Array = []       # FloorData
static var task_defs: Array = []    # Task (plantillas)
static var room_tasks: Array = []   # Dictionary {id, name, dur}
static var room_pool: Array = []    # Room (habitaciones que se reparten a los corredores)
static var key_masterkey: Array = []  # Vector3i (planta, x, y)
static var key_badge: Array = []
static var scrap_spots: Array = []
static var scrap_names: Array = []
static var assembly: Array = []     # punto de reunión en la evacuación (planta baja)
static var loaded := false

static func _v2(a) -> Vector2i:
	if a == null:
		return Vector2i(-1, -1)
	return Vector2i(int(a[0]), int(a[1]))

static func _bytes(a: Array) -> PackedByteArray:
	var p := PackedByteArray()
	p.resize(a.size())
	for i in a.size():
		p[i] = int(a[i])
	return p

static func _fixture(d: Dictionary, fi: int) -> Fixture:
	var f := Fixture.new()
	f.x = int(d["x"]); f.y = int(d["y"]); f.w = int(d["w"]); f.h = int(d["h"]); f.fi = fi
	if d["stand"] != null:
		f.stand = _v2(d["stand"]); f.has_stand = true
	return f

static func load_data(path: String = "res://data/hotel.json") -> void:
	if loaded:
		return
	var txt := FileAccess.get_file_as_string(path)
	var d: Dictionary = JSON.parse_string(txt)
	floors.clear()
	var fi := 0
	for fd in d["floors"]:
		var f := FloorData.new()
		f.fi = fi
		f.label = fd["label"]; f.sub = fd["sub"]; f.dark = float(fd["dark"]); f.sky = fd["sky"]; f.roof = fd["roof"]
		f.g = _bytes(fd["g"]); f.blk = _bytes(fd["blk"]); f.zone = _bytes(fd["zone"]); f.walkable = _bytes(fd["pass"])
		for rd in fd["rooms"]:
			var r := Room.new()
			r.nm = rd["name"]; r.x = int(rd["x"]); r.y = int(rd["y"]); r.w = int(rd["w"]); r.h = int(rd["h"])
			r.zone = int(rd["zone"]); r.side = rd["side"]; r.fi = fi
			if rd["door"] != null:
				r.has_door = true; r.door = _v2(rd["door"]); r.out = _v2(rd["out"])
			f.rooms.append(r)
		for o in fd["furn"]:
			f.furn.append({"k": o["k"], "x": int(o["x"]), "y": int(o["y"]), "w": int(o["w"]), "h": int(o["h"]), "solid": o["solid"]})
		for l in fd["lamps"]:
			f.lamps.append({"x": float(l["x"]), "y": float(l["y"]), "r": float(l["r"]), "tint": l["tint"]})
		for o in fd["wards"]:
			f.wards.append(_fixture(o, fi))
		for o in fd["sinks"]:
			f.sinks.append(_fixture(o, fi))
		for o in fd["washers"]:
			f.washers.append(_fixture(o, fi))
		f.up = _v2(fd["up"]); f.down = _v2(fd["down"]); f.spawn = _v2(fd["spawn"]); f.phone = _v2(fd["phone"])
		for t in fd["tilesPub"]:
			f.tiles_pub.append(_v2(t))
		for k in fd["roomTiles"]:
			var arr: Array = []
			for t in fd["roomTiles"][k]:
				arr.append(_v2(t))
			f.room_tiles[k] = arr
		for k in fd["lockAt"]:
			f.lock_at[int(k)] = f.room_by(fd["lockAt"][k])
		if fi == 1:
			f.open_from = 27
		floors.append(f)
		fi += 1
	task_defs.clear()
	for td in d["taskDefs"]:
		var t := Task.new()
		t.id = td["id"]; t.nm = td["name"]; t.fl = int(td["floor"]); t.x = int(td["x"]); t.y = int(td["y"])
		t.dur = float(td["dur"]); t.kind = td["kind"]; t.pair = td["pair"]; t.room_name = td["roomName"]; t.sab = td["sab"]
		task_defs.append(t)
	room_tasks = d["roomTasks"]
	room_pool.clear()
	for rp in d["roomPool"]:
		room_pool.append(floors[int(rp[0])].room_by(rp[1]))
	key_masterkey.clear(); key_badge.clear(); scrap_spots.clear()
	for s in d["keySpots"]["masterkey"]:
		key_masterkey.append(Vector3i(int(s[0]), int(s[1]), int(s[2])))
	for s in d["keySpots"]["badge"]:
		key_badge.append(Vector3i(int(s[0]), int(s[1]), int(s[2])))
	for s in d["scrapSpots"]:
		scrap_spots.append(Vector3i(int(s[0]), int(s[1]), int(s[2])))
	scrap_names = d["scrapNames"]
	assembly.clear()
	for t in floors[1].tiles_pub:
		if t.y >= 19 and t.y <= 25 and t.x >= 15 and t.x <= 29:
			assembly.append(t)
	loaded = true

## Casilla libre más céntrica de una habitación (donde van sus encargos).
static func room_spot(r: Room) -> Vector2i:
	var tiles: Array = floors[r.fi].room_tiles.get(r.nm, [])
	var best := Vector2i(r.x + r.w / 2, r.y + r.h / 2)
	var bd := 1e9
	var cx := r.x + r.w / 2.0
	var cy := r.y + r.h / 2.0
	for t in tiles:
		var dd := Vector2(t.x + 0.5 - cx, t.y + 0.5 - cy).length()
		if dd < bd:
			bd = dd
			best = t
	return best

static func room_by(fi: int, nm: String) -> Room:
	return floors[fi].room_by(nm)
