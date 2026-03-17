Here’s a cleaned‑up README you can drop into `README.md`. It reflects your actual scripts, makes the flow clear, and includes a security note about permissions.

# fedora-workstation-setup

Automated, reproducible setup for a **Fedora 43 Workstation (KDE)** developer machine.

This repo contains a set of **idempotent Bash scripts** that:

- Update the base system
- Install core development tools
- Configure containers (Podman + kubectl + minikube)
- Set up KVM/libvirt virtualization
- Install desktop apps (Brave Nightly, Dropbox, Spotify, JetBrains Toolbox, Lotion)
- Configure Zsh + Oh My Zsh (Agnoster theme, plugins) and a minimal Neovim setup

> ⚠️ **Target system:** standard Fedora 43 Workstation (dnf/dnf5).  
> This is **not** intended for Silverblue/CoreOS/rpm‑ostree variants.[web:130][web:18]

---

## Repository layout

```text
fedora-workstation-setup/
├─ README.md
├─ LICENSE
├─ scripts/
│  ├─ run.sh                 # small dispatcher for all setup steps
│  ├─ 00-system-update.sh    # update base system packages
│  ├─ 10-core-dev.sh         # core dev tools (git, compilers, neovim, CLI utils)
│  ├─ 20-containers-k8s.sh   # Podman + kubectl + minikube
│  ├─ 30-virtualization.sh   # KVM/qemu-kvm + libvirt + virt-manager
│  ├─ 40-desktop-apps.sh     # Brave Nightly, Dropbox, Spotify, Toolbox, Lotion
│  └─ 50-dotfiles.sh         # Zsh + Oh My Zsh + Agnoster + plugins + Neovim
└─ docs/
   └─ zsh-snippet.txt        # modern CLI aliases (eza, bat, delta, thefuck, etc.)
```

All scripts are designed to be **safe to re‑run**: they check for existing packages/config where it makes sense and avoid overwriting user config without a backup.

---

## Requirements

- Fedora **43** Workstation installed on bare metal or VM
- Internet connection (for packages, repos, GitHub downloads)
- A user with `sudo` rights (scripts re‑exec themselves with `sudo`)

For the Zsh Agnoster theme:

- A **Powerline or Nerd font** configured in your terminal (e.g. FiraCode Nerd Font), otherwise the prompt symbols may look broken.[web:257][web:260]

---

## Security note: do **not** `chmod 777`

You might be tempted to do:

```bash
chmod 777 scripts/*
```

This is a **bad idea**:

- `777` makes scripts world‑writable; any local user/process can modify them.
- On multi‑user or shared systems this is a real security risk; 777 is widely considered an unsafe default.[web:251][web:256][web:259][web:261]

Instead, simply mark scripts as executable:

```bash
chmod +x scripts/*.sh
chmod +x scripts/run.sh
```

---

## Quick start

From a fresh Fedora 43 install:

```bash
# 1. Clone the repo
git clone https://github.com/<your-user>/fedora-workstation-setup.git
cd fedora-workstation-setup

# 2. Make scripts executable (safe)
chmod +x scripts/*.sh scripts/run.sh

# 3. Run the setup steps in order
sudo ./scripts/run.sh update      # 00-system-update.sh
sudo ./scripts/run.sh core        # 10-core-dev.sh
sudo ./scripts/run.sh containers  # 20-containers-k8s.sh
sudo ./scripts/run.sh virt        # 30-virtualization.sh
sudo ./scripts/run.sh desktop     # 40-desktop-apps.sh
sudo ./scripts/run.sh dotfiles    # 50-dotfiles.sh
```

Each script is **interactive by block** (not per‑package). You’ll be asked before major sections (e.g. “Install Podman and container tooling?”).

---

## Step‑by‑step details

### 1. System update (`00-system-update.sh` → `run.sh update`)

Bring the base system fully up to date before installing anything else; this matches Fedora’s guidance for upgrades and large installs.[web:8][web:130]

```bash
sudo ./scripts/run.sh update
```

This will:

- Run `dnf upgrade --refresh` to refresh metadata and upgrade all packages.
- Log output to `/var/log/fedora-system-update-*.log`.
- Ask you to reboot manually when it finishes.

> ✅ **Do this once** right after installing Fedora, then reboot before running the next steps.

---

### 2. Core dev tools (`10-core-dev.sh` → `run.sh core`)

Installs your base developer toolbox:

```bash
sudo ./scripts/run.sh core
```

Includes (among others):

- Build tools: `gcc`, `gcc-c++`, `make`, `cmake`, `ninja-build`
- Languages / runtime helpers: `python3`, `python3-pip`
- Editors: `vim-enhanced`, `neovim`
- CLI tools: `git`, `ripgrep`, `fd-find`, `fzf`, `htop`, `jq`, `tree`
- Enhancements: `git-delta`, `bat`, `thefuck`, `eza`, `tldr`, `shellcheck`, `strace`, `lsof`

Scripts are idempotent: re‑running will just reinstall/confirm packages via DNF.

---

### 3. Containers & Kubernetes (`20-containers-k8s.sh` → `run.sh containers`)

Sets up a **Podman‑based** container workflow plus Kubernetes CLIs:

```bash
sudo ./scripts/run.sh containers
```

Blocks:

- **Podman stack:**
  - Installs `podman`, `podman-docker`, `docker-compose`.
  - Optionally enables `podman.service` if present.
- **Kubernetes CLIs:**
  - Downloads latest stable `kubectl` from `dl.k8s.io` into `/usr/local/bin`.
  - Downloads latest `minikube` Linux binary into `/usr/local/bin`.
  - Suggests `minikube start --driver=podman` as a good default.

You can safely run this again later to refresh `kubectl`/`minikube` to the latest stable release.

---

### 4. Virtualization / KVM (`30-virtualization.sh` → `run.sh virt`)

Installs and configures KVM and libvirt for running local VMs:

```bash
sudo ./scripts/run.sh virt
```

What it does:

- Verifies CPU virtualization flags (`vmx`/`svm`) and warns if missing.
- Installs `qemu-kvm`, `libvirt`, `virt-install`, `bridge-utils`, `virt-manager`, and helper tools.
- Enables and starts `libvirtd`.
- Adds your user to the `libvirt` group (so you can run virt‑manager without sudo).
- Optionally shows and opens the **RHEL ISO** download page via Red Hat Developer subscription.

> Note: Log out and back in (or reboot) after being added to the `libvirt` group before using virt‑manager as a normal user.

---

### 5. Desktop apps (`40-desktop-apps.sh` → `run.sh desktop`)

Installs the desktop applications you specified, no extras:

```bash
sudo ./scripts/run.sh desktop
```

Blocks:

- **Brave Nightly:**
  - Adds Brave’s nightly repo (if not already present).
  - Installs/updates `brave-browser-nightly`.

- **Dropbox:**
  - Enables RPM Fusion free + nonfree.
  - Installs `nautilus-dropbox` (which downloads the Dropbox client on first run).

- **Spotify:**
  - Adds Negativo17 Spotify repo (if needed).
  - Installs `spotify-client`.

- **JetBrains Toolbox (per user):**
  - Uses JetBrains’ releases API to download the latest Toolbox tarball.
  - Installs it under `~/.local/share/JetBrains/Toolbox/bin` and symlinks `~/.local/bin/jetbrains-toolbox`.

- **Lotion (Notion for Linux):**
  - Queries GitHub Releases API for the latest `.x86_64.rpm` from `puneetsl/lotion`.
  - Downloads and installs it via `dnf install ./lotion-*.rpm`.

All blocks are re‑runnable: repos are only added if missing, and `dnf install` will simply update or confirm packages.

---

### 6. Dotfiles & shell/editor config (`50-dotfiles.sh` → `run.sh dotfiles`)

Final step: configure your shell and editor environment:

```bash
sudo ./scripts/run.sh dotfiles
```

Blocks:

1. **Zsh + Oh My Zsh + theme/plugins**
   - Installs `zsh` and Oh My Zsh (if not present).
   - Backs up `~/.zshrc` once to `~/.zshrc.pre-fedora-setup`.
   - Forces:
     - `ZSH_THEME="agnoster"`
     - `plugins=(git z sudo command-not-found history-substring-search colored-man-pages kubectl podman mvn gradle golang sbt)`
   - Ensures `oh-my-zsh.sh` is sourced.
   - Sets `/usr/bin/zsh` as your login shell and adds it to `/etc/shells` if needed.

2. **Zsh snippet (modern CLI aliases)**  
   - Copies `docs/zsh-snippet.txt` to `~/.zsh.d/10-modern-cli.zsh`.
   - Ensures your `~/.zshrc` sources `~/.zsh.d/*.zsh`.

3. **Minimal Neovim config**  
   - If `~/.config/nvim/init.lua` does not exist, creates a small Lua config with sane defaults and basic keymaps.

4. **Global Git defaults**  
   - Sets `init.defaultBranch=main`, `color.ui=auto`.
   - Optionally sets `core.editor=nvim` if Neovim is available.
   - Configures `git-delta` as pager if installed.

This script is also safe to re‑run; it will skip or update existing config while preserving your original `.zshrc` backup.

---

## Idempotency & reruns

All scripts are designed to be re‑run without breaking your system:

- Package installs rely on DNF; re‑running just confirms/updates packages.[web:130]
- Repo configuration checks for existing `.repo` files before adding.
- Dotfiles setup backs up the first version of `.zshrc` and then enforces your chosen defaults.

If something fails (network, repo issue, etc.), fix the problem and rerun the same `run.sh` step.

---

## Fonts and terminal configuration

For the Agnoster theme and glyph‑heavy prompt:

- Install a Nerd or Powerline font (e.g. FiraCode Nerd Font).[web:257][web:260]
- Configure your terminal profile to use that font.
- Open a **new** terminal after changes to verify the icons and separators look correct.

---

## Contributions / customization

- Fork the repo and adjust:
  - `docs/zsh-snippet.txt` for more aliases.
  - Plugin list and theme in `50-dotfiles.sh`.
  - Additional apps in `40-desktop-apps.sh`.

Feel free to open issues or PRs with improvements, bug fixes, or support for newer Fedora releases.
