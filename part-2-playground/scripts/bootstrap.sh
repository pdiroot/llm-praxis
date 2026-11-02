#!/usr/bin/env bash
# bootstrap.sh: configure the running GitLab and register the runner. Safe to run again.
set -euo pipefail
# shellcheck source=lib.sh
# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$PG_ROOT"
compose=(docker compose -f "$PG_ROOT/compose.yaml")
whoami_desc="A whoami web app that Claude Code builds and ships live in the LLM Praxis session"
traefik_ip=172.30.42.250 test_ip=172.30.42.251 prod_ip=172.30.42.252
seed="$PG_ROOT/seed"

# Auto DevOps would start pipelines that never finish and hold the runner.
no_auto_devops() {
  api PUT /application/settings -d auto_devops_enabled=false >/dev/null
}

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
}

# project <name> [curl args]: create demo/<name> unless it exists.
# Turn Auto DevOps off here too, because a new GitLab can still use the old instance setting.
project() {
  local name=$1
  shift

  API_SUDO=demo api GET "/projects/demo%2F$name" >/dev/null 2>&1 && return 0
  log "project demo/$name"
  API_SUDO=demo api POST /projects -d "name=$name" -d auto_devops_enabled=false "$@" >/dev/null
}

# file_var <project> <key> <file>: set a file variable unless it exists.
file_var() {
  api GET "/projects/$1/variables/$2" >/dev/null 2>&1 && return 0
  api POST "/projects/$1/variables" -d "key=$2" -d variable_type=file --data-urlencode "value@$3" >/dev/null
}

# main is protected before it exists.
protect_main() {
  local p=demo%2Fwhoami
  api GET "/projects/$p/protected_branches/main" >/dev/null 2>&1 ||
    api POST "/projects/$p/protected_branches" -d name=main >/dev/null
}

whoami_project() {
  project whoami --data-urlencode "description=$whoami_desc"
  protect_main
  file_var demo%2Fwhoami SSH_PRIVATE_KEY "$PG_RUNTIME/ssh/ci"
  file_var demo%2Fwhoami SSH_KNOWN_HOSTS "$PG_RUNTIME/ssh/known_hosts_ci"
}

# The steps of hello_project. Each runs as demo, with $p set by hello_project.

# seed_commits: push the commits of seed/commits.json to main.
# The commit count on main resumes a run that stopped part way.
# shellcheck disable=SC2154
seed_commits() {
  local have n i msg files

  have=$(api GET "/projects/$p/repository/commits?ref_name=main&per_page=100" | jq length)
  n=$(jq length "$seed/commits.json")

  for ((i = have; i < n; i++)); do
    msg=$(jq -r ".[$i].message" "$seed/commits.json")
    mapfile -t files < <(jq -r ".[$i].files[]" "$seed/commits.json")
    push_dir "$p" main "$msg" "$seed/hello-world" "${files[@]}"
  done
}

# mr_field <index> <key>: one field of a merge request of seed/merge-requests.json.
mr_field() { jq -r ".merge_requests[$1].$2 // empty" "$seed/merge-requests.json"; }

# seed_branch <index>: push the branch of a merge request from its overlay folder.
# shellcheck disable=SC2154
seed_branch() {
  local overlay branch files

  overlay=$seed/$(mr_field "$1" overlay)
  branch=$(mr_field "$1" source_branch)
  api GET "/projects/$p/repository/branches/$(uri "$branch")" >/dev/null 2>&1 && return 0

  mapfile -t files < <(cd "$overlay" && ls)
  START=main push_dir "$p" "$branch" "$(mr_field "$1" commit_message)" "$overlay" "${files[@]}"
}

# merge_when_ready <iid>: merge, and retry while GitLab checks the merge request.
# shellcheck disable=SC2154
merge_when_ready() {
  local i

  for ((i = 0; i < 30; i++)); do
    api PUT "/projects/$p/merge_requests/$1/merge" >/dev/null 2>&1 && return 0
    sleep 1
  done
  die "merge request $1 did not merge"
}

# settle_merge_request <iid> <state>: bring a merge request to its state.
# shellcheck disable=SC2154
settle_merge_request() {
  [[ $(api GET "/projects/$p/merge_requests/$1" | jq -r .state) == "$2" ]] && return 0

  case $2 in
  merged) merge_when_ready "$1" ;;
  closed) api PUT "/projects/$p/merge_requests/$1" -d state_event=close >/dev/null ;;
  esac
}

# seed_merge_request <index>: open a merge request unless one exists for its
# branch, add its note, and bring it to its state.
# shellcheck disable=SC2154
seed_merge_request() {
  local branch note iid

  branch=$(mr_field "$1" source_branch)
  note=$(mr_field "$1" note)
  iid=$(api GET "/projects/$p/merge_requests?source_branch=$(uri "$branch")" | jq -r '.[0].iid // empty')

  if [[ -z $iid ]]; then
    iid=$(api POST "/projects/$p/merge_requests" -d "source_branch=$branch" -d target_branch=main \
      --data-urlencode "title=$(mr_field "$1" title)" \
      --data-urlencode "description=$(mr_field "$1" description)" | jq -r .iid)
    [[ -z $note ]] || api POST "/projects/$p/merge_requests/$iid/notes" \
      --data-urlencode "body=$note" >/dev/null
  fi

  settle_merge_request "$iid" "$(mr_field "$1" state)"
}

# seed_merge_requests: one merged, one closed and one open, in the order of the file.
seed_merge_requests() {
  local n i

  n=$(jq '.merge_requests | length' "$seed/merge-requests.json")
  for ((i = 0; i < n; i++)); do
    seed_branch "$i"
    seed_merge_request "$i"
  done
}

hello_project() {
  local p=demo%2Fhello-world
  project hello-world

  export API_SUDO=demo
  seed_commits
  seed_merge_requests
  unset API_SUDO
}

runner() {
  local id ids token
  if grep -q '^\[\[runners\]\]' "$PG_RUNTIME/runner/config.toml" 2>/dev/null; then return; fi
  log "runner"

  # An earlier run may have made the runner and stopped before it registered.
  ids=$(api GET /runners/all | jq -r '.[].id')
  for id in $ids; do api DELETE "/runners/$id" >/dev/null; done

  token=$(api POST /user/runners -d runner_type=instance_type -d description=playground | jq -r .token)
  [[ -n $token && $token != null ]] || die "no runner token"

  CI_SERVER_TOKEN=$token "${compose[@]}" exec -T -e CI_SERVER_TOKEN runner \
    gitlab-runner register --non-interactive \
    --url https://gitlab.playground.internal --clone-url https://gitlab.playground.internal \
    --executor docker --docker-image alpine:3.22 \
    --docker-host tcp://docker:2375 --tls-ca-file /tls/ca.crt \
    --docker-extra-hosts "gitlab.playground.internal:$traefik_ip" \
    --docker-extra-hosts "test.playground.internal:$traefik_ip" \
    --docker-extra-hosts "prod.playground.internal:$traefik_ip" \
    --docker-extra-hosts "test-ssh:$test_ip" --docker-extra-hosts "prod-ssh:$prod_ip" >/dev/null
}

log "admin token"
admin_token
log "settings: Auto DevOps off"
no_auto_devops
log "user demo: check"
demo_user
log "project demo/whoami: check"
whoami_project
log "project demo/hello-world: commits and merge requests"
hello_project
log "runner: check"
runner
log "bootstrap done"
