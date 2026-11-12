#!/usr/bin/env bash
# Actualiza Hidden Lead desde el repositorio: descarga los cambios y, solo si hay versión nueva,
# recompila y actualiza la instalación (no vuelve a descargar Godot ni reinstala desde cero).
# Si no había nada instalado, hace la instalación completa.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
msg() { printf '\033[1;33m==>\033[0m %s\n' "$*"; }

if git rev-parse --git-dir >/dev/null 2>&1; then
	msg "Buscando cambios en el repositorio…"
	git pull --ff-only || msg "No he podido descargar cambios; sigo con la versión que hay aquí."
fi
NEW="$(git describe --tags --always --dirty 2>/dev/null || echo desconocida)"
OLD="$(cat "${XDG_DATA_HOME:-$HOME/.local/share}/hidden-lead/VERSION" 2>/dev/null || true)"
if [[ -n "$OLD" && "$OLD" == "$NEW" ]]; then
	msg "Ya tienes la última versión instalada ($NEW)."
	exit 0
fi
if [[ -z "$OLD" ]]; then
	msg "No hay ninguna versión instalada: compilo e instalo la $NEW."
else
	msg "Hay versión nueva: $OLD → $NEW. Recompilo y actualizo."
fi
exec "$ROOT/build-linux.sh" --install
