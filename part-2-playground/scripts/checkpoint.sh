#!/usr/bin/env bash
# checkpoint.sh <id>: jump demo/whoami, both VMs and the demo clone to the
# state in checkpoints/<id>/, forward or backward. Touches only the playground
# GitLab, the VMs and runtime/clone/whoami.
set -euo pipefail
# shellcheck source=lib.sh
# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

id=${1:-}
dir="$PG_ROOT/checkpoints/$id"
if [[ -z $id || ! -d $dir/main ]]; then
  log "unknown checkpoint '$id'; valid ids:"
  find "$PG_ROOT/checkpoints" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort >&2
  exit 1
fi

p=demo%2Fwhoami
export API_SUDO=demo # demo owns the project; root is not a member
export GIT_SSH_COMMAND="ssh -F $PG_RUNTIME/ssh/config"
remote=ssh://git@gitlab.playground.localhost:2222/demo/whoami.git
branch=
[[ -f $dir/BRANCH_NAME ]] && branch=$(<"$dir/BRANCH_NAME")

log "1/5 cancel the pipelines"
cancel_pipelines demo/whoami

log "2/5 push main${branch:+ and $branch}"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
g() { git -C "$work" -c commit.gpgsign=false -c user.name=demo -c user.email=demo@playground.internal "$@"; }
# commit_tree <src>: replace the tree of the temp repo with <src> in one commit.
commit_tree() {
  g rm -rqf --ignore-unmatch . >/dev/null
  find "$work" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
  cp -R "$1/." "$work/"
  g add -A -f
  g commit -q -m "checkpoint: $id"
  g rev-parse HEAD
}
g init -q -b main
main_sha=$(commit_tree "$dir/main")
# Smaller than unprotecting: allow the force push on main once it is protected.
allow_force() { api PATCH "/projects/$p/protected_branches/main" -d allow_force_push=true >/dev/null 2>&1 || true; }
allow_force
g push -q --force "$remote" main:main
api PUT "/projects/$p" -d default_branch=main >/dev/null
allow_force # a push that creates main also protects it

log "3/5 deployments"
if [[ -f $dir/main/.gitlab-ci.yml ]]; then
  pipeline=$(wait_pipeline "$main_sha")
  log "main ${main_sha:0:8}, pipeline $pipeline"
  wait_job "$pipeline" deploy-test success
  wait_job "$pipeline" deploy-prod manual
  api POST "/projects/$p/jobs/$(job_id "$pipeline" deploy-prod)/play" >/dev/null
  wait_job "$pipeline" deploy-prod success
else
  "$(dirname "${BASH_SOURCE[0]}")/vm-clean.sh"
fi
if [[ -n $branch ]]; then
  g checkout -q -b "$branch"
  branch_sha=$(commit_tree "$dir/branch")
  g push -q --force "$remote" "$branch:$branch"
fi

log "4/5 demo clone"
clone="$PG_RUNTIME/clone/whoami"
if [[ -d $clone/.git ]]; then
  target=${branch:-main}
  git -C "$clone" fetch -q --prune origin
  git -C "$clone" switch -q -f -C "$target" "origin/$target"
  git -C "$clone" reset -q --hard "origin/$target"
fi

log "5/5 check"
head_of() { api GET "/projects/$p/repository/branches/$(uri "$1")" | jq -r .commit.id; }
[[ $(head_of main) == "$main_sha" ]] || die "main on GitLab is not $main_sha"
if [[ -n $branch ]]; then
  [[ $(head_of "$branch") == "$branch_sha" ]] || die "$branch on GitLab is not $branch_sha"
fi
for site in test prod; do
  body=$(curl -sS --max-time 20 --cacert "$PG_CA_DIR/ca.crt" "https://$site.playground.localhost/" 2>/dev/null || true)
  if [[ -f $dir/main/.gitlab-ci.yml ]]; then
    grep -q "Commit: ${main_sha:0:8}" <<<"$body" || die "$site does not show commit ${main_sha:0:8}"
  else
    ! grep -q "Commit:" <<<"$body" || die "$site still serves the app"
  fi
done
log "checkpoint $id: main ${main_sha:0:8}${branch:+, $branch ${branch_sha:0:8}}"
