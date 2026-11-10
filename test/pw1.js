const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 1280, height: 800 } });
  const errs = []; p.on('pageerror', e => errs.push('PAGEERR ' + e.message)); p.on('console', m => { if (m.type() === 'error') errs.push('CONSOLE ' + m.text()); });
  await p.goto('file://' + process.cwd() + '/index_test.html', { waitUntil: 'domcontentloaded' });
  await p.waitForTimeout(2500);
  await p.screenshot({ path: 'shots/menu.png' });
  // start as hunter
  await p.click('#btnStart'); await p.waitForTimeout(500);
  await p.keyboard.down('KeyW'); await p.waitForTimeout(1200); await p.keyboard.up('KeyW');
  await p.screenshot({ path: 'shots/hunter1.png' });
  console.log('errs', errs.slice(0, 8));
  const st = await p.evaluate(() => { const w = __T.UI.w; return { t: w.time, floor: w.human.floor, x: w.human.x, y: w.human.y, role: w.human.role, ents: w.ents.length }; });
  console.log(JSON.stringify(st));
  await b.close();
})();
