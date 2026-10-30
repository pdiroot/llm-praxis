#!/usr/bin/env bats
# bats file_tags=live
# Live test: needs the running playground. It resets the real one, so the
# CA, the certificates, the SSH keys and the tokens must stay as they are.

setup() {
  ROOT="$BATS_TEST_DIRNAME/.."
  export PG_DEMO_HOME="$BATS_TEST_TMPDIR/demo"
  # shellcheck source=../scripts/lib.sh
  source "$ROOT/scripts/lib.sh"
  STUB="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$STUB"
  # The stub stands in for claude, so the test never logs the owner out.
  printf '#!/usr/bin/env bash\necho "CLAUDE_CONFIG_DIR=${CLAUDE_CONFIG_DIR:-} $*" >>"%s/claude.log"\n' "$BATS_TEST_TMPDIR" >"$STUB/claude"
  chmod +x "$STUB/claude"
}

teardown() {
  if [[ -n ${CREATED:-} ]]; then rm -rf "$PG_DEMO_HOME"; fi
}

keepers() { find "$PG_RUNTIME/ssh" "$PG_RUNTIME/tls" -type f -exec shasum {} + | sort; }

@test "reset during a pipeline" {
  before=$(keepers)
  dir="$ROOT/checkpoints/1-end/main"
  mapfile -t files < <(cd "$dir" && find . -type f | sed 's|^\./||')
  API_SUDO=demo push_dir demo%2Fwhoami main "feat: whoami" "$dir" "${files[@]}"
  for _ in $(seq 30); do
    s=$(api GET "/projects/demo%2Fwhoami/pipelines" | jq -r '.[0].status // empty')
    [[ $s == running || $s == pending || $s == created ]] && break
    sleep 2
  done
  [[ $s == running || $s == pending || $s == created ]]

  mkdir -p "$PG_DEMO_HOME/claude-config" "$PG_DEMO_HOME/whoami" "$PG_DEMO_HOME/sample-service"
  CREATED=1
  PATH="$STUB:$PATH" run "$ROOT/scripts/reset.sh"
  echo "$output"
  [ "$status" -eq 0 ]

  # An empty repository answers 404 or an empty list.
  out=$(api GET /projects/demo%2Fwhoami/repository/commits 2>/dev/null || echo '[]')
  [ "$(jq 'if type == "array" then length else 0 end' <<<"$out")" -eq 0 ]
  run ssh -F "$PG_RUNTIME/ssh/config" test.playground.localhost 'systemctl is-enabled whoami'
  [ "$status" -ne 0 ]
  [ "$status" -ne 255 ] # 255 is ssh itself failing
  [ ! -e "$PG_DEMO_HOME/claude-config" ]
  [ ! -e "$PG_DEMO_HOME/whoami" ]
  [ ! -e "$PG_DEMO_HOME/sample-service" ]
  grep -q "CLAUDE_CONFIG_DIR=$PG_DEMO_HOME/claude-config auth logout" "$BATS_TEST_TMPDIR/claude.log"
  grep -q "CLAUDE_CONFIG_DIR= auth status" "$BATS_TEST_TMPDIR/claude.log"
  [ "$(keepers)" = "$before" ]
  [ "$(api GET /projects/demo%2Fsample-service/repository/commits?per_page=100 | jq length)" -gt 0 ]
}
