*** fedora-workstation-setup — Guía completa (ES) ***

Objetivo
--------

Automatizar la instalación y la configuración de una estación de trabajo Fedora orientada a desarrollo. Los scripts están pensados para Fedora Workstation (idealmente 44) con KDE/Plasma.

Resumen de lo que hace este repo
--------------------------------

- Actualiza el sistema y paquetes (dnf)
- Instala herramientas de desarrollo (compiladores, editores, utilidades CLI)
- Configura contenedores (Podman) y herramientas Kubernetes (kubectl, minikube)
- Instala y configura virtualización (KVM / libvirt / virt-manager)
- Añade aplicaciones de escritorio populares (Brave, Dropbox, Spotify, JetBrains Toolbox, Lotion)
- Configura dotfiles y entorno de usuario (Zsh, Oh My Zsh, Neovim, snippets de alias)
- Aplica tweaks de estación (Flatpak, fuentes, tuned, journald, earlyoom)
- Configura Konsole y KWin (perfil Monokai Pro Spectrum, Bismuth tiling y atajos)

IMPORTANTE: estos scripts usan DNF y no están diseñados para Fedora Silverblue / rpm-ostree.

Estructura del repositorio
--------------------------

scripts/
- run.sh                     — dispatcher para ejecutar los pasos
- 00-system-update.sh        — actualizar sistema
- 10-core-dev.sh             — herramientas de desarrollo
- 20-containers-k8s.sh       — Podman, kubectl, minikube
- 30-virtualization.sh       — qemu-kvm, libvirt, virt-manager
- 40-desktop-apps.sh         — Brave, Dropbox, Spotify, Toolbox, Lotion
- 50-dotfiles.sh             — Zsh, Oh My Zsh, Neovim init.lua, Git defaults
- 60-workstation-tweaks.sh   — Flatpak, fuentes Nerd, fstrim, earlyoom, journald limits, tuned
- 70-konsole-bismuth.sh      — perfil Konsole MonokaiPro, autostart fullscreen, habilita Bismuth y atajos

ci/
- run-dry-checks.sh          — valida sintaxis y ejecuta dry-run de los tweaks

Cómo usar esta guía (resumen)
-----------------------------

1) Cloná el repo y prepará permisos

   git clone https://github.com/<tu-usuario>/fedora-workstation-setup.git
   cd fedora-workstation-setup
   chmod +x scripts/*.sh ci/run-dry-checks.sh

2) Verificaciones rápidas (dry-run, no root)

   ./ci/run-dry-checks.sh

3) Ejecutá los scripts en orden (con sudo)

   sudo ./scripts/run.sh update
   sudo ./scripts/run.sh core
   sudo ./scripts/run.sh containers
   sudo ./scripts/run.sh virt
   sudo ./scripts/run.sh desktop
   sudo ./scripts/run.sh dotfiles

4) Tweaks de estación (opcional; probar dry-run antes)

   SKIP_ROOT_CHECK=1 SKIP_OS_RELEASE=1 DRY_RUN=1 AUTO_YES=1 ./scripts/60-workstation-tweaks.sh
   sudo ./scripts/60-workstation-tweaks.sh

5) Konsole + Bismuth (tiling & atajos)

   sudo ./scripts/70-konsole-bismuth.sh --dry-run
   AUTO_YES=1 sudo ./scripts/70-konsole-bismuth.sh

Detalle de cada script y comprobaciones
--------------------------------------

00-system-update.sh
- Qué hace: actualiza metadata y paquetes con dnf upgrade --refresh -y.
- Log: /var/log/fedora-setup-<timestamp>.log (se muestra al inicio).
- Comprobar: journalctl -xe si hay fallos; dnf history.

10-core-dev.sh
- Qué hace: instala grupos development-tools, c-development y utilidades (git, gcc, neovim, ripgrep, fd, fzf, bat, delta, thefuck, etc.).
- Notas: intenta habilitar COPR para eza; si falla, sigue sin abortar.
- Comprobar: command -v git gcc nvim rg bat delta || true

20-containers-k8s.sh
- Qué hace: instala podman, podman-docker y descarga kubectl/minikube a /usr/local/bin.
- Fallback: si docker-compose no está en dnf, instala pip --user docker-compose.
- Comprobar: podman run --rm -it alpine echo hello; kubectl version --client; minikube version

30-virtualization.sh
- Qué hace: instala qemu-kvm, libvirt, virt-install, virt-manager y habilita libvirtd.
- Comprobar: systemctl status libvirtd; virsh list --all (si libvirt funciona).

40-desktop-apps.sh
- Qué hace: añade repos externos (Brave, RPM Fusion, Negativo17) y instala apps seleccionadas.
- Notas: repos terceros pueden fallar; el script avisará y continuará.

50-dotfiles.sh
- Qué hace: instala zsh y Oh My Zsh para el usuario, aplica tema/plugins, copia snippet zsh, crea init.lua minimal para Neovim si no existe, configura git globalmente.
- Comprobar: su - $SUDO_USER -c 'zsh --version; test -f ~/.zsh.d/10-modern-cli.zsh && echo OK || echo MISSING'

60-workstation-tweaks.sh
- Qué hace: configura Flatpak/Flathub, instala fuentes Nerd (FiraCode Nerd), habilita fstrim.timer, instala earlyoom, ajusta sysctl, configura journald limits, instala tuned y aplica perfil.
- Modo DRY_RUN: muestra acciones sin aplicarlas.

70-konsole-bismuth.sh
- Qué hace: intenta instalar bismuth, habilitarlo en kwin, añadir atajos globales para crear/centrar ventanas direcciónales, instalar esquema MonokaiPro para Konsole y crear un perfil MonokaiPro; crea autostart para abrir Konsole en fullscreen.
- Notas Wayland: KWin/Bismuth funcionan en Wayland; algunos cambios requieren re-login para aplicar atajos y políticas.

Variables y modos importantes
---------------------------

- --dry-run: (cuando está soportado) simula las acciones.
- DRY_RUN=1 / AUTO_YES=1: variantes para ejecutar sin interacción.
- SKIP_ROOT_CHECK=1 / SKIP_OS_RELEASE=1: para pruebas en CI (no recomendado en producción).

Logs, backups y reversión
-------------------------

- Logs: cada script imprime la ruta del log al inicio y escribe en /var/log.
- Backups: cuando se modifica ~/.zshrc u otros archivos importantes, se crea un backup (.pre-fedora-setup o *.bak).
- Revertir: restaurar el backup (ej.: cp ~/.zshrc.pre-fedora-setup ~/.zshrc) y reiniciar sesión si corresponde.

Solución de problemas comunes
----------------------------

- Repos externos fallan: revisar URL; ejecutar dnf config-manager o instalar manualmente desde la web del proveedor.
- docker-compose no aparece: revisar ~/ .local/bin en PATH; ejecutar python3 -m pip install --user docker-compose si hace falta.
- Atajos o Bismuth no funcionan: cerrar sesión y volver a iniciar; habilitar Bismuth en System Settings → Window Management → Window Tiling.

Checklist rápido para verificar después de ejecutar todo
-------------------------------------------------------

1. system update: verificar que no quedaron errores en /var/log/fedora-setup-*.log
2. herramientas: git, gcc, nvim, rg funcionan
3. contenedores: podman run hello; kubectl --client
4. virtualización: systemctl status libvirtd
5. desktop apps: comprobar que Brave/Spotify/Dropbox se instalan o que el script avisó problemas de repo
6. dotfiles: ~/.zshrc.match y ~/.config/nvim/init.lua creado si era necesario
7. tweaks: fstrim.timer activo, tuned activo si fue elegido
8. konsole: perfil MonokaiPro en ~/.local/share/konsole y autostart creado; Bismuth habilitado

Contribuir / PR
---------------

1. Fork & branch
   git checkout -b feature/mi-cambio

2. Commit y push
   git add -A
   git commit -m "feat: descripción corta"
   git push -u origin feature/mi-cambio

3. Crear PR
   gh pr create --title "Título" --body-file pr-body.txt

Si preferís, puedo añadir una checklist automática en el PR con los pasos de verificación. Decime si la querés.
