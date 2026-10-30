#!/usr/bin/env bats
# demo_logout with a claude stub on PATH; the real claude never runs.

setup() {
  ROOT="$BATS_TEST_DIRNAME/.."
  export PG_RUNTIME="$BATS_TEST_TMPDIR/runtime"
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  # STATUS is the JSON of "auth status"; LOGOUT_RC is the exit code of "auth logout".
  cat >"$BATS_TEST_TMPDIR/bin/claude" <<'STUB'
#!/usr/bin/env bash
echo "CLAUDE_CONFIG_DIR=${CLAUDE_CONFIG_DIR:-} $*" >>"$BATS_TEST_TMPDIR/claude.log"
[[ $1 == auth && $2 == status ]] && echo "${STATUS:-{\"loggedIn\":true\}}"
[[ $2 == logout ]] && exit "${LOGOUT_RC:-0}"
exit 0
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/claude"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

logout() { bash -c "source '$ROOT/scripts/lib.sh'; demo_logout"; }

@test "no folder: claude does not run" {
  run logout
  [ "$status" -eq 0 ]
  [ ! -e "$BATS_TEST_TMPDIR/claude.log" ]
}

@test "logged out: no logout" {
  mkdir -p "$PG_RUNTIME/claude-config"
  STATUS='{"loggedIn":false}' run logout
  [ "$status" -eq 0 ]
  ! grep -q logout "$BATS_TEST_TMPDIR/claude.log"
}

@test "logged in: logout runs with the absolute demo folder" {
  mkdir -p "$PG_RUNTIME/claude-config"
  run logout
  [ "$status" -eq 0 ]
  grep -qx "CLAUDE_CONFIG_DIR=$PG_RUNTIME/claude-config auth logout" "$BATS_TEST_TMPDIR/claude.log"
}

@test "a failed logout dies" {
  mkdir -p "$PG_RUNTIME/claude-config"
  LOGOUT_RC=1 run logout
  [ "$status" -ne 0 ]
  [[ $output == *"logout of the demo profile failed"* ]]
}
