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
  asks 'glab api graphql -f query=mutation{jobRetry(input:{id:"gid://gitlab/Ci::Build/49"}){job{id}}}'
  asks 'glab api projects/:id/pipelines -f ref=main'
  asks 'glab api projects/:id/pipeline --field ref=main'
  asks "glab api -H 'X: y' graphql -f query=mutation{jobPlay(input:{id:\"gid://gitlab/Ci::Build/49\"}){job{id}}}"
  asks 'glab api -f ref=main projects/:id/pipeline'
  asks 'glab api --field=ref=main projects/:id/pipeline'
  asks 'glab api projects/:id/pipeline -fref=main'
}

@test "a read does not ask" {
  run ! asks 'glab api user'
  run ! asks 'glab ci list'
  run ! asks 'glab api projects/:id/pipelines'
  run ! asks 'glab api projects/:id/pipelines/12/jobs'
  run ! asks 'glab api projects/:id/jobs'
  run ! asks 'glab api projects/:id/pipelines?per_page=5'
}

@test "the settings deny .env, run the hook and extend the auto mode" {
  [ "$(jq -r '.permissions.deny[0]' "$SETTINGS")" = 'Read(**/.env)' ]
  jq -e '.hooks.SessionStart[0].hooks[0].command | contains("CLAUDE_ENV_FILE") and contains("set -a")' "$SETTINGS"
  [ "$(jq -r '.autoMode.environment[0]' "$SETTINGS")" = '$defaults' ]
  jq -e '.autoMode.environment | length == 3' "$SETTINGS"
}

@test "the launch keeps the owner's config" {
  export PG_RUNTIME="$BATS_TEST_TMPDIR/runtime"
  export PG_DEMO_HOME="$BATS_TEST_TMPDIR/demo"
  mkdir -p "$PG_RUNTIME/ssh" "$PG_DEMO_HOME/whoami"; echo "Host x" >"$PG_RUNTIME/ssh/config"
  mkdir -p "$BATS_TEST_TMPDIR/bin"
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
  [ "${lines[0]}" = "$PG_DEMO_HOME/claude-config" ]
  [ "${lines[1]}" = false ]
  [ "${lines[2]}" = "$PG_RUNTIME/tls/ca.crt" ]
  [ "${lines[3]}" = nano ]
  [[ ${lines[4]} == */demo/whoami ]]
  [ "${lines[5]}" = "--chrome --resume" ]
}

@test "the settings are copied once and never overwritten" {
  export PG_RUNTIME="$BATS_TEST_TMPDIR/runtime"
  export PG_DEMO_HOME="$BATS_TEST_TMPDIR/demo"
  mkdir -p "$PG_RUNTIME/ssh" "$PG_DEMO_HOME/whoami"; echo "Host x" >"$PG_RUNTIME/ssh/config"
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/usr/bin/env bash\n' >"$BATS_TEST_TMPDIR/bin/claude"
  chmod +x "$BATS_TEST_TMPDIR/bin/claude"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" "$ROOT/scripts/demo-claude.sh"
  cmp "$SETTINGS" "$PG_DEMO_HOME/claude-config/settings.json"
  echo '{"mine":1}' >"$PG_DEMO_HOME/claude-config/settings.json"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" "$ROOT/scripts/demo-claude.sh"
  [ "$(cat "$PG_DEMO_HOME/claude-config/settings.json")" = '{"mine":1}' ]
}

@test "the launch copies the ssh config with mode 600" {
  export PG_RUNTIME="$BATS_TEST_TMPDIR/runtime"
  export PG_DEMO_HOME="$BATS_TEST_TMPDIR/demo"
  mkdir -p "$PG_RUNTIME/ssh" "$PG_DEMO_HOME/whoami" "$BATS_TEST_TMPDIR/bin"
  echo "Host x" >"$PG_RUNTIME/ssh/config"
  printf '#!/usr/bin/env bash\n' >"$BATS_TEST_TMPDIR/bin/claude"
  chmod +x "$BATS_TEST_TMPDIR/bin/claude"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" "$ROOT/scripts/demo-claude.sh"
  cmp "$PG_RUNTIME/ssh/config" "$PG_DEMO_HOME/ssh/config"
  [ "$(stat -f %Lp "$PG_DEMO_HOME/ssh/config")" = 600 ]
}

@test "a launch refuses when a parent folder has a CLAUDE.md" {
  export PG_RUNTIME="$BATS_TEST_TMPDIR/runtime"
  export PG_DEMO_HOME="$BATS_TEST_TMPDIR/up/mid/demo"
  mkdir -p "$PG_RUNTIME/ssh" "$PG_DEMO_HOME/whoami" "$BATS_TEST_TMPDIR/bin"
  echo "Host x" >"$PG_RUNTIME/ssh/config"
  touch "$BATS_TEST_TMPDIR/up/CLAUDE.md"
  printf '#!/usr/bin/env bash\necho started\n' >"$BATS_TEST_TMPDIR/bin/claude"
  chmod +x "$BATS_TEST_TMPDIR/bin/claude"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" run "$ROOT/scripts/demo-claude.sh"
  [ "$status" -ne 0 ]
  [[ $output == *"up/CLAUDE.md"* ]]
  [[ $output != *started* ]]
}

scan() { bash -c "source '$ROOT/scripts/lib.sh'; isolation_scan '$1'"; }

@test "the parent scan fails on each file Claude Code loads" {
  for f in CLAUDE.md CLAUDE.local.md .claude/CLAUDE.md .claude/rules/a.md .mcp.json; do
    t="$BATS_TEST_TMPDIR/tree-${f//\//_}"
    mkdir -p "$t/a/b/whoami" "$t/$(dirname "$f")"
    touch "$t/$f"
    run scan "$t/a/b/whoami"
    [ "$status" -ne 0 ]
    [[ $output == *"${f%/a.md}"* ]]
  done
}

@test "the parent scan passes on a clean tree" {
  mkdir -p "$BATS_TEST_TMPDIR/clean/a/b/whoami"
  echo "x" >"$BATS_TEST_TMPDIR/clean/a/b/whoami/CLAUDE.md"
  run scan "$BATS_TEST_TMPDIR/clean/a/b/whoami"
  [ "$status" -eq 0 ]
}
