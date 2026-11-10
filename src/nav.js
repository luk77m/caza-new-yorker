/* ===== navegación y visión ===== */
var _q = new Int32Array(W * H), _prev = new Int32Array(W * H), _seen = new Uint8Array(W * H);
function bfs(f, sx, sy, tx, ty) {
  if (sx < 0 || sy < 0 || sx >= W || sy >= H) return null;
  var target = ty * W + tx, start = sy * W + sx;
  if (!f.pass[target]) {
    /* si el destino está ocupado, usar la casilla libre más cercana alrededor */
    var best = -1, bd = 99;
    for (var j = -2; j <= 2; j++) for (var i = -2; i <= 2; i++) { var nx = tx + i, ny = ty + j; if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue; if (f.pass[ny * W + nx] && Math.abs(i) + Math.abs(j) < bd) { bd = Math.abs(i) + Math.abs(j); best = ny * W + nx; } }
    if (best < 0) return null; target = best;
  }
  if (start === target) return [];
  _seen.fill(0);
  var head = 0, tail = 0; _q[tail++] = start; _seen[start] = 1; _prev[start] = -1;
  var DX = [1, -1, 0, 0, 1, 1, -1, -1], DY = [0, 0, 1, -1, 1, -1, 1, -1];
  var found = false;
  while (head < tail && !found) {
    var cur = _q[head++], cxn = cur % W, cyn = (cur / W) | 0;
    for (var d = 0; d < 8; d++) {
      var ax = cxn + DX[d], ay = cyn + DY[d];
      if (ax < 0 || ay < 0 || ax >= W || ay >= H) continue;
      var ni = ay * W + ax;
      if (_seen[ni] || !f.pass[ni]) continue;
      if (d >= 4 && (!f.pass[cyn * W + ax] || !f.pass[ay * W + cxn])) continue;
      _seen[ni] = 1; _prev[ni] = cur; _q[tail++] = ni;
      if (ni === target) { found = true; break; }
    }
  }
  if (!found) return null;
  var path = [], p = target;
  while (p !== start && p >= 0) { path.push({ x: p % W, y: (p / W) | 0 }); p = _prev[p]; }
  path.reverse();
  return path;
}
function los(f, x0, y0, x1, y1) {
  var dx = x1 - x0, dy = y1 - y0, d = Math.hypot(dx, dy);
  if (d < 1) return true;
  var n = Math.ceil(d / 8), sx = dx / n, sy = dy / n;
  for (var i = 1; i < n; i++) {
    var tx = Math.floor((x0 + sx * i) / TS), ty = Math.floor((y0 + sy * i) / TS);
    if (SIGHTB[at(f, tx, ty)]) return false;
  }
  return true;
}
function rayDist(f, x, y, ang, maxd) {
  var c = Math.cos(ang), s = Math.sin(ang);
  for (var d = 6; d < maxd; d += 6) {
    var tx = Math.floor((x + c * d) / TS), ty = Math.floor((y + s * d) / TS);
    if (SIGHTB[at(f, tx, ty)]) return d + 4;
  }
  return maxd;
}
