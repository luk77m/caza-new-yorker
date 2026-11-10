const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch(); const errs = [];
  const mk = async (vw, vh, name, setup) => {
    const p = await b.newPage({ viewport: { width: vw, height: vh } });
    p.on('pageerror', e => errs.push(name + ' PE ' + e.message));
    p.on('console', m => { if (m.type() === 'error' && !/ERR_TUNNEL|Failed to load resource/.test(m.text())) errs.push(name + ' CE ' + m.text()); });
    await p.goto('file://' + process.cwd() + '/index_test.html', { waitUntil: 'domcontentloaded' }); await p.waitForTimeout(500);
    return p;
  };
  // 1. mobile 400 wide: title, lobby, settings, play
  let p = await mk(400, 820, 'mobile');
  await p.screenshot({ path: 'shots/t_m_title.png' });
  console.log('mobile title overflow', JSON.stringify(await p.evaluate(() => ({ sw: document.documentElement.scrollWidth, cw: document.documentElement.clientWidth }))));
  await p.click('#tmenu [data-act=settings]'); await p.waitForTimeout(250); await p.screenshot({ path: 'shots/t_m_set.png' });
  await p.keyboard.press('Escape');
  await p.click('#tmenu [data-act=play]'); await p.waitForTimeout(400); await p.screenshot({ path: 'shots/t_m_lobby.png', fullPage: true });
  console.log('mobile lobby overflow', JSON.stringify(await p.evaluate(() => ({ sw: document.documentElement.scrollWidth, cw: document.documentElement.clientWidth }))));
  await p.evaluate(() => { __T.UI.cfg.role = 'runner'; }); await p.click('#btnStart'); await p.waitForTimeout(1200);
  await p.screenshot({ path: 'shots/t_m_play.png', fullPage: true });
  console.log('mobile play overflow', JSON.stringify(await p.evaluate(() => ({ sw: document.documentElement.scrollWidth, cw: document.documentElement.clientWidth }))));
  await p.close();
  // 2. full layout via settings seg, esc pause, spectate
  p = await mk(1280, 720, 'full');
  await p.evaluate(() => { __T.UI.cfg.role = 'bots'; }); await p.click('#tmenu [data-act=quick]'); await p.waitForTimeout(500);
  await p.click('#btnSet'); await p.waitForTimeout(250);
  await p.click('#mBody .seg button:nth-child(3)'); await p.waitForTimeout(500);
  console.log('layout', await p.evaluate(() => ({ lay: __T.SET.layout, cls: document.body.className, paused: __T.UI.paused })));
  await p.keyboard.press('Escape'); await p.waitForTimeout(400);
  console.log('after esc paused', await p.evaluate(() => __T.UI.paused));
  await p.evaluate(() => { __T.UI.speed = 4; }); await p.waitForTimeout(1500);
  await p.screenshot({ path: 'shots/t_full_spec.png' });
  await p.keyboard.press('KeyF'); await p.waitForTimeout(400);
  console.log('after F layout', await p.evaluate(() => __T.SET.layout));
  // arrow keys cycle follow
  const f0 = await p.evaluate(() => __T.UI.follow && __T.UI.follow.name); await p.keyboard.press('ArrowRight'); const f1 = await p.evaluate(() => __T.UI.follow && __T.UI.follow.name);
  console.log('follow', f0, '->', f1);
  await p.close();
  console.log('errs', errs); await b.close();
})();
