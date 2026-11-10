# Recursos opcionales

El juego dibuja todo por código, pero si pones aquí ficheros con estos nombres los usa en su lugar
(no hay que tocar código; Godot los importa solo al abrir el proyecto).

## Casillas — `tiles/<nombre>.png` (32×32 px)

`wall`, `marble`, `carpet`, `hall`, `conc`, `wood`, `door`, `elev`, `stairs`, `roof`, `terrace`, `rail`

## Muebles — `furniture/<tipo>.png` (se estiran al tamaño del mueble)

`bed`, `desk`, `table`, `sofa`, `plant`, `bar`, `piano`, `shelf`, `ward`, `sink`, `washer`, `boiler`, `crate`,
`stove`, `safe`, `column`, `bench`, `recdesk`, `night`, `mail`, `stage`, `cart`, `gen`, `steel`, `vent`,
`antenna`, `scope`, `phone`, `rug`

## Fuentes — `fonts/ui.ttf` y `fonts/deco.ttf`

Fuente del juego y fuente de los títulos. Por ejemplo, de Google Fonts (licencia OFL): Josefin Sans para `ui.ttf`
y Poiret One o Limelight para `deco.ttf`. Si no están, se usan fuentes del sistema.

## Música del menú — `music/menu.ogg`

Si existe, suena en lugar de la pieza generada por código (se repite en bucle).

## Dónde buscar recursos libres

- Kenney (CC0): https://kenney.nl/assets — por ejemplo "Roguelike Indoors" o "Tiny Town".
- OpenGameArt (revisa la licencia de cada uno): https://opengameart.org
- Música de los años 20-30 de dominio público: Internet Archive (colección "78rpm") o Musopen.
  Comprueba siempre que la grabación, y no solo la partitura, sea de dominio público.
