#!/usr/bin/env bash
# bootstrap.sh: configure the running GitLab for Claude Code 201. Safe to run again.
set -euo pipefail
# shellcheck source=lib.sh
# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$PG_ROOT"
desc="A dice roller for Dungeons & Dragons that Claude Code builds live in the LLM Praxis session"

no_auto_devops() {
  api PUT /application/settings -d auto_devops_enabled=false >/dev/null
}

# demo_user: create demo with the Mac SSH key, and print its id.
demo_user() {
  local id keys

  id=$(api GET '/users?username=demo' | jq -r '.[0].id // empty')
  if [[ -z $id ]]; then
    log "user demo"
    id=$(api POST /users -d username=demo -d name=Demo -d email=demo@playground.internal \
      -d password='P@ssw0rd' -d skip_confirmation=true | jq -r .id)
  fi

  keys=$(api GET "/users/$id/keys" | jq length)
  if [[ $keys -eq 0 ]]; then
    api POST "/users/$id/keys" -d title=mac --data-urlencode "key@$PG_RUNTIME/ssh/mac.pub" >/dev/null
  fi

  echo "$id"
}

# demo_token <id>: a token of demo for glab, in runtime/tokens/demo. A token
# that still works stays, so a clone keeps a valid .env.
demo_token() {
  local file="$PG_RUNTIME/tokens/demo" expires

  # The header goes to curl on stdin, so the token stays out of the process list.
  if [[ -s $file ]] && printf 'PRIVATE-TOKEN: %s\n' "$(<"$file")" |
    curl -sf --max-time 10 --cacert "$PG_CA_DIR/ca.crt" -H @- \
      https://gitlab.playground.localhost/api/v4/user >/dev/null; then
    return 0
  fi

  log "token of demo"
  expires=$(date -v+30d +%Y-%m-%d)
  (umask 077 && api POST "/users/$1/personal_access_tokens" -d name=claude-code-201 \
    -d 'scopes[]=api' -d "expires_at=$expires" | jq -r .token >"$file")
  [[ $(<"$file") == glpat-* ]] || die "GitLab gave no token for demo"
}

# dice_project: the empty demo/dice-roller, with main protected before it exists.
dice_project() {
  local p=demo%2Fdice-roller

  if ! API_SUDO=demo api GET "/projects/$p" >/dev/null 2>&1; then
    log "project demo/dice-roller"
    API_SUDO=demo api POST /projects -d name=dice-roller -d auto_devops_enabled=false \
      --data-urlencode "description=$desc" >/dev/null
  fi

  api GET "/projects/$p/protected_branches/main" >/dev/null 2>&1 ||
    api POST "/projects/$p/protected_branches" -d name=main >/dev/null
}

log "admin token"
admin_token
log "settings: Auto DevOps off"
no_auto_devops
log "user demo: check"
id=$(demo_user)
[[ $id =~ ^[0-9]+$ ]] || die "no id for the user demo"
demo_token "$id"
log "project demo/dice-roller: check"
dice_project
log "bootstrap done"
