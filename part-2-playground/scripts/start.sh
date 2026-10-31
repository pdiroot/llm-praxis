#!/usr/bin/env bash
# start.sh: provision the playground on a fresh start, or resume a stopped one.
set -euo pipefail
# shellcheck source=lib.sh
# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$PG_ROOT"

wait_gitlab() {
  wait_http https://gitlab.playground.localhost/users/sign_in 200 900 || die "GitLab did not answer in 900 s"
}

provision() {
  scripts/ca.sh ensure
  scripts/ca.sh trust
  scripts/certs.sh
  scripts/ssh.sh keys

  mkdir -p "$PG_RUNTIME/gitlab-trusted" "$PG_RUNTIME/runner"
  cp "$PG_RUNTIME/tls/ca.crt" "$PG_RUNTIME/gitlab-trusted/playground-ca.crt"

  docker compose up -d --build
  wait_gitlab

  scripts/ssh.sh pin
  scripts/bootstrap.sh

  # Write the marker last, so a failed first run provisions again.
  touch "$PG_RUNTIME/.provisioned"
}

resume() {
  docker compose start
  wait_gitlab
}

if provisioned; then
  log "resume the stopped playground"
  resume
else
  log "provision a new playground"
  provision
fi
