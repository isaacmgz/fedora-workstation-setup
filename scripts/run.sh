#!/usr/bin/env bash
set -euo pipefail

# Always resolve to the directory where this script lives,
# so it works no matter where you run it from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<EOF
Usage: $(basename "$0") <command>

Commands:
  update       Run 00-system-update.sh      (full system upgrade, then reboot)
  core         Run 10-core-dev.sh           (core dev tools, CLI utilities)
  containers   Run 20-containers-k8s.sh     (Podman + kubectl + minikube)
  virt         Run 30-virtualization.sh     (KVM / libvirt / virt-manager)
  desktop      Run 40-desktop-apps.sh       (Brave, Dropbox, Spotify, Toolbox, Lotion)
  dotfiles     Run 50-dotfiles.sh           (Zsh + Oh My Zsh + Neovim + Git defaults)

Examples:
  sudo ./run.sh update
  sudo ./run.sh core
  sudo ./run.sh containers

EOF
}

cmd="${1:-}"

if [[ -z "$cmd" ]]; then
  usage
  exit 1
fi

case "$cmd" in
  update)
    exec "${SCRIPT_DIR}/00-system-update.sh"
    ;;
  core)
    exec "${SCRIPT_DIR}/10-core-dev.sh"
    ;;
  containers)
    exec "${SCRIPT_DIR}/20-containers-k8s.sh"
    ;;
  virt|virtualization)
    exec "${SCRIPT_DIR}/30-virtualization.sh"
    ;;
  desktop)
    exec "${SCRIPT_DIR}/40-desktop-apps.sh"
    ;;
  dotfiles)
    exec "${SCRIPT_DIR}/50-dotfiles.sh"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "Unknown command: $cmd"
    echo
    usage
    exit 1
    ;;
esac

