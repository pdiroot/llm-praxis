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
  section "🔐" "TLS: root CA and server certificate"
  scripts/ca.sh ensure
  scripts/ca.sh trust
  scripts/certs.sh

  section "🔑" "SSH: the key for git"
  scripts/ssh.sh keys
}

provision() {
  provision_files

  section "🐳" "Docker Compose: start Traefik and GitLab"
  docker compose up -d
  wait_gitlab

  section "🔑" "SSH: pin the host key of GitLab"
  scripts/ssh.sh pin

  section "🦊" "GitLab: the user, the token and the project"
  scripts/bootstrap.sh

  # Write the marker last, so a failed first run provisions again.
  touch "$PG_RUNTIME/.provisioned"
}

resume() {
  section "🐳" "Docker Compose: start the stopped containers"
  docker compose start
  wait_gitlab
}

if part2_running; then
  die "the part 2 playground runs and uses the same ports: run task playground:stop in part-2-playground"
fi

if provisioned; then
  log "Resume the stopped playground."
  resume
else
  log "Provision a new playground."
  provision
fi

section "✅" "Ready in ${SECONDS} s"
log "GitLab: https://gitlab.playground.localhost (demo / P@ssw0rd)"
log "Project: https://gitlab.playground.localhost/demo/dice-roller"
