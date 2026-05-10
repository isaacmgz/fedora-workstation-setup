#!/usr/bin/env bash
set -euo pipefail

# Simple system update script for Fedora 43 and 44
# - Ensures it's running on Fedora
# - Warns if not Fedora 43/44
# - Runs: dnf upgrade --refresh -y
# - Logs output to /var/log/fedora-setup-YYYY-MM-DD.log
# - Does NOT reboot automatically

LOG_DIR="/var/log"
TIMESTAMP="$(date +%F_%H-%M-%S)"
LOG_FILE="${LOG_DIR}/fedora-setup-${TIMESTAMP}.log"

ensure_root() {
  # Allow tests or CI to skip re-exec as root by setting SKIP_ROOT_CHECK=1
  if [[ "${SKIP_ROOT_CHECK:-0}" == "1" ]]; then
    echo "SKIP_ROOT_CHECK=1: skipping root elevation"
    return 0
  fi

  if [[ "$EUID" -ne 0 ]]; then
    echo "Re-executing as root with sudo..."
    exec sudo --preserve-env=LOG_DIR,TIMESTAMP,LOG_FILE "$0" "$@"
  fi
}

check_os() {
  # Allow tests to override sourcing /etc/os-release with SKIP_OS_RELEASE=1
  if [[ "${SKIP_OS_RELEASE:-0}" == "1" ]]; then
    echo "SKIP_OS_RELEASE=1: not reading /etc/os-release; relying on env vars if set"
  else
    if [[ -r /etc/os-release ]]; then
      # shellcheck disable=SC1091
      source /etc/os-release
    else
      echo "Cannot read /etc/os-release; aborting."
      exit 1
    fi
  fi

  if [[ "${ID:-}" != "fedora" ]]; then
    echo "This script is intended for Fedora. Detected ID='${ID:-unknown}'."
    echo "Press Ctrl+C to abort or wait 5 seconds to continue anyway..."
    sleep 5
  fi

  # Support Fedora 43 and 44. If a different release is detected, warn but continue.
  if ! [[ "${VERSION_ID:-}" =~ ^(43|44)$ ]]; then
    echo "Warning: This script was written for Fedora 43/44, but VERSION_ID='${VERSION_ID:-unknown}'."
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

run_update() {
  echo "==============================================="
  echo " Fedora system update (dnf upgrade --refresh) "
  echo "==============================================="
  echo "Start time: $(date)"
  echo

  # Refresh metadata and upgrade all packages for this release (non-interactive)
  dnf upgrade --refresh -y

  echo
  echo "End time: $(date)"
  echo "Update completed. It is strongly recommended to reboot now."
}

main() {
  ensure_root "$@"
  check_os
  prepare_logging

  # Tee all subsequent output to log file
  {
    run_update
  } 2>&1 | tee -a "$LOG_FILE"
}

main "$@"
