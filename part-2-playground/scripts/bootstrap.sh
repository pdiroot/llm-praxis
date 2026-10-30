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
project() {
  local name=$1
  shift
  API_SUDO=demo api GET "/projects/demo%2F$name" >/dev/null 2>&1 && return 0
  log "project demo/$name"
  API_SUDO=demo api POST /projects -d "name=$name" "$@" >/dev/null
}

# file_var <project> <key> <file>: set a file variable unless it exists.
file_var() {
  api GET "/projects/$1/variables/$2" >/dev/null 2>&1 && return 0
  api POST "/projects/$1/variables" -d "key=$2" -d variable_type=file --data-urlencode "value@$3" >/dev/null
}

# main is protected before it exists, with force pushes allowed for task checkpoint.
protect_main() {
  local p=demo%2Fwhoami
  if api GET "/projects/$p/protected_branches/main" >/dev/null 2>&1; then
    api PATCH "/projects/$p/protected_branches/main" -d allow_force_push=true >/dev/null
  else
    api POST "/projects/$p/protected_branches" -d name=main -d allow_force_push=true >/dev/null
  fi
}

whoami_project() {
  project whoami --data-urlencode "description=$whoami_desc"
  protect_main
  file_var demo%2Fwhoami SSH_PRIVATE_KEY "$PG_RUNTIME/ssh/ci"
  file_var demo%2Fwhoami SSH_KNOWN_HOSTS "$PG_RUNTIME/ssh/known_hosts_ci"
}

sample_project() {
  local p=demo%2Fsample-service seed="$PG_ROOT/seed" i n msg title have found mrs
  project sample-service
  export API_SUDO=demo
  # The commit count on main resumes a run that stopped part way.
  have=$(api GET "/projects/$p/repository/commits?ref_name=main&per_page=100" | jq length)
  n=$(jq length "$seed/commits.json")
  for ((i = have; i < n; i++)); do
    msg=$(jq -r ".[$i].message" "$seed/commits.json")
    mapfile -t files < <(jq -r ".[$i].files[]" "$seed/commits.json")
    push_dir "$p" main "$msg" "$seed/sample-service" "${files[@]}"
  done
  local overlay branch
  overlay=$seed/$(jq -r .merge_request.overlay "$seed/issues.json")
  branch=$(jq -r .merge_request.source_branch "$seed/issues.json")
  if ! api GET "/projects/$p/repository/branches/$(uri "$branch")" >/dev/null 2>&1; then
    mapfile -t files < <(cd "$overlay" && ls)
    # The overlay holds files of the main branch; they are updates there.
    START=main push_dir "$p" "$branch" "$(jq -r .merge_request.commit_message "$seed/issues.json")" "$overlay" "${files[@]}"
  fi
  n=$(jq '.issues | length' "$seed/issues.json")
  for ((i = 0; i < n; i++)); do
    title=$(jq -r ".issues[$i].title" "$seed/issues.json")
    found=$(api GET "/projects/$p/issues?search=$(uri "$title")&in=title" | jq --arg t "$title" '[.[] | select(.title == $t)] | length')
    [[ $found -gt 0 ]] && continue
    api POST "/projects/$p/issues" --data-urlencode "title=$title" \
      --data-urlencode "description=$(jq -r ".issues[$i].description" "$seed/issues.json")" \
      --data-urlencode "labels=$(jq -r ".issues[$i].labels | join(\",\")" "$seed/issues.json")" >/dev/null
  done
  mrs=$(api GET "/projects/$p/merge_requests?source_branch=$(uri "$branch")" | jq length)
  if [[ $mrs -eq 0 ]]; then
    api POST "/projects/$p/merge_requests" -d "source_branch=$branch" -d target_branch=main \
      --data-urlencode "title=$(jq -r .merge_request.title "$seed/issues.json")" \
      --data-urlencode "description=$(jq -r .merge_request.description "$seed/issues.json")" >/dev/null
  fi
  unset API_SUDO
}

runner() {
  if grep -q '^\[\[runners\]\]' "$PG_RUNTIME/runner/config.toml" 2>/dev/null; then return; fi
  log "runner"
  local id ids token
  # An earlier run may have made the runner and stopped before it registered.
  ids=$(api GET /runners/all | jq -r '.[].id')
  for id in $ids; do api DELETE "/runners/$id" >/dev/null; done
  token=$(api POST /user/runners -d runner_type=instance_type -d description=playground | jq -r .token)
  [[ -n $token && $token != null ]] || die "no runner token"
  CI_SERVER_TOKEN=$token "${compose[@]}" exec -T -e CI_SERVER_TOKEN runner gitlab-runner register --non-interactive \
    --url https://gitlab.playground.internal --clone-url https://gitlab.playground.internal \
    --executor docker --docker-image alpine:3.22 \
    --docker-host tcp://docker:2375 --tls-ca-file /tls/ca.crt \
    --docker-extra-hosts "gitlab.playground.internal:$traefik_ip" \
    --docker-extra-hosts "test.playground.internal:$traefik_ip" \
    --docker-extra-hosts "prod.playground.internal:$traefik_ip" \
    --docker-extra-hosts "test-ssh:$test_ip" --docker-extra-hosts "prod-ssh:$prod_ip" >/dev/null
}

admin_token
no_auto_devops
demo_user
whoami_project
sample_project
runner
log "bootstrap done"
