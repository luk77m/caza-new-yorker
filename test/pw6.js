const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch(); const errs = [];
  const p = await b.newPage({ viewport: { width: 1360, height: 820 } });
  p.on('pageerror', e => errs.push('PE ' + e.message));
  p.on('console', m => { if (m.type() === 'error' && !/ERR_TUNNEL|Failed to load resource/.test(m.text())) errs.push('CE ' + m.text()); });
  await p.goto('file://' + process.cwd() + '/index_test.html', { waitUntil: 'domcontentloaded' }); await p.waitForTimeout(1200);
  await p.screenshot({ path: 'shots/t_title.png' });
  const err = await p.evaluate(() => { const e = document.getElementById('err'); return e && !e.hidden ? e.textContent : null; });
  console.log('err box', err);
  // how-to
  await p.click('#tmenu [data-act=how]'); await p.waitForTimeout(300);
  await p.screenshot({ path: 'shots/t_how.png' });
  await p.keyboard.press('Escape'); await p.waitForTimeout(200);
  // settings
  await p.click('#tmenu [data-act=settings]'); await p.waitForTimeout(300);
  await p.screenshot({ path: 'shots/t_set_image.png' });
  await p.click('#mTabs button:nth-child(3)'); await p.waitForTimeout(200);
  await p.screenshot({ path: 'shots/t_set_keys.png' });
  // rebind "pause" to KeyO
  const btns = await p.$$('#mBody .set .kb');
  await btns[5].click(); await p.keyboard.press('KeyO'); await p.waitForTimeout(150);
  console.log('binds.pause', await p.evaluate(() => __T.SET.binds.pause || __T.SET.binds['pause']));
  await p.click('#mFoot .btn:last-child'); await p.waitForTimeout(150);
  // credits
  await p.click('#tmenu [data-act=credits]'); await p.waitForTimeout(250);
  await p.screenshot({ path: 'shots/t_credits.png' });
  await p.keyboard.press('Escape');
  // lobby
  await p.click('#tmenu [data-act=play]'); await p.waitForTimeout(700);
  await p.screenshot({ path: 'shots/t_lobby.png' });
  // start as runner
  await p.evaluate(() => { __T.UI.cfg.role = 'runner'; });
  await p.click('#btnStart'); await p.waitForTimeout(1500);
  await p.screenshot({ path: 'shots/t_play_runner.png' });
  // tab
  await p.keyboard.press('Tab'); await p.waitForTimeout(500);
  await p.screenshot({ path: 'shots/t_tab_runner.png' });
  await p.keyboard.press('Tab'); await p.waitForTimeout(200);
  console.log('tabOpen after 2nd tab', await p.evaluate(() => __T.UI.tabOpen));
  console.log('errs', errs);
  await b.close();
})();
