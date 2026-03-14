#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="/var/log"
TIMESTAMP="$(date +%F_%H-%M-%S)"
LOG_FILE="${LOG_DIR}/fedora-core-dev-${TIMESTAMP}.log"

ensure_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "Re-executing as root with sudo..."
    exec sudo --preserve-env=LOG_DIR,TIMESTAMP,LOG_FILE "$0" "$@"
  fi
}

check_os() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
  else
    echo "Cannot read /etc/os-release; aborting."
    exit 1
  fi

  if [[ "${ID:-}" != "fedora" ]]; then
    echo "This script is intended for Fedora. Detected ID='${ID:-unknown}'."
    echo "Press Ctrl+C to abort or wait 5 seconds to continue anyway..."
    sleep 5
  fi

  if [[ "${VERSION_ID:-}" != "43" ]]; then
    echo "Warning: This script was written for Fedora 43, but VERSION_ID='${VERSION_ID:-unknown}'."
    echo "Press Ctrl+C to abort or wait 5 seconds to continue anyway..."
    sleep 5
  fi
}

prepare_logging() {
  if ! mkdir -p "$LOG_DIR"; then
    echo "Failed to create log directory '$LOG_DIR'."
    exit 1
  fi
  echo "Logging to: $LOG_FILE"
}

confirm_block() {
  local prompt="$1"
  read -r -p "$prompt [y/N]: " answer
  case "$answer" in
    [Yy]* ) return 0 ;;
    * ) echo "Skipped."; return 1 ;;
  esac
}

install_dev_groups() {
  echo "=== Installing core development groups (development-tools, c-development) ==="
  # development-tools: git, patch, diffstat, doxygen, systemtap, etc.[web:39][web:50]
  # c-development: C/C++ compilers, gdb, automake/autoconf, etc.[web:41][web:52]
  dnf group install -y development-tools c-development
}

install_cli_tools() {
  echo "=== Installing core CLI tools and utilities ==="

  # Ensure the copr plugin is available first
  dnf install -y dnf-plugins-core || { echo "Failed to install dnf-plugins-core"; return 1; }

  # Enable COPR that provides eza (non-interactive)
  dnf -y copr enable alternateved/eza || true

  # Install packages (one dnf invocation; no accidental line breaks)
  dnf install -y \
    git \
    gcc gcc-c++ \
    make cmake ninja-build \
    python3 python3-pip \
    neovim vim-enhanced \
    ripgrep fd-find fzf htop jq \
    unzip curl gettext glibc-gconv-extra \
    tree \
    git-delta \
    thefuck \
    bat \
    tldr \
    eza
}

post_summary() {
  cat <<EOF

Installed (via groups and packages), among others:
  - Development Tools group (git, patch, diffstat, doxygen, systemtap, etc.)
  - C Development Tools and Libraries (gcc, g++, gdb, automake/autoconf, etc.)
  - Editors: vim-enhanced, neovim
  - Build tools: make, cmake, ninja-build
  - Python 3 + pip
  - CLI helpers: ripgrep, fd-find, fzf, htop, jq, tree
  - Enhanced tools:
      * git-delta (Git diff pager with syntax highlighting)
      * thefuck (correct previous console command)
      * bat (syntax-highlighted cat with Git integration)
      * tldr (simplified man pages)
  - Common build deps: unzip, curl, gettext, glibc-gconv-extra

You can now proceed with:
  - 20-containers-k8s.sh
  - or your language-specific setup scripts.


EOF
}

run() {
  echo "==============================================="
  echo " Fedora core development environment install   "
  echo "==============================================="
  echo "Start time: $(date)"
  echo

  if confirm_block "Install core development groups (development-tools, c-development)?"; then
    install_dev_groups
  fi

  if confirm_block "Install base CLI tools, editors, and build utilities?"; then
    install_cli_tools
  fi

  echo
  echo "End time: $(date)"
  post_summary
}

main() {
  ensure_root "$@"
  check_os
  prepare_logging

  {
    run
  } 2>&1 | tee -a "$LOG_FILE"
}

main "$@"
