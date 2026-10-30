#!/usr/bin/env bats

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

teardown() {
  kill "${NC_PID:-}" "${SLEEP_PID:-}" 2>/dev/null || true
}

@test "wait_http returns 1 after the timeout" {
  run bash -c "source '$ROOT/scripts/lib.sh'; start=\$SECONDS; wait_http http://127.0.0.1:1/ 200 2; rc=\$?; [ \$((SECONDS - start)) -le 5 ] || exit 99; exit \$rc"
  [ "$status" -eq 1 ]
}

@test "PG_CA_DIR follows the variable" {
  PG_CA_DIR=/tmp/x run bash -c "source '$ROOT/scripts/lib.sh'; echo \"\$PG_CA_DIR\""
  [ "$status" -eq 0 ]
  [ "$output" = "/tmp/x" ]
}

@test "wait_http returns 1 on a server that never answers" {
  port=$((20000 + RANDOM % 20000))
  # curl fails at once on a missing --cacert file, which would hide the hang
  touch "$BATS_TEST_TMPDIR/ca.crt"
  export PG_CA_DIR=$BATS_TEST_TMPDIR
  # the pipe keeps nc stdin open, so it accepts and stays silent
  mkfifo "$BATS_TEST_TMPDIR/hold"
  sleep 20 >"$BATS_TEST_TMPDIR/hold" &
  SLEEP_PID=$!
  nc -l 127.0.0.1 "$port" <"$BATS_TEST_TMPDIR/hold" >/dev/null &
  NC_PID=$!
  sleep 1
  run bash -c "source '$ROOT/scripts/lib.sh'; start=\$SECONDS; wait_http http://127.0.0.1:$port/ 200 2; rc=\$?; [ \$((SECONDS - start)) -le 4 ] || exit 99; exit \$rc"
  [ "$status" -eq 1 ]
}
