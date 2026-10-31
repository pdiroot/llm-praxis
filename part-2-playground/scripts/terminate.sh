#!/usr/bin/env bash
# terminate.sh: delete the playground at once. The root CA stays.
set -euo pipefail
# shellcheck source=lib.sh
# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$PG_ROOT"

section "🤖" "Claude Code: log out and delete the demo folder"
demo_logout
demo_home_rm

section "🐳" "Docker Compose: delete the containers and the volumes"
docker compose down -v --timeout 0

section "🧹" "Files: delete runtime/"
rm -rf "$PG_RUNTIME"

section "✅" "Terminated in ${SECONDS} s. The root CA stays"
