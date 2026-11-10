const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch(); const errs = [];
  const p = await b.newPage({ viewport: { width: 1360, height: 820 } });
  p.on('pageerror', e => errs.push('PE ' + e.message));
  await p.goto('file://' + process.cwd() + '/index_test.html', { waitUntil: 'domcontentloaded' }); await p.waitForTimeout(500);
  await p.evaluate(() => { __T.UI.cfg.role = 'runner'; __T.SET.layout = 'wide'; document.body.classList.add('lay-wide'); });
  await p.click('#tmenu [data-act=quick]'); await p.waitForTimeout(500);
  const info = await p.evaluate(() => {
    const w = __T.UI.w, h = w.human, TS = 32;
    const t = h.tasks.find(t => t.floor === 3) || h.tasks[0];
    h.floor = t.floor; h.x = (t.x + 0.5 - 13) * TS; h.y = (t.y + 0.5) * TS;
    return { t: t.name, tx: t.x, ty: t.y, fl: t.floor };
  });
  console.log(JSON.stringify(info)); await p.waitForTimeout(900);
  await p.screenshot({ path: 'shots/t_arrow.png' });
  // walk near the task and capture plates close
  await p.evaluate(() => { const w = __T.UI.w, h = w.human, TS = 32; h.floor = 3; const f = __T.FLOORS[3]; const r = f.rooms.find(r => r.door); h.x = (r.door.x + 0.5) * TS; h.y = (r.door.y + 2.5) * TS; });
  await p.waitForTimeout(800); await p.screenshot({ path: 'shots/t_plates.png' });
  console.log('errs', errs); await b.close();
})();
