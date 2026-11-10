/* ===== mapa: 7 plantas con zonas (pública / habitación / personal) ===== */
var ZONE_PUB = 0, ZONE_ROOM = 1, ZONE_STAFF = 2;
function zoneOfName(name) {
  if (/^(Hab\.|Suite|Despacho)/.test(name)) return ZONE_ROOM;
  if (/^(Cuarto de servicio|Sala de calderas|Lavandería|Almacén|Cocina de servicio|Sala eléctrica)/.test(name)) return ZONE_STAFF;
  return ZONE_PUB;
}
function mk(label, sub, o) {
  var f = { label: label, sub: sub, g: new Uint8Array(W * H), blk: new Uint8Array(W * H), zone: new Uint8Array(W * H), pass: new Uint8Array(W * H),
    furn: [], rooms: [], doors: [], lamps: [], wards: [], sinks: [], washers: [], dark: 0.3, sky: false, wall: 'deco', up: null, down: null, spawn: null, phone: null,
    tilesPub: [], roomTiles: {}, hallY: null };
  for (var k in o) f[k] = o[k];
  return f;
}
function at(f, x, y) { return (x < 0 || y < 0 || x >= W || y >= H) ? T.VOID : f.g[y * W + x]; }
function set(f, x, y, t) { if (x >= 0 && y >= 0 && x < W && y < H) f.g[y * W + x] = t; }
function fill(f, x, y, w, h, t) { for (var j = y; j < y + h; j++) for (var i = x; i < x + w; i++) set(f, i, j, t); }
function box(f, x, y, w, h, ft) {
  for (var j = y; j < y + h; j++) for (var i = x; i < x + w; i++) set(f, i, j, (i === x || j === y || i === x + w - 1 || j === y + h - 1) ? T.WALL : ft);
}
var NONSOLID = { rug: 1 };
function F(f, k, x, y, w, h, o) { f.furn.push({ k: k, x: x, y: y, w: w || 1, h: h || 1, o: o || {}, solid: !NONSOLID[k] }); }
function room(f, x, y, w, h, name, ft, side, o) {
  o = o || {};
  box(f, x, y, w, h, ft);
  var r = { name: name, x: x, y: y, w: w, h: h, side: side, zone: zoneOfName(name) };
  f.rooms.push(r);
  var dw = o.dw || 1, pos = (o.pos !== undefined) ? o.pos : ((side === 'N' || side === 'S') ? x + Math.floor(w / 2) : y + Math.floor(h / 2));
  for (var i = 0; i < dw; i++) {
    var dx, dy;
    if (side === 'S') { dx = pos + i; dy = y + h - 1; }
    else if (side === 'N') { dx = pos + i; dy = y; }
    else if (side === 'E') { dx = x + w - 1; dy = pos + i; }
    else { dx = x; dy = pos + i; }
    f.doors.push({ x: dx, y: dy });
    if (i === 0) { r.door = { x: dx, y: dy }; r.out = { x: dx + (side === 'E' ? 1 : (side === 'W' ? -1 : 0)), y: dy + (side === 'S' ? 1 : (side === 'N' ? -1 : 0)) }; }
  }
  return r;
}
function placeCore(f, y0, hasUp, hasDown) {
  fill(f, 20, y0 + 1, 4, 1, T.ELEV);
  if (hasUp) { set(f, 18, y0 + 3, T.UP); f.up = { x: 18, y: y0 + 3 }; }
  if (hasDown) { set(f, 25, y0 + 3, T.DOWN); f.down = { x: 25, y: y0 + 3 }; }
  f.spawn = { x: 22, y: y0 + 3 };
  f.coreY = y0;
  F(f, 'plant', 18, y0 + 1); F(f, 'plant', 25, y0 + 1);
  F(f, 'phone', 19, y0 + 1);
  f.phone = { x: 19, y: y0 + 2 };
  F(f, 'rug', 19, y0 + 2, 6, 7);
}
function core(f, y0, yb, ft, hasUp, hasDown, openT) {
  box(f, 17, y0, 10, yb - y0 + 1, ft);
  fill(f, 20, yb, 4, 1, openT);
  placeCore(f, y0, hasUp, hasDown);
  f.rooms.push({ name: 'Núcleo de ascensores', x: 17, y: y0, w: 10, h: yb - y0 + 1, zone: ZONE_PUB });
  F(f, 'bench', 21, yb - 1, 2, 1);
}
function shell(f, x0, x1, y0, y1, ft, hallT, hasUp, hasDown) {
  fill(f, x0 + 1, 14, x1 - x0 - 1, 2, hallT);
  set(f, x0, 14, T.WALL); set(f, x0, 15, T.WALL); set(f, x1, 14, T.WALL); set(f, x1, 15, T.WALL);
  f.hallX = [x0 + 4, x1 - 4];
  core(f, y0, 13, ft, hasUp, hasDown, hallT);
}
function split(xa, xb, target) {
  var n = Math.max(1, Math.round((xb - xa) / target)), e = [];
  for (var k = 0; k <= n; k++) e.push(xa + Math.round(k * (xb - xa) / n));
  return e;
}
function furnishHotel(f, r, side, o) {
  o = o || {};
  var ix0 = r.x + 1, ix1 = r.x + r.w - 2, iw = ix1 - ix0 + 1;
  function far(dy, hh) { return side === 'S' ? r.y + 1 + dy : r.y + r.h - 2 - dy - (hh - 1); }
  F(f, 'bed', ix0, far(0, 3), 2, 3, { c: o.c || 0 });
  F(f, 'night', ix0 + 2, far(0, 1));
  if (iw >= 5) F(f, 'desk', ix1 - 1, far(0, 1), 2, 1);
  F(f, 'ward', ix1, far(iw >= 5 ? 1 : 0, 2), 1, 2);
  F(f, 'plant', ix0, side === 'S' ? r.y + r.h - 2 : r.y + 1);
  F(f, 'sink', ix1, side === 'S' ? r.y + r.h - 2 : r.y + 1);
}
function cx(r) { return r.x + Math.floor(r.w / 2); }
function cy(r) { return r.y + Math.floor(r.h / 2); }

function standTile(f, o) {
  var best = null, bd = 1e9, rcx = o.x + o.w / 2, rcy = o.y + o.h / 2;
  for (var j = o.y - 1; j <= o.y + o.h; j++) for (var i = o.x - 1; i <= o.x + o.w; i++) {
    var inside = i >= o.x && i < o.x + o.w && j >= o.y && j < o.y + o.h;
    var corner = (i < o.x || i >= o.x + o.w) && (j < o.y || j >= o.y + o.h);
    if (inside || corner) continue;
    if (i < 0 || j < 0 || i >= W || j >= H) continue;
    if (SOLIDT[f.g[j * W + i]] || f.blk[j * W + i]) continue;
    var d = Math.hypot(i + .5 - rcx, j + .5 - rcy);
    if (d < bd) { bd = d; best = { x: i, y: j }; }
  }
  return best;
}
function finish(f) {
  f.doors.forEach(function (d) { set(f, d.x, d.y, T.DOOR); });
  f.lockAt = {};
  f.rooms.forEach(function (r) { if (r.zone === ZONE_ROOM && r.door) f.lockAt[r.door.y * W + r.door.x] = r; });
  f.furn.forEach(function (o) { if (!o.solid) return; for (var j = o.y; j < o.y + o.h; j++) for (var i = o.x; i < o.x + o.w; i++) if (i >= 0 && j >= 0 && i < W && j < H) f.blk[j * W + i] = 1; });
  f.rooms.forEach(function (r) {
    if (!r.zone) return;
    for (var j = r.y; j < r.y + r.h; j++) for (var i = r.x; i < r.x + r.w; i++) f.zone[j * W + i] = r.zone;
  });
  for (var k = 0; k < W * H; k++) f.pass[k] = (!SOLIDT[f.g[k]] && !f.blk[k]) ? 1 : 0;
  /* puntos de interacción */
  f.furn.forEach(function (o) {
    if (o.k === 'ward') { var s = standTile(f, o); f.wards.push({ x: o.x, y: o.y, w: o.w, h: o.h, stand: s, looted: false, floorIdx: -1 }); }
    if (o.k === 'sink') { var s2 = standTile(f, o); f.sinks.push({ x: o.x, y: o.y, w: 1, h: 1, stand: s2 }); }
    if (o.k === 'washer') { var s3 = standTile(f, o); f.washers.push({ x: o.x, y: o.y, w: o.w, h: o.h, stand: s3 }); }
  });
  /* listas de casillas para que los PNJ elijan destinos */
  for (var y = 0; y < H; y++) for (var x = 0; x < W; x++) {
    var idx = y * W + x;
    if (!f.pass[idx]) continue;
    var t = f.g[idx];
    if (t === T.UP || t === T.DOWN || t === T.DOOR) continue;
    if (f.zone[idx] === ZONE_PUB) f.tilesPub.push({ x: x, y: y });
  }
  f.rooms.forEach(function (r) {
    var arr = [];
    for (var j = r.y + 1; j < r.y + r.h - 1; j++) for (var i = r.x + 1; i < r.x + r.w - 1; i++) { var id = j * W + i; if (f.pass[id] && f.g[id] !== T.UP && f.g[id] !== T.DOWN) arr.push({ x: i, y: j }); }
    f.roomTiles[r.name] = arr;
  });
  /* luces del techo */
  function lamp(x, y, r, tint) { f.lamps.push({ x: x * TS, y: y * TS, r: r, tint: tint || 'warm' }); }
  f.rooms.forEach(function (r) {
    var area = (r.w - 2) * (r.h - 2);
    if (area > 150) {
      for (var lx = r.x + 4; lx < r.x + r.w - 2; lx += 9) for (var ly = r.y + 4; ly < r.y + r.h - 2; ly += 8) lamp(lx, ly, 175);
    } else lamp(r.x + r.w / 2, r.y + r.h / 2, clamp(Math.max(r.w, r.h) * TS * 0.9, 120, 210), r.zone === ZONE_STAFF ? 'cold' : 'warm');
  });
  if (f.hallX) for (var hx = f.hallX[0]; hx <= f.hallX[1]; hx += 8) lamp(hx, 15, 150);
  return f;
}

var FLOORS = [];
/* Sótano */
(function () {
  var f = mk('Sótano', 'Calderas y lavandería', { dark: 0.45, wall: 'brick' });
  shell(f, 4, 39, 5, 24, T.CONC, T.CONC, true, false);
  room(f, 4, 5, 14, 9, 'Sala de calderas', T.CONC, 'S');
  room(f, 26, 5, 14, 9, 'Lavandería', T.CONC, 'S');
  room(f, 4, 16, 12, 9, 'Almacén', T.CONC, 'N');
  room(f, 15, 16, 12, 9, 'Cocina de servicio', T.CONC, 'N');
  room(f, 26, 16, 14, 9, 'Sala eléctrica', T.CONC, 'N');
  F(f, 'boiler', 6, 6, 3, 3); F(f, 'boiler', 10, 6, 3, 3); F(f, 'boiler', 14, 6, 3, 3);
  [27, 30, 33, 36].forEach(function (x) { F(f, 'washer', x, 6, 2, 2); });
  F(f, 'crate', 5, 17, 2, 2); F(f, 'crate', 13, 17, 2, 2); F(f, 'crate', 5, 22, 2, 2); F(f, 'crate', 9, 22, 2, 2); F(f, 'crate', 13, 22, 2, 2);
  F(f, 'steel', 17, 19, 3, 1); F(f, 'steel', 21, 19, 3, 1); F(f, 'steel', 17, 22, 3, 1); F(f, 'steel', 21, 22, 3, 1); F(f, 'stove', 16, 17, 3, 1);
  F(f, 'gen', 28, 19, 3, 2); F(f, 'gen', 32, 19, 3, 2); F(f, 'gen', 36, 19, 2, 2); F(f, 'gen', 28, 22, 3, 2);
  FLOORS[0] = finish(f);
})();
/* Planta baja */
(function () {
  var f = mk('Planta baja', 'Vestíbulo', { dark: 0.2 });
  box(f, 2, 3, 40, 24, T.MARBLE);
  placeCore(f, 3, true, true);
  fill(f, 20, 26, 4, 1, T.DOOR);
  f.rooms.push({ name: 'Vestíbulo', x: 2, y: 3, w: 40, h: 24, zone: ZONE_PUB });
  room(f, 2, 3, 11, 10, 'Despacho del gerente', T.WOOD, 'S', { pos: 7 });
  room(f, 31, 3, 11, 10, 'Correos', T.WOOD, 'S', { pos: 36 });
  room(f, 2, 17, 11, 10, 'Tienda de regalos', T.WOOD, 'N', { pos: 7 });
  room(f, 31, 17, 11, 10, 'Cafetería', T.WOOD, 'N', { pos: 36 });
  F(f, 'recdesk', 18, 13, 8, 2); F(f, 'rug', 16, 16, 12, 8);
  [[14, 9], [29, 9], [14, 20], [29, 20]].forEach(function (p) { F(f, 'column', p[0], p[1]); });
  F(f, 'sofa', 14, 24, 3, 1); F(f, 'sofa', 27, 24, 3, 1);
  [[13, 4], [30, 4], [13, 25], [30, 25]].forEach(function (p) { F(f, 'plant', p[0], p[1]); });
  F(f, 'desk', 4, 5, 3, 1); F(f, 'safe', 10, 4, 1, 1); F(f, 'plant', 3, 11);
  F(f, 'mail', 33, 4, 6, 1); F(f, 'desk', 33, 8, 3, 1);
  F(f, 'shelf', 4, 19, 6, 1); F(f, 'shelf', 4, 24, 6, 1);
  F(f, 'table', 33, 21, 2, 2); F(f, 'table', 38, 21, 2, 2); F(f, 'bar', 33, 25, 7, 1);
  f.start = { x: 22, y: 24 };
  FLOORS[1] = finish(f);
})();
/* Planta 2: salones */
(function () {
  var f = mk('Planta 2', 'Gran Salón', { dark: 0.28 });
  shell(f, 3, 40, 5, 25, T.WOOD, T.HALL, true, true);
  room(f, 3, 5, 15, 9, 'Restaurante Terrace', T.WOOD, 'S');
  room(f, 26, 5, 15, 9, 'Bar', T.WOOD, 'S');
  room(f, 3, 16, 38, 10, 'Gran Salón', T.WOOD, 'N', { pos: 21, dw: 2 });
  F(f, 'stage', 14, 24, 12, 2); F(f, 'piano', 5, 21, 3, 2);
  [[6, 18], [10, 18], [31, 18], [35, 18], [31, 21], [35, 21]].forEach(function (p) { F(f, 'table', p[0], p[1], 2, 2); });
  F(f, 'rug', 14, 18, 12, 5);
  [[5, 7], [9, 7], [13, 7], [5, 10], [14, 10]].forEach(function (p) { F(f, 'table', p[0], p[1], 2, 2); });
  F(f, 'bar', 28, 8, 9, 1); F(f, 'plant', 27, 6); F(f, 'plant', 39, 6);
  FLOORS[2] = finish(f);
})();
/* Planta 10 */
(function () {
  var f = mk('Planta 10', 'Habitaciones', { dark: 0.38 });
  shell(f, 6, 37, 5, 24, T.CARPET, T.HALL, true, true);
  var n = 1001, e = split(6, 17, 6), i, r;
  for (i = 0; i < e.length - 1; i++) { r = room(f, e[i], 5, e[i + 1] - e[i] + 1, 9, 'Hab. ' + (n++), T.CARPET, 'S'); furnishHotel(f, r, 'S', { c: i % 2 }); }
  e = split(26, 37, 6);
  for (i = 0; i < e.length - 1; i++) {
    var last = i === e.length - 2;
    r = room(f, e[i], 5, e[i + 1] - e[i] + 1, 9, last ? 'Cuarto de servicio' : 'Hab. ' + (n++), last ? T.CONC : T.CARPET, 'S');
    if (last) { F(f, 'shelf', r.x + 1, 6, r.w - 2, 1); F(f, 'cart', r.x + 1, 11, 2, 1); } else furnishHotel(f, r, 'S', { c: (i + 1) % 2 });
  }
  e = split(6, 37, 6);
  for (i = 0; i < e.length - 1; i++) { r = room(f, e[i], 16, e[i + 1] - e[i] + 1, 9, 'Hab. ' + (n++), T.CARPET, 'N'); furnishHotel(f, r, 'N', { c: i % 2 }); }
  FLOORS[3] = finish(f);
})();
/* Planta 20 */
(function () {
  var f = mk('Planta 20', 'Suites', { dark: 0.38 });
  shell(f, 9, 34, 5, 24, T.CARPET, T.HALL, true, true);
  var ra = room(f, 9, 5, 9, 9, 'Suite 2002', T.CARPET, 'S'); furnishHotel(f, ra, 'S', { c: 1 });
  var rb = room(f, 26, 5, 9, 9, 'Suite 2001', T.CARPET, 'S'); furnishHotel(f, rb, 'S', { c: 0 });
  var e = split(9, 34, 6), n = 2003;
  for (var k = 0; k < e.length - 1; k++) { var r = room(f, e[k], 16, e[k + 1] - e[k] + 1, 9, 'Suite ' + (n++), T.CARPET, 'N'); furnishHotel(f, r, 'N', { c: k % 2 }); }
  FLOORS[4] = finish(f);
})();
/* Planta 30 */
(function () {
  var f = mk('Planta 30', 'Terraza mirador', { dark: 0.2, sky: true });
  shell(f, 12, 31, 5, 24, T.CARPET, T.HALL, true, true);
  room(f, 12, 5, 6, 9, 'Salón mirador', T.CARPET, 'S');
  F(f, 'sofa', 13, 6, 3, 1); F(f, 'plant', 16, 6); F(f, 'table', 13, 9, 2, 2); F(f, 'plant', 13, 12);
  room(f, 26, 5, 6, 9, 'Biblioteca', T.WOOD, 'S');
  F(f, 'shelf', 27, 6, 4, 1); F(f, 'table', 28, 9, 2, 2); F(f, 'plant', 27, 12);
  box(f, 12, 16, 20, 9, T.TERR);
  for (var i = 12; i <= 31; i++) set(f, i, 24, T.RAIL);
  for (var j = 17; j <= 24; j++) { set(f, 12, j, T.RAIL); set(f, 31, j, T.RAIL); }
  f.doors.push({ x: 21, y: 16 }); f.doors.push({ x: 22, y: 16 });
  f.rooms.push({ name: 'Terraza', x: 12, y: 16, w: 20, h: 9, zone: ZONE_PUB });
  F(f, 'bench', 14, 22, 3, 1); F(f, 'bench', 27, 22, 3, 1);
  [[13, 17], [30, 17], [13, 23], [30, 23]].forEach(function (p) { F(f, 'plant', p[0], p[1]); });
  F(f, 'table', 16, 18, 2, 2); F(f, 'table', 25, 18, 2, 2); F(f, 'scope', 21, 22);
  FLOORS[5] = finish(f);
})();
/* Azotea */
(function () {
  var f = mk('Azotea', 'Letrero y antena', { dark: 0.1, sky: true, roof: true });
  box(f, 13, 6, 18, 18, T.ROOF);
  for (var i = 13; i <= 30; i++) { set(f, i, 6, T.RAIL); set(f, i, 23, T.RAIL); }
  for (var j = 6; j <= 23; j++) { set(f, 13, j, T.RAIL); set(f, 30, j, T.RAIL); }
  f.rooms.push({ name: 'Azotea', x: 13, y: 6, w: 18, h: 18, zone: ZONE_PUB });
  core(f, 6, 12, T.WOOD, false, true, T.ROOF);
  F(f, 'sign', 15, 20, 14, 2); F(f, 'antenna', 22, 15); F(f, 'vent', 15, 14, 2, 1); F(f, 'vent', 27, 14, 2, 1); F(f, 'scope', 28, 17); F(f, 'vent', 15, 17, 2, 1);
  FLOORS[6] = finish(f);
})();
FLOORS.forEach(function (f, i) { f.wards.forEach(function (w) { w.floorIdx = i; }); f.rooms.forEach(function (r) { r.fi = i; }); });
function roomAt(f, tx, ty) {
  var best = null, ba = 1e9;
  f.rooms.forEach(function (r) { if (tx >= r.x && tx < r.x + r.w && ty >= r.y && ty < r.y + r.h && r.w * r.h < ba) { ba = r.w * r.h; best = r; } });
  return best;
}
function roomLabel(r) { var m = /^Hab\.\s+(\d+)/.exec(r.name); return m ? 'habitación ' + m[1] : (/^Suite/.test(r.name) ? r.name.replace('Suite', 'suite') : r.name.charAt(0).toLowerCase() + r.name.slice(1)); }
function roomSpot(r) {
  var tiles = FLOORS[r.fi].roomTiles[r.name], best = null, bd = 1e9, cxr = r.x + r.w / 2, cyr = r.y + r.h / 2;
  tiles.forEach(function (t) { var d = Math.hypot(t.x + .5 - cxr, t.y + .5 - cyr); if (d < bd) { bd = d; best = t; } });
  return best;
}

function roomBy(fi, name) { var rs = FLOORS[fi].rooms; for (var i = 0; i < rs.length; i++) if (rs[i].name === name) return rs[i]; return null; }
/* Catálogo de encargos con sitio fijo. Cada corredor recibe 8-10 propios (ver assignTasks en sim.js). */
var TASK_DEFS = [
  { id: 'fusible', name: 'Cortar el fusible principal', floor: 0, x: 35, y: 22, dur: 6, sab: 'blackout' },
  { id: 'alarma', name: 'Activar la alarma de incendios', floor: 1, x: 15, y: 11, dur: 4, sab: 'alarm' },
  { id: 'ascensor', name: 'Bloquear los ascensores en la sala de máquinas', floor: 6, x: 24, y: 10, dur: 6, sab: 'elev' },
  { id: 'sobres', name: 'Recoger el sobre de pagos', floor: 0, x: 24, y: 21, dur: 4 },
  { id: 'sabanas', name: 'Esconder el paquete entre las sábanas', floor: 0, x: 30, y: 10, dur: 4 },
  { id: 'caldera', name: 'Aflojar la válvula de la caldera', floor: 0, x: 11, y: 11, dur: 5 },
  { id: 'cocina', name: 'Cambiar la comanda en la cocina', floor: 0, x: 20, y: 21, dur: 4 },
  { id: 'registro', name: 'Falsificar el libro de registro', floor: 1, x: 20, y: 12, dur: 5 },
  { id: 'telegrama', name: 'Enviar un telegrama cifrado', floor: 1, x: 35, y: 6, dur: 4 },
  { id: 'whisky', name: 'Cambiar la botella del mostrador', floor: 1, x: 36, y: 23, dur: 4 },
  { id: 'tienda', name: 'Dejar una nota en la tienda de regalos', floor: 1, x: 7, y: 22, dur: 3 },
  { id: 'barman', name: 'Hablar con el contacto del bar', floor: 2, x: 32, y: 9, dur: 4 },
  { id: 'piano', name: 'Dejar el sobre bajo el piano', floor: 2, x: 9, y: 21, dur: 4 },
  { id: 'escenario', name: 'Pasar el aviso al director de orquesta', floor: 2, x: 20, y: 22, dur: 3 },
  { id: 'espejo', name: 'Hacer señales desde el mirador', floor: 5, x: 20, y: 22, dur: 5 },
  { id: 'biblio', name: 'Esconder un mensaje entre los libros', floor: 5, x: 29, y: 7, dur: 4 },
  { id: 'mirador', name: 'Vigilar la entrada desde el salón mirador', floor: 5, x: 15, y: 11, dur: 5 },
  { id: 'antena', name: 'Reorientar la antena', floor: 6, x: 22, y: 16, dur: 6 },
  { id: 'maletin_a', kind: 'pick', pair: 'maletin_b', name: 'Recoger el maletín del almacén', floor: 0, x: 8, y: 20, dur: 3 },
  { id: 'maletin_b', kind: 'drop', name: 'Entregar el maletín en el despacho del gerente', floor: 1, x: 8, y: 9, dur: 3, roomName: 'Despacho del gerente' },
  { id: 'planos_a', kind: 'pick', pair: 'planos_b', name: 'Recoger los planos en Correos', floor: 1, x: 37, y: 9, dur: 3 },
  { id: 'planos_b', kind: 'drop', name: 'Entregar los planos en la terraza', floor: 5, x: 21, y: 19, dur: 3 }
];
var TASK_UNITS = TASK_DEFS.filter(function (t) { return t.kind !== 'pick'; }).length;
/* Encargos dentro de habitaciones: se generan por corredor (la suya es gratis, las demás están cerradas). */
var ROOM_TASKS = [
  { id: 'busca', name: 'Registrar la {r}', dur: 6 },
  { id: 'paquete', name: 'Esconder un paquete en la {r}', dur: 5 },
  { id: 'caja', name: 'Abrir la caja fuerte de la {r}', dur: 7 },
  { id: 'micro', name: 'Instalar un micrófono en la {r}', dur: 6 },
  { id: 'equipaje', name: 'Cambiar el equipaje de la {r}', dur: 5 }
];
var ROOM_POOL = [];
FLOORS.forEach(function (f, fi) { if (fi !== 3 && fi !== 4) return; f.rooms.forEach(function (r) { if (r.zone === ZONE_ROOM && r.door) ROOM_POOL.push(r); }); });

var KEY_SPOTS = {
  masterkey: [{ f: 1, x: 24, y: 12 }, { f: 3, x: cx(roomBy(3, 'Cuarto de servicio')), y: cy(roomBy(3, 'Cuarto de servicio')) }, { f: 4, x: cx(roomBy(4, 'Suite 2002')), y: cy(roomBy(4, 'Suite 2002')) }],
  badge: [{ f: 1, x: 8, y: 21 }, { f: 1, x: 36, y: 19 }]
};
var SCRAP_SPOTS = [
  { f: 0, x: 12, y: 14 }, { f: 0, x: 10, y: 20 }, { f: 0, x: 31, y: 21 }, { f: 1, x: 15, y: 17 }, { f: 1, x: 28, y: 8 }, { f: 2, x: 20, y: 20 }, { f: 2, x: 12, y: 15 },
  { f: 3, x: 30, y: 14 }, { f: 4, x: 14, y: 15 }, { f: 5, x: 20, y: 19 }, { f: 6, x: 16, y: 18 }, { f: 6, x: 28, y: 10 }
];
var SCRAP_NAMES = ['tubería', 'cinta aislante', 'tuercas', 'trozo de cadena', 'tablón', 'trapo'];
