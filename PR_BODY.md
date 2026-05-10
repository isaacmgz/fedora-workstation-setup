feat: add Fedora 44 workstation tweaks and Konsole/Bismuth configuration

Descripción breve:
Este PR agrega scripts y documentación para soportar Fedora 44 en estaciones de trabajo KDE/Plasma, y automatiza la configuración de Konsole + Bismuth (mosaico y atajos). Incluye tweaks (fonts, fstrim, earlyoom, journald, tuned), perfil de Konsole MonokaiPro, habilitación de Bismuth y un wrapper de CI para dry-runs.

Qué cambia (archivos clave):
- README.md (versión en español con guía de ejecución segura)
- scripts/60-workstation-tweaks.sh
- scripts/70-konsole-bismuth.sh
- ci/run-dry-checks.sh
- scripts/run.sh, scripts/00-system-update.sh (compatibilidad 43|44)
- kwin-scripts/konsole-tiler/metadata.desktop (placeholder)
- otros scripts actualizados: 10/20/30/40/50

Motivación:
Soportar Fedora 44 con pasos idempotentes y robustos, facilitar la configuración reproducible para KDE Plasma + Konsole en Wayland, y proveer unas pruebas básicas en CI (dry-run) para detectar errores tempranos.

Cómo probar (pasos reproducibles)
1) Preparar la rama y permisos
- git checkout <rama-del-PR>
- chmod +x scripts/*.sh

2) Verificación sintáctica y dry-run general (no requiere root)
- bash -n scripts/*.sh
- ./ci/run-dry-checks.sh

3) Dry-run de los tweaks (no modifica el sistema)
- SKIP_ROOT_CHECK=1 SKIP_OS_RELEASE=1 DRY_RUN=1 AUTO_YES=1 ./scripts/60-workstation-tweaks.sh

4) Dry-run de Konsole/Bismuth
- SKIP_ROOT_CHECK=1 SKIP_OS_RELEASE=1 DRY_RUN=1 ./scripts/70-konsole-bismuth.sh --dry-run

5) Ejecución real (en una VM o máquina de pruebas, en este orden recomendado)
- sudo ./scripts/run.sh update
- sudo ./scripts/run.sh core
- sudo ./scripts/run.sh containers
- sudo ./scripts/run.sh virt
- sudo ./scripts/run.sh desktop
- sudo ./scripts/run.sh dotfiles

6) Re-login / restart de sesión para aplicar cambios de KWin y atajos

Comprobaciones esperadas
- ci/run-dry-checks.sh y los DRY_RUNs no arrojan errores fatales.
- scripts/60-workstation-tweaks.sh aplica tweaks idempotentes (fstrim.timer, earlyoom, journald limits, fonts, tuned).
- Bismuth instalado y activo; ~/.config/kwinrc refleja la activación del plugin (o equivalente).
- Atajos de mosaico creados: probar Ctrl+Alt+Flecha para crear ventana en la dirección y Ctrl+Shift+Flecha para foco (si Wayland lo permite).
- Perfil MonokaiPro creado en ~/.local/share/konsole/ y funcional.
- Docker-compose cae a pip --user si no hay paquete de sistema.
- Backups de dotfiles creados (ej.: ~/.zshrc.pre-fedora-setup).
- Ningún secreto (tokens/PAT) está en los commits.

Checklist para reviewers (marcar cada ítem si verificaste)
- [ ] Ejecuté bash -n scripts/*.sh (sin errores)
- [ ] Corrí ./ci/run-dry-checks.sh (exit 0)
- [ ] Probé ./scripts/60-workstation-tweaks.sh en DRY_RUN y no abortó
- [ ] Probé ./scripts/70-konsole-bismuth.sh en DRY_RUN y genera artefactos esperados
- [ ] Verifiqué que Bismuth quedó habilitado (kwinrc / plugin activo)
- [ ] Verifiqué atajos de mosaico en Wayland (o dejé nota si hubo limitaciones)
- [ ] Confirmé que MonokaiPro aparece como perfil en Konsole
- [ ] Corrí la secuencia completa (update/core/containers/virt/desktop/dotfiles) en una VM Fedora 44 y documenté resultados
- [ ] Revisé README.md (ES) y comprobé pasos de DRY_RUN y orden de ejecución
- [ ] Subí logs/artefactos si hubo fallos: /var/log/fedora-setup-*.log y journalctl -b > journal.log
- [ ] Confirmé que no hay secretos expuestos en commits (revocar PATs si corresponde)

Criterios de aceptación
- Mergeable si: todos los items críticos de la checklist pasan o los fallos están documentados con pasos de mitigación y un plan de corrección.
- DRY_RUNs deben pasar sin errores fatales.
- Si Wayland impide aplicar atajos automáticamente, debe haber instrucciones claras para el fallback manual.

Notas y limitaciones
- Las variables SKIP_ROOT_CHECK y SKIP_OS_RELEASE son para pruebas/CI: no recomendadas en producción salvo para debugging.
- En Wayland algunos atajos pueden necesitar re-login o intervención manual en System Settings > Shortcuts.
- Repos externos/COPR son best-effort; si fallan, los scripts advierten y continúan.
- Un GitHub PAT fue expuesto previamente en la conversación anterior: considerarlo comprometido y revocarlo si corresponde.

Archivos para revisar en detalle
- README.md
- scripts/60-workstation-tweaks.sh
- scripts/70-konsole-bismuth.sh
- ci/run-dry-checks.sh
- scripts/run.sh
- scripts/00-system-update.sh
- kwin-scripts/konsole-tiler/metadata.desktop

Fin del PR body.
