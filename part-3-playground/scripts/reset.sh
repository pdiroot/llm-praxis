#!/usr/bin/env bash
# reset.sh: bring GitLab and the demo Claude Code profile back to the start
# state. Keeps the CA, the certificate and the SSH keys.
set -euo pipefail
# shellcheck source=lib.sh
# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$PG_ROOT"
project=demo/dice-roller

# demo_profile: delete the clone, and the plugins, sessions and settings of the
# demo profile. The login stays, so the next session needs no sign-in.
demo_profile() {
  local config="$PG_DEMO_HOME/claude-config"

  demo_home_check
  stop_demo_app
  rm -rf "$PG_DEMO_HOME/dice-roller" "$config/plugins" "$config/projects" \
    "$config/todos" "$config/file-history" "$config/session-env" "$config/settings.json" \
    "$config/history.jsonl"
}

# revoke_tokens: the bootstrap makes a new token for demo.
revoke_tokens() {
  docker compose exec -T gitlab gitlab-rails runner - >/dev/null <<'RUBY'
user = User.find_by!(username: 'demo')
PersonalAccessToken.where(user_id: user.id).destroy_all
RUBY
  rm -f "$PG_RUNTIME/tokens/demo"
}

# project_gone <path> <id>: 0 when the path, and the id when it is set, answer 404.
project_gone() {
  [[ $(http_code "/projects/$(uri "$1")") == 404 ]] || return 1
  [[ -z $2 || $(http_code "/projects/$2") == 404 ]]
}

# purge_marked <id>: the soft delete is asynchronous. Once the project is
# marked, remove it for good under its renamed path.
purge_marked() {
  local marked
  marked=$(api GET "/projects/$1" 2>/dev/null | jq -r 'select(.marked_for_deletion_on != null) | .path_with_namespace' || true)
  [[ -z $marked ]] || api DELETE "/projects/$1?permanently_remove=true&full_path=$(uri "$marked")" >/dev/null 2>&1 || true
}

# remove_project <path>: delete it for good and wait until its path answers 404.
remove_project() {
  local path=$1 id deadline=$((SECONDS + 120))

  id=$(api GET "/projects/$(uri "$path")" 2>/dev/null | jq -r '.id // empty' || true)
  if [[ -n $id ]]; then
    log "delete $path"
    api DELETE "/projects/$id" >/dev/null
  fi

  while ((SECONDS < deadline)); do
    project_gone "$path" "$id" && return 0
    [[ -z $id ]] || purge_marked "$id"
    sleep 2
  done

  die "$path still answers after 120 s"
}

admin_token

section "🤖" "Claude Code: delete the clone and the sessions of the demo profile"
demo_profile

section "🔒" "GitLab: revoke the tokens of demo"
revoke_tokens

section "🦊" "GitLab: recreate the project"
remove_project "$project"
"$PG_ROOT/scripts/bootstrap.sh"

section "✅" "Reset done in ${SECONDS} s"
