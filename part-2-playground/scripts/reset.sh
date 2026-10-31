#!/usr/bin/env bash
# reset.sh: bring GitLab, the VMs and the demo Claude Code profile back to the
# start state. Keeps the CA, the certificates, the SSH keys and the host keys.
set -euo pipefail
# shellcheck source=lib.sh
# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$PG_ROOT"
projects=(demo/whoami demo/sample-service)

demo_profile() {
  demo_logout
  demo_home_check
  rm -rf "$PG_DEMO_HOME/claude-config" "$PG_DEMO_HOME/whoami" "$PG_DEMO_HOME/sample-service"
}

revoke_tokens() {
  docker compose exec -T gitlab gitlab-rails runner - >/dev/null <<'RUBY'
user = User.find_by!(username: 'demo')
PersonalAccessToken.where(user_id: user.id).destroy_all
Doorkeeper::AccessToken.where(resource_owner_id: user.id).delete_all
Doorkeeper::AccessGrant.where(resource_owner_id: user.id).delete_all
RUBY
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

section "🛑" "GitLab: cancel the pipelines"
cancel_pipelines "${projects[@]}"

section "🤖" "Claude Code: delete the demo profile"
demo_profile

section "🔒" "GitLab: revoke the tokens of demo"
revoke_tokens

section "🦊" "GitLab: recreate the projects"
for path in "${projects[@]}"; do remove_project "$path"; done
"$PG_ROOT/scripts/bootstrap.sh"

section "🖥️" "Servers: empty test and prod"
"$PG_ROOT/scripts/vm-clean.sh"

env -u CLAUDE_CONFIG_DIR claude auth status >/dev/null || die "the owner's own Claude Code profile does not work"
section "✅" "Reset done in ${SECONDS} s"
log "reset done"
