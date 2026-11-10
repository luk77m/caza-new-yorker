# Caza en el New Yorker · versión Godot (v0.5, 2D)

Port de la versión web a **Godot 4.3 o superior** en GDScript. Mantiene el 2D y las reglas de la v0.3:
encargos personales (8-10 por corredor), habitaciones con llave, forzar cerraduras, denuncias y fichado,
sabotajes (apagón, alarma de incendios, ascensores), policía, carteles de busca y captura, disfraces y bots.

## Abrir y jugar

1. Instala Godot 4.3+ (versión estándar, no hace falta la de .NET).
   En Debian: descarga el binario de https://godotengine.org/download/linux/ o usa Flatpak (`flatpak install flathub org.godotengine.Godot`).
2. En el gestor de proyectos: **Importar** y elige `godot/project.godot`.
3. Pulsa **F5** (Ejecutar proyecto).

Controles: WASD/flechas, Shift correr, E mantener para interactuar o hablar con un PNJ, E junto al ascensor
(elegir planta con 1-7) o junto a tu contacto (tienda), Tab mapa y encargos, clic derecho apuntar (cazador),
clic izquierdo disparar / cuchillo / llave inglesa, rueda zoom, Esc pausa, F11 pantalla completa,
Espacio cambiar de personaje como espectador. Ajustes (volumen, pasos, zoom, niebla, flechas) en el menú y en la pausa.

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
