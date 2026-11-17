#!/usr/bin/env bash
# preflight.sh: automatic checks before a rehearsal or the session, then the
# manual checks. Exit 1 on the first failed automatic check.
set -euo pipefail
# shellcheck source=lib.sh
# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

step() {
  local what=$1
  shift
  if "$@"; then log "ok: $what"; else die "$what"; fi
}

part2_stopped() { ! part2_running; }
has() { command -v "$1" >/dev/null; }
quiet() { "$@" >/dev/null 2>&1; }
gitlab_up() { wait_http https://gitlab.playground.localhost/users/sign_in 200 30; }
git_ssh() {
  local out
  out=$(ssh -F "$PG_RUNTIME/ssh/config" -o BatchMode=yes -o ConnectTimeout=10 \
    -T git@gitlab.playground.localhost 2>&1 || true)
  [[ $out == *Welcome* ]]
}
project_empty() { [[ $(api GET /projects/demo%2Fdice-roller | jq -r .empty_repo) == true ]]; }

# The official marketplace registers at the first start of the demo session.
official_marketplace() {
  local out

  # claude creates a missing config folder, and a demo folder without its marker blocks claude:start.
  [[ -d $PG_DEMO_HOME/claude-config ]] || return 1
  out=$(CLAUDE_CONFIG_DIR="$PG_DEMO_HOME/claude-config" claude plugin marketplace list 2>/dev/null || true)
  [[ $out == *claude-plugins-official* ]]
}

claude_new_enough() {
  local v
  v=$(claude --version | awk '{print $1}')
  [[ $(printf '%s\n2.1.312\n' "$v" | sort -V | head -n 1) == 2.1.312 ]]
}

# The demo clone must load no parent CLAUDE.md or .mcp.json, and the demo
# profile must list no MCP server except the ones of the clone's own .mcp.json.
demo_isolated() {
  local clone="$PG_DEMO_HOME/dice-roller" hits extra
  [[ -d $clone ]] || return 0

  hits=$(isolation_scan "$clone") || {
    log "a parent folder of the clone has: $hits"
    return 1
  }

  extra=$(mcp_foreign "$clone") || {
    log "claude mcp list failed"
    return 1
  }

  [[ -z $extra ]] || {
    log "the demo session lists MCP servers that are not its own: $extra"
    return 1
  }
}

section "🧱" "Docker: only part 3 runs"
step "the part 2 playground is stopped" part2_stopped

section "🌐" "GitLab: HTTPS, SSH and the API"
step "GitLab answers 200 over HTTPS" gitlab_up
step "git over SSH reaches GitLab" git_ssh
admin_token
step "the API answers" api GET /user -o /dev/null
step "demo/dice-roller is empty" project_empty

section "🤖" "Claude Code: version, tools and isolation"
step "claude is 2.1.312 or later" claude_new_enough
step "direnv is installed" has direnv
step "glab is installed" has glab
step "uv is installed" has uv
step "ruff runs through uvx" quiet uvx ruff --version
step "the demo session loads nothing from the workspace" demo_isolated
step "the official marketplace is there (else start task claude:start once)" official_marketplace

section "📝" "Manual checks, in the demo session"
cat <<'TEXT'
  [ ] /mcp lists no claude.ai connector.
  [ ] A test alert appears: osascript -e 'display alert "Test"'.
  [ ] Do Not Disturb is off, so the alert of the loop shows on the projector.
TEXT
