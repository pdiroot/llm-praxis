#!/usr/bin/env bats

bats_require_minimum_version 1.5.0
setup() {
  ROOT="$BATS_TEST_DIRNAME/.."
  SETTINGS="$ROOT/demo/settings.json"
}

# asks <command>: 0 when a Bash(...) ask rule matches; * is a glob.
asks() {
  local rule pattern
  while IFS= read -r rule; do
    pattern=${rule#Bash(}
    pattern=${pattern%)}
    # shellcheck disable=SC2053
    [[ $1 == $pattern ]] && return 0
  done < <(jq -r '.permissions.ask[]' "$SETTINGS")
  return 1
}

@test "every job start asks" {
  asks 'glab ci trigger deploy-prod -b main'
  asks 'glab ci run -b main'
  asks 'glab api -X POST projects/:id/jobs/49/play'
  asks 'glab api projects/:id/jobs/49/play -X POST'
  asks 'glab ci retry 49'
  asks 'glab api -X POST projects/:id/jobs/49/retry'
  asks 'glab ci run-trig -t x -b main'
  asks 'glab api graphql -f query=mutation{jobPlay(input:{id:"gid://gitlab/Ci::Build/49"}){job{id}}}'
  asks 'glab api -X POST projects/:id/pipelines -f ref=main'
  asks 'glab api projects/:id/pipelines -X POST -f ref=main'
}

@test "a read does not ask" {
  run ! asks 'glab api user'
  run ! asks 'glab ci list'
  run ! asks 'glab api projects/:id/pipelines'
  run ! asks 'glab api projects/:id/pipelines/12/jobs'
}

@test "the settings deny .env, run the hook and extend the auto mode" {
  [ "$(jq -r '.permissions.deny[0]' "$SETTINGS")" = 'Read(**/.env)' ]
  jq -e '.hooks.SessionStart[0].hooks[0].command | contains("CLAUDE_ENV_FILE") and contains("set -a")' "$SETTINGS"
  [ "$(jq -r '.autoMode.environment[0]' "$SETTINGS")" = '$defaults' ]
  jq -e '.autoMode.environment | length == 3' "$SETTINGS"
}

@test "the launch keeps the owner's config" {
  export PG_RUNTIME="$BATS_TEST_TMPDIR/runtime"
  mkdir -p "$PG_RUNTIME/clone/whoami" "$BATS_TEST_TMPDIR/bin"
  cat >"$BATS_TEST_TMPDIR/bin/claude" <<'STUB'
#!/usr/bin/env bash
echo "$CLAUDE_CONFIG_DIR"
echo "$ENABLE_CLAUDEAI_MCP_SERVERS"
echo "$NODE_EXTRA_CA_CERTS"
echo "$EDITOR"
echo "$PWD"
echo "$*"
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/claude"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" run "$ROOT/scripts/demo-claude.sh" --resume
  [ "$status" -eq 0 ]
  # Absolute paths: macOS may resolve the temp dir through a symlink, so compare the pwd by suffix.
  [ "${lines[0]}" = "$PG_RUNTIME/claude-config" ]
  [ "${lines[1]}" = false ]
  [ "${lines[2]}" = "$PG_RUNTIME/tls/ca.crt" ]
  [ "${lines[3]}" = nano ]
  [[ ${lines[4]} == */runtime/clone/whoami ]]
  [ "${lines[5]}" = "--chrome --resume" ]
}

@test "the settings are copied once and never overwritten" {
  export PG_RUNTIME="$BATS_TEST_TMPDIR/runtime"
  mkdir -p "$PG_RUNTIME/clone/whoami" "$BATS_TEST_TMPDIR/bin"
  printf '#!/usr/bin/env bash\n' >"$BATS_TEST_TMPDIR/bin/claude"
  chmod +x "$BATS_TEST_TMPDIR/bin/claude"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" "$ROOT/scripts/demo-claude.sh"
  cmp "$SETTINGS" "$PG_RUNTIME/claude-config/settings.json"
  echo '{"mine":1}' >"$PG_RUNTIME/claude-config/settings.json"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" "$ROOT/scripts/demo-claude.sh"
  [ "$(cat "$PG_RUNTIME/claude-config/settings.json")" = '{"mine":1}' ]
}
