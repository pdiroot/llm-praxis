#!/usr/bin/env bash
# Shared helpers. Source this file; it sets no shell options.

PG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PG_RUNTIME="${PG_RUNTIME:-$PG_ROOT/runtime}"
PG_CA_DIR="${PG_CA_DIR:-$HOME/.config/playgrounds/tls}"

log() { printf '%s\n' "$*" >&2; }
die() {
  log "error: $*"
  exit 1
}

# wait_http <url> <code> <timeout_s>: 0 when the URL answers <code>, 1 on timeout.
wait_http() {
  local url=$1 code=$2 deadline=$((SECONDS + $3)) got
  while ((SECONDS < deadline)); do
    got=$(curl -s --max-time $((deadline - SECONDS)) -o /dev/null -w '%{http_code}' --cacert "$PG_CA_DIR/ca.crt" "$url" 2>/dev/null || true)
    [[ $got == "$code" ]] && return 0
    sleep 1
  done
  return 1
}

# api <method> <path> [curl args]: call the GitLab API as admin, or as
# $API_SUDO when it is set.
api() {
  local method=$1 path=$2 sudo=() header="$PG_RUNTIME/tokens/admin.header"
  shift 2
  # The token goes to curl from a file, so it stays out of the process list.
  if [[ ! -s $header || $header -ot $PG_RUNTIME/tokens/admin ]]; then
    (umask 077 && printf 'PRIVATE-TOKEN: %s\n' "$(<"$PG_RUNTIME/tokens/admin")" >"$header")
  fi
  if [[ -n ${API_SUDO:-} ]]; then sudo=(-H "Sudo: $API_SUDO"); fi
  curl -sS --max-time 30 --fail-with-body --cacert "$PG_CA_DIR/ca.crt" \
    -X "$method" -H "@$header" "${sudo[@]}" \
    "https://gitlab.playground.localhost/api/v4$path" "$@"
}

# uri <text>: percent-encode.
uri() { jq -rn --arg t "$1" '$t|@uri'; }

# push_dir <project-id> <branch> <message> <dir> <file>...: one commit that
# creates or updates the files (paths relative to <dir>) through the API.
# A missing branch starts from $START (an empty repository needs none).
push_dir() {
  local project=$1 branch=$2 message=$3 dir=$4 ref file action actions='[]'
  shift 4
  local start=
  ref=$branch
  if ! api GET "/projects/$project/repository/branches/$(uri "$branch")" >/dev/null 2>&1; then
    start=${START:-}
    ref=${start:-$branch}
  fi
  for file in "$@"; do
    action=create
    if api GET "/projects/$project/repository/files/$(uri "$file")?ref=$(uri "$ref")" >/dev/null 2>&1; then action=update; fi
    actions=$(jq --arg a "$action" --arg f "$file" --rawfile c "$dir/$file" \
      '. + [{action: $a, file_path: $f, content: $c}]' <<<"$actions")
  done
  jq -n --arg b "$branch" --arg s "$start" --arg m "$message" --argjson a "$actions" \
    '{branch: $b, commit_message: $m, actions: $a} + (if $s != "" then {start_branch: $s} else {} end)' |
    api POST "/projects/$project/repository/commits" -H 'Content-Type: application/json' -d @- >/dev/null
}

# http_code <path>: the status code of a GET, 000 when curl fails.
http_code() { api GET "$1" -o /dev/null -w '%{http_code}' 2>/dev/null || true; }

# cancel_pipelines <path>...: cancel again each round, because a pipeline that is still
# being created answers 403 to a cancel. The cancel runs as demo, the owner:
# root gets 403 on the pipelines of a project it is not a member of.
cancel_pipelines() {
  local path id list left deadline=$((SECONDS + 180))
  local active='running|pending|created|preparing|waiting_for_resource|canceling'
  while ((SECONDS < deadline)); do
    left=0
    for path in "$@"; do
      [[ $(http_code "/projects/$(uri "$path")") == 200 ]] || continue
      list=$(api GET "/projects/$(uri "$path")/pipelines?per_page=100") || die "cannot list the pipelines of $path"
      for id in $(jq -r --arg a "$active" '.[] | select(.status | test("^(" + $a + ")$")) | .id' <<<"$list"); do
        left=$((left + 1))
        API_SUDO=demo api POST "/projects/$(uri "$path")/pipelines/$id/cancel" >/dev/null 2>&1 || true
      done
    done
    ((left == 0)) && return 0
    sleep 2
  done
  die "pipelines still run after 180 s"
}

# These use $p (the project path, URL-encoded) and $timeout_s (default 600).
# job_status <pipeline> <name>: the status of a job, empty when it is missing.
# shellcheck disable=SC2154
job_status() { api GET "/projects/$p/pipelines/$1/jobs" | jq -r --arg n "$2" '.[] | select(.name == $n) | .status'; }
# shellcheck disable=SC2154
job_id() { api GET "/projects/$p/pipelines/$1/jobs" | jq -r --arg n "$2" '.[] | select(.name == $n) | .id'; }

# shellcheck disable=SC2154
fail_job() {
  log "job $2 of pipeline $1 failed; log tail:"
  api GET "/projects/$p/jobs/$(job_id "$1" "$2")/trace" | tail -n 30 >&2 || true
  exit 1
}

# wait_job <pipeline> <name> <status>
# shellcheck disable=SC2154
wait_job() {
  local deadline=$((SECONDS + ${timeout_s:-600})) got
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
# shellcheck disable=SC2154
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
