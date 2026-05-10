#!/usr/bin/env bash
set -euo pipefail

echo "Running bash syntax check for scripts..."
bash -n scripts/*.sh

echo
echo "Running workstation tweaks script in dry-run mode..."
chmod +x scripts/60-workstation-tweaks.sh
SKIP_ROOT_CHECK=1 SKIP_OS_RELEASE=1 DRY_RUN=1 AUTO_YES=1 ./scripts/60-workstation-tweaks.sh

echo
echo "Dry-run checks complete."
