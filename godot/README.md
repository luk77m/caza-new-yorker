# Hidden Lead (título provisional) · versión Godot (v0.13, 2D)

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
R registrar muebles y cadáveres, F arrastrar cuerpos, Espacio cambiar de personaje como espectador. Ajustes (volumen, pasos, zoom, niebla, flechas) en el menú y en la pausa.

## Novedades de la v0.13 «La central» (segunda ronda de pruebas)

Arreglos:

- **Reloj:** el sombreado dorado ahora se consume en el sentido de las agujas.
- **Victoria:** los corredores solo pierden si mueren todos. El cartel del cazador enseña dos rostros y, cuando
  caen, la central envía los que faltan.
- **Puertas con llave:** ya no se abren solas al acercarte ni al apuntar; solo si tienes llave, las has abierto
  o estás dentro.
- **Primera persona:** las puertas del ascensor se ven como puertas (latón, abanico art déco, indicador de planta).
  La azotea tiene profundidad: más allá del pretil se ve la ciudad treinta pisos más abajo, hay luna, dos filas de
  rascacielos, pretil de ladrillo con barandilla de hierro y se ve mucho más lejos. Los perros tienen forma de
  perro. La luz de los muros es continua y hay sombra al pie de las paredes.
- **Sin letrero:** el cartel «New Yorker» de la azotea ha desaparecido; en su lugar hay una gran antena de radio
  con baliza roja (también en la vista desde arriba).

Mecánicas:

- **La central:** con la sospecha alta, un agente de la sala de escuchas te avisa por el pinganillo en una
  ventanita. Al límite, un botones te busca y te hace tres preguntas sobre el hotel (plantas de las salas y algún
  dato del New Yorker). Con dos fallos te echan: vuelves al minuto con otra cara y otro nombre de agente.
  Noquear al botones antes de que llegue también vale.
- **Botín:** los objetos ya no están por el suelo. Con **R** registras mesillas, escritorios, sofás, mesas, cajas
  y cadáveres, y puedes coger o dejar cosas (también dinero, de 20 en 20). Lo que dejas en una habitación ajena
  se lo llevan las limpiadoras al minuto y medio; lo que hay en un cadáver se pierde cuando se lo llevan. Quien
  muere deja en su cuerpo lo que llevaba.
- **Ganzúas:** abren las cerraduras con un minijuego propio (A/D busca el punto, mantener E gira el bombín) y se
  rompen si las fuerzas. Se llevan hasta tres y los vendedores tienen más. Sin ganzúa se puede forzar a lo bruto.
- **Minijuegos nuevos:** instalar un micrófono (elegir escondite, colocarlo cuando nadie mira y conectarlo) y
  esconder paquetes debajo de un mueble.
- **Vendedores:** salen con un **$** en el mapa y sobre su cabeza, y una flecha te lleva al tuyo. El bando
  contrario puede noquearlo (1 min) o abatirlo (2 min) una sola vez; vuelve vendado, con los precios rebajados y a
  veces con un «soplo de venganza».
- **Perros:** si el dueño ve que te llevas a su perro (o lo echa de menos), tienes 10 s para soltarlo. Si no, te
  denuncia, y si la policía te ve con él te retiene 15 s y se lo devuelve.
- **Personaje:** antes de la partida eliges género, ropa, sombrero, pelo y piel. Ponerte ropa del otro género es
  un disfraz penoso: la sospecha sube más deprisa.
- **Habilidades de corredor:** uno o dos corredores por partida reciben una al azar (piernas ligeras, dedos de
  seda, cara de póquer o derecha de hierro).
- **Práctica:** el tutorial es ahora una partida de práctica sin reloj ni consecuencias, con una parte de
  corredor y otra de cazador.
- **Presentación:** cada ronda empieza con tu equipo a la vista y el contrario en silueta, con un acorde de
  suspense.

Pendiente de esta ronda: separar más la indumentaria (zapatos, complementos) y usar sprites de un paquete de
arte en vez de dibujo por código.

## Novedades de la v0.12 «El hotel vivo» (resto de propuestas del tester)

- **Día y noche:** el día dura 5 minutos y la noche 4. Los huéspedes desayunan, almuerzan, pasan la tarde en los
  salones, cenan, toman copas y se van a dormir a su habitación. Quien duerme no ve ni oye nada.
  De noche el hotel baja las luces. La hora y la franja salen en un aviso del HUD.
- **Pánico y alerta general:** el pánico (cuerpos descubiertos, crímenes con testigos, disparos) hace que lleguen
  más policías y se queden más tiempo; la alerta general (llamadas y denuncias) hace que todos vean más lejos y
  sospechen antes. Los dos bajan solos con el tiempo.
- **Dos guardias de seguridad** que van donde está la gente (comidas, salones, bar) y avisan por radio al momento.
- **Conductos de ventilación:** rejillas en los muros; con el minijuego de los cuatro tornillos pasas a la
  siguiente rejilla de la planta (también dentro de habitaciones cerradas). Las rejillas quedan abiertas.
- **Perros:** tres huéspedes tienen perro. Si matas al dueño, el perro va hasta el cuerpo (aunque esté en un
  armario) y ladra hasta que alguien lo encuentra. No abren puertas: cógelo en brazos (E) y enciérralo.
- **Deshacerse del arma:** con la pistola en la mano, E sobre alguien inconsciente se la coloca; cuando despierte
  y lo vea la policía, se lo llevan a él, se retiran los carteles y baja el pánico. Tú te quedas sin pistola.
- Sigue pendiente: plantas más grandes con pasillos de servicio (hay que rediseñar el mapa).

## Novedades de la v0.11 «Sigilo» (propuestas del tester)

- **Sangre:** charcos que se pisan y dejan huellas, salpicaduras a quien esté cerca (y al asesino a quemarropa),
  rastro al arrastrar un cuerpo. Con la **fregona** (por el hotel o en la tienda) se limpia.
- **Correr** delante de la gente levanta sospechas. Los PNJ **esquivan los cadáveres**.
- **Ropa:** cambiarte baja tu sospecha, pero si te ven hacerlo ese traje queda «quemado». Con uniforme del
  personal, los empleados del mismo oficio no te reconocen cuando ya se ha descubierto algún muerto.
- **Noquear:** los civiles quedan inconscientes más tiempo; puedes vaciarles los bolsillos y quitarles la ropa
  (limpia). Al despertar, avisan.
- **F: arrastrar** cadáveres o inconscientes; **esconderlos en un armario** ya registrado, o esconderte tú.
  La policía que pasa junto al armario puede encontrar el cuerpo.
- **Ganzúas limitadas** por partida (el anfitrión empieza con una; el resto están por el hotel sin marcar).
  Forzar una puerta hace ruido: quien esté dentro avisa.
- El **personal limpia** la sangre cuando la policía se lleva el cuerpo y baja a lavar el uniforme.
- **Puntuación** al final de la partida.
- Queda para más adelante: ciclo día/noche con rutinas, pánico general, guardias, conductos, mascotas, plantas más grandes.

## Novedades de la v0.10

- Título provisional **Hidden Lead**; menú sin la línea superior y torre sin letrero, con pilastras, cornisas,
  almenas art déco, corona iluminada con focos, depósitos de agua en las alas y marquesina con bombillas.
- Arma y mano en **3D** (corredera pavonada, cachas de nogal, silenciador con anillos, dedos alrededor de la
  empuñadura, manga y puño de la camisa) con luz de la escena, retroceso y fogonazo con destello.
- Muebles más bajos y a escala de los personajes; solo tapan a alguien si están entre tus ojos y él.
- **Puertas que se cierran:** se abren al pasar alguien y se cierran solas; cerradas tapan la vista
  (en primera persona y en la vista cenital, y también para los PNJ y la policía).

## Novedades de la v0.9

- **Primera persona al apuntar**: con la pistola en la mano, mantén el clic derecho y la cámara pasa a los ojos del personaje.
  El ratón mira, el clic izquierdo dispara, WASD se mueve respecto a la mirada y **Q / E** te asoman a izquierda y derecha
  (ladea la cabeza y desplaza el ojo y el cañón sin atravesar muros, así puedes disparar desde una esquina).
  Al soltar el clic derecho vuelves a la vista cenital mirando hacia el mismo sitio.
- La vista es un raycaster sobre el mismo mapa: suelos con mármol, alfombras y parqué por shader, techos con casetones,
  luz de las lámparas, muros con zócalo, moldura dorada, papel pintado, cuadros, apliques y ventanas a la ciudad,
  dinteles en las puertas, muebles en 3D, arañas de luz, coches en la calle y el skyline desde la azotea.
- Mano con una pistola con silenciador de los años 30: retroceso, corredera que se abre al quedarse sin balas,
  fogonazo pequeño, humo, casquillos, mira que se pone roja con un objetivo en alcance y marca de impacto.
- Se puede desactivar (o cambiar la sensibilidad del ratón) en Ajustes.

## Novedades de la v0.8

- Menú nuevo con la **torre del Hotel New Yorker en 3D** como símbolo (bloques art déco con ventanas encendidas,
  letrero rojo, antena y focos), título y menú a la derecha, fondo nocturno con skyline.
- **Nitidez:** fuente MSDF (se ve definida a cualquier zoom), filtrado lineal y antialias. Si pones
  `assets/fonts/ui.ttf` o `assets/fonts/deco.ttf` (por ejemplo Josefin Sans o Poiret One, licencia OFL) se usan.
- **Pies** corregidos: de frente cada pie se levanta por turnos y de lado la puntera mira hacia donde caminas.
- **Matar inocentes tiene consecuencias:** cada civil muerto que se descubre (por testigos o al encontrar el
  cuerpo) cuenta. 2 = alarma 1, 4 = alarma 2 y 5 = Bluegeddon directo.
- **Salas con más detalle:** cuadros, apliques, ventanas a la ciudad en los muros exteriores y placas de latón con
  el nombre de cada sala.

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
