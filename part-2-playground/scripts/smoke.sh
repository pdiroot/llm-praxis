#!/usr/bin/env bash
# smoke.sh: push smoke/ to playground/smoke and run four deploys (test and prod,
# twice), check the commit on both sites, then empty both VMs.
set -euo pipefail
# shellcheck source=lib.sh
# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

p=playground%2Fsmoke
timeout_s=${SMOKE_TIMEOUT:-600} # used by wait_job in lib.sh

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

# The smoke project lives in its own group, apart from the demo projects.
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
