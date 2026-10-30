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

admin_token() {
  if [[ -s $PG_RUNTIME/tokens/admin ]] && api GET /user >/dev/null 2>&1; then return; fi
  log "admin token"
  mkdir -p "$PG_RUNTIME/tokens"
  (
    umask 077
    printf 'glpat-%s' "$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 26)" >"$PG_RUNTIME/tokens/admin"
  )
  "${compose[@]}" exec -T -e ADMIN_TOKEN="$(cat "$PG_RUNTIME/tokens/admin")" gitlab \
    gitlab-rails runner - <"$PG_ROOT/scripts/bootstrap.rb" >/dev/null
  api GET /user >/dev/null || die "the admin token does not work"
}

demo_user() {
  local id
  id=$(api GET '/users?username=demo' | jq -r '.[0].id // empty')
  if [[ -z $id ]]; then
    log "user demo"
    id=$(api POST /users -d username=demo -d name=Demo -d email=demo@playground.internal \
      -d password='P@ssw0rd' -d skip_confirmation=true | jq -r .id)
  fi
  if [[ $(api GET "/users/$id/keys" | jq length) -eq 0 ]]; then
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

whoami_project() {
  project whoami --data-urlencode "description=$whoami_desc"
  file_var demo%2Fwhoami SSH_PRIVATE_KEY "$PG_RUNTIME/ssh/ci"
  file_var demo%2Fwhoami SSH_KNOWN_HOSTS "$PG_RUNTIME/ssh/known_hosts_ci"
}

sample_project() {
  local p=demo%2Fsample-service seed="$PG_ROOT/seed" i n msg title
  project sample-service
  export API_SUDO=demo
  if ! api GET "/projects/$p/repository/branches/main" >/dev/null 2>&1; then
    n=$(jq length "$seed/commits.json")
    for ((i = 0; i < n; i++)); do
      msg=$(jq -r ".[$i].message" "$seed/commits.json")
      mapfile -t files < <(jq -r ".[$i].files[]" "$seed/commits.json")
      push_dir "$p" main "$msg" "$seed/sample-service" "${files[@]}"
    done
  fi
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
    [[ $(api GET "/projects/$p/issues?search=$(uri "$title")&in=title" | jq --arg t "$title" '[.[] | select(.title == $t)] | length') -gt 0 ]] && continue
    api POST "/projects/$p/issues" --data-urlencode "title=$title" \
      --data-urlencode "description=$(jq -r ".issues[$i].description" "$seed/issues.json")" \
      --data-urlencode "labels=$(jq -r ".issues[$i].labels | join(\",\")" "$seed/issues.json")" >/dev/null
  done
  if [[ $(api GET "/projects/$p/merge_requests?source_branch=$(uri "$branch")" | jq length) -eq 0 ]]; then
    api POST "/projects/$p/merge_requests" -d "source_branch=$branch" -d target_branch=main \
      --data-urlencode "title=$(jq -r .merge_request.title "$seed/issues.json")" \
      --data-urlencode "description=$(jq -r .merge_request.description "$seed/issues.json")" >/dev/null
  fi
  unset API_SUDO
}

runner() {
  if grep -q '^\[\[runners\]\]' "$PG_RUNTIME/runner/config.toml" 2>/dev/null; then return; fi
  log "runner"
  local id token
  # An earlier run may have made the runner and stopped before it registered.
  for id in $(api GET /runners/all | jq -r '.[].id'); do api DELETE "/runners/$id" >/dev/null; done
  token=$(api POST /user/runners -d runner_type=instance_type -d description=playground | jq -r .token)
  "${compose[@]}" exec -T runner gitlab-runner register --non-interactive \
    --url https://gitlab.playground.internal --clone-url https://gitlab.playground.internal \
    --token "$token" --executor docker --docker-image alpine:3.22 \
    --docker-host tcp://docker:2375 --tls-ca-file /tls/ca.crt \
    --docker-extra-hosts "gitlab.playground.internal:$traefik_ip" \
    --docker-extra-hosts "test.playground.internal:$traefik_ip" \
    --docker-extra-hosts "prod.playground.internal:$traefik_ip" \
    --docker-extra-hosts "test-ssh:$test_ip" --docker-extra-hosts "prod-ssh:$prod_ip" >/dev/null
}

admin_token
demo_user
whoami_project
sample_project
runner
log "bootstrap done"
