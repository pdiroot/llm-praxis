#!/usr/bin/env bash
# ssh.sh keys | pin: the SSH key for git, its client config and the pinned host key.
set -euo pipefail
# shellcheck source=lib.sh
# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

dir="$PG_RUNTIME/ssh"

keys() {
  mkdir -p "$dir"
  [[ -e $dir/mac ]] || ssh-keygen -q -t ed25519 -N '' -C playground-mac -f "$dir/mac"

  cat >"$dir/config" <<CONF
Host gitlab.playground.localhost
  HostName gitlab.playground.localhost
  Port 2222
  User git
  IdentityFile $dir/mac
  IdentitiesOnly yes
  UserKnownHostsFile $dir/known_hosts
CONF
}

pin() {
  local gitlab

  gitlab=$(docker compose -f "$PG_ROOT/compose.yaml" exec -T gitlab \
    cat /etc/gitlab/ssh_host_ed25519_key.pub | cut -d' ' -f1,2)
  [[ -n $gitlab ]] || die "the host key of GitLab is empty"

  printf '[gitlab.playground.localhost]:2222 %s\n' "$gitlab" >"$dir/known_hosts"
}

case "${1:-}" in
keys) keys ;;
pin) pin ;;
*) die "usage: ssh.sh keys|pin" ;;
esac
