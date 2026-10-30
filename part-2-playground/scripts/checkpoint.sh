#!/usr/bin/env bash
# checkpoint.sh <id>: jump demo/whoami, both VMs and the demo clone to the
# state in checkpoints/<id>/, forward or backward. Touches only the playground
# GitLab, the VMs and $PG_DEMO_HOME/whoami.
set -euo pipefail
# shellcheck source=lib.sh
# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

id=${1:-}
dir="$PG_ROOT/checkpoints/$id"
if [[ ! $id =~ ^[0-9a-z-]+$ || ! -d $dir/main ]]; then
  log "unknown checkpoint '$id'; valid ids:"
  find "$PG_ROOT/checkpoints" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort >&2
  exit 1
fi

admin_token

p=demo%2Fwhoami
export API_SUDO=demo # demo owns the project; root is not a member
export GIT_SSH_COMMAND="ssh -F $PG_RUNTIME/ssh/config"
remote=ssh://git@gitlab.playground.localhost:2222/demo/whoami.git
branch=
[[ -f $dir/BRANCH_NAME ]] && branch=$(<"$dir/BRANCH_NAME")

# The temporary repository that makes the commits of the checkpoint.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

g() { git -C "$work" -c commit.gpgsign=false -c user.name=demo -c user.email=demo@playground.internal "$@"; }

# commit_tree <src>: replace the tree of the temp repo with <src> in one commit.
commit_tree() {
  [[ -d $work/.git ]] || die "no work repository in $work"

  g rm -rqf --ignore-unmatch . >/dev/null
  find "$work" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
  cp -R "$1/." "$work/"

  g add -A -f
  g commit -q -m "checkpoint: $id"
  g rev-parse HEAD
}

# drop_branches: close the open merge requests and delete every branch but
# main and this checkpoint's, so a jump back or a rerun does not collide.
drop_branches() {
  local mrs iid heads name

  mrs=$(api GET "/projects/$p/merge_requests?state=opened&per_page=100" | jq -r '.[].iid')
  for iid in $mrs; do api PUT "/projects/$p/merge_requests/$iid" -d state_event=close >/dev/null; done

  # The git remote lists the branches; the API list can lag a push by a few seconds.
  heads=$(git ls-remote --heads "$remote") || die "git ls-remote failed"
  while read -r _ ref; do
    name=${ref#refs/heads/}
    [[ -z $name || $name == main || $name == "$branch" ]] && continue
    g push -q "$remote" --delete "$name"
  done <<<"$heads"
}

# push_main: sets main_sha.
push_main() {
  g init -q -b main
  main_sha=$(commit_tree "$dir/main")

  drop_branches
  g push -q --force "$remote" main:main
  api PUT "/projects/$p" -d default_branch=main >/dev/null
}

# deploy: run the pipeline of main to test and prod, or empty the VMs when
# the checkpoint has no pipeline yet.
deploy() {
  local pipeline

  if [[ ! -f $dir/main/.gitlab-ci.yml ]]; then
    "$(dirname "${BASH_SOURCE[0]}")/vm-clean.sh"
    return
  fi

  pipeline=$(wait_pipeline "$main_sha")
  log "main ${main_sha:0:8}, pipeline $pipeline"
  wait_job "$pipeline" deploy-test success
  wait_job "$pipeline" deploy-prod manual
  api POST "/projects/$p/jobs/$(job_id "$pipeline" deploy-prod)/play" >/dev/null
  wait_job "$pipeline" deploy-prod success
}

# push_branch: sets branch_sha. The branch starts from main.
push_branch() {
  g checkout -q -b "$branch"
  branch_sha=$(commit_tree "$dir/branch")
  g push -q --force "$remote" "$branch:$branch"
}

head_of() { api GET "/projects/$p/repository/branches/$(uri "$1")" | jq -r .commit.id; }

check_heads() {
  [[ $(head_of main) == "$main_sha" ]] || die "main on GitLab is not $main_sha"
  if [[ -n $branch ]]; then
    [[ $(head_of "$branch") == "$branch_sha" ]] || die "$branch on GitLab is not $branch_sha"
  fi
}

# check_sites: both sites show the commit of main, or no app at all.
check_sites() {
  local site body

  for site in test prod; do
    body=$(curl -sS --max-time 20 --cacert "$PG_CA_DIR/ca.crt" "https://$site.playground.localhost/" 2>/dev/null || true)
    if [[ -f $dir/main/.gitlab-ci.yml ]]; then
      grep -q "Commit: ${main_sha:0:8}" <<<"$body" || die "$site does not show commit ${main_sha:0:8}"
    else
      ! grep -q "Commit:" <<<"$body" || die "$site still serves the app"
    fi
  done
}

log "1/5 cancel the pipelines"
cancel_pipelines demo/whoami

log "2/5 push main${branch:+ and $branch}"
push_main

log "3/5 deployments"
deploy
if [[ -n $branch ]]; then push_branch; fi

log "4/5 demo clone"
sync_demo_clone "${branch:-main}"

log "5/5 check"
check_heads
check_sites

log "checkpoint $id: main ${main_sha:0:8}${branch:+, $branch ${branch_sha:0:8}}"
