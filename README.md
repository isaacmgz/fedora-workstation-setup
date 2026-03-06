# fedora-workstation-setup

#### Folder scheme:

```
fedora-workstation-setup/
├─ README.md
├─ LICENSE
├─ CONTRIBUTING.md
├─ scripts/
│  ├─ bootstrap.sh            # main provisioning script (idempotent)
│  ├─ 00-system-update.sh     # helper scripts (downloaders, checks)
│  ├─ nvim-setup.sh           # installs plugins, links dotfiles
│  ├─ podman-setup.sh         # podman configuration + machine
│  └─ zsh-setup.sh            # installs oh-my-zsh, plugins, theme 
├─ dotfiles/                  # (or a submodule) zsh, nvim config
│  ├─ .zshrc
│  └─ nvim/
├─ docs/
│  ├─ design.md               # engineering notes, choices, reasoning
│  ├─ podman-k8s.md           # limitations & workflows with Kubernetes
│  └─ troubleshooting.md
├─ .github/
│  ├─ workflows/
│  │  └─ ci.yml               # CI for scripts (shellcheck, basic tests)
│  └─ ISSUE_TEMPLATE.md
└─ examples/
   └─ kube/                   # example Kubernetes manifests & tests
```

## Step by step guide

### Update needed

1. Make it executable:
   
   ```bash
   chmod +x fedora-workstation-setup/scripts/00-system-update.sh
   ```
2. Run it right after a fresh Fedora install:
   ```bash
   bash fedora-workstation-setup/scripts/00-system-update.sh
   ```
3. When it finishes, manually reboot (`sudo reboot`) before running your next scripts.

### Installing core dev tools

