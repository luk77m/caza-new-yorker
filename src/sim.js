/* ===== simulación: reglas, IA y estado (sin DOM; lista para moverla a un servidor) ===== */
var HUNTER_NAMES = ['Agente Cole', 'Agente Dunn'], RUNNER_NAMES = ['Vinnie', 'Sal', 'Mickey', 'Lou'];
var NPC_SPECS = [
  { f: 0, staff: 'tech', home: { room: 'Sala de calderas' } }, { f: 0, staff: 'maid', home: { room: 'Lavandería' } }, { f: 0, staff: 'chef', home: { room: 'Cocina de servicio' } }, { f: 0, staff: 'tech', home: { room: 'Sala eléctrica' } },
  { f: 1, staff: 'recep', home: 'fixed', at: { x: 22, y: 12 } }, { f: 1, staff: 'bell', home: 'pub' }, { f: 1, staff: 'bell', home: 'pub' }, { f: 1, home: 'pub' }, { f: 1, home: 'pub' }, { f: 1, home: 'pub' },
  { f: 2, staff: 'waiter', home: { room: 'Restaurante Terrace' } }, { f: 2, staff: 'waiter', home: { room: 'Gran Salón' } }, { f: 2, staff: 'waiter', home: 'fixed', at: { x: 32, y: 7 } }, { f: 2, home: 'pub' }, { f: 2, home: 'pub' }, { f: 2, home: 'pub' },
  { f: 3, staff: 'maid', home: 'rooms' }, { f: 3, home: 'pub' }, { f: 3, home: 'roomOne' },
  { f: 4, staff: 'maid', home: 'rooms' }, { f: 4, home: 'pub' }, { f: 4, home: 'roomOne' },
  { f: 5, home: 'pub' }, { f: 5, home: 'pub' }
];

function newEnt(w, o) {
  var e = { id: w.nextId++, name: '', type: 'npc', role: 'civil', floor: 1, x: 0, y: 0, dir: 'down', walk: 0, moving: false, alive: true, outfit: null, aim: false, aimX: 0, aimY: 0, aimAng: 0, cd: 0,
    sus: 0, inv: { masterkey: false, badge: false, scrap: 0, melee: false, carry: null }, hold: null, bubble: null, bt: 0, path: null, pathKey: null, pi: 0, goal: null,
    ai: { mode: 'idle', t: rnd() * 3, scan: rnd() * 0.3 }, state: 'idle', stairCd: 0, knows: {}, spot: {}, restricted: false, wasRestricted: false, elevT: 0 };
  for (var k in o) e[k] = o[k];
  return e;
}
function say(e, t, d) { e.bubble = t; e.bt = d || 2.4; }
function wlog(w, msg, kind) { w.logs.push({ id: ++w.logId, t: w.time, msg: msg, kind: kind || 'info' }); }
function tileOf(e) { return { x: Math.floor(e.x / TS), y: Math.floor(e.y / TS) }; }

function newWorld(opt) {
  seed(opt.seed || (Date.now() & 0xffffff));
  OID = 0; USED_OUTFITS = {};
  var w = { time: 0, limit: opt.minutes * 60, ents: [], corpses: [], pick: [], dispatch: [], wanted: {}, posters: [], posterActive: {}, logs: [], logId: 0, over: null, tasksDone: 0,
    nextId: 1, human: null, opt: opt, tasks: TASK_DEFS.map(function (t) { var c = {}; for (var k in t) c[k] = t[k]; c.cool = 0; c.busy = 0; return c; }),
    fx: [], acc: 0, acc2: 0, hint: null, targets: [], stats: { kills: 0, civKills: 0, calls: 0, tasks: 0 } };
  w.wards = []; FLOORS.forEach(function (f) { f.wards.forEach(function (x) { x.looted = false; }); });
  var nH = clamp(opt.hunters, 1, 2), nR = clamp(opt.runners, 2, 4);
  w.quota = Math.round((CFG.quotaBase + CFG.quotaPerRunner * nR) * (opt.minutes / 12));
  var i, e;
  var hSpawn = [{ x: 21, y: 24 }, { x: 23, y: 24 }];
  for (i = 0; i < nH; i++) {
    var isH = (opt.role === 'hunter' && i === 0);
    e = newEnt(w, { name: HUNTER_NAMES[i], type: isH ? 'human' : 'bot', role: 'hunter', floor: 1, x: (hSpawn[i].x + .5) * TS, y: (hSpawn[i].y + .5) * TS, outfit: newGuest(false), dir: 'up' });
    e.ai = { mode: 'patrol', scan: 0, wait: ri(12, 22), t: 0, patience: 0, aimT: 0, rec: 0 };
    if (isH) w.human = e;
    w.ents.push(e);
  }
  var rSpawn = shuffle([{ f: 2, x: 30, y: 15 }, { f: 2, x: 12, y: 15 }, { f: 3, x: 30, y: 14 }, { f: 3, x: 12, y: 15 }, { f: 4, x: 14, y: 15 }, { f: 5, x: 20, y: 19 }]);
  var runners = [];
  for (i = 0; i < nR; i++) {
    var isR = (opt.role === 'runner' && i === 0), sp = rSpawn[i];
    e = newEnt(w, { name: RUNNER_NAMES[i], type: isR ? 'human' : 'bot', role: 'runner', floor: sp.f, x: (sp.x + .5) * TS, y: (sp.y + .5) * TS, outfit: newGuest(rnd() < 0.2) });
    e.ai = { mode: 'blend', scan: 0, t: ri(8, 22), wait: 0 };
    if (isR) w.human = e;
    w.ents.push(e); runners.push(e);
  }
  shuffle(runners);
  w.targets = runners.slice(0, 2).map(function (r) { return r.id; });
  w.ents.forEach(function (x) { if (x.role === 'hunter') x.targetIds = w.targets.slice(); });
  /* PNJ */
  NPC_SPECS.forEach(function (sp) {
    var f = FLOORS[sp.f], tiles;
    if (sp.home === 'pub') tiles = f.tilesPub;
    else if (sp.home === 'rooms') { tiles = []; f.rooms.forEach(function (r) { if (r.zone === ZONE_ROOM) tiles = tiles.concat(f.roomTiles[r.name]); }); tiles = tiles.concat(f.tilesPub); }
    else if (sp.home === 'roomOne') { var rr = f.rooms.filter(function (r) { return r.zone === ZONE_ROOM && r.name !== 'Despacho del gerente'; }); tiles = f.roomTiles[pick(rr).name]; }
    else if (sp.home === 'fixed') tiles = [sp.at];
    else tiles = f.roomTiles[sp.home.room];
    var t0 = sp.home === 'fixed' ? sp.at : pick(tiles);
    var o = sp.staff ? newStaff(sp.staff) : newGuest(rnd() < 0.4);
    var n = newEnt(w, { name: sp.staff ? STAFF[sp.staff].label : (o.kind === 'dress' ? 'Huésped' : 'Huésped'), type: 'npc', role: 'civil', floor: sp.f, x: (t0.x + .5) * TS, y: (t0.y + .5) * TS, outfit: o });
    n.staff = !!sp.staff; n.tiles = tiles; n.fixed = sp.home === 'fixed'; n.ai = { mode: 'idle', wait: rnd() * 4 };
    w.ents.push(n);
  });
  /* objetos */
  var pid = 0;
  var mk1 = pick(KEY_SPOTS.masterkey), bd = pick(KEY_SPOTS.badge);
  w.pick.push({ id: ++pid, kind: 'masterkey', floor: mk1.f, x: mk1.x, y: mk1.y, name: 'llave maestra' });
  w.pick.push({ id: ++pid, kind: 'badge', floor: bd.f, x: bd.x, y: bd.y, name: 'insignia de botones' });
  shuffle(SCRAP_SPOTS.slice()).slice(0, 8).forEach(function (s) { w.pick.push({ id: ++pid, kind: 'scrap', floor: s.f, x: s.x, y: s.y, name: pick(SCRAP_NAMES) }); });
  wlog(w, opt.role === 'hunter' ? 'Tu cartel tiene dos rostros. Encuéntralos y elimínalos sin que nadie lo vea.' : 'Completa el trato antes de que llegue el cliente. Hay cazadores entre los huéspedes.', 'info');
  return w;
}

/* ---------- utilidades de reglas ---------- */
function isHunter(e) { return e.role === 'hunter'; }
function access(e) {
  if (e.role === 'runner' || e.role === 'police') return { room: true, staff: true };
  if (e.outfit.staffRole) return { room: true, staff: true };
  return { room: !!e.inv.masterkey, staff: !!e.inv.badge };
}
function callersFor(w, oid) {
  for (var i = 0; i < w.ents.length; i++) { var c = w.ents[i]; if (c.alive && c.role === 'civil' && (c.state === 'call' || c.state === 'calling') && c.callCtx && c.callCtx.outfit === oid) return true; }
  return false;
}
function isHot(w, h) { return !!(w.wanted[h.outfit.id] || callersFor(w, h.outfit.id)); }
function civilsSeeing(w, a, b, rad) {
  var out = [];
  for (var i = 0; i < w.ents.length; i++) {
    var c = w.ents[i];
    if (!c.alive || c.role !== 'civil' || c.floor !== a.floor) continue;
    var f = FLOORS[a.floor];
    if ((dist(c.x, c.y, a.x, a.y) <= rad && los(f, c.x, c.y, a.x, a.y)) || (b && dist(c.x, c.y, b.x, b.y) <= rad && los(f, c.x, c.y, b.x, b.y))) out.push(c);
  }
  return out;
}
function alertNpc(w, npc, culpritId, why, fl, tx, ty) {
  if (!npc.alive || npc.state === 'call' || npc.state === 'calling' || npc.state === 'stun') return;
  npc.state = 'call'; npc.callCtx = { outfit: culpritId, floor: fl, x: tx, y: ty, why: why }; npc.goal = null; npc.pathKey = null; npc.ai.mode = 'call';
  say(npc, why === 'crime' ? '¡Un crimen! ¡Voy a llamar a la policía!' : (why === 'body' ? '¡Un cadáver! ¡Policía!' : '¡Esto no me gusta! Llamo a la policía.'), 3);
}
function policeCall(w, ctx) {
  w.stats.calls++;
  if (ctx.outfit) w.wanted[ctx.outfit] = true;
  wlog(w, 'Un testigo ha llamado a la policía.', 'call');
  var active = w.ents.filter(function (p) { return p.role === 'police' && p.alive; });
  if (active.length) active.forEach(function (p) { p.target = { floor: ctx.floor, x: ctx.x, y: ctx.y }; p.ai.mode = 'go'; p.goal = null; p.stayUntil = w.time + CFG.policeStay; });
  else if (!w.dispatch.some(function (d) { return !d.done; })) w.dispatch.push({ t: w.time + CFG.policeDelay, floor: ctx.floor, x: ctx.x, y: ctx.y, done: false });
}
function spawnPolice(w, d) {
  var sp = [{ x: 21, y: 24 }, { x: 23, y: 24 }, { x: 22, y: 23 }];
  for (var i = 0; i < CFG.policeCount; i++) {
    var p = newEnt(w, { name: 'Policía', type: 'police', role: 'police', floor: 1, x: (sp[i].x + .5) * TS, y: (sp[i].y + .5) * TS, outfit: newPolice(), dir: 'up' });
    p.target = { floor: d.floor, x: d.x, y: d.y }; p.ai = { mode: 'go', t: 0 }; p.stayUntil = w.time + CFG.policeStay;
    w.ents.push(p);
  }
  wlog(w, 'La policía ha llegado al hotel.', 'alarm');
}

/* ---------- acciones ---------- */
function teleport(w, e, fl) {
  var f = FLOORS[fl]; e.floor = fl; e.x = (f.spawn.x + .5) * TS; e.y = (f.spawn.y + .5) * TS;
  e.path = null; e.pathKey = null; e.moving = false; e.stairCd = 0.6; e.goal = null;
}
function useStairs(w, e, dir) {
  var nf = e.floor + dir, f = FLOORS[nf];
  if (!f) return;
  e.floor = nf;
  if (dir > 0) { e.x = (f.down.x - 0.5) * TS; e.y = (f.down.y + 0.5) * TS; } else { e.x = (f.up.x + 1.5) * TS; e.y = (f.up.y + 0.5) * TS; }
  e.stairCd = 0.7; e.path = null; e.pathKey = null;
}
function swapOutfit(w, e, o) {
  e.outfit = o;
  if (e.role === 'hunter') e.sus = Math.min(e.sus, 30);
  e.path = null;
}
function kill(w, killer, victim, how) {
  if (!victim.alive) return;
  victim.alive = false; victim.state = 'dead'; victim.moving = false; victim.aim = false;
  if (victim.hold) cancelHold(w, victim);
  w.corpses.push({ id: w.nextId++, x: victim.x, y: victim.y, floor: victim.floor, outfit: victim.outfit, stripped: false, found: false, name: victim.name, role: victim.role, t: w.time, victimId: victim.id, ang: (victim.id * 1.7) % 6.28 });
  if (victim.role === 'civil') w.stats.civKills++; else w.stats.kills++;
  if (how === 'gun') {
    var wit = civilsSeeing(w, killer, victim, CFG.witnessRadius * TS).filter(function (c) { return c !== victim; });
    if (wit.length) {
      killer.sus = 100;
      wit.forEach(function (c) { alertNpc(w, c, killer.outfit.id, 'crime', killer.floor, Math.floor(killer.x / TS), Math.floor(killer.y / TS)); });
    }
    w.ents.forEach(function (r) {
      if (r.role === 'runner' && r.alive && r.type === 'bot' && r.floor === killer.floor && dist(r.x, r.y, killer.x, killer.y) < CFG.witnessRadius * TS && los(FLOORS[r.floor], r.x, r.y, killer.x, killer.y)) r.knows[killer.outfit.id] = true;
    });
  }
  if (how === 'police') { w.fx.push({ type: 'flash', floor: killer.floor, x: killer.x, y: killer.y, t: 0.25 }); wlog(w, victim.role === 'hunter' ? 'La policía abate a un sospechoso.' : 'La policía abate a ' + victim.name + '.', 'alarm'); }
  else if (victim.role === 'hunter') wlog(w, victim.name + ' ha caído.', 'hunt');
  else if (victim.role === 'runner') wlog(w, victim.name + ' ha sido eliminado.', 'info');
  checkWin(w);
}
function tryShoot(w, e) {
  if (e.cd > 0) return false;
  e.cd = CFG.fireCd;
  var best = null, bd = 20;
  for (var i = 0; i < w.ents.length; i++) {
    var v = w.ents[i];
    if (v === e || !v.alive || v.floor !== e.floor || v.role === 'police') continue;
    var d = dist(v.x, v.y - 2, e.aimX, e.aimY);
    if (d < bd && dist(e.x, e.y, v.x, v.y) <= CFG.killRange * TS && los(FLOORS[e.floor], e.x, e.y, v.x, v.y)) { bd = d; best = v; }
  }
  if (best) { kill(w, e, best, 'gun'); return true; }
  return false;
}
function tryMelee(w, e) {
  if (e.cd > 0 || !e.inv.melee) return;
  e.cd = CFG.meleeCd;
  var ax = e.aimX - e.x, ay = e.aimY - e.y, al = Math.hypot(ax, ay) || 1;
  e.fxSwing = 0.2;
  for (var i = 0; i < w.ents.length; i++) {
    var v = w.ents[i];
    if (v === e || !v.alive || v.floor !== e.floor || v.role === 'police' || v.role === 'runner') continue;
    var dx = v.x - e.x, dy = v.y - e.y, d = Math.hypot(dx, dy);
    if (d > CFG.meleeRange || (dx * ax + dy * ay) / (d * al + 0.001) < 0.2) continue;
    if (v.role === 'hunter') { kill(w, e, v, 'melee'); return; }
    alertNpc(w, v, null, 'sospecha', e.floor, Math.floor(e.x / TS), Math.floor(e.y / TS));
    if (v.state === 'call') { v.state = 'stun'; v.ai.stun = 2.2; v.goal = null; say(v, '¡Eh! ¿Qué hace?', 2); }
    return;
  }
}
function taskAvail(w, t, e) {
  if (t.cool > w.time) return false;
  if (t.busy && t.busy !== e.id) { var b = w.ents[t.busy - 1]; for (var i = 0; i < w.ents.length; i++) if (w.ents[i].id === t.busy) b = w.ents[i]; if (b && b.alive && b.hold && b.hold.ref === t) return false; t.busy = 0; }
  if (t.kind === 'drop') return e.inv.carry === t.id;
  if (t.kind === 'pick') return !e.inv.carry;
  return true;
}
function startHold(w, e, type, ref, dur) {
  e.hold = { type: type, ref: ref, t: 0, dur: dur };
  if (type === 'task') ref.busy = e.id;
  e.moving = false; e.aim = false;
}
function cancelHold(w, e) {
  if (e.hold && e.hold.type === 'task' && e.hold.ref.busy === e.id) e.hold.ref.busy = 0;
  e.hold = null;
}
function holdValid(w, e, h) {
  if (h.type === 'strip') return !h.ref.stripped && h.ref.outfit.kind !== 'under';
  if (h.type === 'ward') return !h.ref.looted;
  if (h.type === 'task') return taskAvail(w, h.ref, e) || h.ref.busy === e.id;
  return true;
}
function finishHold(w, e, h) {
  var human = e === w.human;
  if (h.type === 'task') {
    var t = h.ref;
    t.cool = w.time + CFG.taskCooldown;
    if (t.kind === 'pick') { e.inv.carry = t.pair; if (human) wlog(w, 'Llevas el encargo. Entrégalo: ' + w.tasks.filter(function (x) { return x.id === t.pair; })[0].name + '.', 'info'); }
    else { if (t.kind === 'drop') e.inv.carry = null; w.tasksDone++; w.stats.tasks++; wlog(w, (human ? 'Hecho: ' : e.name + ' completa: ') + t.name + '. Trato: ' + w.tasksDone + '/' + w.quota, 'task'); }
    if (e.type === 'bot') { e.ai.mode = 'blend'; e.ai.t = ri(CFG.botIdle[0], CFG.botIdle[1]); e.goal = null; }
    checkWin(w);
  } else if (h.type === 'strip') {
    var c = h.ref, o = cloneOutfit(c.outfit);
    o.blood = true; swapOutfit(w, e, o);
    c.outfit = newUnder(o.skin, o.hair, o); c.stripped = true;
    if (human) wlog(w, 'Llevas su ropa, pero está manchada de sangre. Lávala antes de que alguien lo note.', 'info');
  } else if (h.type === 'ward') {
    h.ref.looted = true;
    var no = rnd() < 0.5 ? newGuest(rnd() < 0.3) : newStaff(pick(['bell', 'tech', 'waiter', 'maid', 'chef']));
    swapOutfit(w, e, no);
    if (human) wlog(w, 'Te has cambiado de ropa: ' + describeOutfit(no) + '.', 'info');
  } else if (h.type === 'wash') {
    e.outfit.blood = false;
    if (human) wlog(w, 'El traje está limpio.', 'info');
  }
  if (e.type === 'bot' && e.role === 'hunter') { e.ai.mode = 'patrol'; e.goal = null; }
}
function holdUpdate(w, e, dt) {
  var h = e.hold; if (!h) return;
  if (!holdValid(w, e, h)) { cancelHold(w, e); return; }
  h.t += dt;
  if (h.t >= h.dur) { var hh = h; e.hold = null; if (hh.type === 'task' && hh.ref.busy === e.id) hh.ref.busy = 0; finishHold(w, e, hh); }
}
function checkWin(w) {
  if (w.over) return;
  var tA = 0, hA = 0;
  w.ents.forEach(function (e) { if (e.alive && w.targets.indexOf(e.id) >= 0) tA++; if (e.alive && e.role === 'hunter') hA++; });
  if (tA === 0) w.over = { winner: 'hunters', reason: 'Los dos objetivos han sido eliminados.' };
  else if (hA === 0) w.over = { winner: 'runners', reason: 'Todos los cazadores han caído.' };
  else if (w.tasksDone >= w.quota) w.over = { winner: 'runners', reason: 'Trato cerrado: el cargamento está listo antes de que llegue el cliente.' };
  else if (w.time >= w.limit) w.over = { winner: 'runners', reason: 'El cliente ha llegado y al menos un objetivo sigue con vida.' };
}

/* ---------- movimiento ---------- */
function solidPx(f, px, py) { var tx = Math.floor(px / TS), ty = Math.floor(py / TS); if (SOLIDT[at(f, tx, ty)]) return true; return !!f.blk[ty * W + tx]; }
function freeAt(f, x, y) { var r = 9; return !solidPx(f, x - r, y - r) && !solidPx(f, x + r, y - r) && !solidPx(f, x - r, y + r) && !solidPx(f, x + r, y + r); }
function dirOf(dx, dy) { return Math.abs(dx) > Math.abs(dy) ? (dx < 0 ? 'left' : 'right') : (dy < 0 ? 'up' : 'down'); }
function navTo(w, e, fl, x, y) { e.goal = { floor: fl, x: x, y: y }; e.pathKey = null; e.path = null; e.unreach = false; }
function walkTo(w, e, dt, speed, tx, ty) {
  var key = e.floor + ':' + tx + ',' + ty;
  if (e.pathKey !== key || !e.path) {
    e.path = bfs(FLOORS[e.floor], Math.floor(e.x / TS), Math.floor(e.y / TS), tx, ty); e.pathKey = key; e.pi = 0;
    if (!e.path) { e.path = []; e.unreach = true; return true; }
    e.unreach = false;
  }
  if (e.pi >= e.path.length) { e.moving = false; return true; }
  var n = e.path[e.pi], nx = (n.x + .5) * TS, ny = (n.y + .5) * TS, dx = nx - e.x, dy = ny - e.y, d = Math.hypot(dx, dy);
  if (d < 3) { e.pi++; return e.pi >= e.path.length; }
  var st = Math.min(d, speed * dt); e.x += dx / d * st; e.y += dy / d * st; e.moving = true; e.walk += dt * 9; e.dir = dirOf(dx, dy);
  return false;
}
function navUpdate(w, e, dt, speed) {
  var g = e.goal; if (!g) return true;
  var f = FLOORS[e.floor];
  if (e.floor !== g.floor) {
    var fx = f.spawn.x, fy = f.spawn.y - 1;
    if (Math.abs(e.x - (fx + .5) * TS) < 14 && Math.abs(e.y - (fy + .5) * TS) < 14) {
      e.moving = false; e.elevT += dt;
      if (e.elevT >= 1.1) { e.elevT = 0; teleport(w, e, g.floor); e.goal = g; }
    } else { e.elevT = 0; walkTo(w, e, dt, speed, fx, fy); if (e.unreach) return true; }
    return false;
  }
  var done = walkTo(w, e, dt, speed, g.x, g.y);
  return done;
}

/* ---------- IA: civiles ---------- */
function npcAI(w, e, dt) {
  var ai = e.ai;
  if (e.state === 'stun') { ai.stun -= dt; e.moving = false; if (ai.stun <= 0) e.state = 'call'; return; }
  if (e.state === 'call') {
    var ph = FLOORS[e.floor].phone;
    if (!e.goal) navTo(w, e, e.floor, ph.x, ph.y);
    if (navUpdate(w, e, dt, CFG.speed.npc * 1.8)) { e.state = 'calling'; ai.t = 2.4; e.moving = false; say(e, '¡Operadora! ¡Policía, por favor!', 2.4); }
    return;
  }
  if (e.state === 'calling') { ai.t -= dt; e.moving = false; if (ai.t <= 0) { policeCall(w, e.callCtx); e.state = 'scared'; ai.t = 12; e.goal = null; } return; }
  if (e.state === 'scared') { ai.t -= dt; e.moving = false; if (ai.t <= 0) { e.state = 'idle'; ai.wait = 1; } return; }
  if (e.fixed) { ai.wait -= dt; if (ai.wait <= 0) { ai.wait = ri(3, 7); e.dir = pick(['down', 'left', 'right', 'down']); } e.moving = false; return; }
  if (ai.wait > 0) { ai.wait -= dt; e.moving = false; return; }
  if (!e.goal) { var t = pick(e.tiles); navTo(w, e, e.floor, t.x, t.y); }
  if (navUpdate(w, e, dt, CFG.speed.npc)) { e.goal = null; e.moving = false; ai.wait = ri(2, 8); }
}

/* ---------- IA: policía ---------- */
function policeAI(w, e, dt) {
  var ai = e.ai;
  if (e.freeze) { e.moving = false; return; }
  if (ai.mode === 'go') {
    if (!e.goal) navTo(w, e, e.target.floor, e.target.x, e.target.y);
    if (navUpdate(w, e, dt, CFG.speed.police)) { ai.mode = 'search'; ai.t = 0; e.goal = null; }
  } else if (ai.mode === 'search') {
    ai.t -= dt;
    if (!e.goal || ai.t <= 0) {
      var f = FLOORS[e.floor], tiles = f.tilesPub, c = null;
      for (var k = 0; k < 8 && !c; k++) { var t = pick(tiles); if (e.floor !== e.target.floor || dist(t.x, t.y, e.target.x, e.target.y) < 12) c = t; }
      c = c || pick(tiles); navTo(w, e, e.floor, c.x, c.y); ai.t = ri(5, 9);
    }
    if (navUpdate(w, e, dt, CFG.speed.police * 0.7)) { e.goal = null; ai.t = Math.min(ai.t, 1.5); }
    if (w.time > e.stayUntil) { ai.mode = 'leave'; navTo(w, e, 1, 22, 24); }
  } else if (ai.mode === 'leave') {
    if (navUpdate(w, e, dt, CFG.speed.police)) { e.alive = false; e.remove = true; }
  }
}

/* ---------- IA: corredores bot ---------- */
function posterKnown(w, h) { return !!w.posterActive[h.outfit.id]; }
function chooseTask(w, e) {
  var best = null, bs = 1e9;
  w.tasks.forEach(function (t) {
    if (!taskAvail(w, t, e)) return;
    var s = Math.abs(t.floor - e.floor) * 22 + Math.abs(t.x - e.x / TS) + Math.abs(t.y - e.y / TS) + rnd() * 30;
    if (e.inv.carry && t.id === e.inv.carry) s -= 200;
    if (s < bs) { bs = s; best = t; }
  });
  return best;
}
function runnerAI(w, e, dt) {
  var ai = e.ai, i;
  e.cd = Math.max(0, e.cd - dt);
  if (e.fxSwing > 0) e.fxSwing -= dt;
  ai.scan -= dt;
  if (ai.scan <= 0) {
    ai.scan = 0.3;
    for (i = 0; i < w.ents.length; i++) {
      var h = w.ents[i];
      if (h.role !== 'hunter' || !h.alive || h.floor !== e.floor) continue;
      var d = dist(e.x, e.y, h.x, h.y);
      if (d > 6 * TS || !los(FLOORS[e.floor], e.x, e.y, h.x, h.y)) continue;
      var danger = h.aim || e.knows[h.outfit.id] || posterKnown(w, h);
      if (!danger) continue;
      if (e.inv.melee && d < 2.6 * TS) { cancelHold(w, e); e.aimX = h.x; e.aimY = h.y; e.dir = dirOf(h.x - e.x, h.y - e.y); tryMelee(w, e); e.moving = false; return; }
      if (ai.mode !== 'flee') {
        cancelHold(w, e); ai.mode = 'flee'; ai.t = 8;
        var nf; do { nf = ri(0, FLOORS.length - 1); } while (nf === e.floor);
        navTo(w, e, nf, FLOORS[nf].spawn.x, FLOORS[nf].spawn.y);
      }
    }
  }
  if (e.hold) { e.moving = false; return; }
  if (ai.mode === 'flee') {
    ai.t -= dt;
    if (navUpdate(w, e, dt, CFG.speed.botRun) || ai.t <= 0) { ai.mode = 'blend'; ai.t = ri(8, 18); e.goal = null; ai.wait = 1; }
    return;
  }
  if (ai.mode === 'task') {
    var t = ai.task;
    if (!t || !taskAvail(w, t, e)) { ai.mode = 'blend'; ai.t = 6; e.goal = null; return; }
    if (!e.goal) navTo(w, e, t.floor, t.x, t.y);
    if (navUpdate(w, e, dt, CFG.speed.bot)) { if (e.floor === t.floor) startHold(w, e, 'task', t, t.dur); else { ai.mode = 'blend'; ai.t = 5; e.goal = null; } }
    return;
  }
  if (ai.mode === 'scrap') {
    var p = ai.pk;
    if (!p || w.pick.indexOf(p) < 0) { ai.mode = 'blend'; ai.t = 2; e.goal = null; return; }
    if (!e.goal) navTo(w, e, p.floor, p.x, p.y);
    if (navUpdate(w, e, dt, CFG.speed.bot)) { ai.mode = 'blend'; ai.t = 2; e.goal = null; }
    return;
  }
  /* mezclarse con la gente */
  ai.t -= dt;
  if (ai.t <= 0) {
    var cand = null;
    if (!e.inv.melee && rnd() < 0.35) { var ps = w.pick.filter(function (q) { return q.kind === 'scrap'; }); if (ps.length) { cand = pick(ps); ai.mode = 'scrap'; ai.pk = cand; e.goal = null; return; } }
    var tk = chooseTask(w, e);
    if (tk) { ai.mode = 'task'; ai.task = tk; e.goal = null; return; }
    ai.t = 8;
  }
  if (ai.wait > 0) { ai.wait -= dt; e.moving = false; return; }
  if (!e.goal) { var fl = rnd() < 0.15 ? ri(0, FLOORS.length - 1) : e.floor, tt = pick(FLOORS[fl].tilesPub); navTo(w, e, fl, tt.x, tt.y); }
  if (navUpdate(w, e, dt, CFG.speed.bot * 0.85)) { e.goal = null; ai.wait = ri(1, 5); }
}

/* ---------- IA: cazadores bot ---------- */
function hunterAI(w, e, dt) {
  var ai = e.ai, i;
  e.cd = Math.max(0, e.cd - dt);
  if (e.hold) { e.moving = false; return; }
  ai.scan -= dt;
  if (ai.mode === 'patrol' || ai.mode === 'stalk') {
    if (ai.scan <= 0) {
      ai.scan = 0.2;
      var seen = null;
      for (i = 0; i < w.ents.length; i++) {
        var t = w.ents[i];
        if (!t.alive || e.targetIds.indexOf(t.id) < 0 || t.floor !== e.floor) continue;
        if (dist(e.x, e.y, t.x, t.y) <= CFG.botSight * TS && los(FLOORS[e.floor], e.x, e.y, t.x, t.y)) { seen = t; break; }
      }
      if (seen) {
        ai.rec = (ai.rec || 0) + 0.2;
        if (ai.rec >= CFG.botRecognize) { ai.target = seen; ai.lost = 0; if (ai.mode === 'patrol') { ai.mode = 'stalk'; ai.patience = 0; ai.aimT = 0; e.goal = null; } }
      } else {
        ai.rec = 0;
        if (ai.mode === 'stalk') { ai.lost = (ai.lost || 0) + 0.2; if (ai.lost > 4) { ai.mode = 'patrol'; e.aim = false; e.goal = null; ai.wait = 0; } }
      }
    }
  }
  if (isHot(w, e) && ai.mode !== 'disguise') {
    var ward = null, bs = 1e9;
    FLOORS.forEach(function (f, fi) { f.wards.forEach(function (wd) { if (wd.looted || !wd.stand) return; var s = Math.abs(fi - e.floor) * 20 + Math.abs(wd.x - e.x / TS) + Math.abs(wd.y - e.y / TS) + rnd() * 8; if (s < bs) { bs = s; ward = wd; } }); });
    if (ward) { ai.mode = 'disguise'; ai.ward = ward; e.goal = null; e.aim = false; }
  }
  if (ai.mode === 'disguise') {
    var wd = ai.ward;
    if (!wd || wd.looted) { ai.mode = 'patrol'; e.goal = null; return; }
    if (!e.goal) navTo(w, e, wd.floorIdx, wd.stand.x, wd.stand.y);
    if (navUpdate(w, e, dt, CFG.speed.botRun)) { if (e.floor === wd.floorIdx) startHold(w, e, 'ward', wd, CFG.hold.ward); else { ai.mode = 'patrol'; e.goal = null; } }
    return;
  }
  if (ai.mode === 'stalk') {
    var tg = ai.target;
    if (!tg || !tg.alive) { ai.mode = 'patrol'; e.aim = false; e.goal = null; ai.wait = 0; return; }
    var d = dist(e.x, e.y, tg.x, tg.y), vis = tg.floor === e.floor && los(FLOORS[e.floor], e.x, e.y, tg.x, tg.y);
    if (!vis || d > 5.5 * TS) {
      e.aim = false; ai.aimT = 0;
      if (tg.floor === e.floor) { navTo(w, e, e.floor, Math.floor(tg.x / TS), Math.floor(tg.y / TS)); navUpdate(w, e, dt, CFG.speed.bot); }
      return;
    }
    e.moving = false; e.dir = dirOf(tg.x - e.x, tg.y - e.y);
    var safe = civilsSeeing(w, e, tg, CFG.witnessRadius * TS).length === 0;
    if (safe || ai.patience >= CFG.botPatience) {
      e.aim = true; e.aimX = tg.x; e.aimY = tg.y - 2; ai.aimT += dt;
      if (ai.aimT >= CFG.botAimTime && e.cd <= 0) { tryShoot(w, e); e.aim = false; ai.aimT = 0; ai.mode = 'patrol'; e.goal = null; ai.wait = 1.5; ai.patience = 0; }
    } else { e.aim = false; ai.aimT = 0; ai.patience += dt; }
    return;
  }
  /* patrulla */
  e.aim = false;
  if (ai.wait > 0) { ai.wait -= dt; e.moving = false; return; }
  if (!e.goal) { var fl = rnd() < 0.55 ? ri(0, FLOORS.length - 1) : e.floor, tt = pick(FLOORS[fl].tilesPub); navTo(w, e, fl, tt.x, tt.y); }
  if (navUpdate(w, e, dt, CFG.speed.bot * 0.9)) { e.goal = null; ai.wait = ri(1, 3); }
}

/* ---------- percepción (10 veces por segundo) ---------- */
function perceive(w, dt) {
  var civils = w.ents.filter(function (c) { return c.alive && c.role === 'civil'; });
  w.ents.forEach(function (h) {
    if (h.role !== 'hunter' || !h.alive) return;
    var f = FLOORS[h.floor], tx = Math.floor(h.x / TS), ty = Math.floor(h.y / TS), z = f.zone[ty * W + tx], acc = access(h);
    var restricted = (z === ZONE_ROOM && !acc.room) || (z === ZONE_STAFF && !acc.staff);
    var view = [];
    civils.forEach(function (c) { if (c.floor === h.floor && c.state !== 'dead') { var d = dist(c.x, c.y, h.x, h.y); if (d <= CFG.sightTiles * TS && los(f, c.x, c.y, h.x, h.y)) view.push({ c: c, d: d }); } });
    if (isHot(w, h)) { h.sus = 100; }
    else {
      var rate = 0, staffV = null;
      if (restricted) {
        if (!h.wasRestricted && view.length) h.sus = Math.min(100, h.sus + 6);
        view.forEach(function (v) { rate += v.c.staff ? CFG.restrictedStaff : CFG.restrictedGuest; if (v.c.staff && !staffV) staffV = v.c; });
      }
      if (h.aim) {
        var aimR = CFG.aimNoticeRadius * TS, nearest = null;
        view.forEach(function (v) { if (v.d <= aimR) { rate += CFG.aimRate + CFG.aimNear * (1 - v.d / aimR); if (!nearest || v.d < nearest.d) nearest = v; } });
        if (nearest && h.sus >= 20 && w.time - (nearest.c.lastAim || -99) > 6) { nearest.c.lastAim = w.time; say(nearest.c, h.sus >= CFG.warnAt ? '¿Eso que lleva en la mano es un arma?' : '¿Qué esconde ese tipo?', 2.6); }
      }
      if (h.outfit.blood) view.forEach(function (v) { if (v.d <= CFG.bloodRadius * TS) rate += CFG.bloodRate; });
      if (rate === 0) rate = -CFG.susDecay;
      h.sus = clamp(h.sus + rate * dt, 0, 100);
      if (restricted && staffV && h.sus >= CFG.warnAt && h.sus < CFG.callAt && w.time - (staffV.lastWarn || -99) > 6) { staffV.lastWarn = w.time; say(staffV, '¡Esa zona es solo para el personal!', 3); }
      if (h.sus >= CFG.callAt && view.length) {
        var caller = staffV || view[0].c;
        alertNpc(w, caller, h.outfit.id, 'sospecha', h.floor, tx, ty);
      }
    }
    h.wasRestricted = restricted; h.restricted = restricted;
  });
  /* policía */
  w.ents.forEach(function (p) {
    if (p.role !== 'police' || !p.alive) return;
    var spotted = null;
    w.ents.forEach(function (h) {
      if (h.role !== 'hunter' || !h.alive || h.floor !== p.floor) return;
      if (!(w.wanted[h.outfit.id] || h.outfit.blood)) return;
      if (dist(p.x, p.y, h.x, h.y) <= CFG.policeSight * TS && los(FLOORS[p.floor], p.x, p.y, h.x, h.y)) spotted = h;
    });
    if (spotted) {
      p.freeze = true; p.dir = dirOf(spotted.x - p.x, spotted.y - p.y); p.spot[spotted.id] = (p.spot[spotted.id] || 0) + dt; p.spotting = true;
      if (p.spot[spotted.id] >= CFG.policeReact) { kill(w, p, spotted, 'police'); p.spot = {}; p.freeze = false; p.spotting = false; p.stayUntil = Math.max(p.stayUntil, w.time + 20); }
    } else { p.freeze = false; p.spotting = false; p.spot = {}; }
  });
  /* cadáveres */
  w.acc2 += dt;
  if (w.acc2 >= 0.5) {
    w.acc2 = 0;
    w.corpses.forEach(function (c) {
      if (c.found) return;
      for (var i = 0; i < civils.length; i++) {
        var n = civils[i];
        if (n.floor !== c.floor || !n.alive || n.state === 'call' || n.state === 'calling') continue;
        if (dist(n.x, n.y, c.x, c.y) <= 6 * TS && los(FLOORS[c.floor], n.x, n.y, c.x, c.y)) { c.found = true; alertNpc(w, n, null, 'body', c.floor, Math.floor(c.x / TS), Math.floor(c.y / TS)); break; }
      }
    });
  }
  /* carteles de busca y captura (solo cuando hay policía y el NPC ya dio la descripción) */
  var police = w.ents.some(function (p) { return p.role === 'police' && p.alive; });
  if (police) w.ents.forEach(function (h) {
    if (h.role !== 'hunter' || !h.alive || !w.wanted[h.outfit.id]) return;
    if (!w.posters.some(function (p) { return p.outfitId === h.outfit.id; })) { w.posters.push({ outfitId: h.outfit.id, hunterId: h.id, outfit: cloneOutfit(h.outfit), state: 'active', t: 0 }); wlog(w, 'La policía reparte un cartel de busca y captura.', 'alarm'); }
  });
  w.posterActive = {};
  w.posters = w.posters.filter(function (p) {
    var h = null; for (var i = 0; i < w.ents.length; i++) if (w.ents[i].id === p.hunterId) h = w.ents[i];
    if (!h || !h.alive) return false;
    if (p.state === 'active' && h.outfit.id !== p.outfitId) { p.state = 'changed'; p.t = 0; wlog(w, 'El sospechoso ha cambiado de apariencia.', 'poster'); }
    if (p.state === 'changed') { p.t += dt; if (p.t > 6) return false; }
    else w.posterActive[p.outfitId] = true;
    return true;
  });
}

/* ---------- jugador humano ---------- */
function findInteract(w, e) {
  var f = FLOORS[e.floor], best = null, bd = 1e9;
  function cand(type, ref, x, y, range, label, dur) { var d = dist(e.x, e.y, x, y); if (d < range && d < bd) { bd = d; best = { type: type, ref: ref, label: label, dur: dur }; } }
  var tx = Math.floor(e.x / TS), ty = Math.floor(e.y / TS), i, j;
  for (j = ty - 2; j <= ty + 2; j++) for (i = tx - 2; i <= tx + 2; i++) if (at(f, i, j) === T.ELEV) cand('elev', null, (i + .5) * TS, (j + .5) * TS, 52, 'Llamar al ascensor', 0);
  if (e.role === 'hunter') {
    w.corpses.forEach(function (c) { if (c.floor === e.floor && !c.stripped && c.outfit.kind !== 'under') cand('strip', c, c.x, c.y, 38, 'Coger su ropa', CFG.hold.strip); });
    f.wards.forEach(function (wd) { if (!wd.looted) cand('ward', wd, (wd.x + wd.w / 2) * TS, (wd.y + wd.h / 2) * TS, 50, 'Registrar el armario', CFG.hold.ward); });
    if (e.outfit.blood) { f.washers.forEach(function (s) { cand('wash', s, (s.x + s.w / 2) * TS, (s.y + s.h / 2) * TS, 56, 'Lavar el traje', CFG.hold.wash); }); f.sinks.forEach(function (s) { cand('wash', s, (s.x + .5) * TS, (s.y + .5) * TS, 46, 'Lavar el traje', CFG.hold.sink); }); }
  } else {
    w.tasks.forEach(function (t) { if (t.floor === e.floor && taskAvail(w, t, e)) cand('task', t, (t.x + .5) * TS, (t.y + .5) * TS, 30, t.name, t.dur); });
  }
  return best;
}
function autoPickup(w, e) {
  for (var i = 0; i < w.pick.length; i++) {
    var p = w.pick[i];
    if (p.floor !== e.floor || dist(e.x, e.y, (p.x + .5) * TS, (p.y + .5) * TS) > 20) continue;
    if (p.kind === 'scrap' && e.role !== 'runner') continue;
    if (p.kind !== 'scrap' && e.role !== 'hunter') continue;
    w.pick.splice(i, 1);
    if (p.kind === 'masterkey') { e.inv.masterkey = true; if (e === w.human) wlog(w, 'Has cogido una llave maestra: abre las habitaciones sin levantar sospechas.', 'info'); }
    else if (p.kind === 'badge') { e.inv.badge = true; if (e === w.human) wlog(w, 'Has cogido una insignia de botones: te deja pasar a las zonas del personal.', 'info'); }
    else {
      e.inv.scrap++;
      if (e === w.human) wlog(w, 'Has cogido: ' + p.name + ' (' + Math.min(e.inv.scrap, CFG.scrapNeeded) + '/' + CFG.scrapNeeded + ')', 'info');
      if (e.inv.scrap >= CFG.scrapNeeded && !e.inv.melee) { e.inv.melee = true; if (e === w.human) wlog(w, 'Has fabricado una llave inglesa. Clic izquierdo para golpear.', 'info'); }
    }
    return;
  }
}
function humanControl(w, e, dt, inp) {
  var f = FLOORS[e.floor];
  e.cd = Math.max(0, e.cd - dt);
  if (e.fxSwing > 0) e.fxSwing -= dt;
  e.aimX = inp.aimX; e.aimY = inp.aimY;
  e.aim = e.role === 'hunter' && !!inp.aim && !e.hold;
  var mx = inp.mx, my = inp.my;
  if (e.aim) { e.aimAng = Math.atan2(e.aimY - e.y, e.aimX - e.x); e.dir = dirOf(e.aimX - e.x, e.aimY - e.y); }
  if (mx || my) {
    if (e.hold) cancelHold(w, e);
    var len = Math.hypot(mx, my), sp = e.aim ? CFG.speed.aim : (inp.run ? CFG.speed.run : CFG.speed.walk);
    var vx = mx / len * sp * dt, vy = my / len * sp * dt;
    if (freeAt(f, e.x + vx, e.y)) e.x += vx;
    if (freeAt(f, e.x, e.y + vy)) e.y += vy;
    e.walk += dt * 10; e.moving = true;
    if (!e.aim) e.dir = dirOf(mx, my);
  } else e.moving = false;
  if (e.stairCd > 0) e.stairCd -= dt;
  else {
    var t = at(f, Math.floor(e.x / TS), Math.floor(e.y / TS));
    if (t === T.UP && e.floor < FLOORS.length - 1) useStairs(w, e, 1);
    else if (t === T.DOWN && e.floor > 0) useStairs(w, e, -1);
  }
  var hint = e.hold ? null : findInteract(w, e);
  w.hint = hint;
  if (inp.interactHeld && !e.hold && hint && hint.type !== 'elev') startHold(w, e, hint.type, hint.ref, hint.dur);
  if (e.hold && !inp.interactHeld) cancelHold(w, e);
  if (inp.fire) { if (e.role === 'hunter' && e.aim) tryShoot(w, e); else if (e.role === 'runner' && e.inv.melee) tryMelee(w, e); }
}

/* ---------- paso de simulación ---------- */
function step(w, dt, inp) {
  if (w.over) return;
  w.time += dt;
  var h = w.human;
  if (h && h.alive && inp) humanControl(w, h, dt, inp);
  var i;
  for (i = 0; i < w.ents.length; i++) {
    var e = w.ents[i];
    if (e.bt > 0) { e.bt -= dt; if (e.bt <= 0) e.bubble = null; }
    if (!e.alive) continue;
    if (e.type === 'human') { holdUpdate(w, e, dt); if (!e.hold) { /* nada */ } autoPickup(w, e); continue; }
    if (e.type === 'npc') npcAI(w, e, dt);
    else if (e.type === 'police') policeAI(w, e, dt);
    else if (e.role === 'runner') { runnerAI(w, e, dt); holdUpdate(w, e, dt); autoPickup(w, e); }
    else if (e.role === 'hunter') { hunterAI(w, e, dt); holdUpdate(w, e, dt); autoPickup(w, e); }
  }
  w.ents = w.ents.filter(function (e) { return !e.remove; });
  for (i = 0; i < w.dispatch.length; i++) { var d = w.dispatch[i]; if (!d.done && w.time >= d.t) { d.done = true; spawnPolice(w, d); } }
  w.fx = w.fx.filter(function (x) { x.t -= dt; return x.t > 0; });
  w.acc += dt;
  if (w.acc >= 0.1) { var pd = w.acc; w.acc = 0; perceive(w, pd); }
  if (w.time >= w.limit || w.tasksDone >= w.quota) checkWin(w);
}

if (typeof globalThis.__EXPOSE !== 'undefined') globalThis.__API = { FLOORS: FLOORS, TASK_DEFS: TASK_DEFS, KEY_SPOTS: KEY_SPOTS, SCRAP_SPOTS: SCRAP_SPOTS, newWorld: newWorld, step: step, CFG: CFG, T: T, W: W, H: H, TS: TS, SOLIDT: SOLIDT, bfs: bfs, los: los, isHot: isHot, kill: kill, access: access, findInteract: findInteract, startHold: startHold, tryShoot: tryShoot, humanControl: humanControl, teleport: teleport, civilsSeeing: civilsSeeing, perceive: perceive, alertNpc: alertNpc, swapOutfit: swapOutfit, newGuest: newGuest };
