#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="/var/log"
TIMESTAMP="$(date +%F_%H-%M-%S)"
LOG_FILE="${LOG_DIR}/fedora-dotfiles-${TIMESTAMP}.log"

# Resolve repo and docs paths
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ZSH_SNIPPET_SRC="${REPO_ROOT}/docs/zsh-snippet.txt"

ensure_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "Re-executing as root with sudo..."
    exec sudo --preserve-env=LOG_DIR,TIMESTAMP,LOG_FILE,REPO_ROOT,ZSH_SNIPPET_SRC "$0" "$@"
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

install_oh_my_zsh_for_user() {
  echo "=== Installing Zsh and Oh My Zsh for the invoking user ==="

  dnf install -y zsh

  local target_user
  target_user="$(get_target_user)"

  if [[ -z "$target_user" ]]; then
    echo "Cannot determine target user (SUDO_USER is empty or root)."
    echo "Run this script via sudo from your normal user."
    return 1
  fi

  sudo -u "$target_user" bash -c '
set -euo pipefail

# Install Oh My Zsh only if not already installed.
if [[ -d "${HOME}/.oh-my-zsh" ]]; then
  echo "Oh My Zsh already installed at ${HOME}/.oh-my-zsh; skipping."
else
  echo "Installing Oh My Zsh for user ${USER}..."
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

ZSHRC="${HOME}/.zshrc"

# Backup existing .zshrc once
if [[ -f "${ZSHRC}" && ! -f "${HOME}/.zshrc.pre-fedora-setup" ]]; then
  cp "${ZSHRC}" "${HOME}/.zshrc.pre-fedora-setup"
  echo "Backed up existing .zshrc to .zshrc.pre-fedora-setup"
fi

# Ensure theme is set to agnoster in .zshrc
if [[ -f "${ZSHRC}" ]]; then
  if grep -q "^ZSH_THEME=" "${ZSHRC}"; then
    sed -i "s/^ZSH_THEME=.*/ZSH_THEME=\"agnoster\"/" "${ZSHRC}"
  else
    printf "\nZSH_THEME=\"agnoster\"\n" >> "${ZSHRC}"
  fi
else
  {
    echo "export ZSH=\"${HOME}/.oh-my-zsh\""
    echo "ZSH_THEME=\"agnoster\""
  } > "${ZSHRC}"
fi

# Desired plugin set
DESIRED_PLUGINS="plugins=(git z sudo command-not-found history-substring-search colored-man-pages kubectl podman mvn gradle golang sbt)"

if grep -q "^plugins=" "${ZSHRC}"; then
  sed -i "s/^plugins=.*/${DESIRED_PLUGINS}/" "${ZSHRC}"
else
  printf "\n%s\n" "${DESIRED_PLUGINS}" >> "${ZSHRC}"
fi

# Ensure oh-my-zsh is sourced
if ! grep -q "oh-my-zsh.sh" "${ZSHRC}"; then
  printf "\nsource \"${HOME}/.oh-my-zsh/oh-my-zsh.sh\"\n" >> "${ZSHRC}"
fi

echo "Configured ZSH_THEME=\"agnoster\" and ${DESIRED_PLUGINS} in ${ZSHRC}"
'

  # Set Zsh as default shell for target_user.
  local zsh_path

  if [[ -x /usr/bin/zsh ]]; then
    zsh_path="/usr/bin/zsh"
  else
    zsh_path="$(command -v zsh || true)"
  fi

  if [[ -n "$zsh_path" ]]; then
    # Ensure the shell is listed in /etc/shells
    if ! grep -qxF "$zsh_path" /etc/shells; then
      echo "Adding ${zsh_path} to /etc/shells..."
      echo "$zsh_path" >> /etc/shells
    fi

    echo "Setting default shell for ${target_user} to ${zsh_path}..."
    chsh -s "$zsh_path" "$target_user" || echo "Failed to change shell; you may need to run chsh manually."
  else
    echo "zsh binary not found in PATH; cannot change default shell."
  fi
}

install_zsh_snippet_for_user() {
  echo "=== Installing Zsh snippet (modern CLI aliases) for the invoking user ==="

  if [[ ! -f "$ZSH_SNIPPET_SRC" ]]; then
    echo "Zsh snippet source not found at: $ZSH_SNIPPET_SRC"
    echo "Make sure docs/zsh-snippet.txt exists in the repo."
    return 1
  fi

  local target_user
  target_user="$(get_target_user)"

  if [[ -z "$target_user" ]]; then
    echo "Cannot determine target user (SUDO_USER is empty or root)."
    return 1
  fi

  sudo -u "$target_user" ZSH_SNIPPET_SRC="$ZSH_SNIPPET_SRC" bash -c '
set -euo pipefail

ZSH_D_DIR="${HOME}/.zsh.d"
SNIPPET_DEST="${ZSH_D_DIR}/10-modern-cli.zsh"

mkdir -p "${ZSH_D_DIR}"

# Copy the snippet from the repo file
cp "$ZSH_SNIPPET_SRC" "${SNIPPET_DEST}"

echo "Installed Zsh snippet to ${SNIPPET_DEST}"

ZSHRC="${HOME}/.zshrc"

# Ensure ~/.zshrc sources all .zsh.d/*.zsh files once
INCLUDE_BLOCK="for f in \$HOME/.zsh.d/*.zsh; do
  [ -r \"\$f\" ] && source \"\$f\"
done"

if [[ -f "${ZSHRC}" ]]; then
  if ! grep -q "source.*\.zsh.d" "${ZSHRC}"; then
    {
      echo
      echo "# Load additional Zsh snippets"
      echo "${INCLUDE_BLOCK}"
    } >> "${ZSHRC}"
    echo "Appended Zsh snippet include block to ${ZSHRC}"
  else
    echo "Zsh snippet include block seems to already be present in ${ZSHRC}; skipping."
  fi
else
  {
    echo "# ~/.zshrc generated by fedora-workstation-setup"
    echo "${INCLUDE_BLOCK}"
  } > "${ZSHRC}"
  echo "Created new ${ZSHRC} with snippet include block."
fi
'
}

setup_minimal_neovim_for_user() {
  echo "=== Setting up minimal Neovim config for the invoking user ==="

  local target_user
  target_user="$(get_target_user)"

  if [[ -z "$target_user" ]]; then
    echo "Cannot determine target user (SUDO_USER is empty or root)."
    return 1
  fi

  sudo -u "$target_user" bash -c '
set -euo pipefail

NVIM_CONFIG_DIR="${HOME}/.config/nvim"
INIT_LUA="${NVIM_CONFIG_DIR}/init.lua"

if [[ -f "${INIT_LUA}" ]]; then
  echo "Neovim config ${INIT_LUA} already exists; skipping."
  exit 0
fi

mkdir -p "${NVIM_CONFIG_DIR}"

cat <<EOF_INIT > "${INIT_LUA}"
-- Minimal Neovim config generated by fedora-workstation-setup

local o = vim.opt

o.number = true
o.relativenumber = true
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.smartindent = true
o.termguicolors = true
o.ignorecase = true
o.smartcase = true
o.cursorline = true
o.splitright = true
o.splitbelow = true
o.scrolloff = 4
o.signcolumn = "yes"

-- Use system clipboard if available
o.clipboard = "unnamedplus"

-- Leader key
vim.g.mapleader = " "

-- Basic keymaps
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

map("n", "<leader>w", "<cmd>w<CR>", opts)
map("n", "<leader>q", "<cmd>q<CR>", opts)
map("n", "<leader>h", "<C-w>h", opts)
map("n", "<leader>j", "<C-w>j", opts)
map("n", "<leader>k", "<C-w>k", opts)
map("n", "<leader>l", "<C-w>l", opts)

-- Placeholder for plugins: you can extend this later.
EOF_INIT

echo "Created minimal Neovim config at ${INIT_LUA}"
'
}

setup_git_defaults_for_user() {
  echo "=== Setting some safe global Git defaults for the invoking user ==="

  local target_user
  target_user="$(get_target_user)"

  if [[ -z "$target_user" ]]; then
    echo "Cannot determine target user (SUDO_USER is empty or root)."
    return 1
  fi

  sudo -u "$target_user" bash -c '
set -euo pipefail

# Do NOT touch user.name or user.email; leave that to the user.

# Set default branch name and enable colors
git config --global init.defaultBranch main
git config --global color.ui auto

# Prefer Neovim as editor if present, otherwise leave as-is
if command -v nvim >/dev/null 2>&1; then
  git config --global core.editor "nvim"
fi

# If git-delta is installed, ensure it is configured as pager
if command -v delta >/dev/null 2>&1; then
  git config --global core.pager "delta"
  git config --global interactive.diffFilter "delta --color-only"
  git config --global delta.features "side-by-side line-numbers decorations"
  git config --global delta.navigate "true"
fi

echo "Global Git defaults updated (branch name, color, optional editor and delta pager)."
'
}

post_summary() {
  cat <<EOF

Dotfiles/user configuration setup finished.

Performed (depending on your choices):
  - Installed Zsh and Oh My Zsh for your user, set Zsh as default shell,
    and configured Agnoster theme with a curated plugin set.
  - Installed your Zsh snippet under ~/.zsh.d and wired it into ~/.zshrc.
  - Created a minimal Neovim init.lua at ~/.config/nvim/init.lua if none existed.
  - Set some safe global Git defaults (init.defaultBranch=main, color.ui=auto,
    optional editor and delta pager).

You can re-run this script; it will generally skip steps if it detects existing configs.

EOF
}

run() {
  echo "==============================================="
  echo " Fedora dotfiles / user configuration setup    "
  echo "==============================================="
  echo "Start time: $(date)"
  echo

  if confirm_block "Install Zsh and Oh My Zsh for your user and set Zsh as default shell?"; then
    install_oh_my_zsh_for_user || true
  fi

  if confirm_block "Install your Zsh snippet (modern CLI aliases) for your user?"; then
    install_zsh_snippet_for_user || true
  fi

  if confirm_block "Create a minimal Neovim config if none exists?"; then
    setup_minimal_neovim_for_user || true
  fi

  if confirm_block "Set some safe global Git defaults?"; then
    setup_git_defaults_for_user || true
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

