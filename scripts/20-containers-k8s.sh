#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="/var/log"
TIMESTAMP="$(date +%F_%H-%M-%S)"
LOG_FILE="${LOG_DIR}/fedora-containers-${TIMESTAMP}.log"

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

install_podman_stack() {
  echo "=== Installing Podman and container tooling ==="
  # podman is Fedora's primary container engine.[web:83][web:87][web:95]
  dnf install -y \
    podman \
    podman-docker \
    docker-compose

  # Optional: enable podman system service for Docker-compatible workflows.[web:88][web:92]
  if systemctl list-unit-files | grep -q podman.service; then
    systemctl enable --now podman.service || true
  fi

  echo
  echo "Podman and container tooling installed."
  echo "You can use 'podman' directly, or 'docker' via the podman-docker shim."
}

install_kubectl_minikube() {
  echo "=== Installing kubectl (latest stable) ==="
  TMP_DIR="$(mktemp -d)"
  ARCH="amd64"

  pushd "$TMP_DIR" >/dev/null

  # kubectl: download latest stable from dl.k8s.io using stable.txt.[web:85][web:89][web:93]
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl"
  chmod +x kubectl
  install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

  echo "kubectl installed to /usr/local/bin/kubectl"
  kubectl version --client || true

  echo
  echo "=== Installing minikube (latest) ==="
  # minikube: download latest Linux binary and install to /usr/local/bin.[web:94]
  curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  install -o root -g root -m 0755 minikube-linux-amd64 /usr/local/bin/minikube

  echo "minikube installed to /usr/local/bin/minikube"
  minikube version || true

  popd >/dev/null
  rm -rf "$TMP_DIR"

  cat <<EOF

kubectl and minikube installed.

To start a cluster with Podman later, a typical command is:
  minikube start --driver=podman

(You can tune runtime/driver flags based on minikube's Fedora + Podman docs.)

EOF
}

post_summary() {
  cat <<EOF

Container and Kubernetes tooling setup finished.

Installed:
  - Podman (daemonless container engine, Docker-CLI compatible)[web:83][web:87][web:95]
  - podman-docker (allows using 'docker' CLI backed by Podman)[web:92]
  - docker-compose (works with Podman via podman-docker)[web:88][web:92]
  - kubectl (latest stable from dl.k8s.io)[web:85][web:89][web:93]
  - minikube (latest from official storage)[web:94]

Next steps:
  - Log out and back in if you changed any groups in other scripts.
  - Test containers:   podman run --rm -it alpine echo hello
  - Test kubectl:      kubectl version --client
  - Test minikube:     minikube start --driver=podman

EOF
}

run() {
  echo "==============================================="
  echo " Fedora containers & Kubernetes setup (Podman) "
  echo "==============================================="
  echo "Start time: $(date)"
  echo

  if confirm_block "Install Podman and container tooling (podman, podman-docker, docker-compose)?"; then
    install_podman_stack
  fi

  if confirm_block "Install Kubernetes CLI tools (kubectl, minikube)?"; then
    install_kubectl_minikube
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

