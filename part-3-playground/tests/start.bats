#!/usr/bin/env bats
# Needs no playground: docker and curl are stubs.

setup() {
  ROOT="$BATS_TEST_DIRNAME/.."
  export PG_RUNTIME="$BATS_TEST_TMPDIR/runtime"
  export DOCKER_LOG="$BATS_TEST_TMPDIR/docker.log"
  mkdir -p "$PG_RUNTIME" "$BATS_TEST_TMPDIR/bin"

  # CONTAINERS answers "compose ps"; PART2 answers "docker ps" (part 2 containers).
  cat >"$BATS_TEST_TMPDIR/bin/docker" <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$DOCKER_LOG"
[[ $1 == ps ]] && printf '%s' "${PART2-}"
[[ $2 == ps ]] && printf '%s' "${CONTAINERS-}"
exit 0
STUB

  printf '#!/usr/bin/env bash\nprintf 200\n' >"$BATS_TEST_TMPDIR/bin/curl"
  chmod +x "$BATS_TEST_TMPDIR/bin/docker" "$BATS_TEST_TMPDIR/bin/curl"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

provisioned_rc() { bash -c "source '$ROOT/scripts/lib.sh'; provisioned"; }

@test "no marker: not provisioned" {
  CONTAINERS=abc run provisioned_rc

  [ "$status" -ne 0 ]
}

@test "a marker with no containers: not provisioned" {
  touch "$PG_RUNTIME/.provisioned"

  CONTAINERS= run provisioned_rc

  [ "$status" -ne 0 ]
}

@test "a marker with containers: provisioned" {
  touch "$PG_RUNTIME/.provisioned"

  CONTAINERS=abc run provisioned_rc

  [ "$status" -eq 0 ]
}

@test "a stopped playground resumes and is not built again" {
  touch "$PG_RUNTIME/.provisioned"

  CONTAINERS=abc run "$ROOT/scripts/start.sh"

  echo "$output"
  [ "$status" -eq 0 ]
  grep -qx 'compose start' "$DOCKER_LOG"
  ! grep -q 'compose up' "$DOCKER_LOG"
}

@test "part 2 running: start refuses and starts nothing" {
  touch "$PG_RUNTIME/.provisioned"

  PART2=abc CONTAINERS=abc run "$ROOT/scripts/start.sh"

  [ "$status" -ne 0 ]
  [[ $output == *"part 2 playground runs"* ]]
  ! grep -q '^compose' "$DOCKER_LOG"
}

@test "part2_running follows the containers of the part 2 project" {
  PART2=abc run bash -c "source '$ROOT/scripts/lib.sh'; part2_running"
  [ "$status" -eq 0 ]
  grep -q 'label=com.docker.compose.project=llm-praxis-part-2' "$DOCKER_LOG"

  PART2= run bash -c "source '$ROOT/scripts/lib.sh'; part2_running"
  [ "$status" -ne 0 ]
}
