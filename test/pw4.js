const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 1280, height: 900 } });
  const errs = []; p.on('pageerror', e => errs.push('PAGEERR ' + e.message)); p.on('console', m => { if (m.type() === 'error' && !/ERR_TUNNEL/.test(m.text())) errs.push('CONSOLE ' + m.text()); });
  await p.goto('file://' + process.cwd() + '/index_test.html', { waitUntil: 'domcontentloaded' });
  await p.waitForTimeout(600);
  await p.evaluate(() => { __T.UI.cfg.role = 'runner'; __T.UI.cfg.debug = false; __T.startGame(); const w = __T.UI.w; w.human.floor = 2; w.human.x = 12.5 * 32; w.human.y = 15.5 * 32; w.human.inv.scrap = 2; });
  await p.keyboard.down('KeyD'); await p.waitForTimeout(700); await p.keyboard.up('KeyD');
  await p.evaluate(() => { const w = __T.UI.w; const h = w.ents.filter(e => e.role === 'hunter')[0]; w.posters.push({ outfitId: h.outfit.id, hunterId: h.id, outfit: JSON.parse(JSON.stringify(h.outfit)), state: 'active', t: 0 }); w.wanted[h.outfit.id] = true; w.posterActive[h.outfit.id] = true; });
  await p.waitForTimeout(900);
  await p.screenshot({ path: 'shots/runner_poster.png' });
  await p.evaluate(() => { const w = __T.UI.w; w.posters[0].state = 'changed'; w.posters[0].t = -100; });
  await p.waitForTimeout(600);
  await p.locator('#stage').screenshot({ path: 'shots/runner_poster_grey.png', clip: { x: 640, y: 0, width: 290, height: 260 } });
  // ascensor: ir al frente del ascensor y abrir con E
  await p.evaluate(() => { const w = __T.UI.w, f = __T.FLOORS[w.human.floor]; w.human.x = 22.5 * 32; w.human.y = (f.spawn.y - 0.5) * 32; });
  await p.waitForTimeout(300);
  await p.keyboard.press('KeyE'); await p.waitForTimeout(300);
  await p.screenshot({ path: 'shots/elev.png' });
  const open = await p.evaluate(() => __T.UI.elevOpen);
  await p.keyboard.press('Digit5'); await p.waitForTimeout(1200);
  const fl = await p.evaluate(() => __T.UI.w.human.floor);
  console.log('elev open', open, 'floor after', fl);
  console.log('errs', errs.slice(0, 8));
  await b.close();
})();
