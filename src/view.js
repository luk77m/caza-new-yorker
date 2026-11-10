/* ===== vista: visor escalable, personajes detallados, placas, marcadores y mapas ===== */
REN.zoom = 1; REN.dpr = 1; REN.px = 1; REN.cx0 = 0; REN.cy0 = 0;
function setView(cssW, cssH, dpr, zoom) {
  REN.zoom = zoom; REN.dpr = dpr; REN.px = dpr * zoom;
  VW = cssW / zoom; VH = cssH / zoom;
  var lw = Math.ceil(VW), lh = Math.ceil(VH);
  if (!REN.lightC || REN.lightC.width !== lw || REN.lightC.height !== lh) { REN.lightC = mkc(lw, lh); REN.fogC = mkc(lw, lh); }
}
/* las texturas se dibujan algo más grandes que la casilla para que no se vean costuras al escalar */
function DI(g, img, x, y) { var e = 1 / REN.px + 0.15; g.drawImage(img, x, y, TS + e, TS + e); }

/* ---------- personajes ---------- */
function hairShape(g, o, back, side, fl) {
  var hs = o.hs || 'short', c = o.hair;
  g.fillStyle = c;
  if (back) { g.beginPath(); g.arc(0, -27, 5.5, 0, 6.3); g.fill(); if (hs === 'bun') { g.beginPath(); g.arc(0, -33, 2.4, 0, 6.3); g.fill(); } return; }
  if (hs === 'bald') { g.fillRect(-5.4, -28, 1.6, 4); g.fillRect(3.8, -28, 1.6, 4); return; }
  g.beginPath(); g.arc(0, -27.6, 5.5, Math.PI * 1.02, Math.PI * 1.98); g.fill();
  if (hs === 'slick') { g.fillStyle = 'rgba(255,255,255,.28)'; g.fillRect(-3.4, -32, 5, 1); }
  else if (hs === 'side') { g.fillStyle = 'rgba(0,0,0,.35)'; g.fillRect(-1.6, -32.6, .9, 3); }
  else if (hs === 'bob') { g.fillStyle = c; g.fillRect(-5.8, -29, 2.2, 7); g.fillRect(3.6, -29, 2.2, 7); }
  else if (hs === 'wave') { g.fillStyle = c; g.beginPath(); g.arc(-5, -24.5, 2.4, 0, 6.3); g.arc(5, -24.5, 2.4, 0, 6.3); g.fill(); }
  else if (hs === 'bun') { g.fillStyle = c; g.beginPath(); g.arc(0, -33.4, 2.5, 0, 6.3); g.fill(); }
  else { g.fillStyle = c; g.fillRect(-5.5, -28, 1.3, 3); g.fillRect(4.2, -28, 1.3, 3); }
}
function drawActor(g, x, y, o, dir, walk, opt) {
  opt = opt || {};
  var sc = opt.scale || 1, bd = o.build || 1, sw = Math.sin(walk) * 2.6, side = (dir === 'left' || dir === 'right'), fl = dir === 'left' ? -1 : 1, back = dir === 'up';
  var dress = o.kind === 'dress', under = o.kind === 'under', skin = o.skin, shade = 'rgba(0,0,0,.18)', hi = 'rgba(255,255,255,.16)', k;
  g.save(); g.translate(x, y + 11); g.scale(sc * bd, sc * (0.97 + (bd - 0.92) * 0.3));
  g.fillStyle = 'rgba(0,0,0,.34)'; g.beginPath(); g.ellipse(0, 0, 9.5, 3.6, 0, 0, 6.283); g.fill();
  /* piernas y calzado */
  if (dress) {
    g.fillStyle = skin; g.fillRect(-3.6, -7, 2.6, 6 + sw * 0.25); g.fillRect(1, -7, 2.6, 6 - sw * 0.25);
    g.fillStyle = '#15151a'; g.fillRect(-4.2, -1.8 + sw * 0.25, 3.8, 2.2); g.fillRect(0.4, -1.8 - sw * 0.25, 3.8, 2.2);
  } else {
    var lw = side ? 4.2 : 5, a = side ? sw * fl * 0.6 : 0, lx0 = side ? -2.8 : -6, lx1 = side ? -0.4 : 1, shoe = under ? '#8a8478' : '#121216';
    g.fillStyle = o.pants; g.fillRect(lx0 + a, -11, lw, 9.6 + sw * 0.4); g.fillRect(lx1 - a, -11, lw, 9.6 - sw * 0.4);
    g.fillStyle = hi; g.fillRect(lx0 + a + lw / 2 - 0.4, -10, 0.8, 8.2); g.fillRect(lx1 - a + lw / 2 - 0.4, -10, 0.8, 8.2);
    g.fillStyle = shoe; g.fillRect(lx0 + a - (side && fl < 0 ? 1.6 : 0), -1.8 + sw * 0.4, lw + (side ? 1.6 : 1), 2.3); g.fillRect(lx1 - a - (side && fl < 0 ? 1.6 : 0), -1.8 - sw * 0.4, lw + (side ? 1.6 : 1), 2.3);
    if (!under) { g.fillStyle = 'rgba(255,255,255,.35)'; g.fillRect(lx0 + a + 0.6, -1.5 + sw * 0.4, 1.4, 0.6); g.fillRect(lx1 - a + 0.6, -1.5 - sw * 0.4, 1.4, 0.6); }
  }
  /* torso */
  var tw = side ? 10.5 : 16.5, tx = -tw / 2;
  if (dress) {
    g.fillStyle = o.coat; g.beginPath(); g.moveTo(-5.6, -22.4); g.lineTo(5.6, -22.4); g.lineTo(6.4, -15); g.lineTo(9.4, -7.4); g.lineTo(-9.4, -7.4); g.lineTo(-6.4, -15); g.closePath(); g.fill();
    g.fillStyle = shade; g.fillRect(-9.4, -9, 18.8, 1.6); g.fillRect(-6.2, -15.6, 12.4, 1.6);
    if (!back && !side) { g.fillStyle = skin; g.beginPath(); g.moveTo(-3, -22.4); g.lineTo(3, -22.4); g.lineTo(0, -18.4); g.closePath(); g.fill(); g.fillStyle = '#efe6d2'; for (k = -2; k <= 2; k++) g.fillRect(k * 1.3 - 0.4, -19.2 + Math.abs(k) * 0.55, 0.9, 0.9); }
  } else {
    g.fillStyle = o.coat; g.beginPath(); g.moveTo(tx + 1, -22.6); g.lineTo(-tx - 1, -22.6); g.lineTo(-tx, -9); g.lineTo(tx, -9); g.closePath(); g.fill();
    g.fillStyle = shade; g.fillRect(tx, -11.4, tw, 2.4);
    g.fillStyle = hi; g.fillRect(tx + 1, -22.4, tw - 2, 1.6);
    g.fillStyle = 'rgba(0,0,0,.12)'; g.fillRect(tx, -21, 1.8, 12); g.fillRect(-tx - 1.8, -21, 1.8, 12);
  }
  if (!side && !back && !under && !dress) {
    g.fillStyle = '#efe9d9'; g.beginPath(); g.moveTo(-3.8, -22.4); g.lineTo(3.8, -22.4); g.lineTo(0, -14.6); g.closePath(); g.fill();
    if (o.staffRole === 'waiter') { g.fillStyle = '#111'; g.fillRect(-3.2, -21.4, 6.4, 2.6); g.fillRect(-0.8, -21.4, 1.6, 2.6); }
    else if (o.kind !== 'police') { g.fillStyle = o.tie || '#8c2f39'; g.fillRect(-1.1, -21.6, 2.2, 1.8); g.beginPath(); g.moveTo(-1.2, -19.8); g.lineTo(1.2, -19.8); g.lineTo(0.9, -13); g.lineTo(0, -12.2); g.lineTo(-0.9, -13); g.closePath(); g.fill(); }
    g.strokeStyle = 'rgba(0,0,0,.45)'; g.lineWidth = 1; g.beginPath(); g.moveTo(-3.8, -22.4); g.lineTo(0, -14.6); g.lineTo(3.8, -22.4); g.stroke();
    g.strokeStyle = 'rgba(255,255,255,.18)'; g.beginPath(); g.moveTo(-4.8, -22); g.lineTo(-1, -14); g.moveTo(4.8, -22); g.lineTo(1, -14); g.stroke();
    g.fillStyle = 'rgba(0,0,0,.55)'; g.fillRect(-0.4, -13.6, 0.9, 0.9); g.fillRect(-0.4, -11.4, 0.9, 0.9);
    if (o.staffRole !== 'waiter' && o.staffRole !== 'chef' && o.kind !== 'police') { g.fillStyle = o.tie || '#e9e4d6'; g.fillRect(3.6, -19.2, 2.8, 1.2); g.fillStyle = '#f3efe2'; g.fillRect(3.6, -19.8, 2.8, 0.7); }
    if (o.staffRole === 'bell') { g.fillStyle = '#e8c76a'; for (k = 0; k < 4; k++) { g.fillRect(-6.4, -20.4 + k * 2.8, 1.5, 1.5); g.fillRect(4.9, -20.4 + k * 2.8, 1.5, 1.5); } g.fillStyle = '#e8c76a'; g.fillRect(-7, -21.6, 14, 0.9); }
    if (o.kind === 'police') { g.fillStyle = '#e8c76a'; g.beginPath(); g.arc(4.6, -18, 1.9, 0, 6.3); g.fill(); g.fillStyle = '#0d0d12'; g.fillRect(tx + 0.5, -11.6, tw - 1, 2); g.fillStyle = '#e8c76a'; g.fillRect(-1.2, -11.6, 2.4, 2); for (k = 0; k < 3; k++) { g.beginPath(); g.arc(-1.6, -19 + k * 2.6, 0.7, 0, 6.3); g.fill(); } }
    if (o.staffRole === 'chef') { g.fillStyle = '#b7b09e'; for (k = 0; k < 3; k++) { g.fillRect(-0.4, -20 + k * 3, 0.9, 0.9); } g.fillStyle = '#c0392b'; g.fillRect(-4.6, -22, 9.2, 1); }
    if (o.staffRole === 'recep') { g.fillStyle = '#c9a24b'; g.fillRect(-5.2, -17.6, 3, 1); }
    if (o.staffRole === 'tech') { g.fillStyle = 'rgba(255,255,255,.12)'; g.fillRect(-6, -17, 4, 3); g.fillStyle = '#d6c58a'; g.fillRect(-5.2, -16.4, 2.4, 1); }
  }
  if (o.apron && !back) { g.fillStyle = '#f3efe2'; g.beginPath(); g.moveTo(-5.2, -18.4); g.lineTo(5.2, -18.4); g.lineTo(5.8, -8.4); g.lineTo(-5.8, -8.4); g.closePath(); g.fill(); g.fillStyle = 'rgba(0,0,0,.1)'; g.fillRect(-0.5, -17, 1, 8); }
  if (o.blood) { g.fillStyle = 'rgba(125,10,16,.9)'; g.beginPath(); g.arc(-2.4, -16, 3.4, 0, 6.3); g.fill(); g.beginPath(); g.arc(3, -12, 2.4, 0, 6.3); g.fill(); g.fillRect(-1.4, -14, 2.2, 6); g.fillStyle = 'rgba(180,20,28,.6)'; g.beginPath(); g.arc(-3.4, -17, 1.4, 0, 6.3); g.fill(); }
  /* brazos */
  var armC = under ? skin : o.coat;
  if (opt.aim) {
    var sx = side ? 2 * fl : 6.4, sy = -20.4, ex = sx + Math.cos(opt.aimAng) * 11.5, ey = sy + Math.sin(opt.aimAng) * 11.5;
    g.strokeStyle = armC; g.lineWidth = 4.2; g.lineCap = 'round'; g.beginPath(); g.moveTo(sx, sy); g.lineTo(ex, ey); g.stroke();
    g.strokeStyle = 'rgba(255,255,255,.14)'; g.lineWidth = 1; g.beginPath(); g.moveTo(sx, sy - 1.4); g.lineTo(ex, ey - 1.4); g.stroke();
    g.fillStyle = skin; g.beginPath(); g.arc(ex, ey, 2.3, 0, 6.3); g.fill();
    g.fillStyle = 'rgba(18,18,22,.92)'; g.beginPath(); g.arc(ex + Math.cos(opt.aimAng) * 2.8, ey + Math.sin(opt.aimAng) * 2.8, 1.3, 0, 6.3); g.fill();
    if (!side) { g.fillStyle = armC; g.fillRect(-10.4, -21.4, 3.4, 10.4 - sw * 0.3); g.fillStyle = skin; g.fillRect(-10.2, -11, 3, 2.6); }
  } else if (side) {
    var ax = -1.7 + sw * fl * -0.45; g.fillStyle = armC; g.fillRect(ax, -21.4, 3.4, 10.2); g.fillStyle = 'rgba(255,255,255,.55)'; g.fillRect(ax, -11.4, 3.4, 0.9); g.fillStyle = skin; g.fillRect(ax + 0.2, -10.6, 3, 2.7);
  } else {
    g.fillStyle = armC; g.fillRect(-10.6, -21.4, 3.5, 10.4 + sw * 0.35); g.fillRect(7.1, -21.4, 3.5, 10.4 - sw * 0.35);
    g.fillStyle = hi; g.fillRect(-10.6, -21.4, 3.5, 1.2); g.fillRect(7.1, -21.4, 3.5, 1.2);
    if (!under) { g.fillStyle = 'rgba(255,255,255,.55)'; g.fillRect(-10.6, -11.2 + sw * 0.35, 3.5, 0.9); g.fillRect(7.1, -11.2 - sw * 0.35, 3.5, 0.9); }
    g.fillStyle = skin; g.fillRect(-10.4, -10.4 + sw * 0.35, 3.1, 2.8); g.fillRect(7.3, -10.4 - sw * 0.35, 3.1, 2.8);
  }
  /* cuello y cabeza */
  g.fillStyle = skin; g.fillRect(-1.8, -24.6, 3.6, 3);
  g.fillStyle = 'rgba(0,0,0,.18)'; g.fillRect(-1.8, -24.6, 3.6, 1.2);
  var hx = side ? 0.8 * fl : 0;
  g.fillStyle = skin; g.beginPath(); g.arc(hx, -27.2, 5.4, 0, 6.3); g.fill();
  if (!back && !side) { g.beginPath(); g.arc(-5.4, -26.6, 1.3, 0, 6.3); g.arc(5.4, -26.6, 1.3, 0, 6.3); g.fill(); }
  g.fillStyle = 'rgba(0,0,0,.12)'; g.beginPath(); g.arc(hx, -25.2, 5.2, 0.1, Math.PI - 0.1); g.fill();
  if (!back) {
    g.save(); g.translate(hx, 0);
    hairShape(g, o, false, side, fl);
    g.restore();
  } else hairShape(g, o, true, side, fl);
  if (!back) {
    g.fillStyle = '#fff'; g.strokeStyle = '#1b1612';
    if (side) { g.fillRect(hx + 2.4 * fl - 1, -28, 2, 1.7); g.fillStyle = '#1b1612'; g.fillRect(hx + 2.9 * fl - 0.5, -27.8, 1.1, 1.4); g.fillRect(hx + 1.6 * fl - 0.5, -29.2, 2.2, 0.6); g.fillStyle = 'rgba(0,0,0,.25)'; g.fillRect(hx + 5 * fl - 0.5, -26.4, 1, 1.4); }
    else {
      g.fillRect(-3.6, -28, 2.4, 1.8); g.fillRect(1.2, -28, 2.4, 1.8);
      g.fillStyle = '#1b1612'; g.fillRect(-2.9, -27.9, 1.3, 1.6); g.fillRect(1.6, -27.9, 1.3, 1.6);
      g.fillRect(-3.8, -29.6, 2.8, 0.7); g.fillRect(1, -29.6, 2.8, 0.7);
      g.fillStyle = 'rgba(0,0,0,.2)'; g.fillRect(-0.5, -26.4, 1, 1.6);
      g.fillStyle = 'rgba(150,50,50,.85)'; g.fillRect(-1.2, -23.9, 2.4, 0.8);
    }
    if (o.glasses) { g.strokeStyle = '#161616'; g.lineWidth = 0.8; if (side) { g.beginPath(); g.arc(hx + 2.6 * fl, -27.1, 1.9, 0, 6.3); g.stroke(); g.beginPath(); g.moveTo(hx + 0.8 * fl, -27.1); g.lineTo(hx - 3 * fl, -27.4); g.stroke(); } else { g.beginPath(); g.arc(-2.4, -27.1, 1.9, 0, 6.3); g.stroke(); g.beginPath(); g.arc(2.4, -27.1, 1.9, 0, 6.3); g.stroke(); g.beginPath(); g.moveTo(-0.5, -27.2); g.lineTo(0.5, -27.2); g.stroke(); } }
    if (o.stache) { g.fillStyle = o.hair; if (side) g.fillRect(hx + 2.2 * fl - (fl < 0 ? 1.8 : 0), -25.4, 2.6, 1.2); else g.fillRect(-2.6, -25.5, 5.2, 1.3); }
  }
  var ht = o.hat.t, hc = o.hat.c, dk = 'rgba(0,0,0,.28)', hy = hx;
  g.save(); g.translate(hy, 0);
  if (ht === 'fedora') { g.fillStyle = hc; g.beginPath(); g.ellipse(0, -30.6, 9.4, 2.7, 0, 0, 6.3); g.fill(); g.fillRect(-5.2, -38.4, 10.4, 8.2); g.fillStyle = dk; g.fillRect(-5.2, -32.8, 10.4, 2.4); g.fillStyle = 'rgba(255,255,255,.14)'; g.fillRect(-5.2, -38.4, 10.4, 1.6); g.fillStyle = 'rgba(0,0,0,.25)'; g.fillRect(-1.4, -38.4, 2.8, 2); }
  else if (ht === 'bowler') { g.fillStyle = hc; g.beginPath(); g.ellipse(0, -30.6, 8.2, 2.3, 0, 0, 6.3); g.fill(); g.beginPath(); g.arc(0, -30.6, 6, Math.PI, 6.283); g.fill(); g.fillStyle = dk; g.fillRect(-6, -32.2, 12, 1.9); g.fillStyle = 'rgba(255,255,255,.18)'; g.fillRect(-3.4, -35.2, 3, 1); }
  else if (ht === 'cap') { g.fillStyle = hc; g.beginPath(); g.ellipse(0, -31.2, 6.8, 3.1, 0, 0, 6.3); g.fill(); g.fillStyle = dk; g.fillRect(side ? (fl > 0 ? 2 : -9.4) : -6.4, -30.6, side ? 7.4 : 12.8, 2); g.fillStyle = 'rgba(255,255,255,.16)'; g.fillRect(-3, -33.6, 5, 1); }
  else if (ht === 'cloche') { g.fillStyle = hc; g.beginPath(); g.arc(0, -29, 6.6, Math.PI, 6.283); g.lineTo(7, -27.4); g.lineTo(-7, -27.4); g.closePath(); g.fill(); g.fillStyle = dk; g.fillRect(-6.6, -29.2, 13.2, 1.5); g.fillStyle = '#e8c76a'; g.beginPath(); g.arc(4.2, -29.6, 1.2, 0, 6.3); g.fill(); }
  else if (ht === 'pill') { g.fillStyle = hc; g.fillRect(-4.6, -35.4, 9.2, 6.2); g.fillStyle = '#e8c76a'; g.fillRect(-4.6, -30.6, 9.2, 1.2); g.fillRect(-4.6, -35.4, 9.2, 0.9); g.strokeStyle = '#e8c76a'; g.lineWidth = 0.8; g.beginPath(); g.moveTo(-4.6, -30); g.lineTo(-4.2, -25.6); g.moveTo(4.6, -30); g.lineTo(4.2, -25.6); g.stroke(); }
  else if (ht === 'chef') { g.fillStyle = hc; g.fillRect(-4.8, -40, 9.6, 10); g.beginPath(); g.arc(-3, -40, 3.4, 0, 6.3); g.arc(3, -40, 3.4, 0, 6.3); g.arc(0, -42, 3.6, 0, 6.3); g.fill(); g.fillStyle = 'rgba(0,0,0,.12)'; g.fillRect(-4.8, -31.8, 9.6, 1.8); }
  else if (ht === 'maidcap') { g.fillStyle = hc; g.beginPath(); g.ellipse(0, -31.8, 5.2, 2.5, 0, 0, 6.3); g.fill(); g.fillRect(-5.2, -31, 10.4, 1.5); g.fillStyle = 'rgba(0,0,0,.12)'; g.fillRect(-5.2, -30.2, 10.4, 0.7); }
  else if (ht === 'police') { g.fillStyle = hc; g.fillRect(-6.2, -35.8, 12.4, 5.2); g.fillStyle = '#0d0d12'; g.fillRect(-6.6, -31, 13.2, 2.2); g.fillStyle = '#e8c76a'; g.beginPath(); g.arc(0, -33.2, 1.7, 0, 6.3); g.fill(); g.fillStyle = 'rgba(255,255,255,.14)'; g.fillRect(-6.2, -35.8, 12.4, 1); }
  g.restore();
  g.restore();
}

/* ---------- placas de las puertas ---------- */
var PLATES = { 'Despacho del gerente': 'DESPACHO', 'Sala de calderas': 'CALDERAS', 'Lavandería': 'LAVANDERÍA', 'Almacén': 'ALMACÉN', 'Cocina de servicio': 'COCINA', 'Sala eléctrica': 'ELÉCTRICA', 'Cuarto de servicio': 'SERVICIO', 'Correos': 'CORREOS', 'Tienda de regalos': 'TIENDA', 'Cafetería': 'CAFETERÍA', 'Restaurante Terrace': 'RESTAURANTE', 'Bar': 'BAR', 'Gran Salón': 'GRAN SALÓN', 'Salón mirador': 'MIRADOR', 'Biblioteca': 'BIBLIOTECA' };
function plateText(n) { var m = /^(?:Hab\.|Suite)\s+(\d+)/.exec(n); return m ? m[1] : (PLATES[n] || ''); }
function drawName(g, x, y, text, color) {
  g.save(); g.font = '700 10px "Josefin Sans", sans-serif'; g.textAlign = 'center'; g.lineJoin = 'round'; g.lineWidth = 3.2; g.strokeStyle = 'rgba(2,6,14,.9)'; g.strokeText(text, x, y); g.fillStyle = color; g.fillText(text, x, y);
  g.restore();
}
function drawPlates(g, f, x0, x1, y0, y1, lockFn) {
  g.textAlign = 'center'; g.textBaseline = 'middle';
  f.rooms.forEach(function (r) {
    if (!r.door) return;
    var tx = r.door.x, ty = r.door.y;
    if (tx < x0 - 4 || tx > x1 + 4 || ty < y0 - 1 || ty > y1 + 1) return;
    var t = plateText(r.name); if (!t) return;
    var num = /^\d/.test(t); g.font = '700 ' + (t.length > 7 ? 6.6 : 8) + 'px "Josefin Sans", sans-serif';
    var w = Math.max(19, g.measureText(t).width + 7), cx = tx * TS + TS / 2, cy = ty * TS + 8;
    var col = r.zone === ZONE_STAFF ? ['#7a1f2a', '#f6e6e6'] : (num ? ['#d9b25a', '#2a1c08'] : ['#1f4f53', '#e6f2ee']);
    g.fillStyle = 'rgba(0,0,0,.5)'; g.fillRect(cx - w / 2 + 1, cy - 4.5, w, 11);
    g.fillStyle = col[0]; g.fillRect(cx - w / 2, cy - 5, w, 10);
    g.strokeStyle = 'rgba(255,255,255,.4)'; g.lineWidth = 1; g.strokeRect(cx - w / 2 + 0.5, cy - 4.5, w - 1, 9);
    g.fillStyle = col[1]; g.fillText(t, cx, cy + 0.6);
    var lk = lockFn ? lockFn(r) : null;
    if (lk) {
      var ix = cx + w / 2 + 6, iy = cy + 0.5;
      if (lk === 'own') { g.strokeStyle = '#6fb8ff'; g.lineWidth = 1.6; g.strokeRect(cx - w / 2 - 1.5, cy - 6.5, w + 3, 13); g.fillStyle = '#6fb8ff'; g.fillRect(ix - 3, iy - 1, 6, 5); g.beginPath(); g.arc(ix + 2.4, iy - 1, 2.2, Math.PI, 0); g.strokeStyle = '#6fb8ff'; g.lineWidth = 1.2; g.stroke(); }
      else {
        var lc = lk === 'locked' ? '#e0525f' : '#6fcf97';
        g.fillStyle = 'rgba(0,0,0,.55)'; g.fillRect(ix - 4.5, iy - 5.5, 9, 11);
        g.fillStyle = lc; g.fillRect(ix - 3, iy - 1, 6, 5);
        g.strokeStyle = lc; g.lineWidth = 1.3; g.beginPath(); g.arc(ix + (lk === 'locked' ? 0 : 2.2), iy - 1, 2.2, Math.PI, 0); g.stroke();
      }
    }
  });
  g.textBaseline = 'alphabetic';
}

/* ---------- marcadores de objetivos (flechas en el borde si están lejos) ---------- */
function drawMarkers(g, list, cx0, cy0, time) {
  var m = 26, i;
  g.save(); g.textAlign = 'center';
  for (i = 0; i < list.length; i++) {
    var k = list[i], sx = k.x - cx0, sy = k.y - cy0, inside = sx > m && sx < VW - m && sy > m && sy < VH - m, bob = Math.sin(time * 4 + i) * 2.5;
    if (inside) {
      g.strokeStyle = 'rgba(235,208,138,.75)'; g.lineWidth = 2; g.beginPath(); g.arc(sx, sy, 13 + Math.sin(time * 3) * 2, 0, 6.3); g.stroke();
      g.save(); g.translate(sx, sy - 30 + bob);
      g.fillStyle = 'rgba(0,0,0,.55)'; g.beginPath(); g.moveTo(0, 9); g.lineTo(8, 0); g.lineTo(0, -9); g.lineTo(-8, 0); g.closePath(); g.fill();
      g.fillStyle = '#ebd08a'; g.beginPath(); g.moveTo(0, 7); g.lineTo(6, 0); g.lineTo(0, -7); g.lineTo(-6, 0); g.closePath(); g.fill();
      g.fillStyle = '#1a1408'; g.font = '700 9px "Josefin Sans", sans-serif'; g.fillText('!', 0, 3);
      g.restore();
    } else {
      var cxs = VW / 2, cys = VH / 2, dx = sx - cxs, dy = sy - cys, ang = Math.atan2(dy, dx);
      var t = Math.min((VW / 2 - m) / Math.max(Math.abs(dx), 1e-6), (VH / 2 - m) / Math.max(Math.abs(dy), 1e-6)), ax = cxs + dx * t, ay = cys + dy * t;
      var av = REN.avoid; if (av && ax > av.x0 - 24 && ax < av.x1 + 24 && ay > av.y0 - 24 && ay < av.y1 + 24) ay = av.y1 + 28;
      g.save(); g.translate(ax, ay); g.rotate(ang);
      g.fillStyle = 'rgba(0,0,0,.6)'; g.beginPath(); g.moveTo(13, 0); g.lineTo(-8, -10); g.lineTo(-3, 0); g.lineTo(-8, 10); g.closePath(); g.fill();
      g.fillStyle = '#ebd08a'; g.beginPath(); g.moveTo(10, 0); g.lineTo(-6, -7.5); g.lineTo(-2, 0); g.lineTo(-6, 7.5); g.closePath(); g.fill();
      g.restore();
      g.font = '700 10px "Josefin Sans", sans-serif'; g.fillStyle = '#efe8d4'; g.shadowColor = '#000'; g.shadowBlur = 4;
      g.fillText(Math.round(k.d / TS * 1.2) + ' m', ax - Math.cos(ang) * 24, ay - Math.sin(ang) * 24 + 3); g.shadowBlur = 0;
    }
  }
  g.restore();
}

/* ---------- escena principal ---------- */
function drawWorld(g, w, view, time, mouse, opt) {
  opt = opt || {};
  var debug = !!opt.debug, f = FLOORS[view.floor], cam = REN.cam, px = REN.px, bo = w.sab.blackout > w.time, alarm = w.sab.alarm > w.time;
  REN.sight = SIGHT_PX * (bo ? 0.5 : 1);
  if (VW >= W * TS + 128) cam.x = (W * TS - VW) / 2; else cam.x = clamp(view.x - VW / 2, -64, W * TS - VW + 64);
  if (VH >= H * TS + 128) cam.y = (H * TS - VH) / 2; else cam.y = clamp(view.y - VH / 2, -64, H * TS - VH + 64);
  var cx0 = Math.round(cam.x * px) / px, cy0 = Math.round(cam.y * px) / px; REN.cx0 = cx0; REN.cy0 = cy0;
  g.setTransform(px, 0, 0, px, 0, 0);
  if (f.sky) { drawSky(g, time, cam.x); if (f.roof) drawZeppelin(g, time); } else { g.fillStyle = '#05080b'; g.fillRect(0, 0, VW + 1, VH + 1); }
  g.save(); g.translate(-cx0, -cy0);
  var x0 = Math.max(0, Math.floor(cx0 / TS)), x1 = Math.min(W - 1, Math.floor((cx0 + VW) / TS)), y0 = Math.max(0, Math.floor(cy0 / TS)), y1 = Math.min(H - 1, Math.floor((cy0 + VH) / TS));
  var y, x;
  for (y = y0; y <= y1; y++) for (x = x0; x <= x1; x++) { var t = f.g[y * W + x]; if (t !== T.VOID) drawTile(g, f, x, y, t, time); }
  f.furn.forEach(function (o) { if (!o.solid) drawFurn(g, o, time); });
  if (SET.plates) drawPlates(g, f, x0, x1, y0, y1, function (r) {
    if (r.zone !== ZONE_ROOM) return null;
    if (view.room === r.name && view.roomFloor === r.fi) return 'own';
    if (hasKey(view, r)) return 'open';
    return doorOpen(w, r) ? 'open' : 'locked';
  });
  w.pick.forEach(function (p) {
    if (p.floor !== view.floor) return;
    var ppx = (p.x + 0.5) * TS, ppy = (p.y + 0.5) * TS + Math.sin(time * 3 + p.id) * 1.5;
    if (!canSee(f, view, { x: ppx, y: ppy })) return;
    g.fillStyle = 'rgba(235,208,138,.28)'; g.beginPath(); g.arc(ppx, ppy, 12 + Math.sin(time * 4) * 1.5, 0, 6.3); g.fill();
    if (p.kind === 'masterkey') { g.fillStyle = '#ebd08a'; g.beginPath(); g.arc(ppx - 4, ppy, 4.5, 0, 6.3); g.fill(); g.fillRect(ppx, ppy - 1.5, 10, 3); g.fillRect(ppx + 6, ppy, 2.5, 4); g.fillStyle = '#8f7330'; g.beginPath(); g.arc(ppx - 4, ppy, 1.8, 0, 6.3); g.fill(); }
    else if (p.kind === 'badge') { g.fillStyle = '#c9a24b'; g.beginPath(); g.moveTo(ppx, ppy - 7); g.lineTo(ppx + 6, ppy - 2); g.lineTo(ppx + 4, ppy + 6); g.lineTo(ppx - 4, ppy + 6); g.lineTo(ppx - 6, ppy - 2); g.closePath(); g.fill(); g.fillStyle = '#8c2f39'; g.fillRect(ppx - 2, ppy - 2, 4, 5); }
    else { g.fillStyle = '#9aa3ab'; g.fillRect(ppx - 5, ppy - 2, 10, 4); g.fillStyle = '#6a7279'; g.fillRect(ppx - 3, ppy + 2, 8, 2); g.fillStyle = '#c9a24b'; g.fillRect(ppx - 6, ppy - 1, 2, 3); }
  });
  w.corpses.forEach(function (c) { if (c.floor === view.floor && canSee(f, view, c)) drawCorpse(g, c, time); });
  var ents = [], nameQ = [];
  f.furn.forEach(function (o) { if (o.solid) ents.push({ y: (o.y + o.h) * TS, d: function () { drawFurn(g, o, time); } }); });
  w.ents.forEach(function (e) {
    if (!e.alive || e.floor !== view.floor) return;
    if (!canSee(f, view, e) && !debug) return;
    ents.push({ y: e.y + 11, d: function () {
      var ang = e.aim ? Math.atan2(e.aimY - e.y, e.aimX - e.x) : 0;
      drawActor(g, e.x, e.y, e.outfit, e.dir, e.walk, { aim: e.aim, aimAng: ang });
      if (e.fxSwing > 0) { g.strokeStyle = 'rgba(255,255,255,.7)'; g.lineWidth = 3; g.beginPath(); g.arc(e.x, e.y - 6, 20, Math.atan2(e.aimY - e.y, e.aimX - e.x) - 0.9, Math.atan2(e.aimY - e.y, e.aimX - e.x) + 0.9); g.stroke(); }
      if (e.role === 'police' && e.spotting) { g.fillStyle = '#ff4a4a'; g.font = '700 16px sans-serif'; g.textAlign = 'center'; g.fillText('!', e.x, e.y - 46); }
      if (e.hold && e === view) { var pr = e.hold.t / e.hold.dur; g.strokeStyle = 'rgba(0,0,0,.5)'; g.lineWidth = 4; g.beginPath(); g.arc(e.x, e.y - 42, 8, 0, 6.283); g.stroke(); g.strokeStyle = '#ebd08a'; g.beginPath(); g.arc(e.x, e.y - 42, 8, -1.57, -1.57 + 6.283 * pr); g.stroke(); }
      if (debug && e.role !== 'civil') { g.font = '600 9px sans-serif'; g.textAlign = 'center'; g.fillStyle = e.role === 'hunter' ? '#ff6a6a' : (e.role === 'runner' ? '#6fb8ff' : '#8aa8ff'); g.fillText(e.name, e.x, e.y - 44); }
      else if (e !== view && e.role !== 'civil' && e.role === view.role && (e.role === 'runner' || e.role === 'hunter')) nameQ.push([e.x, e.y - 30, e.name, e.role === 'runner' ? '#6fb8ff' : '#ff9a9a']);
      if (e.arrest > 0) nameQ.push([e.x, e.y - 44, 'DETENIDO', '#ff6a78']);
    } });
    if (e.bubble) ents.push({ y: 99999, d: function () { drawBubble(g, e.x, e.y - 2, e.bubble); } });
  });
  ents.sort(function (a, b) { return a.y - b.y; });
  ents.forEach(function (e) { e.d(); });
  w.fx.forEach(function (fx) { if (fx.floor === view.floor && fx.type === 'flash') { g.fillStyle = 'rgba(255,230,160,.8)'; g.beginPath(); g.arc(fx.x, fx.y - 6, 14 * (fx.t / 0.25), 0, 6.3); g.fill(); } });
  g.restore();
  /* luz ambiental */
  var sxv = view.x - cx0, syv = view.y - cy0, vis = [];
  if (SET.lights) {
    var lg = REN.lightC.getContext('2d'), amb = bo ? Math.min(0.97, 0.94 + 0.03 / SET.bright) : clamp((f.dark + 0.28) / SET.bright, 0.28, 0.84);
    lg.globalCompositeOperation = 'source-over'; lg.clearRect(0, 0, REN.lightC.width, REN.lightC.height); lg.fillStyle = 'rgba(4,6,12,' + amb + ')'; lg.fillRect(0, 0, REN.lightC.width, REN.lightC.height);
    lg.globalCompositeOperation = 'destination-out'; lg.globalAlpha = 0.92;
    if (!bo) f.lamps.forEach(function (l) { var sx = l.x - cx0, sy = l.y - cy0; if (sx < -l.r || sy < -l.r || sx > VW + l.r || sy > VH + l.r) return; vis.push([sx, sy, l]); lg.drawImage(SPR.lamp, sx - l.r, sy - l.r, l.r * 2, l.r * 2); });
    lg.globalAlpha = 0.85; var hr = bo ? 62 : 110; lg.drawImage(SPR.lamp, sxv - hr, syv - hr, hr * 2, hr * 2); lg.globalAlpha = 1; lg.globalCompositeOperation = 'source-over';
    g.drawImage(REN.lightC, 0, 0, VW, VH);
    g.save(); g.globalCompositeOperation = 'lighter'; g.globalAlpha = 0.2;
    vis.forEach(function (v) { g.drawImage(v[2].tint === 'cold' ? SPR.cold : SPR.warm, v[0] - v[2].r, v[1] - v[2].r, v[2].r * 2, v[2].r * 2); });
    g.restore();
  } else if (f.dark > 0.3) { g.fillStyle = 'rgba(4,6,12,' + Math.min(0.5, f.dark * 0.7 / SET.bright) + ')'; g.fillRect(0, 0, VW + 1, VH + 1); }
  /* niebla de visión */
  if (!debug) {
    var fg = REN.fogC.getContext('2d'), N = SET.lights ? 150 : 72, i;
    fg.globalCompositeOperation = 'source-over'; fg.clearRect(0, 0, REN.fogC.width, REN.fogC.height); fg.fillStyle = 'rgba(3,5,9,' + SET.fog + ')'; fg.fillRect(0, 0, REN.fogC.width, REN.fogC.height);
    fg.globalCompositeOperation = 'destination-out';
    var rg = fg.createRadialGradient(sxv, syv, 50, sxv, syv, REN.sight); rg.addColorStop(0, 'rgba(0,0,0,1)'); rg.addColorStop(0.7, 'rgba(0,0,0,.95)'); rg.addColorStop(1, 'rgba(0,0,0,.4)');
    fg.fillStyle = rg; fg.beginPath();
    for (i = 0; i < N; i++) { var a = i / N * 6.2832, d = rayDist(f, view.x, view.y, a, REN.sight), qx = sxv + Math.cos(a) * d, qy = syv + Math.sin(a) * d; if (i === 0) fg.moveTo(qx, qy); else fg.lineTo(qx, qy); }
    fg.closePath(); fg.fill(); fg.globalCompositeOperation = 'source-over';
    g.drawImage(REN.fogC, 0, 0, VW, VH);
  }
  nameQ.forEach(function (n) { drawName(g, n[0] - cx0, n[1] - cy0, n[2], n[3]); });
  if (alarm) { g.fillStyle = 'rgba(210,30,44,' + (0.05 + 0.07 * (0.5 + 0.5 * Math.sin(time * 7))) + ')'; g.fillRect(0, 0, VW + 1, VH + 1); }
  if (opt.markers && opt.markers.length) drawMarkers(g, opt.markers, cx0, cy0, time);
  if (mouse && mouse.aiming) {
    var mx = mouse.x, my = mouse.y;
    g.strokeStyle = mouse.onTarget ? '#ff5a5a' : 'rgba(240,235,220,.9)'; g.lineWidth = 1.5;
    g.beginPath(); g.arc(mx, my, 11, 0, 6.283); g.stroke();
    g.beginPath(); g.moveTo(mx - 17, my); g.lineTo(mx - 6, my); g.moveTo(mx + 6, my); g.lineTo(mx + 17, my); g.moveTo(mx, my - 17); g.lineTo(mx, my - 6); g.moveTo(mx, my + 6); g.lineTo(mx, my + 17); g.stroke();
    g.fillStyle = mouse.onTarget ? '#ff5a5a' : '#fff'; g.fillRect(mx - 1, my - 1, 2, 2);
  }
}

/* ---------- mapas (minimapa y mapa grande de la tecla Tab) ---------- */
var MINIC = {}; MINIC[T.WALL] = '#4a5c6e'; MINIC[T.MARBLE] = '#8d8572'; MINIC[T.CARPET] = '#7a2b37'; MINIC[T.HALL] = '#2d6165'; MINIC[T.CONC] = '#58616a'; MINIC[T.WOOD] = '#8a5c37'; MINIC[T.DOOR] = '#c9a24b'; MINIC[T.ELEV] = '#ebd08a'; MINIC[T.UP] = '#47a0a6'; MINIC[T.DOWN] = '#47a0a6'; MINIC[T.ROOF] = '#59616a'; MINIC[T.TERR] = '#6f8076'; MINIC[T.RAIL] = '#a68a45';
function drawMapFloor(g, w, view, fl, s, o) {
  o = o || {};
  var f = FLOORS[fl], ex = REN.expl[fl], x, y;
  g.setTransform(1, 0, 0, 1, 0, 0); g.fillStyle = '#070b10'; g.fillRect(0, 0, W * s, H * s);
  for (y = 0; y < H; y++) for (x = 0; x < W; x++) {
    var seen = ex[y * W + x] || o.all; if (!seen && !o.plan) continue;
    var t = f.g[y * W + x]; if (t === T.VOID) continue;
    g.globalAlpha = seen ? 1 : 0.2; g.fillStyle = MINIC[t] || '#333'; g.fillRect(x * s, y * s, s, s);
  }
  g.globalAlpha = 1;
  if (o.labels) {
    g.font = '700 ' + Math.max(8, Math.round(s * 0.72)) + 'px "Josefin Sans", sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle';
    f.rooms.forEach(function (r) {
      var cx = r.x + (r.w >> 1), cy = r.y + (r.h >> 1), seen = ex[cy * W + cx] || o.all; if (!seen && !o.plan) return; if (r.w < 5) return;
      var nm = r.name.replace('Núcleo de ascensores', 'Ascensores').toUpperCase();
      g.globalAlpha = seen ? 1 : 0.5;
      g.fillStyle = 'rgba(0,0,0,.55)'; g.fillText(nm, (r.x + r.w / 2) * s + 1, (r.y + r.h / 2) * s + 1); g.fillStyle = 'rgba(245,238,220,.92)'; g.fillText(nm, (r.x + r.w / 2) * s, (r.y + r.h / 2) * s);
      g.globalAlpha = 1;
    });
    g.textBaseline = 'alphabetic';
  }
  w.pick.forEach(function (p) { if (p.floor === fl && (ex[p.y * W + p.x] || o.all)) { g.fillStyle = '#ebd08a'; g.fillRect(p.x * s + s * 0.2, p.y * s + s * 0.2, s * 0.6, s * 0.6); } });
  w.corpses.forEach(function (c) { if (c.floor === fl && (ex[Math.floor(c.y / TS) * W + Math.floor(c.x / TS)] || o.all)) { g.fillStyle = '#c0384a'; g.fillRect(c.x / TS * s - s * 0.4, c.y / TS * s - s * 0.4, s * 0.8, s * 0.8); } });
  w.ents.forEach(function (e) {
    if (!e.alive || e.floor !== fl || e === view) return;
    var ally = e.role === view.role && e.role !== 'civil' && e.role !== 'police';
    if (!ally && !o.all) return;
    g.fillStyle = e.role === 'hunter' ? '#ff6a6a' : (e.role === 'runner' ? '#5aa8ff' : (e.role === 'police' ? '#c9b8ff' : 'rgba(255,255,255,.35)'));
    var r = Math.max(1.5, s * 0.3); g.fillRect(e.x / TS * s - r, e.y / TS * s - r, r * 2, r * 2);
  });
  (o.marks || []).forEach(function (m) {
    var cx = (m.x + 0.5) * s, cy = (m.y + 0.5) * s, r = Math.max(3, s * 0.62);
    g.fillStyle = m.dim ? 'rgba(235,208,138,.35)' : '#ebd08a'; g.strokeStyle = '#1a1408'; g.lineWidth = 1;
    g.beginPath(); g.moveTo(cx, cy - r); g.lineTo(cx + r, cy); g.lineTo(cx, cy + r); g.lineTo(cx - r, cy); g.closePath(); g.fill(); g.stroke();
  });
  if (view.floor === fl) {
    var vx = view.x / TS * s, vy = view.y / TS * s, rr = Math.max(2.5, s * 0.4);
    g.fillStyle = '#fff'; g.fillRect(vx - rr, vy - rr, rr * 2, rr * 2); g.strokeStyle = '#ebd08a'; g.lineWidth = 1; g.strokeRect(vx - rr - 1.5, vy - rr - 1.5, rr * 2 + 3, rr * 2 + 3);
  }
}
function drawMini(g, w, view, debug, marks) { drawMapFloor(g, w, view, view.floor, 5, { all: debug, plan: true, marks: marks }); }
