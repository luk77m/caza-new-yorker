/* ===== texturas procedurales: se generan una vez en canvas fuera de pantalla ===== */
var TEX = {}, SPR = {};
var _tr = 987654321;
function tr() { _tr = (_tr * 16807) % 2147483647; return _tr / 2147483647; }
function mkc(w, h) { var c = document.createElement('canvas'); c.width = w; c.height = h; return c; }
function grain(g, amt) {
  var id = g.getImageData(0, 0, TS, TS), d = id.data;
  for (var i = 0; i < d.length; i += 4) { var n = (tr() - 0.5) * amt; d[i] += n; d[i + 1] += n; d[i + 2] += n; }
  g.putImageData(id, 0, 0);
}
function set4(fn) { var a = []; for (var i = 0; i < 4; i++) { var c = mkc(TS, TS); fn(c.getContext('2d'), i); a.push(c); } return a; }
function veins(g, col, a) {
  for (var k = 0; k < 3; k++) {
    g.strokeStyle = col + (a * (0.4 + tr() * 0.8)) + ')'; g.lineWidth = 0.6 + tr() * 1.1; g.beginPath(); g.moveTo(tr() * TS, 0);
    g.bezierCurveTo(tr() * TS, TS * 0.3, tr() * TS, TS * 0.7, tr() * TS, TS); g.stroke();
  }
}
function bevel(g, l, d) { g.fillStyle = l; g.fillRect(0, 0, TS, 1); g.fillRect(0, 0, 1, TS); g.fillStyle = d; g.fillRect(0, TS - 1, TS, 1); g.fillRect(TS - 1, 0, 1, TS); }

function initTextures() {
  TEX.marbleA = set4(function (g) { g.fillStyle = '#d6cdb6'; g.fillRect(0, 0, TS, TS); veins(g, 'rgba(110,100,85,', 0.4); grain(g, 9); bevel(g, 'rgba(255,255,255,.4)', 'rgba(0,0,0,.2)'); g.strokeStyle = 'rgba(201,162,75,.35)'; g.strokeRect(1.5, 1.5, TS - 3, TS - 3); });
  TEX.marbleB = set4(function (g) { g.fillStyle = '#2b3134'; g.fillRect(0, 0, TS, TS); veins(g, 'rgba(210,210,200,', 0.2); grain(g, 9); bevel(g, 'rgba(255,255,255,.12)', 'rgba(0,0,0,.35)'); g.strokeStyle = 'rgba(201,162,75,.3)'; g.strokeRect(1.5, 1.5, TS - 3, TS - 3); });
  TEX.carpet = set4(function (g) {
    g.fillStyle = '#571a26'; g.fillRect(0, 0, TS, TS); g.strokeStyle = 'rgba(201,162,75,.4)'; g.lineWidth = 1;
    [[0, 0], [TS, 0], [TS / 2, TS / 2], [0, TS], [TS, TS]].forEach(function (p) { for (var r = 15; r > 3; r -= 4) { g.beginPath(); g.arc(p[0], p[1], r, 0, 6.283); g.stroke(); } });
    g.fillStyle = 'rgba(0,0,0,.12)'; g.fillRect(0, TS - 1, TS, 1); grain(g, 16);
  });
  TEX.hall = set4(function (g, i) {
    g.fillStyle = '#1a4144'; g.fillRect(0, 0, TS, TS);
    g.strokeStyle = 'rgba(201,162,75,.38)'; g.lineWidth = 1; g.beginPath(); g.moveTo(TS / 2, 7); g.lineTo(TS - 7, TS / 2); g.lineTo(TS / 2, TS - 7); g.lineTo(7, TS / 2); g.closePath(); g.stroke();
    g.fillStyle = 'rgba(201,162,75,.65)'; if (i === 0) { g.fillRect(0, 0, TS, 2); g.fillRect(0, 3, TS, 1); } if (i === 1) { g.fillRect(0, TS - 2, TS, 2); g.fillRect(0, TS - 4, TS, 1); }
    grain(g, 14);
  });
  TEX.conc = set4(function (g) {
    g.fillStyle = '#464d54'; g.fillRect(0, 0, TS, TS); grain(g, 22);
    var st = g.createRadialGradient(tr() * TS, tr() * TS, 1, 16, 16, 18); st.addColorStop(0, 'rgba(0,0,0,.22)'); st.addColorStop(1, 'rgba(0,0,0,0)'); g.fillStyle = st; g.fillRect(0, 0, TS, TS);
    g.strokeStyle = 'rgba(0,0,0,.35)'; g.lineWidth = 1; g.beginPath(); g.moveTo(tr() * TS, 0); g.lineTo(tr() * TS, tr() * TS); g.lineTo(tr() * TS, TS); g.stroke();
    g.fillStyle = 'rgba(0,0,0,.25)'; g.fillRect(0, TS - 1, TS, 1); g.fillRect(TS - 1, 0, 1, TS);
  });
  function parquet(horiz) {
    return set4(function (g, i) {
      var cols = ['#7d5130', '#8a5a33', '#6f4628', '#946238'];
      for (var k = 0; k < 4; k++) {
        for (var j = 0; j < 2; j++) {
          var off = (k % 2) * 8 + j * 16 - (k % 2 ? 0 : 0);
          g.fillStyle = cols[(k * 2 + j + i) % 4];
          if (horiz) g.fillRect(((k % 2) * 8 + j * 16) % 32, k * 8, 16, 8); else g.fillRect(k * 8, ((k % 2) * 8 + j * 16) % 32, 8, 16);
        }
      }
      g.strokeStyle = 'rgba(30,16,6,.7)'; g.lineWidth = 1;
      for (var q = 0; q <= 32; q += 8) { g.beginPath(); if (horiz) { g.moveTo(0, q + .5); g.lineTo(TS, q + .5); } else { g.moveTo(q + .5, 0); g.lineTo(q + .5, TS); } g.stroke(); }
      g.strokeStyle = 'rgba(0,0,0,.14)'; for (var gr = 0; gr < 7; gr++) { var a = tr() * TS, b = tr() * TS; g.beginPath(); if (horiz) { g.moveTo(a, b); g.lineTo(a + 7, b + .4); } else { g.moveTo(b, a); g.lineTo(b + .4, a + 7); } g.stroke(); }
      grain(g, 10);
      var sh = g.createLinearGradient(0, 0, TS, TS); sh.addColorStop(0, 'rgba(255,255,255,.07)'); sh.addColorStop(1, 'rgba(0,0,0,.08)'); g.fillStyle = sh; g.fillRect(0, 0, TS, TS);
    });
  }
  TEX.woodH = parquet(true); TEX.woodV = parquet(false);
  TEX.roof = set4(function (g) { g.fillStyle = '#34393e'; g.fillRect(0, 0, TS, TS); for (var k = 0; k < 70; k++) { g.fillStyle = tr() > 0.5 ? 'rgba(255,255,255,.10)' : 'rgba(0,0,0,.25)'; g.fillRect(tr() * TS, tr() * TS, 1 + tr() * 2, 1 + tr() * 1.5); } g.fillStyle = 'rgba(0,0,0,.25)'; g.fillRect(0, TS - 1, TS, 1); grain(g, 12); });
  TEX.terr = set4(function (g) {
    for (var a = 0; a < 2; a++) for (var b = 0; b < 2; b++) { var l = 92 + Math.floor(tr() * 16); g.fillStyle = 'rgb(' + (l - 4) + ',' + (l + 14) + ',' + (l + 4) + ')'; g.fillRect(a * 16, b * 16, 16, 16); }
    g.strokeStyle = 'rgba(15,25,20,.75)'; g.lineWidth = 1; g.strokeRect(.5, .5, 16, 16); g.strokeRect(16.5, .5, 15, 16); g.strokeRect(.5, 16.5, 16, 15); g.strokeRect(16.5, 16.5, 15, 15); grain(g, 14);
  });
  function wallDeco(sconce) {
    return function (g) {
      g.fillStyle = '#202b38'; g.fillRect(0, 0, TS, TS);
      for (var x = 0; x < TS; x += 8) { g.fillStyle = 'rgba(255,255,255,.04)'; g.fillRect(x, 0, 4, 18); }
      g.strokeStyle = 'rgba(201,162,75,.2)'; g.lineWidth = 1; g.beginPath(); g.moveTo(16, 3); g.lineTo(22, 9); g.lineTo(16, 15); g.lineTo(10, 9); g.closePath(); g.stroke();
      g.fillStyle = '#c9a24b'; g.fillRect(0, 18, TS, 2); g.fillStyle = '#8e7437'; g.fillRect(0, 20, TS, 1);
      g.fillStyle = '#3a2a1e'; g.fillRect(0, 21, TS, 11); g.fillStyle = 'rgba(0,0,0,.28)'; g.fillRect(3, 23, TS - 6, 6); g.strokeStyle = 'rgba(201,162,75,.32)'; g.strokeRect(3.5, 23.5, TS - 7, 5);
      g.fillStyle = '#1a120b'; g.fillRect(0, TS - 3, TS, 3);
      if (sconce) { var gl = g.createRadialGradient(16, 9, 1, 16, 9, 12); gl.addColorStop(0, 'rgba(255,214,140,.75)'); gl.addColorStop(1, 'rgba(255,214,140,0)'); g.fillStyle = gl; g.fillRect(0, 0, TS, 22); g.fillStyle = '#c9a24b'; g.fillRect(14, 6, 4, 7); g.fillStyle = '#fff2c4'; g.fillRect(15, 7, 2, 4); }
      grain(g, 6);
    };
  }
  TEX.wallFace = set4(function (g, i) { wallDeco(i === 3)(g); });
  TEX.wallCap = set4(function (g) { g.fillStyle = '#121a23'; g.fillRect(0, 0, TS, TS); g.fillStyle = '#2a3a4c'; g.fillRect(0, 0, TS, 1); g.fillStyle = 'rgba(201,162,75,.12)'; g.fillRect(0, TS - 2, TS, 1); grain(g, 8); });
  function brick(dark) {
    return function (g) {
      var cols = dark ? ['#4a2a22', '#55302a', '#3d231d'] : ['#6b4034', '#7a4a3a', '#5c352a'];
      g.fillStyle = '#2a2320'; g.fillRect(0, 0, TS, TS);
      for (var r = 0; r < 4; r++) for (var c = -1; c < 2; c++) { g.fillStyle = cols[Math.floor(tr() * 3)]; g.fillRect(c * 16 + (r % 2) * 8 + 1, r * 8 + 1, 14, 6); }
      if (!dark) { var sh = g.createLinearGradient(0, 16, 0, TS); sh.addColorStop(0, 'rgba(0,0,0,0)'); sh.addColorStop(1, 'rgba(0,0,0,.45)'); g.fillStyle = sh; g.fillRect(0, 16, TS, 16); g.fillStyle = '#5a6068'; g.fillRect(0, 22, TS, 3); g.fillStyle = '#7b828a'; g.fillRect(0, 22, TS, 1); }
      grain(g, 14);
    };
  }
  TEX.brickFace = set4(function (g) { brick(false)(g); });
  TEX.brickCap = set4(function (g) { brick(true)(g); });
  TEX.door = (function () { var c = mkc(TS, TS), g = c.getContext('2d'); g.fillStyle = '#4f3c20'; g.fillRect(0, 0, TS, TS); var gr = g.createLinearGradient(0, 0, 0, TS); gr.addColorStop(0, '#e2c06a'); gr.addColorStop(1, '#8f7330'); g.fillStyle = gr; g.fillRect(3, 4, TS - 6, TS - 8); g.strokeStyle = 'rgba(0,0,0,.35)'; g.strokeRect(4.5, 5.5, TS - 9, TS - 11); g.fillStyle = 'rgba(255,255,255,.18)'; g.fillRect(6, 7, TS - 12, 2); return c; })();
  TEX.elev = (function () {
    var c = mkc(TS, TS), g = c.getContext('2d'); g.fillStyle = '#2b2418'; g.fillRect(0, 0, TS, TS);
    var gr = g.createLinearGradient(0, 0, TS, 0); gr.addColorStop(0, '#8d7230'); gr.addColorStop(.5, '#e0bd62'); gr.addColorStop(1, '#8d7230');
    g.fillStyle = gr; g.fillRect(1, 5, TS - 2, TS - 5);
    g.fillStyle = 'rgba(0,0,0,.28)'; g.fillRect(TS / 2 - 1, 5, 2, TS - 5); g.fillRect(1, TS - 6, TS - 2, 5);
    g.strokeStyle = 'rgba(255,255,255,.25)'; g.beginPath(); for (var x = 4; x < TS; x += 5) { g.moveTo(x, 7); g.lineTo(x, TS - 8); } g.stroke();
    g.fillStyle = '#c9a24b'; g.fillRect(0, 0, TS, 2); g.fillStyle = '#16120a'; g.fillRect(TS / 2 - 6, 1, 12, 4);
    return c;
  })();
  function stair(up) {
    var c = mkc(TS, TS), g = c.getContext('2d'); g.fillStyle = '#1e2a35'; g.fillRect(0, 0, TS, TS);
    for (var i = 0; i < 5; i++) { var l = up ? 30 + i * 8 : 62 - i * 8; g.fillStyle = 'hsl(200,12%,' + l + '%)'; g.fillRect(3, 3 + i * 5.6, TS - 6, 4); g.fillStyle = 'rgba(0,0,0,.35)'; g.fillRect(3, 7 + i * 5.6, TS - 6, 1.5); }
    g.fillStyle = '#c9a24b'; g.fillRect(1, 1, 2, TS - 2); g.fillRect(TS - 3, 1, 2, TS - 2);
    g.fillStyle = '#ebd08a'; g.font = '700 11px sans-serif'; g.textAlign = 'center'; g.fillText(up ? '▲' : '▼', TS / 2, TS / 2 + 4);
    return c;
  }
  TEX.up = stair(true); TEX.down = stair(false);
  function sprite(rgb, a0) {
    var c = mkc(256, 256), g = c.getContext('2d'), gr = g.createRadialGradient(128, 128, 4, 128, 128, 128);
    gr.addColorStop(0, 'rgba(' + rgb + ',' + a0 + ')'); gr.addColorStop(0.45, 'rgba(' + rgb + ',' + (a0 * 0.55) + ')'); gr.addColorStop(1, 'rgba(' + rgb + ',0)');
    g.fillStyle = gr; g.fillRect(0, 0, 256, 256); return c;
  }
  SPR.lamp = sprite('255,255,255', 1); SPR.warm = sprite('255,196,120', 0.5); SPR.cold = sprite('150,190,255', 0.35);
}
