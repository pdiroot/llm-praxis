#!/usr/bin/env bash
# merge-request.sh: open the colleague's merge request in demo/dice-roller.
# It adds one new file, so it applies on any main.
set -euo pipefail
# shellcheck source=lib.sh
# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# field <key>: one field of the merge request of the seed.
field() { jq -r ".$1" "$seed/merge-request.json"; }

p=demo%2Fdice-roller
seed="$PG_ROOT/seed/crit-table"

admin_token
export API_SUDO=demo
branch=$(field source_branch)

api GET "/projects/$p/repository/branches/main" >/dev/null 2>&1 ||
  die "demo/dice-roller has no main yet: push the first commit first"

api GET "/projects/$p/repository/branches/$(uri "$branch")" >/dev/null 2>&1 ||
  START=main push_dir "$p" "$branch" "$(field commit_message)" "$seed" crit_table.py

iid=$(api GET "/projects/$p/merge_requests?state=opened&source_branch=$(uri "$branch")" | jq -r '.[0].iid // empty')
if [[ -z $iid ]]; then
  iid=$(api POST "/projects/$p/merge_requests" -d "source_branch=$branch" -d target_branch=main \
    --data-urlencode "title=$(field title)" \
    --data-urlencode "description=$(field description)" | jq -r .iid)
fi

log "merge request !$iid: https://gitlab.playground.localhost/demo/dice-roller/-/merge_requests/$iid"
