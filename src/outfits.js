/* ===== trajes: cada traje tiene un id; el cartel de busca y captura se basa en ese id ===== */
var OID = 0, USED_OUTFITS = {};
var SUITS = [['#2b3a4f', 'azul marino'], ['#4a4a4e', 'gris marengo'], ['#5a3b28', 'marrón'], ['#3b5a3a', 'verde botella'], ['#6a2a30', 'burdeos'], ['#8a826e', 'beige'], ['#1c1c22', 'negro'], ['#5d4b6a', 'ciruela'], ['#7a6a2c', 'mostaza apagado']];
var DRESSES = [['#8c2f39', 'rojo'], ['#2f7478', 'verde azulado'], ['#c0a050', 'dorado'], ['#5d4b8a', 'violeta'], ['#2a4a7a', 'azul']];
var TIES = ['#8c2f39', '#c9a24b', '#2f7478', '#e9e4d6', '#4a2f6a'];
var HATS = [['fedora', 'sombrero de fieltro'], ['bowler', 'bombín'], ['cap', 'gorra plana'], ['none', 'sin sombrero']];
var HATC = [['#2a2420', 'negro'], ['#6b5b45', 'marrón'], ['#8a8478', 'gris'], ['#1d2a38', 'azul oscuro'], ['#7a5a30', 'canela']];
var HAIRS = ['#1a1410', '#3a2a1c', '#6a4a2a', '#b9a88a', '#7a7a7a'];
var SKINS = ['#e1b98f', '#c99a70', '#a8744e', '#f0cfaa'];
var HS_M = ['short', 'slick', 'side', 'short', 'bald'], HS_F = ['bob', 'bun', 'wave'];
function traits(female, extra) { return { hs: pick(female ? HS_F : HS_M), glasses: rnd() < (female ? 0.2 : 0.28), stache: !female && rnd() < (extra || 0.3), build: 0.92 + rnd() * 0.2 }; }

function darker(hex, k) {
  var n = parseInt(hex.slice(1), 16), r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
  return 'rgb(' + Math.round(r * k) + ',' + Math.round(g * k) + ',' + Math.round(b * k) + ')';
}
function newGuest(female) {
  var o, key, tries = 0;
  do {
    var hat = female ? ['cloche', 'sombrero cloché'] : pick(HATS), hc = pick(HATC), su = female ? pick(DRESSES) : pick(SUITS), tie = pick(TIES);
    key = (female ? 'f' : 'm') + su[0] + hat[0] + hc[0] + (female ? '' : tie);
    o = { id: 'o' + (++OID), kind: female ? 'dress' : 'suit', coat: su[0], coatN: su[1], pants: female ? su[0] : darker(su[0], 0.78), tie: tie,
      hat: { t: hat[0], c: female ? su[0] : hc[0], n: hat[1], cn: female ? su[1] : hc[1] }, hair: pick(HAIRS), skin: pick(SKINS), staffRole: null, blood: false, key: key };
    var tr0 = traits(female); o.hs = tr0.hs; o.glasses = tr0.glasses; o.stache = tr0.stache; o.build = tr0.build; o.key += o.hs + (o.glasses ? 'g' : '') + (o.stache ? 'm' : '');
    key = o.key;
    tries++;
  } while (USED_OUTFITS[key] && tries < 40);
  USED_OUTFITS[key] = true;
  return o;
}
var STAFF = {
  bell: { coat: '#8c2f39', coatN: 'librea granate', pants: '#2a1a1c', hat: { t: 'pill', c: '#8c2f39', n: 'gorro de botones', cn: 'granate' }, label: 'Botones' },
  maid: { coat: '#23262c', coatN: 'uniforme negro con delantal', pants: '#23262c', hat: { t: 'maidcap', c: '#efeadb', n: 'cofia', cn: 'blanca' }, label: 'Camarera', dress: true, apron: true },
  chef: { coat: '#efeadb', coatN: 'chaqueta de cocinero', pants: '#4a4f58', hat: { t: 'chef', c: '#f4f1ea', n: 'gorro de cocinero', cn: 'blanco' }, label: 'Cocinero' },
  tech: { coat: '#4a5f6e', coatN: 'mono de trabajo', pants: '#4a5f6e', hat: { t: 'cap', c: '#d6c58a', n: 'gorra', cn: 'crema' }, label: 'Técnico' },
  waiter: { coat: '#f1eee4', coatN: 'chaqueta blanca de camarero', pants: '#16161b', hat: { t: 'none', c: '#000', n: 'sin sombrero', cn: '' }, label: 'Camarero', bow: true },
  recep: { coat: '#2c3f52', coatN: 'traje de recepción', pants: '#1d2a38', hat: { t: 'none', c: '#000', n: 'sin sombrero', cn: '' }, label: 'Recepción', tie: '#c9a24b' }
};
function newStaff(role) {
  var s = STAFF[role], tr1 = traits(!!s.dress, 0.25);
  return { hs: s.dress ? 'bun' : (role === 'chef' ? 'short' : tr1.hs), glasses: tr1.glasses && role !== 'chef', stache: tr1.stache, build: tr1.build, id: 'o' + (++OID), kind: s.dress ? 'dress' : 'staff', coat: s.coat, coatN: s.coatN, pants: s.pants, tie: s.tie || '#8c2f39',
    hat: { t: s.hat.t, c: s.hat.c, n: s.hat.n, cn: s.hat.cn }, hair: pick(HAIRS), skin: pick(SKINS), staffRole: role, apron: !!s.apron, bow: !!s.bow, blood: false, key: 'staff' + role };
}
function newPolice() {
  return { hs: 'short', glasses: false, stache: rnd() < 0.55, build: 1.06, id: 'o' + (++OID), kind: 'police', coat: '#1f2f4a', coatN: 'uniforme de policía', pants: '#1a2438', tie: '#1a1a1a',
    hat: { t: 'police', c: '#1f2f4a', n: 'gorra de policía', cn: 'azul' }, hair: '#2a2018', skin: pick(SKINS), staffRole: null, blood: false, key: 'police' };
}
function newUnder(skin, hair, src) {
  src = src || {};
  return { hs: src.hs || 'short', glasses: !!src.glasses, stache: !!src.stache, build: src.build || 1, id: 'o' + (++OID), kind: 'under', coat: '#d8d1bd', coatN: 'ropa interior', pants: '#cfc6b0', tie: null, hat: { t: 'none', c: '#000', n: 'sin sombrero', cn: '' }, hair: hair || '#3a2a1c', skin: skin || '#e1b98f', staffRole: null, blood: false, key: 'under' };
}
function cloneOutfit(o) {
  var c = {}; for (var k in o) c[k] = o[k]; c.hat = { t: o.hat.t, c: o.hat.c, n: o.hat.n, cn: o.hat.cn }; return c;
}
function describeOutfit(o) {
  var s = o.staffRole ? STAFF[o.staffRole].label + ': ' + o.coatN : (o.kind === 'dress' ? 'Vestido ' : 'Traje ') + o.coatN;
  if (o.hat.t !== 'none') s += ', ' + o.hat.n + (o.hat.cn ? ' ' + o.hat.cn : '');
  if (o.glasses) s += ', gafas';
  if (o.stache) s += ', bigote';
  if (o.hs === 'bald') s += ', calvo';
  return s;
}
