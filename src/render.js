/* ===== dibujo: tiles con textura, mobiliario, personajes, luces y niebla de visión ===== */
var VW = 960, VH = 600, SIGHT_PX = 520;
var REN = { cam: { x: 0, y: 0 }, expl: [], lightC: null, fogC: null, skyline: null };
function resetRender() {
  REN.expl = FLOORS.map(function () { return new Uint8Array(W * H); });
  if (!REN.lightC) { REN.lightC = mkc(VW, VH); REN.fogC = mkc(VW, VH); }
  if (!REN.skyline) {
    var out = [], x = 0, s = 7;
    var r = function () { s = (s * 16807) % 2147483647; return s / 2147483647; };
    while (x < 2400) { var wd = 40 + r() * 70, h = 60 + r() * 170; out.push({ x: x, w: wd, h: h, s: Math.floor(r() * 1000) }); x += wd + r() * 14; }
    REN.skyline = out;
  }
}
function hash2(x, y) { var h = (x * 374761393 + y * 668265263) | 0; h = (h ^ (h >> 13)) * 1274126177; return ((h ^ (h >> 16)) >>> 0) / 4294967295; }

/* ---------- cielo ---------- */
function drawSky(g, time, camX) {
  var gr = g.createLinearGradient(0, 0, 0, VH); gr.addColorStop(0, '#0b1626'); gr.addColorStop(0.6, '#2a2f4a'); gr.addColorStop(1, '#5b4247');
  g.fillStyle = gr; g.fillRect(0, 0, VW, VH);
  [[0.22, '#14202d', 0], [0.4, '#0c1621', 1]].forEach(function (L) {
    var off = -((camX * L[0]) % 2400);
    for (var rep = 0; rep < 3; rep++) REN.skyline.forEach(function (b) {
      var bx = b.x + off + rep * 2400, by = VH - b.h * (L[2] ? 1.15 : 0.8) + (L[2] ? 30 : 0);
      if (bx > VW || bx + b.w < 0) return;
      g.fillStyle = L[1]; g.fillRect(bx, by, b.w, VH - by);
      if (L[2]) { g.fillStyle = 'rgba(235,208,138,.55)'; for (var wy = by + 8; wy < VH - 6; wy += 11) for (var wx = bx + 6; wx < bx + b.w - 6; wx += 10) if (hash2(Math.floor(wx), Math.floor(wy) + b.s) > 0.72) g.fillRect(wx, wy, 3, 4); }
    });
  });
}
function drawZeppelin(g, time) {
  var x = ((time * 16) % (VW + 600)) - 300, y = 74 + Math.sin(time * 0.5) * 7;
  g.save(); g.translate(x, y);
  g.fillStyle = '#c3cad1'; g.beginPath(); g.ellipse(0, 0, 110, 22, 0, 0, Math.PI * 2); g.fill();
  g.fillStyle = '#8f9aa5'; g.beginPath(); g.ellipse(0, 7, 106, 14, 0, 0, Math.PI); g.fill();
  g.fillStyle = '#9aa5ae'; g.beginPath(); g.moveTo(-96, -4); g.lineTo(-122, -26); g.lineTo(-104, 0); g.fill();
  g.beginPath(); g.moveTo(-96, 4); g.lineTo(-122, 26); g.lineTo(-104, 0); g.fill();
  g.fillStyle = '#3a4048'; g.fillRect(-14, 20, 28, 7);
  g.restore();
}

/* ---------- tiles ---------- */
function drawTile(g, f, x, y, t, time) {
  var px = x * TS, py = y * TS, v = Math.floor(hash2(x, y) * 4);
  switch (t) {
    case T.MARBLE: DI(g, ((x + y) & 1 ? TEX.marbleB : TEX.marbleA)[v], px, py); break;
    case T.CARPET: DI(g, TEX.carpet[v], px, py); break;
    case T.HALL: DI(g, TEX.hall[(y & 1) ? 1 : 0], px, py); break;
    case T.CONC: DI(g, TEX.conc[v], px, py); break;
    case T.WOOD: DI(g, ((x + y) & 1 ? TEX.woodH : TEX.woodV)[v], px, py); break;
    case T.ROOF: DI(g, TEX.roof[v], px, py); break;
    case T.TERR: DI(g, TEX.terr[v], px, py); break;
    case T.DOOR: DI(g, TEX.door, px, py); break;
    case T.ELEV: DI(g, TEX.elev, px, py); g.fillStyle = (Math.floor(time * 1.5 + x) % 3 === 0) ? '#ffd98a' : '#4a3d1f'; g.fillRect(px + 13, py + 2, 6, 2); break;
    case T.UP: DI(g, TEX.up, px, py); break;
    case T.DOWN: DI(g, TEX.down, px, py); break;
    case T.WALL: {
      var below = at(f, x, y + 1), face = below !== T.WALL && below !== T.VOID && below !== T.RAIL;
      var brick = f.wall === 'brick';
      if (face) DI(g, (brick ? TEX.brickFace : TEX.wallFace)[(!brick && x % 6 === 0) ? 3 : v % 3], px, py);
      else DI(g, (brick ? TEX.brickCap : TEX.wallCap)[v], px, py);
      break;
    }
    case T.RAIL:
      g.fillStyle = 'rgba(201,162,75,.95)'; g.fillRect(px, py + 14, TS, 3);
      g.fillStyle = 'rgba(201,162,75,.5)'; for (var k = 3; k < TS; k += 8) g.fillRect(px + k, py + 17, 2, 12);
      g.fillStyle = 'rgba(255,255,255,.25)'; g.fillRect(px, py + 14, TS, 1);
      break;
  }
}

/* ---------- mobiliario ---------- */
function P(g, x, y, w, h, c) { g.fillStyle = c; g.fillRect(x, y, w, h); }
function VG(g, y0, y1, c0, c1) { var gr = g.createLinearGradient(0, y0, 0, y1); gr.addColorStop(0, c0); gr.addColorStop(1, c1); return gr; }
function drawFurn(g, o, time) {
  var x = o.x * TS, y = o.y * TS, w = o.w * TS, h = o.h * TS, c, i;
  if (o.solid && o.k !== 'column' && o.k !== 'plant' && o.k !== 'sign') { g.fillStyle = 'rgba(0,0,0,.28)'; g.fillRect(x + 3, y + h - 4, w - 4, 6); }
  switch (o.k) {
    case 'rug': g.fillStyle = 'rgba(120,36,48,.55)'; g.fillRect(x + 4, y + 4, w - 8, h - 8); g.strokeStyle = 'rgba(201,162,75,.75)'; g.lineWidth = 2; g.strokeRect(x + 8, y + 8, w - 16, h - 16); g.strokeStyle = 'rgba(201,162,75,.35)'; g.lineWidth = 1; g.strokeRect(x + 13, y + 13, w - 26, h - 26); break;
    case 'bed': c = o.o.c ? '#2f7478' : '#8c2f39'; P(g, x + 2, y + 2, w - 4, h - 4, '#4a2f1a'); P(g, x + 4, y + 4, w - 8, 12, '#efe9d8'); P(g, x + 6, y + 6, 8, 8, 'rgba(0,0,0,.08)'); P(g, x + 4, y + 18, w - 8, h - 24, c); P(g, x + 4, y + 18, w - 8, 3, 'rgba(255,255,255,.22)'); P(g, x + 4, y + h - 8, w - 8, 3, 'rgba(0,0,0,.25)'); break;
    case 'night': P(g, x + 5, y + 5, 22, 22, '#4a2f1a'); P(g, x + 7, y + 7, 18, 18, '#5d3b22'); P(g, x + 12, y + 8, 8, 7, '#ebd08a'); P(g, x + 14, y + 15, 4, 3, '#3a2a14'); break;
    case 'desk': P(g, x + 2, y + 6, w - 4, h - 10, '#5b3a20'); P(g, x + 2, y + 6, w - 4, 3, '#7d5130'); P(g, x + 6, y + 10, 14, 8, '#e6dfcb'); P(g, x + w - 14, y + 9, 8, 8, '#ebd08a'); break;
    case 'ward': P(g, x + 3, y + 2, w - 6, h - 4, '#3a2616'); P(g, x + 5, y + 4, w - 10, h - 8, '#4a301b'); P(g, x + 15, y + 10, 2, h - 20, '#c9a24b'); break;
    case 'plant': g.fillStyle = 'rgba(0,0,0,.25)'; g.beginPath(); g.ellipse(x + 16, y + 28, 9, 3, 0, 0, 6.3); g.fill(); P(g, x + 9, y + 19, 14, 10, '#6b4a2b'); P(g, x + 9, y + 19, 14, 2, '#8a6038'); g.fillStyle = '#2a6139'; g.beginPath(); g.arc(x + 16, y + 13, 10, 0, 6.3); g.fill(); g.fillStyle = '#3f8a52'; g.beginPath(); g.arc(x + 12, y + 10, 6, 0, 6.3); g.fill(); g.beginPath(); g.arc(x + 20, y + 12, 5, 0, 6.3); g.fill(); break;
    case 'sofa': P(g, x + 1, y + 4, w - 2, h - 6, '#1d575b'); P(g, x + 1, y + 4, w - 2, 8, '#2f7478'); P(g, x + 1, y + 12, 5, h - 14, '#1a4b4e'); P(g, x + w - 6, y + 12, 5, h - 14, '#1a4b4e'); break;
    case 'table': g.fillStyle = '#4a2f1a'; g.beginPath(); g.ellipse(x + w / 2, y + h / 2, w / 2 - 3, h / 2 - 3, 0, 0, 6.3); g.fill(); g.fillStyle = '#ece5d0'; g.beginPath(); g.ellipse(x + w / 2, y + h / 2, w / 2 - 7, h / 2 - 7, 0, 0, 6.3); g.fill(); g.fillStyle = '#c9a24b'; g.beginPath(); g.arc(x + w / 2, y + h / 2, 3, 0, 6.3); g.fill(); break;
    case 'piano': P(g, x + 2, y + 2, w - 4, h - 4, '#14141a'); P(g, x + 2, y + 2, w - 4, 4, '#2a2a33'); P(g, x + 6, y + h - 15, w - 12, 9, '#efeadb'); for (i = 0; i < o.w * 3; i++) P(g, x + 9 + i * 10, y + h - 15, 1, 9, '#222'); break;
    case 'bar': P(g, x, y + 4, w, h - 4, '#3a2616'); P(g, x, y + 4, w, 7, '#d9b25a'); P(g, x, y + 4, w, 1, '#fff2c4'); for (i = 0; i < o.w; i++) P(g, x + i * TS + 10, y - 3, 4, 9, i % 2 ? '#2f7478' : '#8c2f39'); break;
    case 'stage': P(g, x, y, w, h, '#3a2616'); P(g, x, y, w, 9, '#8c2f39'); for (i = 0; i < o.w; i++) { P(g, x + i * TS + 6, y + 9, 20, 2, 'rgba(201,162,75,.6)'); P(g, x + i * TS, y + 12, 1, h - 12, 'rgba(0,0,0,.3)'); } break;
    case 'boiler': P(g, x + 4, y + 4, w - 8, h - 8, '#565d65'); g.fillStyle = VG(g, y, y + h, '#7b828a', '#434950'); g.fillRect(x + 4, y + 4, w - 8, h - 8); P(g, x + 12, y + h - 20, 8, 8, '#8c2f39'); g.fillStyle = '#ebd08a'; g.beginPath(); g.arc(x + w / 2, y + h / 2, 6, 0, 6.3); g.fill(); g.strokeStyle = 'rgba(0,0,0,.4)'; g.strokeRect(x + 4.5, y + 4.5, w - 9, h - 9); break;
    case 'crate': P(g, x + 2, y + 2, w - 4, h - 4, '#7a5a34'); g.strokeStyle = '#4a3519'; g.lineWidth = 2; g.strokeRect(x + 4, y + 4, w - 8, h - 8); g.beginPath(); g.moveTo(x + 4, y + 4); g.lineTo(x + w - 4, y + h - 4); g.stroke(); break;
    case 'washer': P(g, x + 3, y + 3, w - 6, h - 6, '#d9dde0'); P(g, x + 3, y + 3, w - 6, 5, '#b8bdc1'); g.fillStyle = '#52707a'; g.beginPath(); g.arc(x + w / 2, y + h / 2 + 3, 11, 0, 6.3); g.fill(); g.fillStyle = 'rgba(255,255,255,.28)'; g.beginPath(); g.arc(x + w / 2 - 3, y + h / 2, 4, 0, 6.3); g.fill(); break;
    case 'steel': P(g, x + 1, y + 4, w - 2, h - 8, '#aab3ba'); P(g, x + 1, y + 4, w - 2, 4, '#dbe1e6'); P(g, x + 1, y + h - 8, w - 2, 3, '#7b848b'); break;
    case 'stove': P(g, x + 1, y + 2, w - 2, h - 4, '#2d3238'); for (i = 0; i < o.w; i++) { g.fillStyle = '#ff7a3d'; g.beginPath(); g.arc(x + i * TS + 16, y + 14, 5, 0, 6.3); g.fill(); } break;
    case 'gen': P(g, x + 2, y + 2, w - 4, h - 4, '#25402f'); P(g, x + 2, y + 2, w - 4, 5, '#3a6048'); P(g, x + 2, y + h - 12, w - 4, 4, '#e0b73a'); if (Math.floor(time * 6 + o.x) % 4 === 0) { g.fillStyle = '#9fe8ff'; g.fillRect(x + w / 2, y + 8, 2, 8); } break;
    case 'recdesk': P(g, x, y + 4, w, h - 4, '#3a2616'); P(g, x, y + 4, w, 9, '#d9b25a'); P(g, x, y + 4, w, 1, '#fff2c4'); P(g, x + w / 2 - 6, y - 2, 12, 8, '#ebd08a'); for (i = 0; i < o.w; i++) P(g, x + i * TS + 6, y + 18, 20, 8, 'rgba(0,0,0,.25)'); break;
    case 'column': g.fillStyle = 'rgba(0,0,0,.3)'; g.beginPath(); g.ellipse(x + 16, y + 30, 11, 3, 0, 0, 6.3); g.fill(); g.fillStyle = VG(g, y, y + 30, '#efe8d4', '#bdb49c'); g.fillRect(x + 6, y + 2, 20, 28); P(g, x + 4, y + 2, 24, 4, '#c9a24b'); P(g, x + 4, y + 26, 24, 4, '#c9a24b'); P(g, x + 14, y + 6, 1, 20, 'rgba(0,0,0,.15)'); break;
    case 'bench': P(g, x + 1, y + 8, w - 2, 14, '#5b3a20'); P(g, x + 1, y + 6, w - 2, 3, '#8a5a33'); break;
    case 'shelf': P(g, x, y + 2, w, h - 4, '#3a2616'); for (i = 0; i < o.w; i++) { P(g, x + i * TS + 4, y + 6, 6, 12, i % 3 ? '#8c2f39' : '#2f7478'); P(g, x + i * TS + 12, y + 8, 6, 10, '#c9a24b'); P(g, x + i * TS + 20, y + 7, 5, 11, '#d6cdb6'); } break;
    case 'cart': P(g, x + 2, y + 6, w - 4, 18, '#9aa3ab'); P(g, x + 6, y + 8, 12, 8, '#efeadb'); P(g, x + 4, y + 24, 4, 4, '#222'); P(g, x + w - 8, y + 24, 4, 4, '#222'); break;
    case 'safe': P(g, x + 3, y + 3, 26, 26, '#2c3138'); P(g, x + 3, y + 3, 26, 3, '#4a525b'); g.fillStyle = '#c9a24b'; g.beginPath(); g.arc(x + 16, y + 16, 6, 0, 6.3); g.fill(); break;
    case 'mail': P(g, x, y + 2, w, h - 4, '#3a2616'); for (i = 0; i < o.w * 2; i++) P(g, x + i * 16 + 3, y + 8, 10, 12, '#c9a24b'); break;
    case 'scope': P(g, x + 14, y + 6, 4, 24, '#3a3f45'); P(g, x + 6, y + 6, 20, 8, '#c9a24b'); break;
    case 'antenna': P(g, x + 14, y + 4, 4, 26, '#9aa3ab'); P(g, x + 8, y + 10, 16, 2, '#9aa3ab'); P(g, x + 10, y + 18, 12, 2, '#9aa3ab'); if (Math.floor(time * 2) % 2) { g.fillStyle = '#ff4a4a'; g.beginPath(); g.arc(x + 16, y + 3, 3, 0, 6.3); g.fill(); } break;
    case 'vent': P(g, x + 3, y + 6, w - 6, h - 8, '#5c636a'); for (i = 0; i < o.w; i++) P(g, x + i * TS + 6, y + 10, 20, 2, '#2b3036'); break;
    case 'phone': P(g, x + 6, y + 12, 20, 16, '#4a2f1a'); P(g, x + 6, y + 12, 20, 3, '#6b4527'); P(g, x + 12, y + 7, 8, 6, '#15151a'); P(g, x + 10, y + 5, 12, 2, '#15151a'); break;
    case 'sink': P(g, x + 4, y + 8, 24, 18, '#e6e6e0'); P(g, x + 7, y + 11, 18, 12, '#b9c9cf'); P(g, x + 14, y + 6, 4, 6, '#c9a24b'); break;
    case 'sign':
      P(g, x, y + 4, w, h - 4, '#241418'); P(g, x, y + 4, w, 3, '#c9a24b');
      g.font = '700 24px "Josefin Sans", sans-serif'; g.textAlign = 'center'; g.shadowColor = '#ff3b4a'; g.shadowBlur = 14; g.fillStyle = '#ff5a66'; g.fillText('NEW YORKER', x + w / 2, y + 44); g.shadowBlur = 0;
      break;
    default: P(g, x + 2, y + 2, w - 4, h - 4, '#777');
  }
}

/* ---------- cadáveres ---------- */
function drawCorpse(g, c, time) {
  var gr = g.createRadialGradient(c.x, c.y + 4, 2, c.x, c.y + 4, 20); gr.addColorStop(0, 'rgba(110,8,14,.92)'); gr.addColorStop(0.7, 'rgba(80,6,10,.7)'); gr.addColorStop(1, 'rgba(60,4,8,0)');
  g.fillStyle = gr; g.beginPath(); g.ellipse(c.x, c.y + 4, 21, 12, 0, 0, 6.3); g.fill();
  var o = c.outfit; g.save(); g.translate(c.x, c.y + 3); g.rotate(c.ang * 0.25 - 0.1);
  g.fillStyle = o.pants; g.fillRect(4, -4, 14, 8); g.fillStyle = '#14141a'; g.fillRect(17, -4, 3, 3); g.fillRect(17, 1, 3, 3);
  g.fillStyle = o.coat; g.fillRect(-10, -6, 15, 12); g.fillStyle = 'rgba(0,0,0,.18)'; g.fillRect(-10, 3, 15, 3);
  g.fillStyle = o.skin; g.beginPath(); g.arc(-14, 0, 5, 0, 6.3); g.fill();
  if (o.hat.t !== 'none' && o.hat.t !== 'cap') { g.fillStyle = o.hat.c; g.beginPath(); g.ellipse(-15, -1, 4, 5, 0, 0, 6.3); g.fill(); }
  g.fillStyle = 'rgba(120,10,16,.8)'; g.beginPath(); g.arc(-4, 0, 3, 0, 6.3); g.fill();
  g.restore();
}
function drawBubble(g, x, y, text) {
  g.font = '600 11px "Josefin Sans", sans-serif'; g.textAlign = 'center';
  var w = g.measureText(text).width + 14, bx = x - w / 2, by = y - 62;
  g.fillStyle = 'rgba(245,240,225,.96)'; g.fillRect(bx, by, w, 18); g.beginPath(); g.moveTo(x - 4, by + 18); g.lineTo(x + 4, by + 18); g.lineTo(x, by + 24); g.fill();
  g.strokeStyle = '#2a2a2a'; g.lineWidth = 1; g.strokeRect(bx + .5, by + .5, w - 1, 17);
  g.fillStyle = '#1a1a1a'; g.fillText(text, x, by + 13);
}
function drawPortrait(cv, outfit, alt) {
  var g = cv.getContext('2d'), w = cv.width, h = cv.height;
  var gr = g.createLinearGradient(0, 0, 0, h); gr.addColorStop(0, '#d9c9a3'); gr.addColorStop(1, '#a9946a'); g.fillStyle = gr; g.fillRect(0, 0, w, h);
  g.save(); g.beginPath(); g.rect(0, 0, w, h); g.clip(); g.translate(w / 2, h * 1.04); g.scale(w / 26, w / 26); drawActor(g, 0, -11, outfit, 'down', 0, {}); g.restore();
  var v = g.createRadialGradient(w / 2, h / 2, w * 0.25, w / 2, h / 2, w * 0.8); v.addColorStop(0, 'rgba(60,40,10,0)'); v.addColorStop(1, 'rgba(60,40,10,.5)'); g.fillStyle = v; g.fillRect(0, 0, w, h);
  g.strokeStyle = 'rgba(40,28,10,.85)'; g.lineWidth = 2; g.strokeRect(1, 1, w - 2, h - 2);
  if (alt === 'grey') { g.fillStyle = 'rgba(70,70,70,.72)'; g.fillRect(0, 0, w, h); }
  if (alt === 'dead') { g.fillStyle = 'rgba(40,10,10,.55)'; g.fillRect(0, 0, w, h); g.strokeStyle = 'rgba(200,40,40,.9)'; g.lineWidth = 3; g.beginPath(); g.moveTo(6, 6); g.lineTo(w - 6, h - 6); g.moveTo(w - 6, 6); g.lineTo(6, h - 6); g.stroke(); }
}

/* ---------- vista ---------- */
function canSee(f, view, e) {
  if (e === view) return true;
  var d = dist(view.x, view.y, e.x, e.y);
  return d <= (REN.sight || SIGHT_PX) && los(f, view.x, view.y, e.x, e.y);
}
function updateExplored(view) {
  var ex = REN.expl[view.floor], f = FLOORS[view.floor], tx = Math.floor(view.x / TS), ty = Math.floor(view.y / TS);
  for (var yy = ty - 5; yy <= ty + 5; yy++) for (var xx = tx - 5; xx <= tx + 5; xx++) {
    if (xx < 0 || yy < 0 || xx >= W || yy >= H) continue;
    if ((xx - tx) * (xx - tx) + (yy - ty) * (yy - ty) <= 26 && los(f, view.x, view.y, (xx + .5) * TS, (yy + .5) * TS)) ex[yy * W + xx] = 1;
  }
  f.rooms.forEach(function (r) { if (tx > r.x && tx < r.x + r.w - 1 && ty > r.y && ty < r.y + r.h - 1 && r.w * r.h < 400) for (var yy2 = r.y; yy2 < r.y + r.h; yy2++) for (var xx2 = r.x; xx2 < r.x + r.w; xx2++) ex[yy2 * W + xx2] = 1; });
}
