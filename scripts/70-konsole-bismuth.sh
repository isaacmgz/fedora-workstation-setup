#!/usr/bin/env bash
set -euo pipefail

# scripts/70-konsole-bismuth.sh
# Instala y configura Bismuth (tiling) + atajos para Konsole en KDE/Wayland
# - Instala bismuth paquete (si está en dnf)
# - Habilita plugin en kwinrc usando kwriteconfig5
# - Añade shortcuts (Ctrl+Alt+Arrows para crear ventana/tiling y Ctrl+Shift+Arrows para focus)
# - Instala esquema Monokai Pro Spectrum para Konsole y crea perfil por defecto
# - Crea autostart que lance Konsole en fullscreen

LOG_DIR="/var/log"
TIMESTAMP="$(date +%F_%H-%M-%S)"
LOG_FILE="${LOG_DIR}/konsole-bismuth-${TIMESTAMP}.log"

DRY_RUN=0
AUTO_YES="${AUTO_YES:-0}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--dry-run] [--yes|-y]
EOF
}

while [[ "${1:-}" != "" ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --yes|-y) AUTO_YES=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 1 ;;
  esac
done

log() { printf '%s %s\n' "$(date +%FT%T%z)" "$*" | tee -a "$LOG_FILE"; }

run_or_echo() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log "[DRY-RUN] $*"
  else
    log "[RUN] $*"
    bash -c "$*"
  fi
}

ensure_root() {
  if [[ "$EUID" -ne 0 ]]; then
    log "Re-executando con sudo..."
    exec sudo --preserve-env=LOG_DIR,TIMESTAMP,LOG_FILE,DRY_RUN,AUTO_YES "$0" "$@"
  fi
}

ensure_root

mkdir -p "${LOG_DIR}"
log "Iniciando configuración Konsole + Bismuth (DRY_RUN=${DRY_RUN})"

# 1) Instalar Bismuth (si está disponible en dnf)
if confirm(){
  if [[ "${AUTO_YES}" == "1" ]]; then return 0; fi
  read -r -p "$1 [y/N]: " ans
  case "$ans" in [Yy]*) return 0;; *) return 1;; esac
}

if confirm "Instalar bismuth (plugin de tiling para KWin) si está disponible en dnf?"; then
  run_or_echo "dnf install -y bismuth || true"
fi

# 2) Habilitar plugin en kwinrc
log "Habilitando bismuth en kwinrc..."
run_or_echo "kwriteconfig5 --file kwinrc --group Plugins --key bismuthEnabled true"
run_or_echo "qdbus org.kde.KWin /KWin reconfigure || true"

# 3) Atajos: definimos acciones personalizadas en kglobalaccel
# Crear shortcuts para: Ctrl+Alt+Arrow -> lanzar konsole y mover/tiling
# Ctrl+Shift+Arrow -> focus dirección

KGLOBALACCEL_FILE=~/.config/kglobalshortcutsrc
backup_shortcuts() { cp -n "${KGLOBALACCEL_FILE}" "${KGLOBALACCEL_FILE}.bak" || true; }

backup_shortcuts

# Mapear atajos (ejemplo para Right). Repetir para Left/Up/Down.
set_shortcut() {
  local name="$1" key="$2"
  # Escribir en kglobalshortcutsrc (forma simple; puede ser sobrescrita por Plasma)
  run_or_echo "kwriteconfig5 --file kglobalshortcutsrc --group ${name} --key global '${key}'"
}

# Definimos atajos: Ctrl+Alt+Right para 'konsole_right', Ctrl+Shift+Right para 'focus_right'
set_shortcut 'konsole_right' 'Ctrl+Alt+Right'
set_shortcut 'focus_right' 'Ctrl+Shift+Right'
set_shortcut 'konsole_left' 'Ctrl+Alt+Left'
set_shortcut 'focus_left' 'Ctrl+Shift+Left'
set_shortcut 'konsole_up' 'Ctrl+Alt+Up'
set_shortcut 'focus_up' 'Ctrl+Shift+Up'
set_shortcut 'konsole_down' 'Ctrl+Alt+Down'
set_shortcut 'focus_down' 'Ctrl+Shift+Down'

# Apply shortcuts (global accelerator reload)
run_or_echo "qdbus org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel.componentLoaded plasmashell || true"

# 4) Instalar perfil Monokai Pro Spectrum para Konsole
KONSOLE_DIR="${HOME:-/root}/.local/share/konsole"
run_or_echo "mkdir -p \"${KONSOLE_DIR}\""

# Try to fetch colorscheme file from known repo; fallback to embedded minimal scheme
MONOKAI_URL='https://raw.githubusercontent.com/lyxal/konsole-colorschemes/master/Monokai%20Pro%20(Spectrum).colorscheme'
tmpf=$(mktemp)
if curl -fsSL "${MONOKAI_URL}" -o "${tmpf}"; then
  run_or_echo "cp -f ${tmpf} ${KONSOLE_DIR}/MonokaiProSpectrum.colorscheme"
  rm -f "${tmpf}"
else
  log "No se pudo descargar Monokai Pro Spectrum; creando esquema mínimo de fallback."
  cat > "${KONSOLE_DIR}/MonokaiProSpectrum.colorscheme" <<'EOF'
[Background]
Color=39,40,34
[BackgroundIntense]
Color=63,63,53
[Foreground]
Color=248,248,242
[ForegroundIntense]
Color=248,248,242
[General]
Opacity=1
EOF
fi

# Create Konsole profile that uses the colorscheme
PROFILE_FILE="${KONSOLE_DIR}/MonokaiPro.profile"
cat > "${PROFILE_FILE}" <<EOF
[Desktop Entry]
Name=Monokai Pro (Spectrum)
Comment=Monokai Pro Spectrum for Konsole
Type=Link
X-KDE-Konsole-Profile-Version=1.0

[Appearance]
ColorScheme=MonokaiProSpectrum.colorscheme

[General]
Name=MonokaiPro
EOF

# Set as default profile
run_or_echo "kwriteconfig5 --file konsolerc --group 'Desktop Entry' --key DefaultProfile MonokaiPro.profile || true"

# 5) Autostart: crear .desktop en ~/.config/autostart para abrir Konsole en fullscreen
AUTOSTART_DIR="${HOME:-/root}/.config/autostart"
mkdir -p "${AUTOSTART_DIR}"
cat > "${AUTOSTART_DIR}/konsole-fullscreen.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Konsole Fullscreen
Exec=konsole --new-tab -p Profile=MonokaiPro --separate --fullscreen
X-KDE-autostart-phase=1
X-KDE-Username=
EOF

run_or_echo "kreadconfig5 --group 'Windows' --key BorderlessMaximizedWindows true || true"
run_or_echo "qdbus org.kde.KWin /KWin reconfigure || true"

log "Konsole + Bismuth configuration applied (or simulated). Re-login for some changes to take full effect." 
