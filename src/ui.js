/* ===== interfaz: portada, menús, ajustes, entrada, HUD y bucle principal ===== */
var $ = function (id) { return document.getElementById(id); };
var STEP = 1 / 60;
var UI = {
  w: null, mode: 'title', cfg: { role: 'hunter', hunters: 2, runners: 4, minutes: 12, debug: false },
  keys: {}, mouse: { x: 480, y: 300, left: false, right: false, inside: false },
  anim: 0, acc: 0, speed: 1, paused: false, modalPause: false, follow: null, lastLog: 0, logList: [], pcache: {}, elevOpen: false, elevPend: null,
  hudT: 0, exT: 0, last: 0, endShown: false, ac: null, demoT: 0, taskEls: null, tgCache: {}, tabOpen: false, tabFloor: 0, tabT: 0, tabSide: '', prevLayout: 'normal', logDirty: false
};
var MODAL = { kind: null, tab: null, capture: null };
var cv, g, mini, mg, bigc, bg;

function fmt(t) { t = Math.max(0, Math.ceil(t)); var m = Math.floor(t / 60), s = t % 60; return m + ':' + (s < 10 ? '0' : '') + s; }
function showErr(err) { var el = $('err'); el.hidden = false; el.textContent = String(err && err.stack || err).slice(0, 600); }
function el(tag, cls, html) { var e = document.createElement(tag); if (cls) e.className = cls; if (html !== undefined) e.innerHTML = html; return e; }

/* ---------- sonido ---------- */
var SFX_CAT = { shot: 'weapons', alarm: 'alerts', call: 'alerts', task: 'alerts', ping: 'ui', click: 'ui' };
function sfx(kind) {
  var cat = SFX_CAT[kind]; if (!cat || SET.muted) return;
  var vol = SET.vol.master * SET.vol[cat]; if (vol <= 0.001) return;
  try {
    if (!UI.ac) UI.ac = new (window.AudioContext || window.webkitAudioContext)();
    var a = UI.ac; if (a.state === 'suspended') a.resume();
    var t0 = a.currentTime;
    var tone = function (f, d, type, v, delay) { var o = a.createOscillator(), gn = a.createGain(); o.type = type; o.frequency.value = f; gn.gain.setValueAtTime(0, t0 + delay); gn.gain.linearRampToValueAtTime(v * vol, t0 + delay + 0.01); gn.gain.exponentialRampToValueAtTime(0.0001, t0 + delay + d); o.connect(gn); gn.connect(a.destination); o.start(t0 + delay); o.stop(t0 + delay + d + 0.02); };
    if (kind === 'task') { tone(660, 0.14, 'sine', 0.18, 0); tone(990, 0.2, 'sine', 0.18, 0.1); }
    else if (kind === 'alarm') { tone(220, 0.25, 'square', 0.1, 0); tone(165, 0.35, 'square', 0.1, 0.25); }
    else if (kind === 'call') { tone(440, 0.1, 'triangle', 0.15, 0); tone(440, 0.1, 'triangle', 0.15, 0.18); }
    else if (kind === 'shot') { var n = a.createBufferSource(), len = Math.floor(a.sampleRate * 0.09), buf = a.createBuffer(1, len, a.sampleRate), d = buf.getChannelData(0); for (var i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, 3); n.buffer = buf; var gn = a.createGain(); gn.gain.value = 0.25 * vol; n.connect(gn); gn.connect(a.destination); n.start(); }
    else if (kind === 'ping') tone(520, 0.09, 'sine', 0.1, 0);
    else if (kind === 'click') tone(380, 0.05, 'triangle', 0.1, 0);
  } catch (e) { /* sin audio */ }
}

/* ---------- teclas ---------- */
function actionOf(code) { var b = SET.binds; for (var a in b) if (b[a] === code) return a; return null; }
function isDown(a) {
  var k = UI.keys, c = SET.binds[a];
  if (k[c] || (/^Shift/.test(c) && (k.ShiftLeft || k.ShiftRight))) return true;
  if (a === 'up') return !!k.ArrowUp; if (a === 'down') return !!k.ArrowDown; if (a === 'left') return !!k.ArrowLeft; if (a === 'right') return !!k.ArrowRight;
  return false;
}
function kb(code) { return '<kbd>' + keyLabel(code) + '</kbd>'; }
function refreshCtrl() {
  var b = SET.binds;
  $('ctrlList').innerHTML =
    '<dt>' + kb(b.up) + kb(b.left) + kb(b.down) + kb(b.right) + '</dt><dd>Moverse (las flechas también)</dd>' +
    '<dt>' + kb(b.run) + '</dt><dd>Correr</dd>' +
    '<dt>' + kb(b.use) + '</dt><dd>Mantener: robar ropa, lavar, tareas · pulsar: ascensor</dd>' +
    '<dt>' + kb(b.map) + '</dt><dd>Mapa grande, encargos e inventario</dd>' +
    '<dt>Clic der.</dt><dd>Cazador: sacar el arma y apuntar</dd>' +
    '<dt>Clic izq.</dt><dd>Disparar (apuntando) · golpear con la herramienta</dd>' +
    '<dt>' + kb(b.pause) + kb(b.mute) + kb(b.full) + '</dt><dd>Pausa · sonido · pantalla completa</dd>';
}

/* ---------- modos y partida ---------- */
function setMode(m) {
  UI.mode = m;
  document.body.classList.toggle('intitle', m === 'title');
  document.body.classList.toggle('inmenu', m === 'menu');
  $('title').hidden = m !== 'title'; $('menu').hidden = m !== 'menu'; $('hud').hidden = m !== 'play';
  ['pnStatus', 'pnMap', 'pnLog'].forEach(function (id) { $(id).hidden = m !== 'play'; });
  if (m !== 'play') { $('pnHunter').hidden = true; $('pnRunner').hidden = true; $('stage').classList.remove('aiming'); }
  if (m === 'title') { resizeTitle(); var f = $('tmenu').querySelector('.tb'); if (f && f.focus) try { f.focus({ preventScroll: true }); } catch (e) { /* nada */ } }
  else setTimeout(resizeCanvas, 0);
}
function newDemo() {
  UI.w = newWorld({ role: 'bots', hunters: 2, runners: 4, minutes: 12, debug: true });
  UI.follow = null; UI.demoT = 0; UI.lastLog = 0; UI.logList = [];
  resetRender();
}
function toTitle() { closeModal(); closeElev(); toggleTab(false); $('end').hidden = true; $('pause').hidden = true; $('fade').classList.remove('on'); clearPosters(); UI.paused = false; setMode('title'); }
function goLobby() { UI.paused = false; newDemo(); setMode('menu'); }
function startGame() {
  var c = UI.cfg;
  var w = newWorld({ role: c.role, hunters: c.hunters, runners: c.runners, minutes: c.minutes, debug: c.debug });
  UI.w = w; UI.lastLog = 0; UI.logList = []; UI.follow = null; UI.speed = 1; UI.paused = false; UI.modalPause = false; UI.endShown = false; UI.elevPend = null; UI.acc = 0;
  resetRender(); closeElev(); closeModal(); toggleTab(false);
  $('toasts').innerHTML = ''; $('end').hidden = true; $('pause').hidden = true; $('fade').classList.remove('on');
  clearPosters(); buildTargets(w); buildTasks(w); buildFloors();
  setMode('play');
  var hm = w.human;
  $('pnHunter').hidden = !(hm && hm.role === 'hunter'); $('pnRunner').hidden = !(hm && hm.role === 'runner');
  $('susWrap').hidden = !(hm && hm.role === 'hunter');
  $('sbRole').textContent = hm ? (hm.role === 'hunter' ? 'Cazador' : 'Corredor') : 'Observador';
  $('sbSub').textContent = hm ? hm.name : 'solo bots';
  $('sbTimerLbl').textContent = hm && hm.role === 'hunter' ? 'Tiempo de ronda' : 'Llega el cliente en';
  $('dealWrap').hidden = !(hm ? hm.role === 'runner' : true);
  $('hDeal').hidden = !hm;
  updateHud(true);
  sfx('ping');
}
function viewEnt() {
  var w = UI.w;
  if (w.human && w.human.alive) return w.human;
  var l = w.ents.filter(function (e) { return e.alive && (e.role === 'runner' || e.role === 'hunter'); });
  if (UI.mode !== 'play') {
    if (!UI.follow || !UI.follow.alive || UI.demoT <= 0) { UI.follow = l.length ? l[Math.floor(Math.random() * l.length)] : null; UI.demoT = 14; }
    return UI.follow || w.ents[0];
  }
  if (!UI.follow || !UI.follow.alive) {
    var pref = w.human ? l.filter(function (e) { return e.role === w.human.role; }) : [];
    UI.follow = (pref[0] || l[0]) || w.human || w.ents[0];
  }
  return UI.follow;
}
function cycleFollow(dir) {
  var w = UI.w; if (w.human && w.human.alive) return;
  var l = w.ents.filter(function (e) { return e.alive && (e.role === 'runner' || e.role === 'hunter'); });
  if (!l.length) return;
  var i = Math.max(0, l.indexOf(UI.follow)); UI.follow = l[(i + dir + l.length) % l.length];
}

/* ---------- visor, tamaño y pantalla completa ---------- */
function resizeCanvas() {
  if (!cv) return;
  var st = $('stage'), cw = st.clientWidth, ch = st.clientHeight; if (!cw || !ch) return;
  var dpr = Math.min(window.devicePixelRatio || 1, 2);
  cv.width = Math.round(cw * dpr); cv.height = Math.round(ch * dpr);
  setView(cw, ch, dpr, SET.zoom * clamp(cw / 820, 0.62, 1.45));
}
function applyLayout() {
  var b = document.body; b.classList.toggle('lay-wide', SET.layout === 'wide'); b.classList.toggle('lay-full', SET.layout === 'full');
  setTimeout(resizeCanvas, 0);
}
function setLayout(v) {
  if (SET.layout !== 'full') UI.prevLayout = SET.layout;
  SET.layout = v; saveSettings(); applyLayout();
  try {
    if (v === 'full') { if (!document.fullscreenElement && document.documentElement.requestFullscreen) document.documentElement.requestFullscreen().catch(function () { /* bloqueado: queda el modo ocupando toda la ventana */ }); }
    else if (document.fullscreenElement && document.exitFullscreen) document.exitFullscreen().catch(function () { /* nada */ });
  } catch (e) { /* nada */ }
}
function toggleFull() { setLayout(SET.layout === 'full' ? (UI.prevLayout === 'full' ? 'normal' : UI.prevLayout) : 'full'); if (MODAL.kind === 'settings') renderModal(); }

/* ---------- ascensor ---------- */
function buildElev() {
  var box = $('elevList'); box.innerHTML = '';
  FLOORS.forEach(function (f, i) {
    var b = document.createElement('button'); b.dataset.f = i; b.innerHTML = '<b>' + (i + 1) + '</b>' + f.label + '<small>' + f.sub + '</small>';
    b.onclick = function () { chooseElev(i); }; box.appendChild(b);
  });
}
function openElev() {
  var h = UI.w.human; if (!h) return;
  UI.elevOpen = true; $('elev').hidden = false;
  Array.prototype.forEach.call($('elevList').children, function (b) { b.disabled = (+b.dataset.f === h.floor); });
}
function closeElev() { UI.elevOpen = false; $('elev').hidden = true; }
function chooseElev(fl) {
  var h = UI.w.human; if (!h || !h.alive || fl === h.floor) return;
  closeElev(); UI.elevPend = { fl: fl, t: 0.55 }; $('fade').classList.add('on'); sfx('ping');
}

/* ---------- carteles ---------- */
function clearPosters() { $('posters').innerHTML = ''; UI.pcache = {}; }
function syncPosters(w, role) {
  var box = $('posters'), seen = {};
  var list = role === 'hunter' ? [] : w.posters;
  list.forEach(function (p) {
    var key = p.outfitId; seen[key] = 1;
    var e = UI.pcache[key];
    if (!e) {
      e = el('div', 'poster', '<canvas width="104" height="124"></canvas><div class="pt"></div><div class="pd"></div>');
      e.cv = e.firstChild; e.pt = e.children[1]; e.pd = e.children[2]; e.st = null;
      UI.pcache[key] = e; box.appendChild(e); sfx('alarm');
    }
    if (e.st !== p.state) {
      e.st = p.state; e.className = 'poster ' + p.state;
      drawPortrait(e.cv, p.outfit, p.state === 'changed' ? 'grey' : null);
      e.pt.textContent = p.state === 'changed' ? 'HA CAMBIADO DE APARIENCIA' : 'SE BUSCA';
      e.pd.textContent = p.state === 'changed' ? 'Ya no sirve este cartel.' : describeOutfit(p.outfit);
    }
  });
  for (var k in UI.pcache) if (!seen[k]) { box.removeChild(UI.pcache[k]); delete UI.pcache[k]; }
}

/* ---------- paneles laterales ---------- */
function buildTargets(w) {
  var box = $('targets'); box.innerHTML = ''; UI.tgCache = {};
  if (!(w.human && w.human.role === 'hunter')) return;
  w.targets.forEach(function (id, i) {
    var ent = null; w.ents.forEach(function (e) { if (e.id === id) ent = e; });
    var d = el('div', 'tg', '<canvas width="96" height="116"></canvas><b>Objetivo ' + (i + 1) + '</b><span>' + describeOutfit(ent.outfit) + '</span>');
    drawPortrait(d.firstChild, ent.outfit, null);
    box.appendChild(d); UI.tgCache[id] = { el: d, ent: ent, dead: false };
  });
}
var FL_SHORT = ['Sót.', 'PB', 'P2', 'P10', 'P20', 'P30', 'Azotea'];
function buildTasks(w) {
  var ul = $('taskList'); ul.innerHTML = ''; UI.taskEls = [];
  var tasks = w.tasks.slice().sort(function (a, b) { return a.floor - b.floor; });
  tasks.forEach(function (t) {
    var li = el('li', '', '<em>' + FL_SHORT[t.floor] + '</em><span>' + t.name + '<small></small></span>');
    ul.appendChild(li); UI.taskEls.push({ li: li, t: t, sm: li.querySelector('small') });
  });
}
function buildFloors() {
  var ul = $('floors'); ul.innerHTML = '';
  for (var i = FLOORS.length - 1; i >= 0; i--) { var li = el('li', '', '<span>' + FLOORS[i].label + '</span><span>' + FLOORS[i].sub + '</span>'); li.dataset.f = i; ul.appendChild(li); }
}
function taskState(w, hm, t) {
  if (t.cool > w.time) return { cls: 'cool', msg: 'Hecho · otra vez en ' + fmt(t.cool - w.time) };
  if (t.kind === 'drop' && hm.inv.carry !== t.id) return { cls: 'lock', msg: 'Necesitas recoger el encargo antes' };
  if (t.kind === 'pick' && hm.inv.carry) return { cls: 'lock', msg: 'Ya llevas un encargo' };
  if (t.kind === 'drop') return { cls: '', msg: 'Llevas el encargo: entrégalo' };
  return { cls: '', msg: '' };
}
function taskMarks(w, hm, fl) {
  if (!(hm && hm.role === 'runner')) return [];
  var out = []; w.tasks.forEach(function (t) { if (t.floor === fl) out.push({ x: t.x, y: t.y, dim: taskState(w, hm, t).cls !== '' }); });
  return out;
}
function worldMarkers(w, hm, view) {
  if (!SET.arrows || !(hm && hm.alive && hm.role === 'runner')) return null;
  var out = [];
  w.tasks.forEach(function (t) {
    if (t.floor !== view.floor || taskState(w, hm, t).cls) return;
    var x = (t.x + 0.5) * TS, y = (t.y + 0.5) * TS, d = dist(x, y, view.x, view.y);
    if (d <= 17 * TS && d > 26) out.push({ x: x, y: y, d: d });
  });
  out.sort(function (a, b) { return a.d - b.d; });
  return out.slice(0, 3);
}
function logVisible(l, role) {
  if (role === 'runner') return l.kind !== 'call' && l.kind !== 'hunt';
  if (role === 'hunter') return l.kind !== 'task' && l.kind !== 'poster';
  return true;
}
function pumpLogs(w) {
  var role = w.human ? w.human.role : null, tb = $('toasts');
  w.logs.forEach(function (l) {
    if (l.id <= UI.lastLog) return; UI.lastLog = l.id;
    if (UI.mode !== 'play' || !logVisible(l, role)) return;
    UI.logList.push(l); if (UI.logList.length > 60) UI.logList.shift();
    var e = el('div', 'toast ' + l.kind); e.textContent = l.msg; tb.appendChild(e);
    while (tb.children.length > 4) tb.removeChild(tb.firstChild);
    setTimeout(function () { e.classList.add('out'); setTimeout(function () { if (e.parentNode) e.parentNode.removeChild(e); }, 700); }, 6000);
    UI.logDirty = true;
    if (l.kind === 'task') sfx('task'); else if (l.kind === 'alarm') sfx('alarm'); else if (l.kind === 'call') sfx('call');
  });
}
function holdLabel(h) {
  if (h.type === 'strip') return 'Cogiendo su ropa…';
  if (h.type === 'ward') return 'Registrando el armario…';
  if (h.type === 'wash') return 'Lavando el traje…';
  return h.ref.name + '…';
}
function hunterFlags(w, hm) {
  var hot = hm.alive && isHot(w, hm), fl = '';
  if (hm.restricted) fl += '<span class="flag warn">Zona restringida</span>';
  if (hm.outfit.blood) fl += '<span class="flag bad">Traje manchado</span>';
  if (hm.aim) fl += '<span class="flag warn">Arma fuera</span>';
  if (hot) fl += '<span class="flag bad">La policía te describe</span>';
  return fl;
}
function updateHud(force) {
  var w = UI.w, view = viewEnt(), hm = w.human, role = hm ? hm.role : null, f = FLOORS[view.floor];
  var rm = roomAt(f, Math.floor(view.x / TS), Math.floor(view.y / TS));
  $('hFloor').innerHTML = '<b>' + f.label + '</b> · ' + ((rm && rm.name !== 'Núcleo de ascensores') ? rm.name : f.sub);
  var rem = w.limit - w.time;
  $('hTime').innerHTML = (role === 'hunter' ? 'Tiempo ' : 'Cliente ') + '<b>' + fmt(rem) + '</b>';
  $('sbTimer').textContent = fmt(rem);
  $('dealTxt').textContent = w.tasksDone + ' / ' + w.quota;
  $('dealBar').style.width = Math.min(100, w.tasksDone / w.quota * 100) + '%';
  if (role === 'runner') $('hDeal').innerHTML = 'Trato <b>' + w.tasksDone + '/' + w.quota + '</b>';
  else if (role === 'hunter') { var tl = 0; w.targets.forEach(function (id) { w.ents.forEach(function (e) { if (e.id === id && e.alive) tl++; }); }); $('hDeal').innerHTML = 'Objetivos vivos <b>' + tl + '/' + w.targets.length + '</b>'; }
  $('mapFloor').textContent = f.label;
  Array.prototype.forEach.call($('floors').children, function (li) { li.className = (+li.dataset.f === view.floor) ? 'cur' : ''; });
  if (hm && hm.role === 'hunter') {
    var sus = hm.alive ? hm.sus : 0, hot = hm.alive && isHot(w, hm);
    $('susFill').style.width = sus + '%'; $('susNum').textContent = hot ? 'BUSCADO' : Math.round(sus);
    var fl = hunterFlags(w, hm); if ($('susFlags').innerHTML !== fl) $('susFlags').innerHTML = fl;
    $('outfitDesc').textContent = describeOutfit(hm.outfit) + (hm.outfit.blood ? ' · manchado de sangre' : '');
    var inv = '<span class="flag ' + (hm.inv.masterkey ? 'on' : '') + '">Llave maestra ' + (hm.inv.masterkey ? '✓' : '—') + '</span><span class="flag ' + (hm.inv.badge ? 'on' : '') + '">Insignia ' + (hm.inv.badge ? '✓' : '—') + '</span>';
    if ($('hInv').innerHTML !== inv) $('hInv').innerHTML = inv;
    for (var id in UI.tgCache) { var tg = UI.tgCache[id]; if (!tg.ent.alive && !tg.dead) { tg.dead = true; tg.el.classList.add('dead'); drawPortrait(tg.el.firstChild, tg.ent.outfit, 'dead'); tg.el.children[1].textContent += ' ✕'; } }
  }
  if (hm && hm.role === 'runner') {
    $('rInv').textContent = hm.inv.melee ? 'llave inglesa ✓' : 'piezas ' + Math.min(hm.inv.scrap, CFG.scrapNeeded) + '/' + CFG.scrapNeeded;
    UI.taskEls.forEach(function (te) {
      var st = taskState(w, hm, te.t), cls = st.cls;
      if (te.t.floor === view.floor && !cls) cls = 'here';
      te.li.className = cls; te.sm.textContent = st.msg;
    });
  }
  var ht = $('hintTxt'), hb = $('hintBar');
  if (hm && hm.alive && hm.hold) { ht.hidden = false; ht.textContent = holdLabel(hm.hold); hb.style.display = 'block'; $('hintFill').style.width = (hm.hold.t / hm.hold.dur * 100) + '%'; }
  else if (SET.hints && hm && hm.alive && w.hint) { ht.hidden = false; ht.innerHTML = kb(SET.binds.use) + ' ' + w.hint.label + (w.hint.dur ? ' <small style="color:var(--mut)">(mantén ' + w.hint.dur + ' s)</small>' : ''); hb.style.display = 'none'; }
  else { ht.hidden = true; hb.style.display = 'none'; }
  if (UI.elevOpen && !(hm && hm.alive && w.hint && w.hint.type === 'elev')) closeElev();
  var spec = !(hm && hm.alive) && !w.over;
  $('specbar').hidden = !spec;
  if (spec) {
    $('specName').textContent = (hm && !hm.alive ? 'Has caído · ' : 'Observando · ') + view.name;
    Array.prototype.forEach.call($('specbar').querySelectorAll('[data-speed]'), function (b) { b.classList.toggle('on', +b.dataset.speed === UI.speed); });
  } else UI.speed = 1;
  syncPosters(w, role);
  if (UI.logDirty || force) {
    UI.logDirty = false;
    var ul = $('log'), html = '';
    for (var i = UI.logList.length - 1, n = 0; i >= 0 && n < 9; i--, n++) { var l = UI.logList[i]; html += '<li class="' + l.kind + '"><time>' + fmt(l.t) + '</time>' + l.msg + '</li>'; }
    ul.innerHTML = html;
  }
}

/* ---------- panel de mapa y encargos (Tab) ---------- */
function toggleTab(force) {
  var open = force === undefined ? !UI.tabOpen : force;
  if (open && (UI.mode !== 'play' || UI.paused || UI.w.over || UI.endShown)) return;
  UI.tabOpen = open; $('tabp').hidden = !open; UI.mouse.right = UI.mouse.left = false;
  if (open) {
    UI.tabFloor = viewEnt().floor; UI.tabT = 0; UI.tabSide = '';
    var fb = $('ftabs'); fb.innerHTML = '';
    FLOORS.forEach(function (f, i) { var b = el('button', '', FL_SHORT[i]); b.dataset.f = i; b.title = f.label + ' · ' + f.sub; b.onclick = function () { UI.tabFloor = i; renderTab(); }; fb.appendChild(b); });
    $('tabside').innerHTML = '<div id="tabTop"></div><div id="tabDyn"></div>';
    var w = UI.w, hm = w.human;
    if (hm && hm.role === 'hunter') {
      var top = $('tabTop'), blk = el('div', 'blk', '<h3>Cartel</h3>'), row = el('div', ''); row.style.cssText = 'display:flex;gap:8px';
      for (var id in UI.tgCache) { var tg = UI.tgCache[id], d = el('div', 'tg' + (tg.ent.alive ? '' : ' dead'), '<canvas width="96" height="116"></canvas><b>' + (tg.ent.alive ? 'Vivo' : 'Eliminado') + '</b><span>' + describeOutfit(tg.ent.outfit) + '</span>'); drawPortrait(d.firstChild, tg.ent.outfit, tg.ent.alive ? null : 'dead'); row.appendChild(d); }
      blk.appendChild(row); top.appendChild(blk);
    }
    renderTab();
  }
}
function renderTab() {
  if (!UI.tabOpen) return;
  var w = UI.w, view = viewEnt(), hm = w.human, fl = UI.tabFloor;
  drawMapFloor(bg, w, view, fl, 14, { all: !!w.opt.debug, plan: true, labels: true, marks: taskMarks(w, hm, fl) });
  Array.prototype.forEach.call($('ftabs').children, function (b) { var i = +b.dataset.f; b.className = (i === fl ? 'on ' : '') + (i === view.floor ? 'cur' : ''); });
  $('tabTitle').textContent = FLOORS[fl].label + ' · ' + FLOORS[fl].sub;
  var h = '';
  if (hm && hm.role === 'runner') {
    h += '<div class="blk"><h3>Trato ' + w.tasksDone + ' / ' + w.quota + '</h3><div class="bar"><i style="width:' + Math.min(100, w.tasksDone / w.quota * 100) + '%"></i></div></div>';
    h += '<div class="blk"><h3>Encargos</h3><ul class="tl">';
    w.tasks.slice().sort(function (a, b) { return (a.floor === fl ? -1 : 0) - (b.floor === fl ? -1 : 0) || a.floor - b.floor; }).forEach(function (t) {
      var st = taskState(w, hm, t), cls = st.cls || (t.floor === fl ? 'here' : '');
      h += '<li class="' + cls + '"><em>' + FL_SHORT[t.floor] + '</em><span>' + t.name + (st.msg ? '<small>' + st.msg + '</small>' : '') + '</span></li>';
    });
    h += '</ul></div><div class="blk"><h3>Inventario</h3><div class="kv"><span class="flag ' + (hm.inv.melee ? 'on' : '') + '">Llave inglesa ' + (hm.inv.melee ? '✓' : Math.min(hm.inv.scrap, CFG.scrapNeeded) + '/' + CFG.scrapNeeded) + '</span><span class="flag ' + (hm.inv.carry ? 'on' : '') + '">Encargo ' + (hm.inv.carry ? 'en mano' : '—') + '</span></div></div>';
  } else if (hm && hm.role === 'hunter') {
    h += '<div class="blk"><h3>Sospecha ' + (isHot(w, hm) ? '· buscado' : Math.round(hm.alive ? hm.sus : 0)) + '</h3><div class="bar"><i style="width:' + (hm.alive ? hm.sus : 0) + '%;background:var(--warn)"></i></div><div class="kv">' + hunterFlags(w, hm) + '</div></div>';
    h += '<div class="blk"><h3>Llevas puesto</h3><div id="outfitDesc">' + describeOutfit(hm.outfit) + (hm.outfit.blood ? ' · manchado de sangre' : '') + '</div></div>';
    h += '<div class="blk"><h3>Accesos</h3><div class="kv"><span class="flag ' + (hm.inv.masterkey ? 'on' : '') + '">Llave maestra ' + (hm.inv.masterkey ? '✓' : '—') + '</span><span class="flag ' + (hm.inv.badge ? 'on' : '') + '">Insignia ' + (hm.inv.badge ? '✓' : '—') + '</span></div></div>';
  } else {
    var nh = 0, nr = 0; w.ents.forEach(function (e) { if (e.alive && e.role === 'hunter') nh++; if (e.alive && e.role === 'runner') nr++; });
    h += '<div class="blk"><h3>Partida</h3><div class="kv"><span class="flag">Cazadores vivos ' + nh + '</span><span class="flag">Corredores vivos ' + nr + '</span><span class="flag">Trato ' + w.tasksDone + '/' + w.quota + '</span></div></div>';
  }
  if (h !== UI.tabSide) { UI.tabSide = h; $('tabDyn').innerHTML = h; }
}

/* ---------- ventanas: ajustes, cómo se juega, créditos ---------- */
var pct = function (v) { return Math.round(v * 100) + '%'; };
var SCHEMA = {
  image: [
    { k: 'layout', t: 'seg', label: 'Tamaño del visor', note: 'Normal junto a los paneles · Ancho ocupa toda la página · Pantalla completa (tecla F)', opts: [['normal', 'Normal'], ['wide', 'Ancho'], ['full', 'Completa']] },
    { k: 'zoom', t: 'range', min: 0.8, max: 1.9, step: 0.05, label: 'Zoom de cámara', note: 'Más zoom = personajes y detalles más grandes', fmt: pct },
    { k: 'bright', t: 'range', min: 0.7, max: 1.6, step: 0.05, label: 'Brillo', note: 'Aclara u oscurece las plantas', fmt: pct },
    { k: 'fog', t: 'range', min: 0.5, max: 0.97, step: 0.01, label: 'Oscuridad de la niebla', note: 'Lo que no ves ahora mismo', fmt: pct },
    { k: 'lights', t: 'check', label: 'Efectos de luz', note: 'Lámparas, niebla suave y lluvia de la portada. Apágalo si va lento.' },
    { k: 'plates', t: 'check', label: 'Números en las puertas', note: 'Placas con el número o el nombre de cada sala' }
  ],
  sound: [
    { k: 'vol.master', t: 'range', min: 0, max: 1, step: 0.05, label: 'Volumen general', fmt: pct },
    { k: 'vol.weapons', t: 'range', min: 0, max: 1, step: 0.05, label: 'Armas', fmt: pct },
    { k: 'vol.alerts', t: 'range', min: 0, max: 1, step: 0.05, label: 'Avisos y tareas', note: 'Alarmas, llamadas a la policía y tareas completadas', fmt: pct },
    { k: 'vol.ui', t: 'range', min: 0, max: 1, step: 0.05, label: 'Interfaz', fmt: pct },
    { k: 'muted', t: 'check', label: 'Silenciar todo' }
  ],
  game: [
    { k: 'arrows', t: 'check', label: 'Flechas y marcadores de objetivos', note: 'Corredor: te señalan los encargos cuando estás cerca' },
    { k: 'hints', t: 'check', label: 'Avisos de interacción', note: 'El cuadro con la tecla que puedes pulsar' }
  ]
};
var BIND_LABELS = [['up', 'Mover arriba'], ['down', 'Mover abajo'], ['left', 'Mover a la izquierda'], ['right', 'Mover a la derecha'], ['run', 'Correr'], ['use', 'Interactuar (mantener) y ascensor'], ['map', 'Mapa y encargos'], ['pause', 'Pausa'], ['mute', 'Silenciar'], ['full', 'Pantalla completa']];
function onSettingChange(k) {
  saveSettings();
  if (k === 'zoom') resizeCanvas();
  if (k === 'lights') { /* se aplica en el siguiente fotograma */ }
}
function settingRow(d) {
  var row = el('div', 'set'), lab = el('div', 'lab', d.label + (d.note ? '<small>' + d.note + '</small>' : '')), ctl = el('div', ''), val = getPath(SET, d.k);
  if (d.t === 'range') {
    ctl.className = 'slid';
    var inp = el('input'); inp.type = 'range'; inp.min = d.min; inp.max = d.max; inp.step = d.step; inp.value = val; inp.setAttribute('aria-label', d.label);
    var rv = el('span', 'rv', d.fmt(val));
    inp.oninput = function () { var v = parseFloat(inp.value); setPath(SET, d.k, v); rv.textContent = d.fmt(v); onSettingChange(d.k); };
    inp.onchange = function () { sfx('ping'); };
    ctl.appendChild(inp); ctl.appendChild(rv);
  } else if (d.t === 'check') {
    var lb = el('label', 'chk'), cb = el('input'); cb.type = 'checkbox'; cb.checked = !!val; lb.appendChild(cb); lb.appendChild(document.createTextNode(val ? ' Activado' : ' Desactivado'));
    cb.onchange = function () { setPath(SET, d.k, cb.checked); lb.lastChild.nodeValue = cb.checked ? ' Activado' : ' Desactivado'; onSettingChange(d.k); sfx('click'); };
    ctl.appendChild(lb);
  } else if (d.t === 'seg') {
    ctl.className = 'seg';
    d.opts.forEach(function (o) {
      var b = el('button', o[0] === val ? 'on' : '', o[1]);
      b.onclick = function () { Array.prototype.forEach.call(ctl.children, function (x) { x.classList.remove('on'); }); b.classList.add('on'); if (d.k === 'layout') setLayout(o[0]); else { setPath(SET, d.k, o[0]); onSettingChange(d.k); } sfx('click'); };
      ctl.appendChild(b);
    });
  }
  row.appendChild(lab); row.appendChild(ctl); return row;
}
var HOW = {
  goal: '<h4>Dos bandos</h4><ul><li><b>Cazadores</b> (máx. 2): policía secreta infiltrada en el hotel. Solo ganan eliminando a los <b>dos</b> retratados en su cartel.</li><li><b>Corredores</b> (máx. 4): mafia contratada. Ganan cerrando el trato (completando tareas), aguantando hasta que llegue el cliente (fin del tiempo) o abatiendo a los cazadores.</li></ul><h4>Los testigos</h4><ul><li>Huéspedes y trabajadores ven lo que ocurre. Si presencian un asesinato corren a un teléfono y llaman a la policía.</li><li>La policía tarda unos segundos en llegar y dispara solo al cazador descrito (o a cualquiera manchado de sangre) en cuanto lo ve.</li><li>Los corredores no saben nada de los cazadores hasta que la policía reparte un cartel con su aspecto.</li></ul>',
  hunter: '<h4>Cartel y arma</h4><ul><li>Tu cartel muestra a los dos objetivos. Búscalos entre los huéspedes.</li><li><b>Clic derecho</b> saca la pistola con silenciador y aparece una mira. <b>Clic izquierdo</b> dispara. Con el arma fuera te mueves más despacio.</li></ul><h4>Sospecha</h4><ul><li>La barra sube si entras sin permiso en habitaciones o zonas de personal, si apuntas cerca de un PNJ (más rápido cuanto más cerca) o si llevas ropa manchada de sangre.</li><li>A partir de 35 los trabajadores te avisan; a partir de 80, si insistes, llaman a la policía. Matar con testigos la lleva al máximo.</li></ul><h4>Disfraz y accesos</h4><ul><li>Mantén la tecla de interactuar sobre un cadáver para coger su ropa (queda manchada: lávala en una pila o lavadora) o abre un armario para llevarte un traje limpio.</li><li>Cambiar de ropa anula el cartel que la policía repartió sobre ti.</li><li>Una llave maestra abre habitaciones, una insignia de botones abre zonas de personal, y el uniforme de trabajador sirve para ambas.</li></ul>',
  runner: '<h4>Encargos</h4><ul><li>Hay 14 encargos repartidos por las 7 plantas. Mantén la tecla de interactuar sobre el punto marcado. Algunos son parejas: recoger en un sitio y entregar en otro.</li><li>Cada encargo suma al trato y se puede repetir pasado un tiempo. El ascensor (acércate y pulsa la tecla) te lleva a cualquier planta; las escaleras, a la contigua.</li><li>En el mapa (tecla Tab) y con flechas en pantalla ves dónde están los encargos cercanos.</li></ul><h4>Defensa</h4><ul><li>Recoge 4 objetos sueltos por el hotel y fabricarás una <b>llave inglesa</b>: clic izquierdo para golpear. Un golpe mata a un cazador.</li><li>No puedes cambiar de ropa. Cuando la policía reparta un cartel de busca y captura, verás el aspecto del cazador; si se cambia, el cartel se pone gris y desaparece.</li></ul>'
};
function modalTabs(list) {
  var box = $('mTabs'); box.innerHTML = '';
  list.forEach(function (t) { var b = el('button', t[0] === MODAL.tab ? 'on' : '', t[1]); b.onclick = function () { MODAL.tab = t[0]; MODAL.capture = null; renderModal(); }; box.appendChild(b); });
}
function renderModal() {
  var body = $('mBody'), foot = $('mFoot'); body.innerHTML = ''; foot.innerHTML = '';
  var close = el('button', 'btn ghost', 'Cerrar'); close.onclick = closeModal;
  if (MODAL.kind === 'settings') {
    $('mTitle').textContent = 'Ajustes';
    modalTabs([['image', 'Imagen'], ['sound', 'Sonido'], ['keys', 'Controles'], ['game', 'Juego']]);
    if (MODAL.tab === 'keys') {
      BIND_LABELS.forEach(function (bl) {
        var row = el('div', 'set'), lab = el('div', 'lab', bl[1]), b = el('button', 'kb' + (MODAL.capture === bl[0] ? ' cap' : ''), MODAL.capture === bl[0] ? 'Pulsa una tecla…' : keyLabel(SET.binds[bl[0]]));
        b.onclick = function () { MODAL.capture = MODAL.capture === bl[0] ? null : bl[0]; renderModal(); };
        var c = el('div', ''); c.appendChild(b); row.appendChild(lab); row.appendChild(c); body.appendChild(row);
      });
      body.appendChild(el('p', 'fixed', 'Fijos: clic derecho apunta · clic izquierdo dispara o golpea · 1–7 elige planta en el ascensor · las flechas también mueven · Esc cierra ventanas y pausa.'));
    } else (SCHEMA[MODAL.tab] || []).forEach(function (d) { body.appendChild(settingRow(d)); });
    var rs = el('button', 'btn ghost', 'Restablecer esta pestaña');
    rs.onclick = function () { resetSettings(MODAL.tab === 'keys' ? 'binds' : MODAL.tab); saveSettings(); applyLayout(); resizeCanvas(); refreshCtrl(); renderModal(); };
    foot.appendChild(rs); foot.appendChild(close);
  } else if (MODAL.kind === 'how') {
    $('mTitle').textContent = 'Cómo se juega';
    modalTabs([['goal', 'Objetivo'], ['hunter', 'Cazador'], ['runner', 'Corredor'], ['keys', 'Controles']]);
    if (MODAL.tab === 'keys') { body.innerHTML = '<div class="how"><h4>Teclado y ratón</h4><dl class="ctrl" style="font-size:.92rem;gap:6px 14px">' + $('ctrlList').innerHTML + '</dl><p>Puedes cambiar las teclas en Ajustes › Controles.</p></div>'; }
    else body.innerHTML = '<div class="how">' + HOW[MODAL.tab] + '</div>';
    foot.appendChild(el('span', 'meta', 'Partida contra bots · v0.2')); foot.appendChild(close);
  } else if (MODAL.kind === 'credits') {
    $('mTitle').textContent = 'Créditos';
    $('mTabs').innerHTML = '';
    body.innerHTML = '<div class="how"><h4>Caza en el New Yorker</h4><p>Prototipo jugable v0.2 de un juego asimétrico de cazadores y corredores ambientado en el hotel New Yorker de 1930.</p><h4>Equipo</h4><ul><li><b>Idea y diseño del juego:</b> Luca</li><li><b>Código, texturas procedurales y bots:</b> Claude</li></ul><h4>Qué hay hoy</h4><ul><li>Siete plantas con zonas públicas, de habitaciones y de personal.</li><li>Cazadores, corredores, PNJ con testigos, policía y carteles de busca y captura.</li><li>Bots para ambos bandos, así que se puede probar sin más jugadores.</li></ul><h4>Próximamente</h4><ul><li>Economía de los corredores, munición y ventajas del cazador.</li><li>Ascensor con enfriamiento y avería.</li><li>Disparos visibles y sonido de armas y pasos.</li><li>Multijugador con servidor y, más adelante, versión 3D.</li></ul></div>';
    foot.appendChild(el('span', 'meta', 'Hecho para probar ideas')); foot.appendChild(close);
  }
}
function openModal(kind, tab) {
  MODAL.kind = kind; MODAL.capture = null; MODAL.tab = tab || (kind === 'settings' ? 'image' : (kind === 'how' ? 'goal' : null));
  UI.modalPause = UI.mode === 'play' && !UI.paused && !UI.w.over && !UI.endShown; if (UI.modalPause) UI.paused = true;
  if (UI.tabOpen) toggleTab(false);
  $('modal').hidden = false; renderModal(); sfx('click');
}
function closeModal() {
  if (!MODAL.kind) return;
  MODAL.kind = null; MODAL.capture = null; $('modal').hidden = true;
  if (UI.modalPause) { UI.paused = false; UI.modalPause = false; }
  if (UI.mode === 'title') { var f = $('tmenu').querySelector('.tb'); if (f) try { f.focus({ preventScroll: true }); } catch (e) { /* nada */ } }
}

/* ---------- entrada ---------- */
function readInput() {
  var m = UI.mouse, mx = 0, my = 0, open = UI.tabOpen;
  if (isDown('left')) mx -= 1; if (isDown('right')) mx += 1; if (isDown('up')) my -= 1; if (isDown('down')) my += 1;
  return { mx: mx, my: my, run: isDown('run'), aim: m.right && !open, aimX: m.x + REN.cx0, aimY: m.y + REN.cy0, fire: m.left && !open, interactHeld: isDown('use') && !UI.elevOpen && !open };
}
function togglePause() {
  if (UI.mode !== 'play' || UI.w.over || UI.endShown || MODAL.kind) return;
  if (UI.tabOpen) toggleTab(false);
  UI.paused = !UI.paused; $('pause').hidden = !UI.paused; if (UI.paused) $('stage').classList.remove('aiming');
}
function quickLabel() { var c = UI.cfg; return (c.role === 'hunter' ? 'Cazador' : (c.role === 'runner' ? 'Corredor' : 'Observar')) + ' · ' + c.hunters + ' vs ' + c.runners + ' · ' + c.minutes + ' min'; }
function titleAct(a) {
  sfx('click');
  if (a === 'play') goLobby(); else if (a === 'quick') startGame();
  else if (a === 'how') openModal('how'); else if (a === 'settings') openModal('settings'); else if (a === 'credits') openModal('credits');
}
function onKeyDown(ev) {
  var k = ev.code;
  if (MODAL.capture) {
    ev.preventDefault();
    if (k !== 'Escape') { var a = MODAL.capture, other = actionOf(k); if (other && other !== a) SET.binds[other] = SET.binds[a]; SET.binds[a] = k; saveSettings(); refreshCtrl(); }
    MODAL.capture = null; renderModal(); return;
  }
  if (MODAL.kind) { if (k === 'Escape') { ev.preventDefault(); closeModal(); } return; }
  if (UI.mode === 'title') {
    var btns = Array.prototype.slice.call($('tmenu').querySelectorAll('.tb')), i = btns.indexOf(document.activeElement);
    if (k === 'ArrowDown' || k === 'ArrowUp') { ev.preventDefault(); btns[(i + (k === 'ArrowDown' ? 1 : -1) + btns.length) % btns.length].focus(); }
    return;
  }
  if (UI.mode === 'menu') { if (k === 'Enter') startGame(); else if (k === 'Escape') toTitle(); return; }
  var act = actionOf(k);
  if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Space', 'Tab'].indexOf(k) >= 0 || act) ev.preventDefault();
  UI.keys[k] = true;
  if (UI.ac && UI.ac.state === 'suspended') UI.ac.resume();
  var w = UI.w, h = w.human, spec = !(h && h.alive);
  if (act === 'pause') togglePause();
  else if (act === 'mute') { SET.muted = !SET.muted; saveSettings(); }
  else if (act === 'full') toggleFull();
  else if (act === 'map') { if (!ev.repeat) toggleTab(); }
  else if (k === 'Escape') { if (UI.elevOpen) closeElev(); else if (UI.tabOpen) toggleTab(false); else togglePause(); }
  else if (spec && (act === 'left' || k === 'ArrowLeft')) cycleFollow(-1);
  else if (spec && (act === 'right' || k === 'ArrowRight')) cycleFollow(1);
  else if (act === 'use' && !ev.repeat && h && h.alive && !UI.paused && !UI.tabOpen && w.hint && w.hint.type === 'elev' && !UI.elevPend) openElev();
  else if (UI.elevOpen && /^Digit[1-7]$/.test(k)) chooseElev(+k.slice(5) - 1);
}
function bindInput() {
  window.addEventListener('keydown', onKeyDown);
  window.addEventListener('keyup', function (ev) { delete UI.keys[ev.code]; });
  window.addEventListener('blur', function () { UI.keys = {}; UI.mouse.left = UI.mouse.right = false; });
  window.addEventListener('resize', function () { resizeTitle(); resizeCanvas(); });
  document.addEventListener('fullscreenchange', function () { if (!document.fullscreenElement && SET.layout === 'full') setLayout(UI.prevLayout === 'full' ? 'normal' : UI.prevLayout); });
  if (window.ResizeObserver) new ResizeObserver(function () { resizeCanvas(); }).observe($('stage'));
  var st = $('stage');
  function pos(ev) { var r = cv.getBoundingClientRect(); UI.mouse.x = (ev.clientX - r.left) * VW / r.width; UI.mouse.y = (ev.clientY - r.top) * VH / r.height; }
  cv.addEventListener('mousemove', function (ev) { pos(ev); UI.mouse.inside = true; });
  cv.addEventListener('mouseleave', function () { UI.mouse.inside = false; });
  cv.addEventListener('mousedown', function (ev) { pos(ev); if (UI.ac && UI.ac.state === 'suspended') UI.ac.resume(); if (ev.button === 0) UI.mouse.left = true; if (ev.button === 2) UI.mouse.right = true; ev.preventDefault(); });
  window.addEventListener('mouseup', function (ev) { if (ev.button === 0) UI.mouse.left = false; if (ev.button === 2) UI.mouse.right = false; });
  st.addEventListener('contextmenu', function (ev) { ev.preventDefault(); });
  /* portada y lobby */
  Array.prototype.forEach.call(document.querySelectorAll('#tmenu .tb'), function (b) { b.onclick = function () { titleAct(b.dataset.act); }; });
  Array.prototype.forEach.call(document.querySelectorAll('#roles .rolecard'), function (b) { b.onclick = function () { UI.cfg.role = b.dataset.role; syncMenu(); sfx('click'); }; });
  Array.prototype.forEach.call(document.querySelectorAll('.seg[data-opt]'), function (s) { Array.prototype.forEach.call(s.children, function (b) { b.onclick = function () { UI.cfg[s.dataset.opt] = +b.dataset.v; syncMenu(); sfx('click'); }; }); });
  $('optDebug').onchange = function () { UI.cfg.debug = this.checked; syncMenu(); };
  $('btnStart').onclick = startGame; $('btnBack').onclick = function () { sfx('click'); toTitle(); };
  $('btnAgain').onclick = startGame; $('btnMenu').onclick = toTitle; $('btnPauseMenu').onclick = toTitle;
  $('btnResume').onclick = togglePause; $('btnPauseSet').onclick = function () { openModal('settings'); };
  $('btnElevClose').onclick = closeElev;
  $('btnPrev').onclick = function () { cycleFollow(-1); }; $('btnNext').onclick = function () { cycleFollow(1); };
  Array.prototype.forEach.call(document.querySelectorAll('#specbar [data-speed]'), function (b) { b.onclick = function () { UI.speed = +b.dataset.speed; }; });
  $('btnTab').onclick = function () { toggleTab(); }; $('btnSet').onclick = function () { openModal('settings'); }; $('btnFull').onclick = toggleFull;
  $('btnHome').onclick = function () { if (UI.mode === 'play' && !UI.w.over && !UI.endShown) togglePause(); else toTitle(); };
  $('mClose').onclick = closeModal;
  $('modal').addEventListener('mousedown', function (ev) { if (ev.target === $('modal')) closeModal(); });
}
function syncMenu() {
  var c = UI.cfg;
  Array.prototype.forEach.call(document.querySelectorAll('#roles .rolecard'), function (b) { b.classList.toggle('on', b.dataset.role === c.role); });
  Array.prototype.forEach.call(document.querySelectorAll('.seg[data-opt]'), function (s) { Array.prototype.forEach.call(s.children, function (b) { b.classList.toggle('on', +b.dataset.v === c[s.dataset.opt]); }); });
  $('quickSub').textContent = quickLabel();
  try { localStorage.setItem('caza-cfg', JSON.stringify(c)); } catch (e) { /* sin almacenamiento */ }
}

/* ---------- bucle ---------- */
function mouseState(view, w) {
  var m = UI.mouse, hm = w.human, aiming = !!(hm && hm.alive && hm.role === 'hunter' && m.right && m.inside && !hm.hold && !UI.paused && !UI.tabOpen && !w.over);
  var on = false;
  if (aiming) {
    var wx = m.x + REN.cx0, wy = m.y + REN.cy0;
    w.ents.forEach(function (e) { if (e !== hm && e.alive && e.floor === hm.floor && e.role !== 'police' && Math.hypot(e.x - wx, e.y - 2 - wy) < 20 && Math.hypot(e.x - hm.x, e.y - hm.y) <= CFG.killRange * TS && los(FLOORS[hm.floor], hm.x, hm.y, e.x, e.y)) on = true; });
  }
  $('stage').classList.toggle('aiming', aiming);
  return { x: m.x, y: m.y, aiming: aiming, onTarget: on };
}
function tick(dt) {
  var w = UI.w;
  if (UI.mode === 'menu') {
    UI.demoT -= dt; step(w, Math.min(dt, 0.05), null); if (w.over) newDemo();
  } else if (UI.mode === 'play' && !UI.paused && !w.over) {
    var h = w.human, spec = !(h && h.alive);
    if (!spec) UI.speed = 1;
    UI.acc += dt * UI.speed;
    var n = 0, inp = (h && h.alive) ? readInput() : null, cdBefore = h ? h.cd : 0;
    while (UI.acc >= STEP && n < 24) {
      if (UI.elevPend) { UI.elevPend.t -= STEP; if (UI.elevPend.t <= 0) { var hh = w.human; if (hh && hh.alive) { cancelHold(w, hh); teleport(w, hh, UI.elevPend.fl); } UI.elevPend = null; $('fade').classList.remove('on'); } }
      step(w, STEP, inp); UI.acc -= STEP; n++; if (w.over) break;
    }
    if (UI.acc > STEP * 3) UI.acc = 0;
    if (h && h.alive && h.cd > cdBefore + 0.3 && h.role === 'hunter') sfx('shot');
  }
  pumpLogs(w);
  if (w.over && !UI.endShown && UI.mode === 'play') { UI.endShown = true; toggleTab(false); updateHud(true); showEnd(); }
}
function showEnd() {
  var w = UI.w, o = w.over, hm = w.human, role = hm ? hm.role : null;
  var won = hm ? ((o.winner === 'hunters') === (role === 'hunter')) : null;
  var t = $('endTitle');
  if (hm) { t.textContent = won ? 'Victoria' : 'Derrota'; t.className = won ? 'win' : 'lose'; }
  else { t.textContent = o.winner === 'hunters' ? 'Ganan los cazadores' : 'Ganan los corredores'; t.className = ''; }
  $('endReason').textContent = o.reason;
  var names = w.targets.map(function (id) { var n = ''; w.ents.forEach(function (e) { if (e.id === id) n = e.name; }); return n; }).join(' y ');
  $('endStats').innerHTML = [['Duración', fmt(w.time)], ['Objetivos', names], ['Bajas', w.stats.kills], ['Civiles muertos', w.stats.civKills], ['Llamadas a la policía', w.stats.calls], ['Tareas cerradas', w.tasksDone + ' / ' + w.quota]].map(function (r) { return '<div><span>' + r[0] + '</span><b>' + r[1] + '</b></div>'; }).join('');
  $('end').hidden = false; $('specbar').hidden = true; $('stage').classList.remove('aiming');
  sfx(won === false ? 'alarm' : 'task');
}
function frame(now) {
  var dt = Math.min(0.05, (now - UI.last) / 1000 || 0.016); UI.last = now; UI.anim += dt;
  try {
    if (UI.mode === 'title') drawTitle(dt);
    else {
      tick(dt);
      var w = UI.w, view = viewEnt(), play = UI.mode === 'play', hm = w.human, dbg = !play || !!w.opt.debug;
      UI.exT -= dt; if (UI.exT <= 0) { UI.exT = 0.12; updateExplored(view); }
      drawWorld(g, w, view, UI.anim, play ? mouseState(view, w) : null, { debug: dbg, markers: play ? worldMarkers(w, hm, view) : null });
      UI.hudT -= dt;
      if (play && UI.hudT <= 0) { UI.hudT = 0.12; updateHud(false); drawMini(mg, w, view, !!w.opt.debug, taskMarks(w, hm, view.floor)); }
      if (UI.tabOpen) { UI.tabT -= dt; if (UI.tabT <= 0) { UI.tabT = 0.25; renderTab(); } }
    }
  } catch (err) { showErr(err); console.error(err); }
  requestAnimationFrame(frame);
}
function init() {
  cv = $('cv'); g = cv.getContext('2d'); mini = $('mini'); mg = mini.getContext('2d'); bigc = $('bigmap'); bg = bigc.getContext('2d');
  loadSettings();
  try { var sv = JSON.parse(localStorage.getItem('caza-cfg') || 'null'); if (sv) for (var k in UI.cfg) if (sv[k] !== undefined && typeof sv[k] === typeof UI.cfg[k]) UI.cfg[k] = sv[k]; } catch (e) { /* sin almacenamiento */ }
  $('optDebug').checked = UI.cfg.debug;
  initTextures(); initTitle(); buildElev(); bindInput(); syncMenu(); refreshCtrl(); applyLayout();
  UI.prevLayout = SET.layout === 'full' ? 'normal' : SET.layout;
  newDemo(); setMode('title');
  requestAnimationFrame(frame);
}
init();
