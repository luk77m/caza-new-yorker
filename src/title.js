/* ===== portada animada: torre art déco, rayos, reflectores, dirigible y lluvia ===== */
var TITLE = { cv: null, g: null, t: 0, w: 0, h: 0, dpr: 1, rain: [], stars: [], sky: [] };
function tHash(a, b) { var h = (a * 374761393 + b * 668265263) | 0; h = (h ^ (h >> 13)) * 1274126177; return ((h ^ (h >> 16)) >>> 0) / 4294967295; }
function initTitle() {
  TITLE.cv = document.getElementById('hero'); TITLE.g = TITLE.cv.getContext('2d');
  var i; for (i = 0; i < 110; i++) TITLE.rain.push({ x: Math.random(), y: Math.random(), v: 0.5 + Math.random() * 0.9, l: 8 + Math.random() * 14 });
  for (i = 0; i < 90; i++) TITLE.stars.push({ x: Math.random(), y: Math.random() * 0.55, r: Math.random() * 1.2 + 0.3, p: Math.random() * 6.3 });
  var x = 0; while (x < 1.2) { var wd = 0.02 + Math.random() * 0.035; TITLE.sky.push({ x: x, w: wd, h: 0.12 + Math.random() * 0.3, s: Math.floor(Math.random() * 999) }); x += wd + Math.random() * 0.006; }
  resizeTitle();
}
function resizeTitle() {
  if (!TITLE.cv) return;
  var dpr = Math.min(window.devicePixelRatio || 1, 1.5), w = window.innerWidth, h = window.innerHeight;
  TITLE.dpr = dpr; TITLE.w = w; TITLE.h = h; TITLE.cv.width = Math.round(w * dpr); TITLE.cv.height = Math.round(h * dpr);
}
function tZep(g, x, y, s) {
  g.save(); g.translate(x, y); g.scale(s, s);
  g.fillStyle = '#c7ced5'; g.beginPath(); g.ellipse(0, 0, 110, 22, 0, 0, 6.283); g.fill();
  g.fillStyle = '#8c97a2'; g.beginPath(); g.ellipse(0, 7, 106, 14, 0, 0, Math.PI); g.fill();
  g.fillStyle = 'rgba(255,255,255,.35)'; g.beginPath(); g.ellipse(-10, -9, 80, 6, 0, 0, 6.283); g.fill();
  g.fillStyle = '#9aa5ae'; g.beginPath(); g.moveTo(-96, -4); g.lineTo(-124, -27); g.lineTo(-104, 0); g.fill(); g.beginPath(); g.moveTo(-96, 4); g.lineTo(-124, 27); g.lineTo(-104, 0); g.fill();
  g.fillStyle = '#3a4048'; g.fillRect(-14, 20, 28, 7);
  g.fillStyle = '#ffd98a'; for (var i = 0; i < 5; i++) g.fillRect(-10 + i * 5, 22, 2.6, 3);
  g.restore();
}
function drawTitle(dt) {
  var g = TITLE.g, w = TITLE.w, h = TITLE.h; if (!g || !w) return;
  TITLE.t += dt; var t = TITLE.t, fx = SET.lights, i, j;
  g.setTransform(TITLE.dpr, 0, 0, TITLE.dpr, 0, 0);
  var cx = w > 900 ? w * 0.7 : w * 0.5, base = h * 0.93, th = h * 0.8;
  var bg = g.createLinearGradient(0, 0, 0, h); bg.addColorStop(0, '#05080f'); bg.addColorStop(0.5, '#191a2c'); bg.addColorStop(0.85, '#43262e'); bg.addColorStop(1, '#1a0f14');
  g.fillStyle = bg; g.fillRect(0, 0, w, h);
  /* estrellas */
  TITLE.stars.forEach(function (s) { g.fillStyle = 'rgba(255,240,210,' + (0.35 + 0.35 * Math.sin(t * 1.3 + s.p)) + ')'; g.fillRect(s.x * w, s.y * h, s.r, s.r); });
  /* rayos art déco */
  g.save(); g.translate(cx, base - th * 0.5); g.rotate(t * 0.02);
  var rays = 32, R = Math.max(w, h) * 1.4;
  for (i = 0; i < rays; i++) { var a0 = i / rays * 6.2832, a1 = a0 + 6.2832 / rays * 0.5; g.fillStyle = (i % 2) ? 'rgba(201,162,75,.05)' : 'rgba(201,162,75,.02)'; g.beginPath(); g.moveTo(0, 0); g.arc(0, 0, R, a0, a1); g.closePath(); g.fill(); }
  g.restore();
  var halo = g.createRadialGradient(cx, base - th * 0.5, 10, cx, base - th * 0.5, h * 0.7); halo.addColorStop(0, 'rgba(235,170,100,.28)'); halo.addColorStop(1, 'rgba(235,170,100,0)'); g.fillStyle = halo; g.fillRect(0, 0, w, h);
  /* dirigible */
  var zx = ((t * 18) % (w + 500)) - 250; tZep(g, zx, h * 0.17 + Math.sin(t * 0.5) * 6, Math.min(1, w / 1100) * 0.8);
  /* skyline lejano */
  [[0.18, '#101722', 1.0, 0], [0.34, '#0a1018', 1.45, 0.06]].forEach(function (L, li) {
    var sway = (Math.sin(t * 0.05 + li) * 8);
    TITLE.sky.forEach(function (b) {
      var bx = b.x * w * 1.1 - w * 0.05 + sway, bh = b.h * h * L[2] * 0.62, by = base + 10 - bh;
      g.fillStyle = L[1]; g.fillRect(bx, by, b.w * w * 1.1, bh + h);
      if (li) { for (var wy = by + 8; wy < base; wy += 11) for (var wx = bx + 4; wx < bx + b.w * w * 1.1 - 4; wx += 9) { var hv = tHash(Math.floor(wx / 9) + b.s, Math.floor(wy / 11)); if (hv > 0.78) { g.fillStyle = 'rgba(235,208,138,' + (0.25 + 0.4 * ((Math.sin(t * 0.6 + hv * 40) + 1) / 2)) + ')'; g.fillRect(wx, wy, 3, 4); } } }
    });
  });
  /* reflectores */
  if (fx) for (j = 0; j < 2; j++) {
    var ox = cx + (j ? 1 : -1) * th * 0.32, ang = -Math.PI / 2 + Math.sin(t * 0.35 + j * 2.1) * 0.55, len = h * 1.1, sp = 0.07;
    var bm = g.createLinearGradient(ox, base, ox + Math.cos(ang) * len, base + Math.sin(ang) * len); bm.addColorStop(0, 'rgba(255,240,200,.22)'); bm.addColorStop(1, 'rgba(255,240,200,0)');
    g.fillStyle = bm; g.beginPath(); g.moveTo(ox, base); g.lineTo(ox + Math.cos(ang - sp) * len, base + Math.sin(ang - sp) * len); g.lineTo(ox + Math.cos(ang + sp) * len, base + Math.sin(ang + sp) * len); g.closePath(); g.fill();
  }
  /* torre escalonada */
  var tiers = [[1.0, 0.36], [0.78, 0.2], [0.56, 0.17], [0.38, 0.14], [0.2, 0.09]], baseW = th * 0.34, yy = base, ty = base;
  tiers.forEach(function (tr, k) {
    var tw = baseW * tr[0], tH = th * tr[1]; ty = yy - tH;
    var tg = g.createLinearGradient(cx - tw / 2, 0, cx + tw / 2, 0); tg.addColorStop(0, '#0b1017'); tg.addColorStop(0.5, '#141d28'); tg.addColorStop(1, '#0b1017');
    g.fillStyle = tg; g.fillRect(cx - tw / 2, ty, tw, tH + 1);
    g.strokeStyle = 'rgba(201,162,75,.55)'; g.lineWidth = 1.4; g.strokeRect(cx - tw / 2 + 0.5, ty + 0.5, tw - 1, tH);
    g.fillStyle = 'rgba(201,162,75,.8)'; g.fillRect(cx - tw / 2 - 3, ty - 1, tw + 6, 2.5);
    var cols = Math.max(3, Math.round(tw / 13)), rowsN = Math.max(2, Math.round(tH / 13));
    for (i = 0; i < cols; i++) for (j = 0; j < rowsN; j++) {
      var hv = tHash(i + k * 31, j + k * 7), on = hv > 0.45, fl = 0.55 + 0.45 * Math.sin(t * 0.5 + hv * 30);
      if (!on) continue; g.fillStyle = 'rgba(255,214,130,' + (0.22 + 0.5 * fl * hv) + ')';
      g.fillRect(cx - tw / 2 + (i + 0.5) * tw / cols - 2.5, ty + 7 + j * (tH - 12) / rowsN, 5, 6);
    }
    g.strokeStyle = 'rgba(201,162,75,.22)'; g.lineWidth = 1; for (i = 1; i < cols; i += 2) { g.beginPath(); g.moveTo(cx - tw / 2 + i * tw / cols, ty + 3); g.lineTo(cx - tw / 2 + i * tw / cols, ty + tH); g.stroke(); }
    yy = ty;
  });
  /* aguja, letrero y baliza */
  g.fillStyle = '#c9a24b'; g.fillRect(cx - 1.2, ty - th * 0.1, 2.4, th * 0.1);
  g.fillStyle = (Math.floor(t * 1.6) % 2) ? '#ff4a4a' : '#7a2020'; g.beginPath(); g.arc(cx, ty - th * 0.1, 3, 0, 6.3); g.fill();
  var sg = g.createRadialGradient(cx, ty - th * 0.1, 1, cx, ty - th * 0.1, 26); sg.addColorStop(0, 'rgba(255,70,70,.45)'); sg.addColorStop(1, 'rgba(255,70,70,0)'); g.fillStyle = sg; g.fillRect(cx - 30, ty - th * 0.1 - 30, 60, 60);
  g.font = '700 ' + Math.max(9, th * 0.025) + 'px "Josefin Sans", sans-serif'; g.textAlign = 'center'; g.shadowColor = '#ff3b4a'; g.shadowBlur = 14; g.fillStyle = '#ff6a76';
  g.fillText('NEW YORKER', cx, base - th * 0.36 - th * 0.2 + th * 0.012); g.shadowBlur = 0;
  /* calle y reflejos */
  var st = g.createLinearGradient(0, base, 0, h); st.addColorStop(0, '#120b0e'); st.addColorStop(1, '#07070a'); g.fillStyle = st; g.fillRect(0, base, w, h - base);
  g.fillStyle = 'rgba(255,200,120,.08)'; g.fillRect(cx - baseW * 0.5, base, baseW, h - base);
  /* lluvia */
  if (fx) { g.strokeStyle = 'rgba(190,205,225,.22)'; g.lineWidth = 1; g.beginPath(); TITLE.rain.forEach(function (r) { r.y += r.v * dt * 0.9; r.x -= r.v * dt * 0.12; if (r.y > 1) { r.y = -0.05; r.x = Math.random() * 1.1; } if (r.x < 0) r.x = 1; g.moveTo(r.x * w, r.y * h); g.lineTo(r.x * w - 2, r.y * h + r.l); }); g.stroke(); }
  /* viñeta */
  var vg = g.createRadialGradient(w / 2, h / 2, Math.min(w, h) * 0.35, w / 2, h / 2, Math.max(w, h) * 0.78); vg.addColorStop(0, 'rgba(0,0,0,0)'); vg.addColorStop(1, 'rgba(0,0,0,.7)'); g.fillStyle = vg; g.fillRect(0, 0, w, h);
  if (w <= 900) { g.fillStyle = 'rgba(4,6,10,.45)'; g.fillRect(0, 0, w, h); }
}
