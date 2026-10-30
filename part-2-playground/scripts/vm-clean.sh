#!/usr/bin/env bash
# vm-clean.sh: remove the whoami app from the test and prod VMs.
set -euo pipefail
# shellcheck source=lib.sh
# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

for vm in test prod; do
  ssh -F "$PG_RUNTIME/ssh/config" "$vm.playground.localhost" '
    sudo systemctl disable --now whoami 2>/dev/null || true
    sudo rm -rf /usr/local/bin/whoami /etc/systemd/system/whoami.service /var/log/whoami /run/whoami
    sudo systemctl daemon-reload'
  log "$vm: clean"
done
