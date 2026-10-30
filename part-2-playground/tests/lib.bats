#!/usr/bin/env bats

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "wait_http returns 1 after the timeout" {
  run bash -c "source '$ROOT/scripts/lib.sh'; start=\$SECONDS; wait_http http://127.0.0.1:1/ 200 2; rc=\$?; [ \$((SECONDS - start)) -le 5 ] && exit \$rc"
  [ "$status" -eq 1 ]
}

@test "PG_CA_DIR follows the variable" {
  PG_CA_DIR=/tmp/x run bash -c "source '$ROOT/scripts/lib.sh'; echo \"\$PG_CA_DIR\""
  [ "$status" -eq 0 ]
  [ "$output" = "/tmp/x" ]
}
