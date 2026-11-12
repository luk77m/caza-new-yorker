#!/usr/bin/env bash
# Instala Hidden Lead para tu usuario, o lo ACTUALIZA si ya tenías una versión anterior.
# No hace falta Godot ni permisos de administrador.
#
#   ./instalar.sh                 instala o actualiza (conserva tus ajustes)
#   ./instalar.sh --forzar        reinstala aunque ya tengas esta misma versión (o una más nueva)
#   ./instalar.sh --desinstalar   lo quita todo (los ajustes del juego se conservan)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME="hidden-lead"
BIN_SRC="$HERE/$NAME.x86_64"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
APP_DIR="$DATA/$NAME"
BIN_DIR="$HOME/.local/bin"
APPS="$DATA/applications"
DESKTOP_FILE="$APPS/$NAME.desktop"
DESK_DIR="$(command -v xdg-user-dir >/dev/null && xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Escritorio")"

msg()  { printf '\033[1;33m==>\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

if [[ "${1:-}" == "--desinstalar" ]]; then
	rm -rf "$APP_DIR"
	rm -f "$BIN_DIR/$NAME" "$DESKTOP_FILE" "$DESK_DIR/$NAME.desktop"
	command -v update-desktop-database >/dev/null && update-desktop-database "$APPS" 2>/dev/null || true
	msg "Hidden Lead desinstalado. Tus ajustes siguen en $DATA/godot/app_userdata/"
	exit 0
fi

[[ -f "$BIN_SRC" ]] || fail "No encuentro $NAME.x86_64 junto a este script."
NEW="$(cat "$HERE/VERSION" 2>/dev/null || echo desconocida)"
OLD="$(cat "$APP_DIR/VERSION" 2>/dev/null || true)"

if [[ -z "$OLD" ]]; then
	msg "Instalación nueva de Hidden Lead $NEW"
elif [[ "$OLD" == "$NEW" && "${1:-}" != "--forzar" ]]; then
	msg "Ya tienes Hidden Lead $NEW instalado. No hay nada que actualizar (usa --forzar para reinstalar)."
	exit 0
else
	newest="$(printf '%s\n%s\n' "$OLD" "$NEW" | sort -V | tail -n 1)"
	if [[ "$newest" == "$OLD" && "$OLD" != "$NEW" && "${1:-}" != "--forzar" ]]; then
		msg "Tienes instalada la $OLD, que es más nueva que este paquete ($NEW). No toco nada (usa --forzar para bajar de versión)."
		exit 0
	fi
	msg "Actualizando Hidden Lead: $OLD → $NEW (tus ajustes y partidas se conservan)"
fi

mkdir -p "$APP_DIR" "$BIN_DIR" "$APPS"
# se copia a un temporal y se cambia de golpe: si el juego está abierto no se corrompe
install -m 755 "$BIN_SRC" "$APP_DIR/$NAME.x86_64.nuevo"
mv -f "$APP_DIR/$NAME.x86_64.nuevo" "$APP_DIR/$NAME.x86_64"
[[ -f "$HERE/$NAME.svg" ]] && install -m 644 "$HERE/$NAME.svg" "$APP_DIR/$NAME.svg"
echo "$NEW" > "$APP_DIR/VERSION"
ln -sf "$APP_DIR/$NAME.x86_64" "$BIN_DIR/$NAME"

cat > "$DESKTOP_FILE" <<DESK
[Desktop Entry]
Type=Application
Version=1.0
Name=Hidden Lead
GenericName=Juego de sigilo
Comment=Cazadores contra corredores en un hotel de 1930
Exec="$APP_DIR/$NAME.x86_64"
Icon=$APP_DIR/$NAME.svg
Terminal=false
Categories=Game;ActionGame;
StartupWMClass=Hidden Lead
DESK
chmod 644 "$DESKTOP_FILE"
command -v update-desktop-database >/dev/null && update-desktop-database "$APPS" 2>/dev/null || true

# icono en el escritorio (si existe la carpeta)
if [[ -d "$DESK_DIR" ]]; then
	install -m 755 "$DESKTOP_FILE" "$DESK_DIR/$NAME.desktop"
	command -v gio >/dev/null && gio set "$DESK_DIR/$NAME.desktop" metadata::trusted true 2>/dev/null || true
	msg "Icono creado en $DESK_DIR"
fi
msg "Listo. Búscalo como «Hidden Lead» en el menú de aplicaciones, o pulsa el icono del escritorio."
