#!/usr/bin/env bash
# reset.sh: bring GitLab, the VMs and the demo Claude Code profile back to the
# start state. Keeps the CA, the certificates, the SSH keys and the host keys.
set -euo pipefail
# shellcheck source=lib.sh
# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$PG_ROOT"
admin_token
projects=(demo/whoami demo/sample-service)

demo_profile() {
  demo_logout
  demo_home_ok || die "refusing to delete PG_DEMO_HOME='$PG_DEMO_HOME'"
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

# remove_project <path>: delete it for good and wait until its path answers 404.
remove_project() {
  local path=$1 id marked deadline=$((SECONDS + 300))
  id=$(api GET "/projects/$(uri "$path")" 2>/dev/null | jq -r '.id // empty' || true)
  if [[ -n $id ]]; then
    log "delete $path"
    api DELETE "/projects/$id" >/dev/null
  fi
  while ((SECONDS < deadline)); do
    if [[ $(http_code "/projects/$(uri "$path")") == 404 && (-z $id || $(http_code "/projects/$id") == 404) ]]; then return 0; fi
    # The soft delete is asynchronous: once the project is marked, remove it for good under its renamed path.
    if [[ -n $id ]]; then
      marked=$(api GET "/projects/$id" 2>/dev/null | jq -r 'select(.marked_for_deletion_on != null) | .path_with_namespace' || true)
      if [[ -n $marked ]]; then
        api DELETE "/projects/$id?permanently_remove=true&full_path=$(uri "$marked")" >/dev/null 2>&1 || true
      fi
    fi
    sleep 2
  done
  die "$path still answers after 300 s"
}

log "1/5 cancel the pipelines"
cancel_pipelines "${projects[@]}"
log "2/5 demo Claude Code profile"
demo_profile
log "3/5 revoke the tokens of demo"
revoke_tokens
log "4/5 recreate the projects"
for path in "${projects[@]}"; do remove_project "$path"; done
"$PG_ROOT/scripts/bootstrap.sh"
log "5/5 clean the VMs"
"$PG_ROOT/scripts/vm-clean.sh"

env -u CLAUDE_CONFIG_DIR claude auth status >/dev/null || die "the owner's own Claude Code profile does not work"
log "reset done"
