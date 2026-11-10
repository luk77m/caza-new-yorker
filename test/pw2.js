const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 1280, height: 800 }, deviceScaleFactor: 1 });
  const errs = []; p.on('pageerror', e => errs.push('PAGEERR ' + e.message)); p.on('console', m => { if (m.type() === 'error' && !/ERR_TUNNEL/.test(m.text())) errs.push('CONSOLE ' + m.text()); });
  await p.goto('file://' + process.cwd() + '/index_test.html', { waitUntil: 'domcontentloaded' });
  await p.waitForTimeout(800);
  await p.evaluate(() => { __T.UI.cfg.role = 'hunter'; __T.UI.cfg.debug = true; __T.startGame(); });
  await p.waitForTimeout(400);
  for (let i = 0; i < 7; i++) {
    await p.evaluate((i) => { const w = __T.UI.w, h = w.human, f = __T.FLOORS[i]; h.floor = i; h.x = (f.spawn.x + .5) * 32; h.y = (f.spawn.y + 1.5) * 32; h.path = null; }, i);
    await p.waitForTimeout(500);
    await p.locator('#stage').screenshot({ path: 'shots/floor' + i + '.png' });
  }
  console.log('errs', errs.slice(0, 8));
  await b.close();
})();
