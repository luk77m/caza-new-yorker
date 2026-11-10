const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch(); const errs = [];
  const p = await b.newPage({ viewport: { width: 1000, height: 400 } });
  p.on('pageerror', e => errs.push('PE ' + e.message));
  await p.goto('file://' + process.cwd() + '/index_test.html', { waitUntil: 'domcontentloaded' }); await p.waitForTimeout(500);
  await p.evaluate(() => {
    const c = document.createElement('canvas'); c.width = 1000; c.height = 360; c.style.cssText = 'position:fixed;left:0;top:0;z-index:9999;background:#243040';
    document.body.appendChild(c); const g = c.getContext('2d'); g.setTransform(3, 0, 0, 3, 0, 0);
    const dirs = ['down', 'up', 'left', 'right']; const hs = ['short', 'slick', 'side', 'bald', 'bob', 'bun', 'wave'];
    hs.forEach((h, i) => dirs.forEach((d, j) => { const o = __T.newGuest(i >= 4); o.hs = h; o.hat = { t: 'none', c: '#000', n: '', cn: '' }; o.glasses = j === 0 && i % 2; o.stache = false; __T.drawActor(g, 20 + i * 45, 25 + j * 30, o, d, 0.5, {}); }));
  });
  await p.screenshot({ path: 'shots/t_hair.png', clip: { x: 0, y: 0, width: 1000, height: 380 } });
  console.log('errs', errs); await b.close();
})();
