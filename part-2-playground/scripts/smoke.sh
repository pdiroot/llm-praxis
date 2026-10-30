#!/usr/bin/env bash
# smoke.sh: push smoke/ to playground/smoke and run four deploys (test and prod,
# twice), check the commit on both sites, then empty both VMs.
set -euo pipefail
# shellcheck source=lib.sh
# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

p=playground%2Fsmoke
timeout_s=${SMOKE_TIMEOUT:-600}

# job_status <pipeline> <name>: the status of a job, empty when it is missing.
job_status() { api GET "/projects/$p/pipelines/$1/jobs" | jq -r --arg n "$2" '.[] | select(.name == $n) | .status'; }
job_id() { api GET "/projects/$p/pipelines/$1/jobs" | jq -r --arg n "$2" '.[] | select(.name == $n) | .id'; }

fail_job() {
  log "job $2 of pipeline $1 failed; log tail:"
  api GET "/projects/$p/jobs/$(job_id "$1" "$2")/trace" | tail -n 30 >&2 || true
  exit 1
}

# wait_job <pipeline> <name> <status>
wait_job() {
  local deadline=$((SECONDS + timeout_s)) got
  while ((SECONDS < deadline)); do
    got=$(job_status "$1" "$2")
    [[ $got == "$3" ]] && return 0
    [[ $got == failed || $got == canceled ]] && fail_job "$1" "$2"
    sleep 3
  done
  log "timeout: job $2 of pipeline $1 is '$got', wanted $3"
  fail_job "$1" "$2"
}

# wait_pipeline <sha>: print the id of the pipeline of a commit.
wait_pipeline() {
  local deadline=$((SECONDS + 60)) id
  while ((SECONDS < deadline)); do
    id=$(api GET "/projects/$p/pipelines?sha=$1" | jq -r '.[0].id // empty')
    [[ -n $id ]] && {
      echo "$id"
      return 0
    }
    sleep 2
  done
  die "no pipeline for commit $1"
}

run_round() {
  local n=$1 sha pipeline site body jid
  shift
  # The API cannot make an empty commit; a new STAMP makes each commit differ.
  printf 'round %s at %s\n' "$n" "$(date +%s)" >"$PG_RUNTIME/smoke/STAMP"
  push_dir "$p" main "chore: smoke round $n" "$PG_RUNTIME/smoke" STAMP "$@"
  sha=$(api GET "/projects/$p/repository/commits/main" | jq -r .id)
  pipeline=$(wait_pipeline "$sha")
  log "round $n: commit ${sha:0:8}, pipeline $pipeline"
  wait_job "$pipeline" deploy-test success
  wait_job "$pipeline" deploy-prod manual
  jid=$(job_id "$pipeline" deploy-prod)
  api POST "/projects/$p/jobs/$jid/play" >/dev/null
  wait_job "$pipeline" deploy-prod success
  for site in test prod; do
    body=$(curl -fsS --cacert "$PG_CA_DIR/ca.crt" "https://$site.playground.localhost/")
    grep -q "Commit: ${sha:0:8}" <<<"$body" || die "$site does not show commit ${sha:0:8}"
    log "round $n: deploy-test and deploy-prod green, $site shows ${sha:0:8}"
  done
}

# GitLab reserves the path admin/, so the admin's project lives in a group.
# A deleted project leaves a redirect, which answers 301 with no id.
if ! api GET "/projects/$p" 2>/dev/null | jq -e .id >/dev/null 2>&1; then
  group=$(api GET /groups/playground 2>/dev/null | jq -r '.id // empty' || true)
  [[ -n $group ]] || group=$(api POST /groups -d name=playground -d path=playground -d visibility=private | jq -r .id)
  api POST /projects -d name=smoke -d "namespace_id=$group" -d visibility=private >/dev/null
fi
for v in "SSH_PRIVATE_KEY:ci" "SSH_KNOWN_HOSTS:known_hosts_ci"; do
  if ! api GET "/projects/$p/variables/${v%%:*}" >/dev/null 2>&1; then
    api POST "/projects/$p/variables" -d "key=${v%%:*}" -d variable_type=file \
      --data-urlencode "value@$PG_RUNTIME/ssh/${v##*:}" >/dev/null
  fi
done
rm -rf "$PG_RUNTIME/smoke"
mkdir -p "$PG_RUNTIME/smoke"
cp -R "$PG_ROOT/smoke/." "$PG_RUNTIME/smoke/"
mapfile -t files < <(cd "$PG_ROOT/smoke" && find . -type f | sed 's|^\./||' | sort)
run_round 1 "${files[@]}"
run_round 2
"$(dirname "${BASH_SOURCE[0]}")/vm-clean.sh"
log "smoke: four green deploys, VMs empty"
