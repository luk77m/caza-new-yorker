const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch(); const errs = [];
  const p = await b.newPage({ viewport: { width: 1366, height: 768 } });
  p.on('pageerror', e => errs.push('PE ' + e.message)); p.on('console', m => { if (m.type() === 'error') errs.push('CE ' + m.text()); });
  await p.goto('file://' + process.cwd() + '/index_test.html', { waitUntil: 'domcontentloaded' }); await p.waitForTimeout(500);
  console.log('layout default', await p.evaluate(() => __T.SET.layout), 'body class', await p.evaluate(() => document.body.className));
  await p.evaluate(() => { __T.UI.cfg.role = 'runner'; });
  await p.click('#tmenu [data-act=quick]'); await p.waitForTimeout(1200);
  const info = await p.evaluate(() => {
    const w = __T.UI.w, hm = w.human, vis = id => { const e = document.getElementById(id); return e ? { hidden: e.hidden, disp: getComputedStyle(e).display, txt: e.textContent.trim().slice(0, 80) } : null; };
    const side = document.querySelector('#side, aside, #tabside');
    return { tasks: hm.tasks.length, units: hm.tasks.filter(t => t.kind !== 'pick').length, room: hm.room, roomFloor: hm.roomFloor,
      hDeal: vis('hDeal'), hOwn: vis('hOwn'), hRep: vis('hRep'), hSab: vis('hSab'), hudMap: vis('hudMap'), mini2: (() => { const c = document.getElementById('mini2'); const r = c.getBoundingClientRect(); return [r.width, r.height]; })(),
      sidebarDisp: ['side', 'sidebar', 'panel'].map(i => { const e = document.getElementById(i); return e ? i + ':' + getComputedStyle(e).display : null; }).filter(Boolean),
      stage: (() => { const r = document.getElementById('stage').getBoundingClientRect(); return [r.x, r.y, r.width, r.height]; })(), allies: w.ents.filter(e => e.role === 'runner' && e !== hm).length };
  });
  console.log(JSON.stringify(info, null, 1));
  await p.screenshot({ path: 'shots/v3_runner_full.png' });
  // open tab panel
  await p.keyboard.press('Tab'); await p.waitForTimeout(400);
  await p.screenshot({ path: 'shots/v3_tab_runner.png' });
  console.log('tab text', (await p.evaluate(() => document.getElementById('tabside').innerText)).slice(0, 700));
  await p.keyboard.press('Tab'); await p.waitForTimeout(200);
  // hunter
  await p.click('#btnMenu').catch(() => {}); await p.waitForTimeout(300);
  console.log('errs', errs); await b.close();
})();
