const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch(); const errs = [];
  const p = await b.newPage({ viewport: { width: 1366, height: 768 } });
  p.on('pageerror', e => errs.push('PE ' + e.message));
  await p.goto('file://' + process.cwd() + '/index_test.html', { waitUntil: 'domcontentloaded' }); await p.waitForTimeout(500);
  await p.evaluate(() => { __T.UI.cfg.role = 'hunter'; });
  await p.click('#tmenu [data-act=quick]'); await p.waitForTimeout(1200);
  console.log(JSON.stringify(await p.evaluate(() => ({ hDeal: document.getElementById('hDeal').hidden, hOwn: document.getElementById('hOwn').hidden, sus: document.getElementById('susWrap').hidden, susLbl: document.getElementById('susLbl').textContent, tasksEls: document.querySelectorAll('#taskList li').length }))));
  // teleport hunter in front of a foreign room door with a nearby witness
  await p.evaluate(() => { const w = __T.UI.w, hm = w.human, F = __T.FLOORS; hm.floor = 3; const rm = F[3].rooms.find(r => r.door); hm.x = (rm.out.x + .5) * 32; hm.y = (rm.out.y + .5) * 32; });
  await p.waitForTimeout(500); await p.screenshot({ path: 'shots/v3_hunter_full.png' });
  await p.keyboard.press('Tab'); await p.waitForTimeout(400); await p.screenshot({ path: 'shots/v3_tab_hunter.png' });
  console.log((await p.evaluate(() => document.getElementById('tabside').innerText)).slice(0, 500));
  await p.keyboard.press('Tab');
  // mobile runner
  const m = await b.newPage({ viewport: { width: 400, height: 800 }, isMobile: true, hasTouch: true, deviceScaleFactor: 2 });
  m.on('pageerror', e => errs.push('MPE ' + e.message));
  await m.goto('file://' + process.cwd() + '/index_test.html', { waitUntil: 'domcontentloaded' }); await m.waitForTimeout(500);
  await m.evaluate(() => { __T.UI.cfg.role = 'runner'; });
  await m.click('#tmenu [data-act=quick]'); await m.waitForTimeout(1200);
  await m.evaluate(() => { const w = __T.UI.w; w.sab.alarm = w.time + 40; w.sab.blackout = w.time + 1; w.human.reports = 2; });
  await m.waitForTimeout(500); await m.screenshot({ path: 'shots/v3_mobile_play.png' });
  console.log('mobile overflow', await m.evaluate(() => ({ sw: document.documentElement.scrollWidth, cw: document.documentElement.clientWidth })));
  console.log('errs', errs); await b.close();
})();
