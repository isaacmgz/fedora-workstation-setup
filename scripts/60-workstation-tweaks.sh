#!/usr/bin/env bash
set -euo pipefail

# scripts/60-workstation-tweaks.sh
# Opt-in workstation tweaks for Fedora 44 (idempotente, best-effort).
# Usage:
#   sudo ./scripts/60-workstation-tweaks.sh        # interactivo
#   sudo ./scripts/60-workstation-tweaks.sh --dry-run
#   AUTO_YES=1 sudo ./scripts/60-workstation-tweaks.sh    # no preguntar
#
# Notas:
# - El script intenta ser conservador: si falla un repo/paquete 3rd-party
#   muestra advertencia y continúa.
# - Soporta SKIP_ROOT_CHECK=1 y SKIP_OS_RELEASE=1 para pruebas en CI.

LOG_DIR="/var/log"
TIMESTAMP="$(date +%F_%H-%M-%S)"
LOG_FILE="${LOG_DIR}/fedora-workstation-tweaks-${TIMESTAMP}.log"

DRY_RUN=0
AUTO_YES="${AUTO_YES:-0}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--dry-run] [--yes|-y] [-h|--help]

Options:
  --dry-run        Muestra acciones sin ejecutarlas.
  --yes, -y        Responde sí a todos los bloques (non-interactive).
  -h, --help       Muestra esta ayuda.
EOF
}

# parse args
while [[ "${1:-}" != "" ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --yes|-y) AUTO_YES=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 1 ;;
  esac
done

log() {
  printf '%s %s\n' "$(date +%FT%T%z)" "$*" | tee -a "$LOG_FILE"
}

ensure_root() {
  # Para tests/CI: SKIP_ROOT_CHECK=1 evita re-ejecutar con sudo
  if [[ "${SKIP_ROOT_CHECK:-0}" == "1" ]]; then
    log "SKIP_ROOT_CHECK=1: no requiero root (modo test)."
    return 0
  fi

  if [[ "$EUID" -ne 0 ]]; then
    log "Re-executando como root con sudo..."
    exec sudo --preserve-env=LOG_DIR,TIMESTAMP,LOG_FILE,DRY_RUN,AUTO_YES "$0" "$@"
  fi
}

# Lectura /etc/os-release salvo que SKIP_OS_RELEASE=1
check_os() {
  if [[ "${SKIP_OS_RELEASE:-0}" == "1" ]]; then
    log "SKIP_OS_RELEASE=1: no leyendo /etc/os-release (modo test)."
  else
    if [[ -r /etc/os-release ]]; then
      # shellcheck disable=SC1091
      source /etc/os-release
    else
      log "ERROR: no se puede leer /etc/os-release; abortando."
      exit 1
    fi
  fi

  if [[ "${ID:-}" != "fedora" ]]; then
    log "Advertencia: este script es para Fedora (ID='${ID:-unknown}'). Continuo por si quieres ejecutarlo."
  fi
}

confirm_block() {
  local prompt="$1"
  if [[ "${AUTO_YES:-0}" == "1" ]]; then
    log "[auto-yes] $prompt -> Sí"
    return 0
  fi
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log "[dry-run] $prompt -> simulando 'Sí' (no efectúa cambios)"
    return 0
  fi

  read -r -p "$prompt [y/N]: " answer
  case "$answer" in
    [Yy]* ) return 0 ;;
    * ) log "Bloque omitido por el usuario."; return 1 ;;
  esac
}

run_or_echo() {
  # Helper para respetar --dry-run; pasa un comando como string
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log "[DRY-RUN] $*"
  else
    log "[RUN] $*"
    bash -c "$*"
  fi
}

install_flatpak_and_flathub() {
  log "=== Flatpak + Flathub (instalación y apps recomendadas) ==="
  if ! command -v flatpak >/dev/null 2>&1; then
    run_or_echo "dnf install -y flatpak || true"
  else
    log "flatpak ya instalado."
  fi

  run_or_echo "flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true"

  if confirm_block "¿Instalar apps recomendadas vía Flatpak (VSCode, Signal, Slack, Discord, Postman)?"; then
    # apps candidatas; se instalan desde flathub en modo system (requiere root)
    local apps=(com.visualstudio.code org.signal.Signal com.slack.Slack com.discordapp.Discord com.getpostman.Postman)
    for a in "${apps[@]}"; do
      run_or_echo "flatpak install -y --if-not-installed flathub ${a} || true"
    done
  fi
}

install_nerd_font() {
  log "=== Instalación de fuente Nerd (FiraCode) ==="
  local dest="/usr/local/share/fonts/nerd"
  if ls "${dest}"/*FiraCode* >/dev/null 2>&1; then
    log "FiraCode Nerd ya parece instalada en ${dest}; saltando."
    return 0
  fi

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log "[DRY-RUN] Descarga e instalación de FiraCode Nerd (GitHub releases)."
    return 0
  fi

  local tmp
  tmp="$(mktemp -d)"
  if curl -fsSL -o "${tmp}/FiraCode.zip" "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"; then
    mkdir -p "${dest}"
    unzip -q "${tmp}/FiraCode.zip" -d "${tmp}/fira" || true
    # Copiar ttf/otf
    find "${tmp}/fira" -type f -iname "*.ttf" -o -iname "*.otf" -exec cp -v {} "${dest}/" \; || true
    fc-cache -f -v || true
    rm -rf "${tmp}"
    log "FiraCode Nerd instalada en ${dest} (si la descarga fue exitosa)."
  else
    log "Advertencia: no se pudo descargar FiraCode desde GitHub; considerá instalar manualmente."
    rm -rf "${tmp}"
  fi
}

enable_fstrim() {
  log "=== Habilitar fstrim.timer (SSD trim programado) ==="
  run_or_echo "systemctl enable --now fstrim.timer || true"
  run_or_echo "systemctl status fstrim.timer --no-pager || true"
}

install_earlyoom_and_tweaks() {
  log "=== earlyoom + ajustes de memoria (swappiness) ==="
  run_or_echo "dnf install -y earlyoom || true"
  run_or_echo "systemctl enable --now earlyoom.service || true"

  # sysctl swappiness (persistente)
  local sysctlf="/etc/sysctl.d/99-workstation.conf"
  log "Escribiendo tunables de sysctl en ${sysctlf} (backup si existía)."
  if [[ -f "${sysctlf}" ]]; then
    run_or_echo "cp -n ${sysctlf} ${sysctlf}.bak || true"
  fi

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log "[DRY-RUN] vm.swappiness=10; vm.vfs_cache_pressure=50; fs.inotify.max_user_watches=524288"
  else
    cat > "${sysctlf}" <<EOF
# workstation defaults (tweaks para responsividad)
vm.swappiness = 10
vm.vfs_cache_pressure = 50
fs.inotify.max_user_watches = 524288
net.core.somaxconn = 1024
EOF
    run_or_echo "sysctl --system || true"
  fi
}

configure_journald_limits() {
  log "=== Configurar límites de journald para evitar llenar disco ==="
  local d="/etc/systemd/journald.conf.d"
  local f="${d}/99-workstation.conf"
  run_or_echo "mkdir -p ${d}"
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log "[DRY-RUN] Configurar SystemMaxUse=200M RuntimeMaxUse=50M"
  else
    if [[ -f "${f}" ]]; then
      cp -n "${f}" "${f}.bak" || true
    fi
    cat > "${f}" <<EOF
[Journal]
SystemMaxUse=200M
RuntimeMaxUse=50M
MaxFileSec=1month
EOF
    run_or_echo "systemctl restart systemd-journald || true"
  fi
}

install_dnf_automatic() {
  log "=== dnf-automatic (actualizaciones automáticas) ==="
  if confirm_block "¿Querés habilitar actualizaciones automáticas (dnf-automatic timer)? (reinicios no automáticos)"; then
    run_or_echo "dnf install -y dnf-automatic || true"
    # systemd timer suele llamarse dnf-automatic.timer
    run_or_echo "systemctl enable --now dnf-automatic.timer || true"
    log "Nota: dnf-automatic aplica actualizaciones; reinicios de kernel requieren intervención."
  else
    log "Saltando dnf-automatic."
  fi
}

install_tuned_and_profile() {
  log "=== tuned (perfiles de rendimiento) ==="
  run_or_echo "dnf install -y tuned tuned-utils || true"
  run_or_echo "systemctl enable --now tuned || true"
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log "[DRY-RUN] tuned-adm list; elegir perfil desktop/throughput-performance/balanced si está disponible."
    return 0
  fi

  # elegir perfil recomendado en orden
  if tuned-adm list | grep -q 'desktop'; then
    run_or_echo "tuned-adm profile desktop || true"
  elif tuned-adm list | grep -q 'throughput-performance'; then
    run_or_echo "tuned-adm profile throughput-performance || true"
  else
    run_or_echo "tuned-adm profile balanced || true"
  fi
}

ensure_firewall_and_time() {
  log "=== Firewall (firewalld) y sincronización de tiempo (chrony) ==="
  run_or_echo "dnf install -y firewalld || true"
  run_or_echo "systemctl enable --now firewalld || true"
  run_or_echo "firewall-cmd --state || true"

  # Chrony
  run_or_echo "dnf install -y chrony || true"
  run_or_echo "systemctl enable --now chronyd || true"
  run_or_echo "chronyc tracking || true"
}

post_summary() {
  cat <<EOF | tee -a "$LOG_FILE"
===============================================
Fedora workstation tweaks applied (o simuladas)
Log: ${LOG_FILE}
Recomendaciones adicionales:
 - Reiniciar si actualizaste el kernel.
 - Revisar servicios con: systemctl status <service>
 - Si cambiaste shell/fonts, abrir un nuevo terminal.
===============================================
EOF
}

main() {
  ensure_root "$@"
  check_os
  mkdir -p "${LOG_DIR}" || true
  log "Iniciando workstation tweaks (DRY_RUN=${DRY_RUN}, AUTO_YES=${AUTO_YES})"

  if confirm_block "Instalar y configurar Flatpak + Flathub y apps recomendadas?"; then
    install_flatpak_and_flathub
  fi

  if confirm_block "Instalar FiraCode Nerd Font (sistema) y actualizar cache de fuentes?"; then
    install_nerd_font
  fi

  if confirm_block "Habilitar fstrim.timer (SSD)?"; then
    enable_fstrim
  fi

  if confirm_block "Instalar earlyoom y aplicar tweaks de memoria (sysctl swappiness)?"; then
    install_earlyoom_and_tweaks
  fi

  if confirm_block "Configurar límites de journald para evitar ocupar todo el disco?"; then
    configure_journald_limits
  fi

  if confirm_block "Habilitar actualizaciones automáticas con dnf-automatic (opt-in)?"; then
    install_dnf_automatic
  fi

  if confirm_block "Instalar tuned y aplicar perfil de rendimiento recomendado?"; then
    install_tuned_and_profile
  fi

  if confirm_block "Asegurar firewall (firewalld) y sincronización horaria (chrony)?"; then
    ensure_firewall_and_time
  fi

  post_summary
}

main "$@"
