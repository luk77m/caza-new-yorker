/* ===== ajustes del jugador (se guardan en el navegador si se puede) ===== */
var SET_DEF = {
  layout: 'normal',        // normal | wide | full
  zoom: 1.25, bright: 1, fog: 0.9,
  lights: true, plates: true, arrows: true, hints: true,
  vol: { master: 0.7, weapons: 1, alerts: 0.9, ui: 0.6 }, muted: false,
  binds: { up: 'KeyW', down: 'KeyS', left: 'KeyA', right: 'KeyD', run: 'ShiftLeft', use: 'KeyE', map: 'Tab', pause: 'KeyP', mute: 'KeyM', full: 'KeyF' }
};
var SET = JSON.parse(JSON.stringify(SET_DEF));
function mergeInto(dst, src) {
  for (var k in src) {
    if (!(k in dst)) continue;
    if (dst[k] && typeof dst[k] === 'object') { if (src[k] && typeof src[k] === 'object') mergeInto(dst[k], src[k]); }
    else if (typeof src[k] === typeof dst[k]) dst[k] = src[k];
  }
}
function loadSettings() { try { var s = JSON.parse(localStorage.getItem('caza-set') || 'null'); if (s) mergeInto(SET, s); } catch (e) { /* sin almacenamiento */ } }
function saveSettings() { try { localStorage.setItem('caza-set', JSON.stringify(SET)); } catch (e) { /* sin almacenamiento */ } }
function resetSettings(group) {
  var def = JSON.parse(JSON.stringify(SET_DEF));
  if (group === 'binds') SET.binds = def.binds;
  else if (group === 'sound') { SET.vol = def.vol; SET.muted = def.muted; }
  else if (group === 'image') { ['layout', 'zoom', 'bright', 'fog', 'lights', 'plates'].forEach(function (k) { SET[k] = def[k]; }); }
  else if (group === 'game') { SET.arrows = def.arrows; SET.hints = def.hints; }
}
function getPath(o, p) { var a = p.split('.'); for (var i = 0; i < a.length; i++) o = o[a[i]]; return o; }
function setPath(o, p, v) { var a = p.split('.'); for (var i = 0; i < a.length - 1; i++) o = o[a[i]]; o[a[a.length - 1]] = v; }
function keyLabel(code) {
  var map = { ArrowUp: '↑', ArrowDown: '↓', ArrowLeft: '←', ArrowRight: '→', ShiftLeft: 'Shift', ShiftRight: 'Shift', Space: 'Espacio', Tab: 'Tab', Escape: 'Esc', Enter: 'Intro', ControlLeft: 'Ctrl', ControlRight: 'Ctrl', AltLeft: 'Alt', AltRight: 'Alt', Backquote: '`', Backspace: '⌫' };
  if (map[code]) return map[code];
  if (/^Key/.test(code)) return code.slice(3);
  if (/^Digit/.test(code)) return code.slice(5);
  if (/^Numpad/.test(code)) return 'Num ' + code.slice(6);
  return code;
}
