const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 1280, height: 800 } });
  const errs = []; p.on('pageerror', e => errs.push('PAGEERR ' + e.message)); p.on('console', m => { if (m.type() === 'error' && !/ERR_TUNNEL/.test(m.text())) errs.push('CONSOLE ' + m.text()); });
  await p.goto('file://' + process.cwd() + '/index_test.html', { waitUntil: 'domcontentloaded' });
  await p.waitForTimeout(600);
  /* --- cazador: apuntar y disparar con ratón real --- */
  await p.evaluate(() => { __T.UI.cfg.role = 'hunter'; __T.UI.cfg.debug = false; __T.startGame(); });
  await p.waitForTimeout(300);
  const info = await p.evaluate(() => {
    const w = __T.UI.w, h = w.human; const npc = w.ents.filter(e => e.role === 'civil' && e.floor === 1 && e.alive)[0];
    // colocar al cazador a 4 tiles a la izquierda del NPC con visión
    h.x = npc.x - 4 * 32; h.y = npc.y; npc.ai.mode = 'idle'; npc.fixed = true;
    return { nx: npc.x, ny: npc.y };
  });
  await p.waitForTimeout(400);
  const scr = await p.evaluate(() => { const T = __T, w = T.UI.w, h = w.human; const npc = w.ents.filter(e => e.role === 'civil' && e.floor === 1 && e.alive).sort((a, b) => Math.hypot(a.x - h.x, a.y - h.y) - Math.hypot(b.x - h.x, b.y - h.y))[0]; const r = document.getElementById('cv').getBoundingClientRect(); return { x: r.left + (npc.x - Math.round(T.REN.cam.x)) * r.width / 960, y: r.top + (npc.y - 2 - Math.round(T.REN.cam.y)) * r.height / 600, id: npc.id }; });
  await p.mouse.move(scr.x, scr.y);
  await p.mouse.down({ button: 'right' }); await p.waitForTimeout(400);
  await p.locator('#stage').screenshot({ path: 'shots/aim.png' });
  const before = await p.evaluate(() => ({ sus: __T.UI.w.human.sus, aim: __T.UI.w.human.aim }));
  await p.mouse.down({ button: 'left' }); await p.waitForTimeout(120); await p.mouse.up({ button: 'left' });
  await p.waitForTimeout(500);
  await p.mouse.up({ button: 'right' });
  const after = await p.evaluate(() => { const w = __T.UI.w; return { corpses: w.corpses.length, civKills: w.stats.civKills, sus: w.human.sus, calls: w.stats.calls }; });
  console.log('aim', JSON.stringify(before), 'after shot', JSON.stringify(after));
  await p.locator('#stage').screenshot({ path: 'shots/aftershot.png' });
  /* --- corredor: simular hasta cartel y fin --- */
  await p.evaluate(() => { __T.UI.cfg.role = 'runner'; __T.UI.cfg.minutes = 8; __T.startGame(); });
  const res = await p.evaluate(() => {
    const w = __T.UI.w; let t = 0, firstPoster = null;
    while (!w.over && t < 8 * 60 + 5) { __T.step(w, 1 / 30, null); t += 1 / 30; if (!firstPoster && w.posters.length) { firstPoster = t; break; } }
    return { t, firstPoster, over: !!w.over, alive: w.human.alive };
  });
  console.log('runner sim', JSON.stringify(res));
  await p.waitForTimeout(700);
  await p.locator('#stage').screenshot({ path: 'shots/runner_poster.png' });
  await p.screenshot({ path: 'shots/runner_full.png' });
  // acabar partida
  const fin = await p.evaluate(() => { const w = __T.UI.w; let t = 0; while (!w.over && t < 1200) { __T.step(w, 1 / 30, null); t += 1 / 30; } return { over: w.over, t: w.time }; });
  await p.waitForTimeout(700);
  await p.locator('#stage').screenshot({ path: 'shots/end.png' });
  console.log('fin', JSON.stringify(fin));
  // observador
  await p.evaluate(() => { __T.UI.cfg.role = 'bots'; __T.startGame(); __T.UI.speed = 10; });
  await p.waitForTimeout(3000);
  await p.screenshot({ path: 'shots/spectate.png' });
  console.log('errs', errs.slice(0, 8));
  await b.close();
})();
