#!/usr/bin/env bash
# ssh.sh keys | pin: SSH keys, client config and pinned host keys.
set -euo pipefail
# shellcheck source=lib.sh
# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

dir="$PG_RUNTIME/ssh"

keys() {
  mkdir -p "$dir"
  local name
  for name in ci mac; do
    [[ -e $dir/$name ]] || ssh-keygen -q -t ed25519 -N '' -C "playground-$name" -f "$dir/$name"
  done
  cat >"$dir/config" <<CONF
Host test.playground.localhost
  HostName test.playground.localhost
  Port 2201
  User deploy
  IdentityFile $dir/mac
  IdentitiesOnly yes
  UserKnownHostsFile $dir/known_hosts

Host prod.playground.localhost
  HostName prod.playground.localhost
  Port 2202
  User deploy
  IdentityFile $dir/mac
  IdentitiesOnly yes
  UserKnownHostsFile $dir/known_hosts

Host gitlab.playground.localhost
  HostName gitlab.playground.localhost
  Port 2222
  User git
  IdentityFile $dir/mac
  IdentitiesOnly yes
  UserKnownHostsFile $dir/known_hosts
CONF
}

# hostkey <service> <path>: the ed25519 host key of a running container, "type base64".
hostkey() {
  docker compose -f "$PG_ROOT/compose.yaml" exec -T "$1" cat "$2" | cut -d' ' -f1,2
}

pin() {
  local test prod gitlab
  test=$(hostkey test /etc/ssh/ssh_host_ed25519_key.pub)
  prod=$(hostkey prod /etc/ssh/ssh_host_ed25519_key.pub)
  gitlab=$(hostkey gitlab /etc/gitlab/ssh_host_ed25519_key.pub)
  [[ -n $test && -n $prod && -n $gitlab ]] || die "a host key is empty"
  cat >"$dir/known_hosts" <<KH
[test.playground.localhost]:2201 $test
[prod.playground.localhost]:2202 $prod
[gitlab.playground.localhost]:2222 $gitlab
KH
  cat >"$dir/known_hosts_ci" <<KH
test-ssh $test
prod-ssh $prod
KH
}

case "${1:-}" in
keys) keys ;;
pin) pin ;;
*) die "usage: ssh.sh keys|pin" ;;
esac
