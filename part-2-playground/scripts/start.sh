#!/usr/bin/env bash
# start.sh: provision the playground on a fresh start, or resume a stopped one.
set -euo pipefail
# shellcheck source=lib.sh
# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$PG_ROOT"

# Report each 30 s, because GitLab is silent for minutes when it boots.
wait_gitlab() {
  local start=$SECONDS

  section "⏳" "GitLab: wait until it answers (about 2 minutes)"
  until wait_http https://gitlab.playground.localhost/users/sign_in 200 30; do
    ((SECONDS - start < 300)) || die "GitLab did not answer in 300 s"
    log "still waiting: $((SECONDS - start)) s"
  done
  log "GitLab answers after $((SECONDS - start)) s"
}

provision_files() {
  section "🔐" "TLS: root CA and server certificates"
  scripts/ca.sh ensure
  scripts/ca.sh trust
  scripts/certs.sh

  section "🔑" "SSH: keys"
  scripts/ssh.sh keys

  mkdir -p "$PG_RUNTIME/gitlab-trusted" "$PG_RUNTIME/runner"
  cp "$PG_RUNTIME/tls/ca.crt" "$PG_RUNTIME/gitlab-trusted/playground-ca.crt"
}

provision() {
  provision_files

  section "🐳" "Docker Compose: build and start the containers"
  docker compose up -d --build
  wait_gitlab

  section "🔑" "SSH: pin the host keys"
  scripts/ssh.sh pin

  section "🦊" "GitLab: users, projects and runner"
  scripts/bootstrap.sh

  # Write the marker last, so a failed first run provisions again.
  touch "$PG_RUNTIME/.provisioned"
}

resume() {
  section "🐳" "Docker Compose: start the stopped containers"
  docker compose start
  wait_gitlab
}

if provisioned; then
  log "Resume the stopped playground."
  resume
else
  log "Provision a new playground."
  provision
fi

section "✅" "Ready in ${SECONDS} s"
log "GitLab: https://gitlab.playground.localhost (demo / P@ssw0rd)"
log "test:   https://test.playground.localhost"
log "prod:   https://prod.playground.localhost"
