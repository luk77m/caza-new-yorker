## Búsqueda de caminos (BFS en 8 direcciones) y línea de visión.
class_name Nav
extends RefCounted

const DX := [1, -1, 0, 0, 1, 1, -1, -1]
const DY := [0, 0, 1, -1, 1, -1, 1, -1]
static var _q := PackedInt32Array()
static var _prev := PackedInt32Array()
static var _seen := PackedByteArray()

## Devuelve un Array de Vector2i, [] si ya estás, o null si no hay camino.
static func bfs(f: FloorData, sx: int, sy: int, tx: int, ty: int, avoid: PackedByteArray) -> Variant:
	var W := Cfg.W
	var H := Cfg.H
	if sx < 0 or sy < 0 or sx >= W or sy >= H:
		return null
	if _q.size() != W * H:
		_q.resize(W * H); _prev.resize(W * H); _seen.resize(W * H)
	var target := ty * W + tx
	var start := sy * W + sx
	if tx < 0 or ty < 0 or tx >= W or ty >= H or f.walkable[target] == 0:
		# si el destino está ocupado, usar la casilla libre más cercana
		var best := -1
		var bd := 99
		for j in range(-2, 3):
			for i in range(-2, 3):
				var nx := tx + i
				var ny := ty + j
				if nx < 0 or ny < 0 or nx >= W or ny >= H:
					continue
				if f.walkable[ny * W + nx] != 0 and absi(i) + absi(j) < bd:
					bd = absi(i) + absi(j)
					best = ny * W + nx
		if best < 0:
			return null
		target = best
	if start == target:
		return []
	_seen.fill(0)
	var head := 0
	var tail := 0
	_q[tail] = start; tail += 1
	_seen[start] = 1
	_prev[start] = -1
	var found := false
	var has_avoid := avoid.size() == W * H
	while head < tail and not found:
		var cur := _q[head]; head += 1
		var cx := cur % W
		var cy := cur / W
		for d in 8:
			var ax: int = cx + DX[d]
			var ay: int = cy + DY[d]
			if ax < 0 or ay < 0 or ax >= W or ay >= H:
				continue
			var ni := ay * W + ax
			if _seen[ni] != 0 or f.walkable[ni] == 0 or (has_avoid and avoid[ni] != 0):
				continue
			if d >= 4 and (f.walkable[cy * W + ax] == 0 or f.walkable[ay * W + cx] == 0):
				continue
			_seen[ni] = 1
			_prev[ni] = cur
			_q[tail] = ni; tail += 1
			if ni == target:
				found = true
				break
	if not found:
		return null
	var path: Array = []
	var p := target
	while p != start and p >= 0:
		path.append(Vector2i(p % W, p / W))
		p = _prev[p]
	path.reverse()
	return path

static func los(f: FloorData, x0: float, y0: float, x1: float, y1: float) -> bool:
	var dx := x1 - x0
	var dy := y1 - y0
	var d := sqrt(dx * dx + dy * dy)
	if d < 1.0:
		return true
	var n := ceili(d / 8.0)
	var sx := dx / n
	var sy := dy / n
	for i in range(1, n):
		var tx := floori((x0 + sx * i) / Cfg.TS)
		var ty := floori((y0 + sy * i) / Cfg.TS)
		if Cfg.blocks_sight(f.at(tx, ty)):
			return false
	return true

static func ray_dist(f: FloorData, x: float, y: float, ang: float, maxd: float) -> float:
	var c := cos(ang)
	var s := sin(ang)
	var d := 6.0
	while d < maxd:
		var tx := floori((x + c * d) / Cfg.TS)
		var ty := floori((y + s * d) / Cfg.TS)
		if Cfg.blocks_sight(f.at(tx, ty)):
			return d + 4.0
		d += 6.0
	return maxd

## Distancia exacta hasta la primera casilla que tapa la vista (recorrido DDA por la cuadrícula).
static func ray_exact(f: FloorData, ox: float, oy: float, dx: float, dy: float, maxd: float) -> float:
	var TS := float(Cfg.TS)
	var tx := floori(ox / TS)
	var ty := floori(oy / TS)
	var sx := 1 if dx > 0 else -1
	var sy := 1 if dy > 0 else -1
	var t_max_x := INF
	var t_max_y := INF
	var t_dx := INF
	var t_dy := INF
	if absf(dx) > 1e-9:
		t_max_x = ((tx + (1 if dx > 0 else 0)) * TS - ox) / dx
		t_dx = TS / absf(dx)
	if absf(dy) > 1e-9:
		t_max_y = ((ty + (1 if dy > 0 else 0)) * TS - oy) / dy
		t_dy = TS / absf(dy)
	var t := 0.0
	for _i in 256:
		if t_max_x < t_max_y:
			t = t_max_x
			t_max_x += t_dx
			tx += sx
		else:
			t = t_max_y
			t_max_y += t_dy
			ty += sy
		if t >= maxd:
			return maxd
		if Cfg.blocks_sight(f.at(tx, ty)):
			return t
	return maxd

## Polígono de visión exacto (sin dientes): rayos a las esquinas de las paredes cercanas
## más un círculo de rayos para el límite de la vista. Devuelve puntos ordenados por ángulo.
static func vis_poly(f: FloorData, ox: float, oy: float, radius: float) -> PackedVector2Array:
	var TS := float(Cfg.TS)
	var angs := {}
	for i in 72:
		angs[i * 10000] = TAU * i / 72.0
	var x0 := floori((ox - radius) / TS)
	var x1 := floori((ox + radius) / TS)
	var y0 := floori((oy - radius) / TS)
	var y1 := floori((oy + radius) / TS)
	var r2 := radius * radius * 1.1
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			if not Cfg.blocks_sight(f.at(tx, ty)):
				continue
			if Cfg.blocks_sight(f.at(tx - 1, ty)) and Cfg.blocks_sight(f.at(tx + 1, ty)) and Cfg.blocks_sight(f.at(tx, ty - 1)) and Cfg.blocks_sight(f.at(tx, ty + 1)):
				continue
			for c in 4:
				var cx := (tx + (c & 1)) * TS
				var cy := (ty + ((c >> 1) & 1)) * TS
				var ddx := cx - ox
				var ddy := cy - oy
				if ddx * ddx + ddy * ddy > r2:
					continue
				var a := fposmod(atan2(ddy, ddx), TAU)
				var key := int(a * 100000.0)
				if angs.has(key):
					continue
				angs[key] = a
				angs[key - 1] = fposmod(a - 0.0004, TAU)
				angs[key + 1] = fposmod(a + 0.0004, TAU)
	var list: Array = angs.values()
	list.sort()
	var pts := PackedVector2Array()
	for a in list:
		var dx := cos(a)
		var dy := sin(a)
		var d := ray_exact(f, ox, oy, dx, dy, radius)
		pts.append(Vector2(ox + dx * d, oy + dy * d))
	return pts
