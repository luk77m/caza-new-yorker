const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch(); const errs = [];
  const p = await b.newPage({ viewport: { width: 1366, height: 768 } });
  p.on('pageerror', e => errs.push('PE ' + e.message));
  await p.goto('file://' + process.cwd() + '/index_test.html', { waitUntil: 'domcontentloaded' }); await p.waitForTimeout(500);
  await p.evaluate(() => { __T.UI.cfg.role = 'runner'; });
  await p.click('#tmenu [data-act=quick]'); await p.waitForTimeout(800);
  // teleport to a locked-room task door
  const tp = await p.evaluate(() => {
    const w = __T.UI.w, hm = w.human, F = __T.FLOORS;
    const t = hm.tasks.find(t => t.roomName && !t.own); const rm = F[t.floor].rooms.find(r => r.name === t.roomName);
    hm.floor = t.floor; hm.x = (rm.out.x + 0.5) * 32; hm.y = (rm.out.y + 0.5) * 32;
    // also place an ally runner nearby to see blue name
    const al = w.ents.find(e => e.role === 'runner' && e !== hm); al.floor = t.floor; al.x = hm.x + 90; al.y = hm.y; al.type = 'frozen';
    return { room: rm.name, floor: t.floor, out: rm.out, door: rm.door };
  });
  console.log(JSON.stringify(tp)); await p.waitForTimeout(600);
  await p.screenshot({ path: 'shots/v3_lock.png' });
  console.log('prompt', await p.evaluate(() => { const e = document.getElementById('hintTxt'); return e ? [e.hidden, e.textContent] : null; }));
  await p.keyboard.down('KeyE'); await p.waitForTimeout(1800);
  await p.screenshot({ path: 'shots/v3_force.png' });
  console.log('hold', await p.evaluate(() => { const h = __T.UI.w.human.hold; return h ? h.type + ' ' + (h.t / h.dur).toFixed(2) : null; }));
  await p.waitForTimeout(5000); await p.keyboard.up('KeyE'); await p.waitForTimeout(300);
  console.log('unlocked', await p.evaluate(() => Object.keys(__T.UI.w.unlocked).length), 'reports', await p.evaluate(() => __T.UI.w.human.reports + ' marked ' + __T.UI.w.human.marked));
  await p.screenshot({ path: 'shots/v3_forced.png' });
  // sabotage visuals
  await p.evaluate(() => { const w = __T.UI.w; w.sab.blackout = w.time + 30; w.sab.alarm = w.time + 30; w.sab.elev = w.time + 30; });
  await p.waitForTimeout(700);
  console.log('hSab', await p.evaluate(() => document.getElementById('hSab').textContent));
  await p.screenshot({ path: 'shots/v3_sab.png' });
  console.log('errs', errs); await b.close();
})();
