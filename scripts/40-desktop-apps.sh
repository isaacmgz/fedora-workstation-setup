#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="/var/log"
TIMESTAMP="$(date +%F_%H-%M-%S)"
LOG_FILE="${LOG_DIR}/fedora-desktop-apps-${TIMESTAMP}.log"

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

get_target_user() {
  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    printf '%s\n' "${SUDO_USER}"
  else
    printf '%s\n' ""
  fi
}

install_brave_nightly() {
  echo "=== Installing Brave Nightly browser ==="

  dnf install -y dnf-plugins-core

  # If repo file already exists, don't add it again.
  if [[ -f /etc/yum.repos.d/brave-browser-nightly.repo ]]; then
    echo "Brave Nightly repo already present; skipping addrepo."
  else
    dnf config-manager addrepo \
      --from-repofile=https://brave-browser-rpm-nightly.s3.brave.com/brave-browser-nightly.repo
  fi

  dnf install -y brave-browser-nightly
  echo "Brave Nightly installed (command: brave-browser-nightly)."
}

install_dropbox() {
  echo "=== Installing Dropbox client (via RPM Fusion nonfree) ==="

  # Enable RPM Fusion free + nonfree so nautilus-dropbox is available.[web:176]
  dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

  echo
  echo "Installing nautilus-dropbox from RPM Fusion nonfree..."
  dnf install -y nautilus-dropbox

  echo
  echo "Dropbox installed (package: nautilus-dropbox)."
  echo "On first run, it will open a browser to link your account."
}

install_spotify() {
  echo "=== Installing Spotify desktop client (Negativo17 repo) ==="

  dnf install -y dnf-plugins-core

  # Add Negativo17 Spotify repo if not present.[web:114]
  if [[ -f /etc/yum.repos.d/fedora-spotify.repo ]]; then
    echo "Spotify repo already present; skipping addrepo."
  else
    dnf config-manager addrepo \
      --from-repofile=https://negativo17.org/repos/fedora-spotify.repo
  fi

  dnf install -y spotify-client
  echo "Spotify client installed (command: spotify)."
}

install_jetbrains_toolbox_for_user() {
  echo "=== Installing JetBrains Toolbox for the invoking user ==="

  local target_user
  target_user="$(get_target_user)"

  if [[ -z "$target_user" ]]; then
    echo "Cannot determine target user (SUDO_USER is empty or root)."
    echo "Please run this script via sudo from your normal user to install JetBrains Toolbox."
    return 1
  fi

  dnf install -y jq curl

  sudo -u "$target_user" bash -c '
set -euo pipefail

RELEASE_TYPE="release"
TOOLBOX_BIN_DIR="${HOME}/.local/share/JetBrains/Toolbox/bin"
LOCAL_BIN_DIR="${HOME}/.local/bin"

mkdir -p "${TOOLBOX_BIN_DIR}" "${LOCAL_BIN_DIR}"

curl -sL "$(curl -s "https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=${RELEASE_TYPE}" \
  | jq -r ".TBA[0].downloads.linux.link")" \
  | tar xzvf - \
      --directory="${TOOLBOX_BIN_DIR}" \
      --strip-components=2

ln -sf "${TOOLBOX_BIN_DIR}/jetbrains-toolbox" "${LOCAL_BIN_DIR}/jetbrains-toolbox"

echo
echo "JetBrains Toolbox installed for user ${USER}."
echo "Make sure ${LOCAL_BIN_DIR} is in your PATH."
'
}

install_lotion_for_user() {
  echo "=== Installing Lotion (Notion for Linux) (latest RPM release) ==="

  # Lotion is distributed as .rpm packages under GitHub Releases; we fetch latest via API.[web:119][web:202]
  dnf install -y jq curl

  local api_url="https://api.github.com/repos/puneetsl/lotion/releases/latest"
  local tmp_dir rpm_url rpm_name rpm_path

  echo "Querying GitHub for latest Lotion release..."
  rpm_url="$(
    curl -fsSL "$api_url" \
      | jq -r ".assets[] | select(.name | endswith(\".x86_64.rpm\")) | .browser_download_url" || true
  )"

  if [[ -z "$rpm_url" || "$rpm_url" == "null" ]]; then
    echo "Failed to determine latest Lotion .x86_64.rpm from GitHub API:"
    echo "  $api_url"
    echo "Check that the project still publishes RPM assets."
    return 1
  fi

  rpm_name="$(basename "$rpm_url")"
  tmp_dir="$(mktemp -d)"
  rpm_path="${tmp_dir}/${rpm_name}"

  echo "Downloading ${rpm_name} from ${rpm_url} ..."
  curl -fL "$rpm_url" -o "$rpm_path"

  echo "Installing ${rpm_name} via dnf..."
  dnf install -y "$rpm_path"

  rm -rf "$tmp_dir"

  echo
  echo "Lotion installed/updated from latest RPM release."
}

post_summary() {
  cat <<EOF

Desktop applications setup finished.

Installed (depending on your choices):
  - Brave Nightly (brave-browser-nightly) via Brave nightly repo.
  - Dropbox client (nautilus-dropbox) from RPM Fusion nonfree.
  - Spotify desktop client (spotify-client) from Negativo17 repo.
  - JetBrains Toolbox for your user (~/.local/share/JetBrains/Toolbox).
  - Lotion (Notion for Linux) from the latest GitHub RPM release.

EOF
}

run() {
  echo "==============================================="
  echo " Fedora desktop applications setup             "
  echo "==============================================="
  echo "Start time: $(date)"
  echo

  if confirm_block "Install Brave Nightly browser?"; then
    install_brave_nightly
  fi

  if confirm_block "Install Dropbox client?"; then
    install_dropbox
  fi

  if confirm_block "Install Spotify desktop client (Negativo17 repo)?"; then
    install_spotify
  fi

  if confirm_block "Install JetBrains Toolbox for the invoking user?"; then
    install_jetbrains_toolbox_for_user || true
  fi

  if confirm_block "Install Lotion (Notion for Linux) from latest RPM release?"; then
    install_lotion_for_user || true
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


