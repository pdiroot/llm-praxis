#!/usr/bin/env bash
# terminate.sh: delete the playground at once. The root CA stays.
set -euo pipefail
# shellcheck source=lib.sh
# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$PG_ROOT"

section "🤖" "Claude Code: log out and delete the demo folder"
demo_logout
stop_demo_app
demo_home_rm

section "🐳" "Docker Compose: delete the containers and the volumes of part 3"
docker compose down -v --timeout 0

section "🧹" "Files: delete runtime/"
[[ $PG_RUNTIME == "$PG_ROOT/runtime" ]] || die "refusing to delete PG_RUNTIME='$PG_RUNTIME'"
rm -rf "$PG_RUNTIME"

section "✅" "Terminated in ${SECONDS} s. The root CA stays"
