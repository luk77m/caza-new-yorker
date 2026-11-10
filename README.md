# Caza en el New Yorker

Prototipo jugable (HTML5 Canvas, un solo archivo) de un juego multijugador asimétrico ambientado en el hotel New Yorker, 1930, art déco. De momento se juega contra bots.

- **Cazadores** (máx. 2): policía secreta infiltrada. Ganan eliminando a los dos retratados en su cartel.
- **Corredores** (máx. 4): mafia contratada. Ganan si todos terminan sus encargos, si sobreviven hasta que llegue el cliente o si abaten a los cazadores.

## Jugar

- **Versión Godot (v0.9, rama `godot`):** abre `godot/project.godot` con Godot 4.3+ y pulsa F5. Detalles en [`godot/README.md`](godot/README.md).
- **Versión web (v0.3):** abre `index.html` en el navegador. No necesita servidor ni dependencias.

## Estructura

```
src/            código fuente por módulos
  core.js       constantes y utilidades (CFG)
  settings.js   ajustes y teclas (localStorage)
  map.js        las 7 plantas, habitaciones, catálogo de encargos
  outfits.js    ropa y aspecto de los personajes
  nav.js        búsqueda de caminos
  sim.js        simulación (sin DOM): reglas, IA de bots, policía, sabotajes
  tex.js        texturas
  render.js     visibilidad y niebla
  view.js       dibujo de la escena y de los mapas
  title.js      menú principal
  ui.js         HUD, paneles, entrada, flujo de partida
  head.html     HTML y CSS
build.py        concatena src/ en index.html (+ bundle.js)
mktest.py       genera index_test.html, que expone window.__T para las pruebas
test/           pruebas (Node y Playwright)
tools/          exportador de datos para Godot y comprobación estática del GDScript
godot/          versión Godot 4 (ver godot/README.md)
```

`core`, `map`, `outfits`, `nav` y `sim` no tocan el DOM, así que las pruebas de reglas se ejecutan directamente en Node.

## Desarrollo

```bash
python3 build.py        # genera index.html y bundle.js
python3 mktest.py       # genera index_test.html (para las pruebas de interfaz)
npm run build           # las dos cosas

npm test                # pruebas de reglas y simulación en Node (N=96 partidas con N=96 npm test)
npm run test:ui         # pruebas de interfaz; necesita Playwright (npm i -D playwright)
```

`index.html` se versiona porque es el juego terminado; `bundle.js` e `index_test.html` se regeneran y no se suben.

Flujo recomendado: editar `src/`, `npm run build`, `npm test`, commit. Etiquetar cada versión jugable (`git tag v0.4`).

## Versiones

| Versión | Qué trae |
|---|---|
| v0.2 | Mapa de 7 plantas, bots, policía, testigos, carteles de busca, disfraces, menú principal |
| v0.4 | Port a Godot 4 (GDScript, 2D) con las reglas de la v0.3; datos del mapa exportados a JSON |
| v0.8 | Godot: menú con la torre en 3D, texto nítido, pies corregidos, alarma por inocentes muertos, salas con más detalle |
| v0.9 | Godot: primera persona al apuntar con la pistola (mano y arma de los años 30, Q/E para asomarse) |
| v0.7 | Godot: minijuegos en los encargos, puñetazos, esposas con combinación de flechas, balas visibles y salud, pistola antigua con partículas, calle con coches de policía y coche fúnebre, interior detallado, menú art déco y tutorial |
| v0.6 | Godot: HUD nuevo (minimapa, cronómetro, inventario rápido, bloc de notas, mapa, inventario), interacción con pulsar/clic, recompensa con cinemática, alarmas por matar policías hasta el Bluegeddon, visión sin dientes, perspectiva 3/4, azotea con ciudad, menú con música |
| v0.5 | Godot: economía y tiendas, soplos, munición y cuchillo, ventajas del cazador, ascensor con espera y cizalla, hablar con PNJ, sonido, ajustes y mejoras visuales |
| v0.3 | Pantalla completa por defecto, 8-10 encargos por corredor, puertas con llave (forzar o llave maestra), denuncias y fichado, sabotajes (apagón, alarma de incendios, ascensores), nombres azules para aliados |

## Siguiente (tanda 2)

- Economía: dinero, vender y comprar información.
- Cazador: 8 balas y luego cuerpo a cuerpo, ventaja inicial.
- Disparos visibles (silenciado discreto, policía llamativo).
- Ascensor con 5 s de espera y un objeto raro que lo rompe, con animación.
- Sonidos de pasos y de arma.
- Más interacción con los PNJ.
- Sprites y `TileMapLayer` en la versión Godot.
- Multijugador en red con servidor dedicado (la simulación de `godot/scripts/sim` no depende de nodos).
