#!/usr/bin/env bash
# Start the demo Claude Code session in the whoami clone, with its own config
# folder, so the owner's ~/.claude stays untouched.
set -euo pipefail
# shellcheck source=lib.sh
# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

config="$PG_RUNTIME/claude-config"
mkdir -p "$config"
[[ -e $config/settings.json ]] || cp "$PG_ROOT/demo/settings.json" "$config/settings.json"

export CLAUDE_CONFIG_DIR="$config"
export ENABLE_CLAUDEAI_MCP_SERVERS=false
export NODE_EXTRA_CA_CERTS="$PG_RUNTIME/tls/ca.crt"
export EDITOR=nano
cd "$PG_RUNTIME/clone/whoami"
exec claude --chrome "$@"
