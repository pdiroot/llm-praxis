#!/usr/bin/env bash
# Start the demo Claude Code session in the whoami clone, with its own config
# folder, so the owner's ~/.claude stays untouched.
set -euo pipefail
# shellcheck source=lib.sh
# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

config="$PG_DEMO_HOME/claude-config"
clone="$PG_DEMO_HOME/whoami"

command -v direnv >/dev/null || die "direnv is missing: brew install direnv"

demo_home_init
mkdir -p "$config"
[[ -e $config/settings.json ]] || cp "$PG_ROOT/demo/settings.json" "$config/settings.json"

export CLAUDE_CONFIG_DIR="$config"
export ENABLE_CLAUDEAI_MCP_SERVERS=false
export NODE_EXTRA_CA_CERTS="$PG_RUNTIME/tls/ca.crt"
export EDITOR=nano
export GITLAB_HOST=gitlab.playground.localhost
# Keep the survey and the grey suggestions off the projector.
export CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY=1
export CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false

demo_ssh_config
hits=$(isolation_scan "$clone") || die "Claude Code would load these files from a parent folder of the clone:
$hits"

section "🤖" "Claude Code: isolated session"
log "Profile:    $config"
log "Project:    $clone"
log "Connectors: off"

# direnv loads .env, so the session starts with the token that the owner saved.
cd "$clone"
export DIRENV_LOG_FORMAT=""
exec direnv exec . claude --chrome "$@"
