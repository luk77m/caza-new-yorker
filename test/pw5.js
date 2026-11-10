const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch(); const errs = [];
  const p = await b.newPage({ viewport: { width: 400, height: 860 } });
  p.on('pageerror', e => errs.push(e.message));
  await p.goto('file://' + process.cwd() + '/index_test.html', { waitUntil: 'domcontentloaded' }); await p.waitForTimeout(800);
  await p.screenshot({ path: 'shots/mobile_menu.png', fullPage: true });
  const ov = await p.evaluate(() => ({ sw: document.documentElement.scrollWidth, cw: document.documentElement.clientWidth }));
  console.log('overflow', JSON.stringify(ov));
  const p2 = await b.newPage({ viewport: { width: 1280, height: 800 } });
  p2.on('pageerror', e => errs.push(e.message));
  await p2.goto('file://' + process.cwd() + '/index_test.html', { waitUntil: 'domcontentloaded' }); await p2.waitForTimeout(500);
  await p2.evaluate(() => { __T.UI.cfg.role = 'bots'; __T.startGame(); __T.UI.speed = 4; });
  await p2.waitForTimeout(1500); await p2.locator('#stage').screenshot({ path: 'shots/spec2.png' });
  console.log('errs', errs);
  await b.close();
})();
