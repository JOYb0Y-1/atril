#!/bin/bash
# Instala Atril en esta Mac: baja el .dmg, comprueba su huella, copia la app a Aplicaciones y la abre.
#
# Uso, en Terminal:
#   curl -fsSL https://raw.githubusercontent.com/JOYb0Y-1/atril/main/instalar.sh | bash
# o, con el archivo ya bajado:
#   bash instalar.sh
#
# No usa sudo ni instala nada más: el .dmg ya trae todo lo que Atril necesita.

set -euo pipefail

# Lo que cambia con cada versión: el enlace directo al .dmg y su huella (shasum -a 256 Atril-….dmg).
ATRIL_URL="${ATRIL_URL:-https://github.com/JOYb0Y-1/atril/releases/download/v0.1.5/Atril-0.1.5-universal.dmg}"
ATRIL_SHA256="${ATRIL_SHA256:-464165e734450c6d65dd0e6925d47cab1f6f172637da4f810590940427d3f386}"
MACOS_MINIMO=12
# Solo para probar el instalador: otra carpeta en lugar de Aplicaciones. Así no cierra ni abre Atril.
DESTINO="${DESTINO:-}"

TEMPORAL=""
MONTAJE=""
MONTADO=0

paso() { printf '\n==> %s\n' "$*"; }
dice() { printf '    %s\n' "$*"; }
fallar() {
  printf '\n✗ %s\n' "$*" >&2
  exit 1
}

limpiar() {
  if [ "$MONTADO" = 1 ]; then
    hdiutil detach "$MONTAJE" -quiet >/dev/null 2>&1 || hdiutil detach "$MONTAJE" -force -quiet >/dev/null 2>&1 || true
    MONTADO=0
  fi
  if [ -n "$TEMPORAL" ]; then rm -rf "$TEMPORAL"; fi
}

# $1: versión de macOS, como 12.7.6. Sirve si la mayor es MACOS_MINIMO o más.
macos_sirve() {
  local mayor="${1%%.*}"
  case "$mayor" in '' | *[!0-9]*) return 1 ;; esac
  [ "$mayor" -ge "$MACOS_MINIMO" ]
}

# Cierra Atril solo si lo que está abierto es la app que se va a reemplazar ($1). Con SIGTERM, Electron sale
# ordenado, como con ⌘Q, y Terminal no pide permiso de Automatización (osascript sí, la primera vez).
cerrar_atril() {
  local pid ruta n
  for pid in $(pgrep -x Atril || true); do
    ruta="$(ps -o comm= -p "$pid" 2>/dev/null || true)"
    case "$ruta" in
      "$1"/*)
        dice "Atril está abierto: lo cierro."
        kill -TERM "$pid" 2>/dev/null || true
        n=0
        while kill -0 "$pid" 2>/dev/null; do
          n=$((n + 1))
          [ "$n" -le 20 ] || fallar "Atril no se cerró. Ciérralo con ⌘Q y vuelve a correr el instalador."
          sleep 0.5
        done
        ;;
    esac
  done
}

principal() {
  paso "Reviso la versión de macOS"
  local version
  version="$(sw_vers -productVersion)"
  macos_sirve "$version" || fallar "Esta Mac tiene macOS $version. Atril necesita macOS $MACOS_MINIMO o posterior."
  dice "macOS $version: sirve. El .dmg es universal: anda con chip Apple y con Intel."

  TEMPORAL="$(mktemp -d "${TMPDIR:-/tmp}/atril-instalar.XXXXXX")"
  MONTAJE="$TEMPORAL/montaje"
  trap limpiar EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  local dmg="$TEMPORAL/Atril.dmg"

  paso "Bajo Atril"
  dice "$ATRIL_URL"
  # Solo https, también en las redirecciones. file:// y http://127.0.0.1 quedan para probar el instalador.
  local protocolo="=https"
  case "$ATRIL_URL" in
    file://*) protocolo="=file" ;;
    http://127.0.0.1:* | http://localhost:*) protocolo="=http" ;;
  esac
  curl -fL --proto "$protocolo" --proto-redir "$protocolo" --retry 2 --connect-timeout 20 --progress-bar -o "$dmg" "$ATRIL_URL" ||
    fallar "No pude bajar Atril. Revisa tu conexión y vuelve a intentarlo."

  paso "Compruebo que el archivo sea el publicado"
  local huella esperada
  huella="$(shasum -a 256 "$dmg" | awk '{print $1}')"
  esperada="$(printf '%s' "$ATRIL_SHA256" | tr 'A-F' 'a-f')"
  if [ "$huella" != "$esperada" ]; then
    rm -f "$dmg"
    fallar "La huella del archivo bajado no coincide con la publicada, así que lo borré y no instalé nada."
  fi
  dice "La huella coincide."

  paso "Abro el .dmg en solo lectura"
  mkdir -p "$MONTAJE"
  hdiutil attach -nobrowse -readonly -noautoopen -mountpoint "$MONTAJE" "$dmg" </dev/null >/dev/null 2>&1 ||
    fallar "No pude abrir el .dmg."
  MONTADO=1
  [ -d "$MONTAJE/Atril.app" ] || fallar "El .dmg no trae Atril.app. No instalé nada."
  codesign --verify --deep --strict "$MONTAJE/Atril.app" 2>/dev/null || fallar "La firma de Atril.app no es válida. No instalé nada."

  local carpeta
  if [ -n "$DESTINO" ]; then
    carpeta="$DESTINO"
  elif [ -w /Applications ]; then
    carpeta=/Applications
  else
    carpeta="$HOME/Applications"
  fi
  mkdir -p "$carpeta"
  local app="$carpeta/Atril.app"

  paso "Copio Atril a $carpeta"
  [ -n "$DESTINO" ] || cerrar_atril "$app"
  if [ -e "$app" ]; then
    dice "Ya había un Atril ahí: lo reemplazo."
    mv "$app" "$TEMPORAL/Atril-anterior.app" || fallar "No pude mover el Atril anterior. Ciérralo y vuelve a intentarlo."
  fi
  if ! ditto "$MONTAJE/Atril.app" "$app"; then
    rm -rf "$app"
    if [ -e "$TEMPORAL/Atril-anterior.app" ]; then mv "$TEMPORAL/Atril-anterior.app" "$app"; fi
    fallar "No pude copiar Atril a $carpeta; dejé el que estaba."
  fi
  hdiutil detach "$MONTAJE" -quiet >/dev/null 2>&1 && MONTADO=0
  codesign --verify --deep --strict "$app" 2>/dev/null || fallar "La copia de Atril quedó dañada. Vuelve a correr el instalador."

  local nueva
  nueva="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist" 2>/dev/null || echo '?')"
  if xattr -p com.apple.quarantine "$app" >/dev/null 2>&1; then
    dice "macOS marcó Atril como bajado de internet. La primera vez que lo abras:"
    dice "  - macOS 15 o posterior: Ajustes del Sistema → Privacidad y seguridad → «Abrir igualmente»."
    dice "  - macOS 12 a 14: clic derecho sobre Atril → Abrir → Abrir."
  fi

  paso "Listo: Atril $nueva quedó en $carpeta"
  dice "El contenido de Ovunara llega solo: Atril lo baja al abrirse y cada 30 minutos."
  dice "Si editas tu contenido.md, Atril respeta tus cambios y ya no lo reemplaza."
  dice "Claude: Ajustes (⌘,) → Claude."
  dice "Si macOS te pide permiso para el llavero («Atril Safe Storage»), es por la versión nueva: escribe la contraseña de tu Mac y elige «Permitir siempre»."
  if [ -z "$DESTINO" ]; then open "$app"; fi
}

# ATRIL_SOLO_CARGAR=1 carga las funciones sin instalar nada (lo usan las pruebas).
[ "${ATRIL_SOLO_CARGAR:-}" = 1 ] || principal
