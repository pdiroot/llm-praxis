#!/usr/bin/env bash
# Start a demo Claude Code session in the dice-roller clone, with its own
# config folder, so the owner's ~/.claude stays untouched. The main session
# and the loop session both start here.
set -euo pipefail
# shellcheck source=lib.sh
# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

config="$PG_DEMO_HOME/claude-config"
clone="$PG_DEMO_HOME/dice-roller"

# quiet_lsp_dialog: Claude Code stops the LSP plugin dialog after five ignored
# dialogs, so the dialog never covers a live step on the projector.
quiet_lsp_dialog() {
  local state="$config/.claude.json" tmp

  [[ -f $state ]] || return 0
  jq -e '(.lspRecommendationIgnoredCount // 0) >= 5' "$state" >/dev/null 2>&1 && return 0

  tmp=$(mktemp "$config/.claude.json.XXXXXX")
  if jq '.lspRecommendationIgnoredCount = 5' "$state" >"$tmp"; then
    mv "$tmp" "$state"
  else
    rm -f "$tmp"
    log "warning: cannot turn off the LSP plugin dialog"
  fi
}

command -v direnv >/dev/null || die "direnv is missing: brew install direnv"
command -v uv >/dev/null || die "uv is missing: brew install uv"
[[ -d $clone ]] || die "no clone at $clone: run task claude:start first"

demo_home_init
mkdir -p "$config"
[[ -e $config/settings.json ]] || cp "$PG_ROOT/demo/settings.json" "$config/settings.json"
quiet_lsp_dialog

export CLAUDE_CONFIG_DIR="$config"
export ENABLE_CLAUDEAI_MCP_SERVERS=false
export NODE_EXTRA_CA_CERTS="$PG_RUNTIME/tls/ca.crt"
export EDITOR=nano
export GITLAB_HOST=gitlab.playground.localhost
# Keep the survey and the grey suggestions off the projector.
export CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY=1
export CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false

hits=$(isolation_scan "$clone") || die "Claude Code would load these files from a parent folder of the clone:
$hits"

section "🤖" "Claude Code: isolated session"
log "Profile:    $config"
log "Project:    $clone"
log "Connectors: off"

# direnv loads .env, so the session has the token of demo for glab.
cd "$clone"
# Forget the outer direnv state: direnv exec would revert the exports above.
unset DIRENV_DIFF DIRENV_DIR DIRENV_FILE DIRENV_WATCHES
export DIRENV_LOG_FORMAT=""
# The demo session commits without a signature.
export GIT_CONFIG_GLOBAL="$PG_ROOT/demo/gitconfig"
exec direnv exec . claude "$@"
