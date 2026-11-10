# Caza en el New Yorker · versión Godot (v0.7, 2D)

Port de la versión web a **Godot 4.3 o superior** en GDScript. Mantiene el 2D y las reglas de la v0.3:
encargos personales (8-10 por corredor), habitaciones con llave, forzar cerraduras, denuncias y fichado,
sabotajes (apagón, alarma de incendios, ascensores), policía, carteles de busca y captura, disfraces y bots.

## Abrir y jugar

1. Instala Godot 4.3+ (versión estándar, no hace falta la de .NET).
   En Debian: descarga el binario de https://godotengine.org/download/linux/ o usa Flatpak (`flatpak install flathub org.godotengine.Godot`).
2. En el gestor de proyectos: **Importar** y elige `godot/project.godot`.
3. Pulsa **F5** (Ejecutar proyecto).

Controles: WASD/flechas, Shift correr, E o clic para hablar, comprar, ascensor o liberar, E mantenido para
encargos y cerraduras, Q cambiar lo que llevas en la mano, clic derecho apuntar, clic izquierdo usar,
Tab bloc de notas, M mapa, I inventario, rueda zoom, Esc pausa, F11 pantalla completa,
Espacio cambiar de personaje como espectador. Ajustes (volumen, pasos, zoom, niebla, flechas) en el menú y en la pausa.

## Novedades de la v0.7

- **Minijuegos** en encargos, cerraduras y trabajos (en vez de mantener E): secuencia de flechas, parar la aguja,
  mantener el equilibrio y conectar cables. Dificultad media, unos 3-8 s.
- **Puños:** noquean a cualquiera unos segundos (a la policía, menos). Sirven para escapar a los dos bandos.
- **Esposas del cazador** (adiós al cuchillo): esposas a un corredor por sorpresa y este tiene 3 s para meter una
  combinación de 4 flechas y zafarse. Si no, desaparece 10 s y reaparece en otro sitio, tú ves dónde están todos
  los corredores 10 s y los corredores reciben el aviso.
- **Policía:** dispara balas visibles con dispersión; los jugadores aguantan 3 impactos y recuperan salud poco a poco.
- **Pistola de los años 30 con silenciador**, chispas y humo al disparar, y el fogonazo se ve en pleno apagón.
- **Calle frente al vestíbulo:** acera, farolas, toldo y coches aparcados; se ve a través de las puertas. La
  policía llega en coche, aparca y entra. Un coche fúnebre de la policía se lleva los cadáveres descubiertos y deja
  la silueta de tiza.
- **Interior:** moquetas con medallones, mármol con vetas, parqué en espiga, puertas de madera, ascensores de latón
  y muebles con detalle (camas, pianos, bar con botellas, estanterías con libros...). Los ascensores ya no quedan
  en sombra.
- **Reloj** con las agujas en el sentido correcto. **Menú** art déco con rayos dorados, skyline y galería de
  personajes, y **tutorial** guiado de 7 pasos.

## Novedades de la v0.6

- **HUD nuevo:** minimapa con el nombre de la planta arriba a la izquierda, reloj de cronómetro arriba a la derecha,
  inventario rápido abajo a la izquierda (Q cambia lo que llevas en la mano), avisos arriba en el centro.
  Tab abre el bloc de notas con los encargos (se tachan al hacerlos), M el mapa e I el inventario.
- **Interacción:** hablar, comprar, ascensor, sobornar o liberar se hace pulsando E o haciendo clic encima, sin
  mantener. Los encargos y cerraduras se pueden empezar con un clic (se cancelan al moverte). Más alcance.
- **Economía:** los encargos ya no pagan. El vendedor ofrece trabajos extra por $50-90. Las carteras son raras.
  Los cazadores compran al vigilante de la entrada (amigo de la policía), no al contacto de los corredores.
- **Recompensa:** el primer corredor en terminar recibe una pistola y el chivatazo de un cazador (se le marca en
  rojo 45 s), con escena de cine: franjas negras, rótulo y el contacto que se acerca a dárselo. Evento raro: un
  policía con un café le da su placa y su pistola, y la policía deja de molestarle. Los demás pueden hacer los
  encargos de sus compañeros.
- **Matar policías y niveles de alarma:** nivel 1, refuerzos y cacheos (si llevas algo te esposan 1:30 en el
  vestíbulo; te libera un soborno de $250, la ganzúa de un compañero con minijuego o la llave de esposas caída;
  si escapas sin guardia y te pillan, grilletes). Nivel 2, federales registrando habitación por habitación, y el
  bando culpable paga en tiempo. Nivel 3, BLUEGEDDON: los huéspedes huyen, la policía dispara a cualquiera y los
  corredores pueden escapar con una cuerda (azotea) o la llave del muelle (sótano).
- **Gráficos:** visión con bordes rectos (polígono exacto, sin dientes), muros altos en perspectiva 3/4 con papel
  pintado y muebles con volumen, azotea abierta con la ciudad de noche, coches y el letrero de neón.
  Texturas y música propias opcionales en `assets/` (ver `assets/README.md`).
- **Menú principal** como el de la web, con una partida de fondo y música de swing de los años 30 generada por código.

## Novedades de la v0.5

- **Economía:** los corredores cobran $40 por encargo y encuentran carteras; los cazadores cobran por objetivo
  eliminado y por cada denuncia contra un corredor.
- **Tiendas:** el contacto del bar (Planta 2) vende a los corredores ganzúa, soborno, chivatazo y llave inglesa,
  y les compra chatarra y **soplos** (la descripción de un cazador que conozcan, que pasa a la policía).
  El conserje de recepción vende a los cazadores munición, traje limpio, rastro e insignia.
- **Cazador:** 8 balas (12 con la ventaja de munición) y cuchillo sin límite (clic izquierdo sin apuntar).
  Ventaja inicial a elegir: silenciador mejorado, copia de la llave maestra, munición extra o fondos reservados.
- **Disparos visibles:** fogonazo y trazada; los de la policía se oyen en toda la planta y asustan a los PNJ.
  Un disparo con silenciador se oye de cerca.
- **Ascensor:** tarda 2 s en llegar y hay que esperar 5 s entre viajes. Hay una **cizalla** (una por partida) con la
  que un corredor puede romper los ascensores 70 s, con chispas.
- **PNJ:** se puede hablar con ellos (mantén E). A veces dan rumores: a los corredores, el aspecto de un cazador que ha
  llamado la atención; a los cazadores, la planta de un objetivo.
- **Sonido** generado por código: pasos muy bajos, disparos, cuchillo, alarma, apagón, ascensor, chispas, dinero.
- **Gráficos:** luces de lámparas con mezcla aditiva, niebla con borde suave, muros art déco con sombras de contacto,
  manchas de sangre, chispas, sacudida de cámara, viñeta roja cuando sube la sospecha, flechas hacia tus encargos,
  anillo sobre lo que puedes usar y una partida entre bots de fondo en el menú principal.

## Estructura

```
project.godot
scenes/main.tscn           escena raíz (todo lo demás se crea por código)
data/hotel.json            plantas, habitaciones, encargos (exportado desde src/map.js)
scripts/sim/               simulación sin nodos (sirve igual para un servidor dedicado)
  cfg.gd                   todos los números de equilibrio
  sim.gd                   reglas, IA de bots, policía, percepción (port de src/sim.js)
  hotel.gd                 carga de data/hotel.json
  nav.gd                   caminos (BFS) y línea de visión
  ent.gd world.gd task.gd room.gd outfit.gd items.gd ...
scripts/game/              presentación
  main.gd                  controles, cámara y bucle (60 pasos/s en _physics_process)
  world_view.gd            dibujo de la planta, niebla y luz
  painter.gd               dibujo procedural de casillas, muebles y personajes
  hud.gd                   menú, HUD, panel Tab, ascensor, pausa y final
  minimap.gd portrait.gd
```

## Regenerar los datos del mapa

El mapa sigue definido en `src/map.js` (versión web). Si lo cambias:

```bash
node tools/export_godot_data.js
```

## Exportar

En **Proyecto › Exportar**, pestaña Recursos, añade `*.json` a "Filtros para exportar archivos que no son recursos"
para que se incluya `data/hotel.json`.

## Estado

- Port hecho sin poder abrir Godot en el entorno donde se escribió: pasa una comprobación estática
  (`python3 tools/gdlint_lite.py`), pero es la primera vez que se ejecuta. Si sale un error en la consola
  de Godot, copia el mensaje (fichero y línea) para corregirlo.
- Los gráficos son procedurales, como en la web. El siguiente paso natural es pasar a sprites y `TileMapLayer`.
