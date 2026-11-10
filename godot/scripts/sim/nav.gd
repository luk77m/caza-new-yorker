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
	if tx < 0 or ty < 0 or tx >= W or ty >= H or f.pass[target] == 0:
		# si el destino está ocupado, usar la casilla libre más cercana
		var best := -1
		var bd := 99
		for j in range(-2, 3):
			for i in range(-2, 3):
				var nx := tx + i
				var ny := ty + j
				if nx < 0 or ny < 0 or nx >= W or ny >= H:
					continue
				if f.pass[ny * W + nx] != 0 and absi(i) + absi(j) < bd:
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
			if _seen[ni] != 0 or f.pass[ni] == 0 or (has_avoid and avoid[ni] != 0):
				continue
			if d >= 4 and (f.pass[cy * W + ax] == 0 or f.pass[ay * W + cx] == 0):
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
