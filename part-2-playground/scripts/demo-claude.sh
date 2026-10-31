#!/usr/bin/env bash
# Start the demo Claude Code session in the whoami clone, with its own config
# folder, so the owner's ~/.claude stays untouched.
set -euo pipefail
# shellcheck source=lib.sh
# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

config="$PG_DEMO_HOME/claude-config"
clone="$PG_DEMO_HOME/whoami"

demo_home_init
mkdir -p "$config"
[[ -e $config/settings.json ]] || cp "$PG_ROOT/demo/settings.json" "$config/settings.json"

export CLAUDE_CONFIG_DIR="$config"
export ENABLE_CLAUDEAI_MCP_SERVERS=false
export NODE_EXTRA_CA_CERTS="$PG_RUNTIME/tls/ca.crt"
export EDITOR=nano

demo_ssh_config
hits=$(isolation_scan "$clone") || die "Claude Code would load these files from a parent folder of the clone:
$hits"

cd "$clone"
exec claude --chrome "$@"
