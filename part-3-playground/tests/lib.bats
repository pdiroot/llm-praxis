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

@test "lib.sh keeps compose on part 3 when the shell names part 2" {
  COMPOSE_PROJECT_NAME=llm-praxis-part-2 run bash -c "source '$ROOT/scripts/lib.sh'; echo \"\$COMPOSE_PROJECT_NAME\""

  [ "$status" -eq 0 ]
  [ "$output" = "llm-praxis-part-3" ]
}

@test "clone_demo stops before it clones when the token of demo is missing" {
  export PG_RUNTIME="$BATS_TEST_TMPDIR/runtime" PG_DEMO_HOME="$BATS_TEST_TMPDIR/demo"
  mkdir -p "$PG_RUNTIME/tokens"

  run bash -c "source '$ROOT/scripts/lib.sh'; clone_demo"

  [ "$status" -ne 0 ]
  [[ $output == *"no token of demo"* ]]
  [ ! -e "$PG_DEMO_HOME/dice-roller" ]
}

@test "stop_demo_app stops a dice-roller server and leaves other servers alone" {
  app=$((20000 + RANDOM % 20000))
  other=$((app + 1))
  mkdir -p "$BATS_TEST_TMPDIR/dice_roller"
  printf 'import http.server, sys\nhttp.server.test(http.server.SimpleHTTPRequestHandler, port=int(sys.argv[1]), bind="127.0.0.1")\n' \
    >"$BATS_TEST_TMPDIR/dice_roller/__main__.py"
  (cd "$BATS_TEST_TMPDIR" && exec python3 -m dice_roller "$app" >/dev/null 2>&1) &
  NC_PID=$!
  python3 -m http.server "$other" --bind 127.0.0.1 >/dev/null 2>&1 &
  SLEEP_PID=$!
  sleep 1

  run bash -c "source '$ROOT/scripts/lib.sh'; stop_demo_app $app $other"

  [ "$status" -eq 0 ]
  sleep 0.5
  ! kill -0 "$NC_PID" 2>/dev/null
  kill -0 "$SLEEP_PID"
}
