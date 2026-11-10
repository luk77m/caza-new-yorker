const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch(); const errs = [];
  const p = await b.newPage({ viewport: { width: 1440, height: 900 } });
  p.on('pageerror', e => errs.push('PE ' + e.message));
  p.on('console', m => { if (m.type() === 'error' && !/ERR_TUNNEL|Failed to load resource/.test(m.text())) errs.push('CE ' + m.text()); });
  await p.goto('file://' + process.cwd() + '/index_test.html', { waitUntil: 'domcontentloaded' }); await p.waitForTimeout(600);
  // hunter in wide layout
  await p.evaluate(() => { __T.UI.cfg.role = 'hunter'; __T.SET.layout = 'wide'; __T.SET.zoom = 1.6; });
  await p.click('#tmenu [data-act=quick]'); await p.waitForTimeout(300);
  await p.evaluate(() => document.body.classList.add('lay-wide')); await p.waitForTimeout(1200);
  await p.screenshot({ path: 'shots/t_hunter_wide.png' });
  // move player to a populated lobby (planta baja), look at NPCs
  await p.keyboard.down('KeyD'); await p.waitForTimeout(900); await p.keyboard.up('KeyD');
  await p.keyboard.press('Tab'); await p.waitForTimeout(500);
  await p.screenshot({ path: 'shots/t_tab_hunter.png' });
  await p.keyboard.press('Tab');
  // characters lineup
  await p.evaluate(() => {
    const c = document.createElement('canvas'); c.id = 'lineup'; c.width = 1200; c.height = 280; c.style.cssText = 'position:fixed;left:0;top:0;z-index:9999;background:#243040';
    document.body.appendChild(c); const g = c.getContext('2d'); g.setTransform(3, 0, 0, 3, 0, 0);
    const list = []; for (let i = 0; i < 8; i++) list.push(__T.newGuest(i % 2 === 1));
    for (let i = 0; i < 4; i++) list.push(__T.newStaff(['bell','chef','recep','tech'][i]));
    list.push(__T.newPolice());
    window.__lineErr = null;
    try { list.forEach((o, i) => __T.drawActor(g, 20 + i * 30, 60, o, i % 4, 0, {})); } catch (e) { window.__lineErr = String(e.stack || e); }
  });
  console.log('lineErr', await p.evaluate(() => window.__lineErr));
  await p.screenshot({ path: 'shots/t_lineup.png', clip: { x: 0, y: 0, width: 1200, height: 200 } });
  console.log('errs', errs);
  await b.close();
})();
