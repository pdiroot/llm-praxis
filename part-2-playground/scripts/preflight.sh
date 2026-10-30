#!/usr/bin/env bash
# preflight.sh: automatic checks before a rehearsal or the session, then the
# manual checks. Exit 1 on the first failed automatic check.
set -euo pipefail
# shellcheck source=lib.sh
# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# "Answers" means: the TLS handshake succeeds against the playground CA and
# an HTTP status comes back. test and prod answer 502 or 404 while no app runs.
answers() {
  local url=$1 code
  code=$(curl -s --max-time 10 -o /dev/null -w '%{http_code}' --cacert "$PG_CA_DIR/ca.crt" "$url" 2>/dev/null || true)
  [[ $code =~ ^[1-5][0-9][0-9]$ ]]
}

step() {
  local what=$1
  shift
  if "$@"; then log "ok: $what"; else die "$what"; fi
}

gitlab_up() { wait_http https://gitlab.playground.localhost/users/sign_in 200 30; }
vm_ssh() { ssh -F "$PG_RUNTIME/ssh/config" -o BatchMode=yes -o ConnectTimeout=10 "$1.playground.localhost" true; }
claude_new_enough() {
  local v
  v=$(claude --version | awk '{print $1}')
  [[ $(printf '%s\n2.1.312\n' "$v" | sort -V | head -n 1) == 2.1.312 ]]
}

step "GitLab answers 200 over HTTPS" gitlab_up
step "test answers over HTTPS" answers https://test.playground.localhost/
step "prod answers over HTTPS" answers https://prod.playground.localhost/
step "ssh to test" vm_ssh test
step "ssh to prod" vm_ssh prod
step "the API answers" api GET /user -o /dev/null
step "claude is 2.1.312 or later" claude_new_enough

cat <<'TEXT'

Manual checks, in the demo session:
  [ ] /mcp lists no claude.ai connector.
  [ ] Claude in Chrome opens a page and reads it.
  [ ] /plugin shows the name of the frontend-design plugin.
  [ ] Ctrl+O shows the summary after /compact; if not, the slide shows /context only.
TEXT
