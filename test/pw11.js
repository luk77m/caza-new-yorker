const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch(); const errs = [];
  const p = await b.newPage({ viewport: { width: 1280, height: 800 } });
  p.on('pageerror', e => errs.push('PE ' + e.message));
  await p.goto('file://' + process.cwd() + '/index_test.html', { waitUntil: 'domcontentloaded' }); await p.waitForTimeout(500);
  await p.click('#tmenu [data-act=settings]'); await p.click('#mTabs button:nth-child(3)');
  const btns = await p.$$('#mBody .set .kb'); await btns[7].click(); await p.keyboard.press('KeyO'); await p.waitForTimeout(150);
  console.log('pause bind', await p.evaluate(() => __T.SET.binds.pause), 'persisted', await p.evaluate(() => JSON.parse(localStorage.getItem('caza-set')).binds.pause));
  await p.keyboard.press('Escape');
  await p.evaluate(() => { __T.UI.cfg.role = 'hunter'; }); await p.click('#tmenu [data-act=quick]'); await p.waitForTimeout(500);
  await p.keyboard.press('KeyO'); await p.waitForTimeout(150);
  console.log('paused with O', await p.evaluate(() => __T.UI.paused), 'pause overlay visible', await p.evaluate(() => !document.getElementById('pause').hidden));
  await p.click('#btnPauseSet'); await p.waitForTimeout(200); await p.keyboard.press('Escape'); await p.waitForTimeout(150);
  console.log('after settings from pause still paused', await p.evaluate(() => __T.UI.paused));
  await p.click('#btnResume'); await p.waitForTimeout(150);
  console.log('resumed', await p.evaluate(() => !__T.UI.paused));
  // finish game quickly
  await p.evaluate(() => { const w = __T.UI.w; w.ents.forEach(e => { if (e.type === 'human') e.type = 'human'; }); let n = 0; while (!w.over && n++ < 60000) __T.step(w, 1 / 60, { mx: 0, my: 0, run: false, aim: false, aimX: 0, aimY: 0, fire: false, interactHeld: false }); });
  await p.waitForTimeout(800);
  console.log('end overlay', await p.evaluate(() => !document.getElementById('end').hidden), await p.evaluate(() => document.getElementById('endTitle').textContent));
  await p.screenshot({ path: 'shots/t_end.png' });
  await p.click('#btnMenu'); await p.waitForTimeout(400);
  console.log('mode after menu', await p.evaluate(() => __T.UI.mode));
  console.log('errs', errs); await b.close();
})();
