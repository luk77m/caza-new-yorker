#!/usr/bin/env bash
# Compila Hidden Lead para Linux (probado para Debian 13) en un único ejecutable.
# Quien lo reciba NO necesita tener Godot instalado: solo ejecuta el fichero.
#
# Uso:
#   ./build-linux.sh              genera dist/hidden-lead.x86_64 y dist/hidden-lead-linux-x86_64.tar.gz
#   ./build-linux.sh --install    además lo instala (o actualiza) para tu usuario, con icono en el menú y el escritorio
#   ./build-linux.sh --clean      borra la caché de descargas (.build-cache) y dist/
#
# Variables opcionales:
#   GODOT_VERSION=4.7   versión de Godot que se descarga (por defecto, la que diga godot/project.godot)
#   GODOT_BIN=/ruta     usa un Godot ya descargado (versión normal, no Flatpak) en vez de bajarlo
#
# El script descarga el editor de Godot y las plantillas de exportación oficiales (solo la primera vez;
# las plantillas ocupan alrededor de 1 GB de descarga) y los guarda en .build-cache/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$ROOT/godot"
CACHE="$ROOT/.build-cache"
DIST="$ROOT/dist"
NAME="hidden-lead"
ARCH="x86_64"

msg()  { printf '\033[1;33m==>\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

if [[ "${1:-}" == "--clean" ]]; then
	rm -rf "$CACHE" "$DIST"
	msg "Caché y dist/ borrados."
	exit 0
fi

[[ -f "$PROJECT/project.godot" ]] || fail "No encuentro $PROJECT/project.godot. Ejecuta el script desde el repositorio."
[[ "$(uname -m)" == "x86_64" ]] || fail "Este script solo compila para x86_64 (tu máquina es $(uname -m))."

# ---------------------------------------------------------------- dependencias del sistema
need=()
command -v unzip >/dev/null || need+=(unzip)
command -v curl  >/dev/null || command -v wget >/dev/null || need+=(curl)
# librerías que necesita Godot incluso sin ventana
for lib in libfontconfig.so.1 libGL.so.1; do
	ldconfig -p 2>/dev/null | grep -q "$lib" || case "$lib" in
		libfontconfig.so.1) need+=(libfontconfig1) ;;
		libGL.so.1)         need+=(libgl1) ;;
	esac
done
if (( ${#need[@]} )); then
	msg "Faltan paquetes: ${need[*]}"
	if command -v apt-get >/dev/null; then
		msg "Los instalo con apt (te pedirá la contraseña de sudo)…"
		sudo apt-get update -qq
		sudo apt-get install -y "${need[@]}"
	else
		fail "Instala a mano: ${need[*]}"
	fi
fi

download() {  # download URL DESTINO
	local url="$1" out="$2"
	msg "Descargando $(basename "$out")…"
	if command -v curl >/dev/null; then
		curl -fL --retry 3 --progress-bar -o "$out.part" "$url" || { rm -f "$out.part"; return 1; }
	else
		wget -q --show-progress -O "$out.part" "$url" || { rm -f "$out.part"; return 1; }
	fi
	mv "$out.part" "$out"
}

# ---------------------------------------------------------------- versión de Godot
if [[ -z "${GODOT_VERSION:-}" ]]; then
	GODOT_VERSION="$(grep -oP 'config/features=PackedStringArray\("\K[0-9]+\.[0-9]+(\.[0-9]+)?' "$PROJECT/project.godot" || true)"
	[[ -n "$GODOT_VERSION" ]] || GODOT_VERSION="4.3"
fi
TAG="${GODOT_VERSION}-stable"
BASE="https://github.com/godotengine/godot/releases/download/${TAG}"
msg "Godot $TAG"
mkdir -p "$CACHE" "$DIST"

# ---------------------------------------------------------------- editor (para exportar sin ventana)
if [[ -n "${GODOT_BIN:-}" ]]; then
	[[ -x "$GODOT_BIN" ]] || fail "GODOT_BIN=$GODOT_BIN no es ejecutable."
	GODOT="$GODOT_BIN"
else
	GODOT="$CACHE/Godot_v${TAG}_linux.${ARCH}"
	if [[ ! -x "$GODOT" ]]; then
		download "$BASE/Godot_v${TAG}_linux.${ARCH}.zip" "$CACHE/editor.zip" \
			|| fail "No he podido descargar Godot $TAG. Comprueba la versión (GODOT_VERSION=4.x ./build-linux.sh) o tu conexión."
		unzip -oq "$CACHE/editor.zip" -d "$CACHE"
		rm -f "$CACHE/editor.zip"
		chmod +x "$GODOT"
	fi
fi

# ---------------------------------------------------------------- plantilla de exportación de Linux
# Godot la busca en ~/.local/share/godot/export_templates/<versión>.stable/
TPL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${GODOT_VERSION}.stable"
TPL="$TPL_DIR/linux_release.${ARCH}"
if [[ ! -f "$TPL" ]]; then
	TPZ="$CACHE/templates-${TAG}.tpz"
	if [[ ! -f "$TPZ" ]]; then
		download "$BASE/Godot_v${TAG}_export_templates.tpz" "$TPZ" \
			|| fail "No he podido descargar las plantillas de exportación de Godot $TAG."
	fi
	msg "Extrayendo la plantilla de Linux…"
	mkdir -p "$TPL_DIR"
	unzip -oqj "$TPZ" "templates/linux_release.${ARCH}" "templates/version.txt" -d "$TPL_DIR"
	[[ -f "$TPL" ]] || fail "La plantilla no está dentro del .tpz descargado."
	rm -f "$TPZ"   # ya no hace falta (ocupa mucho)
fi

# ---------------------------------------------------------------- perfil de exportación
PRESET="$PROJECT/export_presets.cfg"
if ! grep -q 'name="Linux"' "$PRESET" 2>/dev/null; then
	msg "Creando godot/export_presets.cfg"
	cat > "$PRESET" <<'EOF'
[preset.0]

name="Linux"
platform="Linux"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="*.json"
exclude_filter=""
export_path=""
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.0.options]

custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=0
binary_format/embed_pck=true
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
binary_format/architecture="x86_64"
EOF
fi

# ---------------------------------------------------------------- exportar
OUT="$DIST/$NAME.$ARCH"
rm -f "$OUT"
msg "Importando recursos…"
"$GODOT" --headless --path "$PROJECT" --import >/dev/null 2>&1 || true
msg "Exportando el juego…"
"$GODOT" --headless --path "$PROJECT" --export-release "Linux" "$OUT" 2>&1 | grep -v '^$' | tail -n 25 || true
[[ -s "$OUT" ]] || fail "La exportación no ha generado el ejecutable. Mira los mensajes de arriba."
chmod +x "$OUT"

VERSION="$(git -C "$ROOT" describe --tags --always --dirty 2>/dev/null || echo desconocida)"
echo "$VERSION" > "$DIST/VERSION"
install -m 755 "$ROOT/packaging/instalar.sh" "$DIST/instalar.sh"
install -m 644 "$ROOT/packaging/$NAME.svg" "$DIST/$NAME.svg"
cat > "$DIST/LEEME.txt" <<EOF
HIDDEN LEAD (prototipo) · versión $VERSION

Para instalarlo o actualizarlo (Linux de 64 bits, sin permisos de administrador):
    ./instalar.sh
Crea el icono «Hidden Lead» en el menú de aplicaciones y en el escritorio.
Si ya tenías una versión anterior, la actualiza y conserva tus ajustes.

Para jugar sin instalar: doble clic en $NAME.$ARCH o, desde una terminal,
    chmod +x $NAME.$ARCH && ./$NAME.$ARCH

Para quitarlo:  ./instalar.sh --desinstalar
Necesita una tarjeta gráfica con OpenGL 3.3. No hace falta instalar nada más.
EOF
PKG="$DIST/$NAME-linux-$ARCH.tar.gz"
tar -C "$DIST" --transform "s,^,$NAME/," -czf "$PKG" "$NAME.$ARCH" instalar.sh "$NAME.svg" VERSION LEEME.txt
msg "Listo (versión $VERSION):"
ls -lh "$OUT" "$PKG" | awk '{print "    " $5 "  " $9}'

# ---------------------------------------------------------------- instalación o actualización opcional
if [[ "${1:-}" == "--install" ]]; then
	"$DIST/instalar.sh" --forzar
fi
