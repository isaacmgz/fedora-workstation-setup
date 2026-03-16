#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="/var/log"
TIMESTAMP="$(date +%F_%H-%M-%S)"
LOG_FILE="${LOG_DIR}/fedora-virtualization-${TIMESTAMP}.log"

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

check_virtualization_support() {
  echo "=== Checking CPU virtualization support (vmx/svm) ==="
  if grep -E -q 'vmx|svm' /proc/cpuinfo; then
    echo "Hardware virtualization extensions detected."
  else
    echo "WARNING: No vmx/svm flags detected in /proc/cpuinfo."
    echo "KVM may not work; check BIOS/UEFI virtualization settings."
  fi
  echo
}

install_virtualization_packages() {
  echo "=== Installing KVM / libvirt / virt-manager stack ==="
  # Core virtualization packages and tools.[web:98][web:101][web:110]
  dnf install -y \
    qemu-kvm \
    libvirt \
    virt-install \
    bridge-utils \
    virt-manager \
    libvirt-devel \
    virt-top \
    libguestfs-tools \
    guestfs-tools

  echo
  echo "Enabling and starting libvirtd service..."
  systemctl enable --now libvirtd

  echo
  echo "Virtualization packages installed and libvirtd started."
}

add_user_to_libvirt_group() {
  echo "=== Adding user to 'libvirt' group (for non-root virt-manager) ==="

  local target_user
  # Prefer the original invoking user if running under sudo
  target_user="${SUDO_USER:-$(whoami)}"

  if ! getent group libvirt >/dev/null 2>&1; then
    echo "libvirt group does not exist yet; it should be created by libvirt packages."
    echo "If this persists, check /usr/lib/group for libvirt and copy it to /etc/group."
    return 1
  fi

  echo "Adding user '${target_user}' to 'libvirt' group..."
  usermod -aG libvirt "$target_user" || {
    echo "Failed to add ${target_user} to libvirt group."
    return 1
  }

  cat <<EOF

User '${target_user}' has been added to the 'libvirt' group.[web:99][web:101][web:111]
You must log out and log back in (or reboot) for group changes to take effect.

EOF
}

show_rhel_iso_ad() {
  echo "=== Red Hat Enterprise Linux (RHEL) ISO information ==="
  cat <<'EOF'
If you plan to run RHEL virtual machines, you can download official
Red Hat Enterprise Linux ISOs at no cost via the Red Hat Developer program.

This gives you a free developer subscription for personal/dev use and access
to the latest RHEL images.[web:100][web:103][web:106]

Download page:
  https://developers.redhat.com/products/rhel/download
EOF

  if confirm_block "Open the RHEL download page in your default browser now?"; then
    if command -v xdg-open >/dev/null 2>&1; then
      xdg-open "https://developers.redhat.com/products/rhel/download" || true
    else
      echo "xdg-open not found; please open the URL manually:"
      echo "https://developers.redhat.com/products/rhel/download"
    fi
  fi
}

post_summary() {
  cat <<EOF

Virtualization setup finished.

Installed and configured:
  - qemu-kvm (KVM/QEMU hypervisor)[web:98][web:101]
  - libvirt (virtualization management daemon and tooling)[web:101][web:110]
  - virt-install (CLI VM creation) and virt-manager (GUI VM manager)[web:98][web:101][web:110]
  - bridge-utils, virt-top, libguestfs-tools, guestfs-tools (networking/inspection helpers)[web:98]

If you added your user to the 'libvirt' group, log out and back in before
using virt-manager as a non-root user.[web:101]

You can now:
  - Validate host:   sudo virt-host-validate qemu   (optional, if installed)[web:107]
  - Launch GUI:      virt-manager
  - Create VMs and, if desired, download a RHEL ISO using the link above.[web:106][web:112]

EOF
}

run() {
  echo "==============================================="
  echo " Fedora virtualization (KVM / libvirt) setup   "
  echo "==============================================="
  echo "Start time: $(date)"
  echo

  check_virtualization_support

  if confirm_block "Install KVM, libvirt, virt-manager and related tools?"; then
    install_virtualization_packages
  fi

  if confirm_block "Add your user to the 'libvirt' group (use virt-manager without sudo)?"; then
    add_user_to_libvirt_group || true
  fi

  if confirm_block "Show info and optional link to download RHEL ISO?"; then
    show_rhel_iso_ad
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

