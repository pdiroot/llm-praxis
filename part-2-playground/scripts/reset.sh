#!/usr/bin/env bash
# reset.sh: bring GitLab, the VMs and the demo Claude Code profile back to the
# start state. Keeps the CA, the certificates, the SSH keys and the host keys.
set -euo pipefail
# shellcheck source=lib.sh
# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$PG_ROOT"
projects=(demo/whoami demo/sample-service)
active='running|pending|created|preparing|waiting_for_resource|canceling'

# http_code <path>: the status code of a GET, 000 when curl fails.
http_code() { api GET "$1" -o /dev/null -w '%{http_code}' 2>/dev/null || true; }

# cancel_pipelines: cancel again each round, because a pipeline that is still
# being created answers 403 to a cancel. The cancel runs as demo, the owner:
# admin gets 403 on the pipelines of a project it is not a member of.
cancel_pipelines() {
  local path id left deadline=$((SECONDS + 180))
  while ((SECONDS < deadline)); do
    left=0
    for path in "${projects[@]}"; do
      [[ $(http_code "/projects/$(uri "$path")") == 200 ]] || continue
      for id in $(api GET "/projects/$(uri "$path")/pipelines?per_page=100" | jq -r --arg a "$active" '.[] | select(.status | test("^(" + $a + ")$")) | .id'); do
        left=$((left + 1))
        API_SUDO=demo api POST "/projects/$(uri "$path")/pipelines/$id/cancel" >/dev/null 2>&1 || true
      done
    done
    ((left == 0)) && return 0
    sleep 2
  done
  die "pipelines still run after 180 s"
}

demo_profile() {
  local config="$PG_RUNTIME/claude-config"
  # The demo profile has its own Keychain entry, so the logout leaves the owner's login alone.
  if [[ -d $config ]]; then CLAUDE_CONFIG_DIR=$config claude auth logout || log "logout failed; continuing"; fi
  rm -rf "$config" "$PG_RUNTIME/clone"
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
    # GitLab marks the project first; the second call removes it, under its renamed path.
    marked=$(api GET "/projects/$id" 2>/dev/null | jq -r 'select(.marked_for_deletion_on != null) | .path_with_namespace' || true)
    if [[ -n $marked ]]; then
      api DELETE "/projects/$id?permanently_remove=true&full_path=$(uri "$marked")" >/dev/null || true
    fi
  fi
  while ((SECONDS < deadline)); do
    if [[ $(http_code "/projects/$(uri "$path")") == 404 && (-z $id || $(http_code "/projects/$id") == 404) ]]; then return 0; fi
    sleep 2
  done
  die "$path still answers after 300 s"
}

log "1/5 cancel the pipelines"
cancel_pipelines
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
