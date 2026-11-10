// Exporta los datos del hotel (generados por src/map.js) a godot/data/hotel.json
// Uso: node tools/export_godot_data.js
const fs = require('fs'), path = require('path');
const root = path.join(__dirname, '..');
const src = ['core', 'map', 'outfits', 'nav', 'sim'].map(n => fs.readFileSync(path.join(root, 'src', n + '.js'), 'utf8')).join('\n');
globalThis.__EXPOSE = 1;
(0, eval)('(function(){' + src + '\nglobalThis.__X={ROOM_TASKS:ROOM_TASKS,SCRAP_NAMES:SCRAP_NAMES};})()');
const A = globalThis.__API, X = globalThis.__X;
const xy = p => p ? [p.x, p.y] : null;
const room = r => ({ name: r.name, x: r.x, y: r.y, w: r.w, h: r.h, zone: r.zone, side: r.side || '', door: xy(r.door), out: xy(r.out) });
const floors = A.FLOORS.map((f, fi) => ({
  label: f.label, sub: f.sub, dark: f.dark, sky: !!f.sky, roof: !!f.roof,
  g: Array.from(f.g), blk: Array.from(f.blk), zone: Array.from(f.zone), pass: Array.from(f.pass),
  rooms: f.rooms.map(room),
  furn: f.furn.map(o => ({ k: o.k, x: o.x, y: o.y, w: o.w, h: o.h, solid: !!o.solid })),
  lamps: f.lamps.map(l => ({ x: l.x, y: l.y, r: l.r, tint: l.tint })),
  wards: f.wards.map(o => ({ x: o.x, y: o.y, w: o.w, h: o.h, stand: xy(o.stand) })),
  sinks: f.sinks.map(o => ({ x: o.x, y: o.y, w: o.w, h: o.h, stand: xy(o.stand) })),
  washers: f.washers.map(o => ({ x: o.x, y: o.y, w: o.w, h: o.h, stand: xy(o.stand) })),
  up: xy(f.up), down: xy(f.down), spawn: xy(f.spawn), phone: xy(f.phone),
  tilesPub: f.tilesPub.map(xy),
  roomTiles: Object.fromEntries(Object.entries(f.roomTiles).map(([k, v]) => [k, v.map(xy)])),
  lockAt: Object.fromEntries(Object.entries(f.lockAt).map(([k, r]) => [k, r.name]))
}));
const out = {
  version: 1, W: A.W, H: A.H, TS: A.TS,
  floors,
  taskDefs: A.TASK_DEFS.map(t => ({ id: t.id, name: t.name, floor: t.floor, x: t.x, y: t.y, dur: t.dur, kind: t.kind || '', pair: t.pair || '', roomName: t.roomName || '', sab: t.sab || '' })),
  roomTasks: X.ROOM_TASKS,
  roomPool: A.ROOM_POOL.map(r => [r.fi, r.name]),
  keySpots: { masterkey: A.KEY_SPOTS.masterkey.map(s => [s.f, s.x, s.y]), badge: A.KEY_SPOTS.badge.map(s => [s.f, s.x, s.y]) },
  scrapSpots: A.SCRAP_SPOTS.map(s => [s.f, s.x, s.y]),
  scrapNames: X.SCRAP_NAMES
};
const dst = path.join(root, 'godot', 'data', 'hotel.json');
fs.writeFileSync(dst, JSON.stringify(out));
console.log('ok', dst, fs.statSync(dst).size, 'bytes');
