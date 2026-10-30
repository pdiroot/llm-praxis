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
  curl -sS --fail-with-body --cacert "$PG_CA_DIR/ca.crt" \
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
