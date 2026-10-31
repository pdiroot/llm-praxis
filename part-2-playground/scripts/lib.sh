#!/usr/bin/env bash
# Shared helpers. Source this file; it sets no shell options.

# Paths.

PG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PG_RUNTIME="${PG_RUNTIME:-$PG_ROOT/runtime}"
PG_CA_DIR="${PG_CA_DIR:-$HOME/.config/playgrounds/tls}"

# The demo session lives outside this repository and the workspace, so Claude
# Code finds no parent CLAUDE.md or .mcp.json.
PG_DEMO_HOME="${PG_DEMO_HOME-$HOME/llm-praxis-demo}"
while [[ $PG_DEMO_HOME == */ && $PG_DEMO_HOME != / ]]; do PG_DEMO_HOME=${PG_DEMO_HOME%/}; done

# provisioned: 0 when a finished provisioning left its marker and the containers exist.
provisioned() {
  [[ -f $PG_RUNTIME/.provisioned && -n $(cd "$PG_ROOT" && docker compose ps -aq 2>/dev/null) ]]
}

# Logging.

log() { printf '%s\n' "$*" >&2; }

die() {
  log "error: $*"
  exit 1
}

# section <emoji> <title>: print a banner for a new category of work.
section() {
  local line="── $1 $2 "

  while ((${#line} < 72)); do line+="─"; done
  log ""
  log "$line"
}

# HTTP.

# wait_http <url> <code> <timeout_s>: 0 when the URL answers <code>, 1 on timeout.
wait_http() {
  local url=$1 code=$2 deadline=$((SECONDS + $3)) got left

  while ((SECONDS < deadline)); do
    left=$((deadline - SECONDS > 1 ? deadline - SECONDS : 1))
    got=$(curl -s --max-time "$left" -o /dev/null -w '%{http_code}' \
      --cacert "$PG_CA_DIR/ca.crt" "$url" 2>/dev/null || true)
    [[ $got == "$code" ]] && return 0
    sleep 1
  done

  return 1
}

# GitLab API.

# admin_header: write the header file that carries the admin token to curl.
# The token goes to curl from a file, so it stays out of the process list.
admin_header() {
  local header=$1 token="$PG_RUNTIME/tokens/admin"
  if [[ ! -s $header || $header -ot $token ]]; then
    (umask 077 && printf 'PRIVATE-TOKEN: %s\n' "$(<"$token")" >"$header")
  fi
}

# api <method> <path> [curl args]: call the GitLab API as admin, or as
# $API_SUDO when it is set.
api() {
  local method=$1 path=$2 sudo=() header="$PG_RUNTIME/tokens/admin.header"
  shift 2

  admin_header "$header"
  if [[ -n ${API_SUDO:-} ]]; then sudo=(-H "Sudo: $API_SUDO"); fi

  curl -sS --max-time 30 --fail-with-body --cacert "$PG_CA_DIR/ca.crt" \
    -X "$method" -H "@$header" "${sudo[@]}" \
    "https://gitlab.playground.localhost/api/v4$path" "$@"
}

# new_admin_token: write a random token to runtime/tokens/admin and give it
# to root with bootstrap.rb. The caller runs it with ||, which turns off
# errexit here, so each step returns on its own failure.
new_admin_token() {
  local token="$PG_RUNTIME/tokens/admin"

  mkdir -p "$PG_RUNTIME/tokens" || return
  (
    umask 077
    printf 'glpat-%s' "$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 26)" >"$token"
  ) || return

  ADMIN_TOKEN=$(<"$token") docker compose -f "$PG_ROOT/compose.yaml" \
    exec -T -e ADMIN_TOKEN gitlab gitlab-rails runner - <"$PG_ROOT/scripts/bootstrap.rb" >/dev/null
}

# admin_token: make sure runtime/tokens/admin works. The token expires after
# 30 days; an expired or missing one is made again with bootstrap.rb.
admin_token() {
  if [[ -s $PG_RUNTIME/tokens/admin ]] && api GET /user >/dev/null 2>&1; then return; fi

  log "admin token"
  new_admin_token || die "cannot renew the admin token; is the playground up? Run task playground:start"
  api GET /user >/dev/null || die "the admin token does not work; run task playground:start"
}

# uri <text>: percent-encode.
uri() { jq -rn --arg t "$1" '$t|@uri'; }

# http_code <path>: the status code of a GET, 000 when curl fails.
http_code() { api GET "$1" -o /dev/null -w '%{http_code}' 2>/dev/null || true; }

# commit_actions <project> <ref> <dir> <file>...: print the JSON actions of a
# commit: "update" for a file that exists on <ref>, else "create".
# It runs in $(...), where errexit is off, so a failed jq returns at once.
commit_actions() {
  local project=$1 ref=$2 dir=$3 file action actions='[]'
  shift 3

  for file in "$@"; do
    action=create
    if api GET "/projects/$project/repository/files/$(uri "$file")?ref=$(uri "$ref")" >/dev/null 2>&1; then
      action=update
    fi
    actions=$(jq --arg a "$action" --arg f "$file" --rawfile c "$dir/$file" \
      '. + [{action: $a, file_path: $f, content: $c}]' <<<"$actions") || return
  done

  printf '%s\n' "$actions"
}

# push_dir <project-id> <branch> <message> <dir> <file>...: one commit that
# creates or updates the files (paths relative to <dir>) through the API.
# A missing branch starts from $START (an empty repository needs none).
push_dir() {
  local project=$1 branch=$2 message=$3 dir=$4 ref start='' actions
  shift 4

  ref=$branch
  if ! api GET "/projects/$project/repository/branches/$(uri "$branch")" >/dev/null 2>&1; then
    start=${START:-}
    ref=${start:-$branch}
  fi

  actions=$(commit_actions "$project" "$ref" "$dir" "$@") || return

  jq -n --arg b "$branch" --arg s "$start" --arg m "$message" --argjson a "$actions" \
    '{branch: $b, commit_message: $m, actions: $a} + (if $s != "" then {start_branch: $s} else {} end)' |
    api POST "/projects/$project/repository/commits" -H 'Content-Type: application/json' -d @- >/dev/null
}

# Pipelines and jobs.

# cancel_active <path>: cancel the active pipelines of a project and print
# their count. The cancel runs as demo, the owner: root gets 403 on the
# pipelines of a project it is not a member of.
cancel_active() {
  local path=$1 code list id count=0
  local active='running|pending|created|preparing|waiting_for_resource|canceling'

  code=$(http_code "/projects/$(uri "$path")")
  if [[ $code == 404 ]]; then
    echo 0
    return
  fi
  [[ $code == 200 ]] || die "cannot read $path: HTTP $code"

  list=$(api GET "/projects/$(uri "$path")/pipelines?per_page=100") || die "cannot list the pipelines of $path"
  for id in $(jq -r --arg a "$active" '.[] | select(.status | test("^(" + $a + ")$")) | .id' <<<"$list"); do
    count=$((count + 1))
    API_SUDO=demo api POST "/projects/$(uri "$path")/pipelines/$id/cancel" >/dev/null 2>&1 || true
  done

  echo "$count"
}

# cancel_pipelines <path>...: cancel again each round, because a pipeline
# that is still being created answers 403 to a cancel.
cancel_pipelines() {
  local path n left deadline=$((SECONDS + 60))

  while ((SECONDS < deadline)); do
    left=0
    for path in "$@"; do
      n=$(cancel_active "$path") || exit 1
      left=$((left + n))
    done
    ((left == 0)) && return 0
    sleep 2
  done

  die "pipelines still run after 60 s"
}

# These use $p (the project path, URL-encoded) and $timeout_s (default 300).
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
  local start=$SECONDS deadline=$((SECONDS + ${timeout_s:-300})) got next=$((SECONDS + 30))

  while ((SECONDS < deadline)); do
    got=$(job_status "$1" "$2")
    [[ $got == "$3" ]] && return 0
    [[ $got == failed || $got == canceled ]] && fail_job "$1" "$2"
    if ((SECONDS >= next)); then
      log "job $2 is '$got' after $((SECONDS - start)) s"
      next=$((SECONDS + 30))
    fi
    sleep 3
  done

  log "timeout: job $2 of pipeline $1 is '$got', wanted $3"
  fail_job "$1" "$2"
}

# wait_pipeline <sha>: print the id of the pipeline of a commit.
# shellcheck disable=SC2154
wait_pipeline() {
  local deadline=$((SECONDS + 30)) id

  while ((SECONDS < deadline)); do
    id=$(api GET "/projects/$p/pipelines?sha=$1" | jq -r '.[0].id // empty')
    if [[ -n $id ]]; then
      echo "$id"
      return 0
    fi
    sleep 2
  done

  die "no pipeline for commit $1"
}

# Demo folder.

# demo_home_ok: 0 when PG_DEMO_HOME is an absolute folder that may be deleted:
# not /, not $HOME, and neither contains $HOME or $PG_ROOT.
demo_home_ok() {
  [[ $PG_DEMO_HOME == /?* && $PG_DEMO_HOME != "$HOME" ]] || return 1
  [[ $HOME/ != "$PG_DEMO_HOME"/* && $PG_ROOT/ != "$PG_DEMO_HOME"/* ]]
}

# demo_home_check: demo_home_ok, and an existing folder must hold the marker
# that demo_home_init writes, so only a folder made by this playground goes.
demo_home_check() {
  demo_home_ok || die "refusing PG_DEMO_HOME='$PG_DEMO_HOME'"
  [[ ! -e $PG_DEMO_HOME || -f $PG_DEMO_HOME/.llm-praxis-demo ]] ||
    die "refusing PG_DEMO_HOME='$PG_DEMO_HOME': no .llm-praxis-demo marker"
}

# demo_home_rm: delete PG_DEMO_HOME after demo_home_check.
demo_home_rm() {
  demo_home_check
  rm -rf "$PG_DEMO_HOME"
}

# demo_home_init: make PG_DEMO_HOME with its marker when it is missing, keep a
# marked folder, die on a folder without the marker. Call it before any step
# that creates something in the folder.
demo_home_init() {
  demo_home_ok || die "refusing PG_DEMO_HOME='$PG_DEMO_HOME'"
  if [[ ! -e $PG_DEMO_HOME ]]; then
    mkdir -p "$PG_DEMO_HOME"
    touch "$PG_DEMO_HOME/.llm-praxis-demo"
  fi
  demo_home_check
}

# demo_ssh_config: copy runtime/ssh/config to $PG_DEMO_HOME/ssh/config (mode
# 600). Its key and known_hosts paths are absolute, so the keys stay in runtime/.
demo_ssh_config() {
  demo_home_init
  mkdir -p "$PG_DEMO_HOME/ssh"
  (umask 077 && cp "$PG_RUNTIME/ssh/config" "$PG_DEMO_HOME/ssh/config")
  chmod 600 "$PG_DEMO_HOME/ssh/config"
}

# clone_demo: clone demo/whoami to $PG_DEMO_HOME/whoami.
clone_demo() {
  demo_home_init
  demo_ssh_config

  git clone -c "core.sshCommand=ssh -F '$PG_DEMO_HOME/ssh/config'" \
    ssh://git@gitlab.playground.localhost:2222/demo/whoami.git "$PG_DEMO_HOME/whoami"
}

# Isolation of the demo session.

# claude_files_in <dir>: print each file in <dir> that Claude Code loads from
# a parent folder.
claude_files_in() {
  local f
  for f in CLAUDE.md CLAUDE.local.md .claude/CLAUDE.md .claude/rules AGENTS.md .claude/AGENTS.md .mcp.json; do
    [[ ! -e $1/$f ]] || printf '%s\n' "${1%/}/$f"
  done
}

# isolation_scan <clone>: list every file in a parent folder of <clone>, up to
# /, that Claude Code would load. It walks the physical and the logical path.
# Prints one path per line; 0 when none, 1 when found, 2 on a missing parent.
isolation_scan() {
  local mode dir out=""

  for mode in -P -L; do
    dir=$(cd "$1/.." && pwd "$mode") || return 2
    while :; do
      out+=$(claude_files_in "$dir")$'\n'
      [[ $dir == / ]] && break
      dir=$(dirname "$dir")
    done
  done

  out=$(sort -u <<<"$out" | sed '/^$/d')
  [[ -z $out ]] || {
    printf '%s\n' "$out"
    return 1
  }
}

# mcp_foreign <clone>: run "claude mcp list" as the demo session and print the
# servers that the clone's own .mcp.json does not name. Fails when claude fails.
mcp_foreign() {
  local clone=$1 listed own

  listed=$(cd "$clone" &&
    CLAUDE_CONFIG_DIR="$PG_DEMO_HOME/claude-config" ENABLE_CLAUDEAI_MCP_SERVERS=false \
      claude mcp list 2>/dev/null) || return 2
  own=$(if [[ -f $clone/.mcp.json ]]; then jq -r '.mcpServers // {} | keys[]' "$clone/.mcp.json"; fi)

  # A server line is "name: url-or-command - status"; a name can hold ":" or " " but not ": ".
  awk 'index($0, ": ") && index($0, " - ") { print substr($0, 1, index($0, ": ") - 1) }' <<<"$listed" |
    grep -vxF -e "$own" -e '' || true
}

# Claude Code profile of the demo.

# demo_logout: log the demo profile out of Claude Code. The profile has its own
# Keychain entry, so the owner's login stays. It runs only with the absolute
# $PG_DEMO_HOME/claude-config folder in CLAUDE_CONFIG_DIR, and only when that exists.
demo_logout() {
  local config="$PG_DEMO_HOME/claude-config" status

  demo_home_ok || die "refusing PG_DEMO_HOME='$PG_DEMO_HOME'"
  [[ -d $config ]] || return 0

  # "auth status" exits 1 on a profile that is not logged in; then there is nothing to log out.
  status=$(CLAUDE_CONFIG_DIR=$config claude auth status 2>/dev/null || true)
  if jq -e '.loggedIn == false' <<<"$status" >/dev/null 2>&1; then
    log "demo profile is not logged in"
  else
    CLAUDE_CONFIG_DIR=$config claude auth logout || die "the logout of the demo profile failed; the folder stays"
  fi
}
