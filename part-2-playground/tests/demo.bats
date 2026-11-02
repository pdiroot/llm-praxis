#!/usr/bin/env bats

bats_require_minimum_version 1.5.0
setup() {
  ROOT="$BATS_TEST_DIRNAME/.."
  SETTINGS="$ROOT/demo/settings.json"
}

@test "glab and git push need no approval, and .env stays denied" {
  jq -e '.permissions.allow | index("Bash(glab *)") and index("Bash(git push *)")' "$SETTINGS"
  jq -e '.permissions.deny | index("Read(**/.env)")' "$SETTINGS"
  jq -e '.permissions.ask == null' "$SETTINGS"
}

@test "the settings deny .env, have no hook and extend the auto mode" {
  [ "$(jq -r '.permissions.deny[0]' "$SETTINGS")" = 'Read(**/.env)' ]
  jq -e '.hooks == null' "$SETTINGS"
  [ "$(jq -r '.autoMode.environment[0]' "$SETTINGS")" = '$defaults' ]
  jq -e '.autoMode.environment | length == 3' "$SETTINGS"
}

@test "the launch keeps the owner's config" {
  export PG_RUNTIME="$BATS_TEST_TMPDIR/runtime"
  export PG_DEMO_HOME="$BATS_TEST_TMPDIR/demo"
  mkdir -p "$PG_RUNTIME/ssh" "$PG_DEMO_HOME/whoami"
  touch "$PG_DEMO_HOME/.llm-praxis-demo"
  echo "Host x" >"$PG_RUNTIME/ssh/config"
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

  PATH="$BATS_TEST_TMPDIR/bin:$PATH" run --separate-stderr "$ROOT/scripts/demo-claude.sh" --resume

  [ "$status" -eq 0 ]
  # Absolute paths: macOS may resolve the temp dir through a symlink, so compare the pwd by suffix.
  [ "${lines[0]}" = "$PG_DEMO_HOME/claude-config" ]
  [ "${lines[1]}" = false ]
  [ "${lines[2]}" = "$PG_RUNTIME/tls/ca.crt" ]
  [ "${lines[3]}" = nano ]
  [[ ${lines[4]} == */demo/whoami ]]
  [ "${lines[5]}" = "--add-dir $PG_DEMO_HOME/ssh --chrome --resume" ]
}

@test "the demo settings keep the account's plugins, skills and connectors out" {
  [ "$(jq .syncClaudeAiPlugins "$SETTINGS")" = false ]
  [ "$(jq .syncClaudeAiSkills "$SETTINGS")" = false ]
  [ "$(jq .disableClaudeAiConnectors "$SETTINGS")" = true ]
}

@test "the settings are copied once and never overwritten" {
  export PG_RUNTIME="$BATS_TEST_TMPDIR/runtime"
  export PG_DEMO_HOME="$BATS_TEST_TMPDIR/demo"
  mkdir -p "$PG_RUNTIME/ssh" "$PG_DEMO_HOME/whoami"
  touch "$PG_DEMO_HOME/.llm-praxis-demo"
  echo "Host x" >"$PG_RUNTIME/ssh/config"
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
  touch "$PG_DEMO_HOME/.llm-praxis-demo"
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
  touch "$PG_DEMO_HOME/.llm-praxis-demo"
  echo "Host x" >"$PG_RUNTIME/ssh/config"
  touch "$BATS_TEST_TMPDIR/up/CLAUDE.md"
  printf '#!/usr/bin/env bash\necho started\n' >"$BATS_TEST_TMPDIR/bin/claude"
  chmod +x "$BATS_TEST_TMPDIR/bin/claude"

  PATH="$BATS_TEST_TMPDIR/bin:$PATH" run "$ROOT/scripts/demo-claude.sh"

  [ "$status" -ne 0 ]
  [[ $output == *"$(cd "$BATS_TEST_TMPDIR" && pwd -P)/up/CLAUDE.md"* ]]
  [[ $output != *started* ]]
}

scan() { bash -c "source '$ROOT/scripts/lib.sh'; isolation_scan '$1'"; }

@test "the parent scan fails on each file Claude Code loads" {
  for f in CLAUDE.md CLAUDE.local.md .claude/CLAUDE.md .claude/rules/a.md AGENTS.md .claude/AGENTS.md .mcp.json; do
    t="$BATS_TEST_TMPDIR/tree-${f//\//_}"
    mkdir -p "$t/a/b/whoami" "$t/$(dirname "$f")"
    touch "$t/$f"
    run scan "$t/a/b/whoami"
    [ "$status" -eq 1 ]
    [[ $output == *"$(cd "$t" && pwd -P)/${f%/a.md}"* ]]
  done
}

@test "the parent scan passes on a clean tree" {
  mkdir -p "$BATS_TEST_TMPDIR/clean/a/b/whoami"
  echo "x" >"$BATS_TEST_TMPDIR/clean/a/b/whoami/CLAUDE.md"
  run scan "$BATS_TEST_TMPDIR/clean/a/b/whoami"
  [ "$status" -eq 0 ]
}

@test "the parent scan fails on a missing clone" {
  run scan "$BATS_TEST_TMPDIR/none/whoami"
  [ "$status" -eq 2 ]
}

@test "the parent scan reads the logical path too" {
  mkdir -p "$BATS_TEST_TMPDIR/real/a/whoami" "$BATS_TEST_TMPDIR/link/x"
  touch "$BATS_TEST_TMPDIR/link/x/CLAUDE.md"
  ln -s "$BATS_TEST_TMPDIR/real/a" "$BATS_TEST_TMPDIR/link/x/lnk"
  run scan "$BATS_TEST_TMPDIR/link/x/lnk/whoami"
  [ "$status" -eq 1 ]
  [[ $output == *"/link/x/CLAUDE.md"* ]]
}

# home_ok <value>: demo_home_ok / demo_home_check with PG_DEMO_HOME set to <value>.
home_ok() { PG_DEMO_HOME="$1" bash -c "source '$ROOT/scripts/lib.sh'; $2"; }

@test "demo_home_ok refuses the dangerous values" {
  for v in "" / "$HOME" "$HOME/" . relative/dir "$(cd "$ROOT/.." && pwd)" "$(cd "$ROOT" && pwd)"; do
    run home_ok "$v" demo_home_ok
    [ "$status" -eq 1 ] || {
      echo "accepted '$v'"
      false
    }
  done
  run home_ok "$HOME/llm-praxis-demo" demo_home_ok
  [ "$status" -eq 0 ]
  run home_ok "$BATS_TEST_TMPDIR/demo" demo_home_ok
  [ "$status" -eq 0 ]
}

@test "demo_home_rm needs the marker" {
  d="$BATS_TEST_TMPDIR/demo"
  mkdir -p "$d/whoami"
  run home_ok "$d" demo_home_rm
  [ "$status" -ne 0 ]
  [ -d "$d/whoami" ]
  touch "$d/.llm-praxis-demo"
  run home_ok "$d" demo_home_rm
  [ "$status" -eq 0 ]
  [ ! -e "$d" ]
}

@test "demo_home_init marks a new folder, keeps a marked one, dies on an unmarked one" {
  run home_ok "$BATS_TEST_TMPDIR/new" demo_home_init
  [ "$status" -eq 0 ]
  [ -f "$BATS_TEST_TMPDIR/new/.llm-praxis-demo" ]
  run home_ok "$BATS_TEST_TMPDIR/new" demo_home_init
  [ "$status" -eq 0 ]
  mkdir "$BATS_TEST_TMPDIR/old"
  run home_ok "$BATS_TEST_TMPDIR/old" demo_home_init
  [ "$status" -ne 0 ]
}

# mcp_check <list-file> <rc> [mcp.json content]: run mcp_foreign with a claude stub.
mcp_check() {
  export PG_DEMO_HOME="$BATS_TEST_TMPDIR/demo"
  mkdir -p "$PG_DEMO_HOME/whoami" "$BATS_TEST_TMPDIR/bin"
  rm -f "$PG_DEMO_HOME/whoami/.mcp.json"
  if [[ -n ${3:-} ]]; then echo "$3" >"$PG_DEMO_HOME/whoami/.mcp.json"; fi
  printf '#!/usr/bin/env bash\ncat "%s"\nexit %s\n' "$1" "$2" >"$BATS_TEST_TMPDIR/bin/claude"
  chmod +x "$BATS_TEST_TMPDIR/bin/claude"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" bash -c "source '$ROOT/scripts/lib.sh'; mcp_foreign '$PG_DEMO_HOME/whoami'"
}

@test "mcp_foreign: a clean list passes" {
  echo "No MCP servers configured. Use \`claude mcp add\` to add a server." >"$BATS_TEST_TMPDIR/l"
  run mcp_check "$BATS_TEST_TMPDIR/l" 0
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "mcp_foreign: foreign servers with colons and spaces are named" {
  printf 'Checking MCP server health...\n\nplugin:x:y: npx foo - ✓ Connected\nclaude.ai Gmail: https://gmail.example/mcp - ! Needs authentication\nmine: https://a.example - ✓ Connected\n' >"$BATS_TEST_TMPDIR/l"
  run mcp_check "$BATS_TEST_TMPDIR/l" 0 '{"mcpServers":{"mine":{"url":"https://a.example"}}}'
  [ "$status" -eq 0 ]
  [ "$output" = $'plugin:x:y\nclaude.ai Gmail' ]
}

@test "mcp_foreign: the clone's own server passes" {
  printf 'mine: https://a.example - ✓ Connected\n' >"$BATS_TEST_TMPDIR/l"
  run mcp_check "$BATS_TEST_TMPDIR/l" 0 '{"mcpServers":{"mine":{"url":"https://a.example"}}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "mcp_foreign: a non-zero exit fails" {
  : >"$BATS_TEST_TMPDIR/l"
  run mcp_check "$BATS_TEST_TMPDIR/l" 1
  [ "$status" -ne 0 ]
}

# launch_env <outer env...>: run the launcher with a stub claude that prints two values.
launch_env() {
  export PG_RUNTIME="$BATS_TEST_TMPDIR/runtime"
  export PG_DEMO_HOME="$BATS_TEST_TMPDIR/demo"
  export XDG_DATA_HOME="$BATS_TEST_TMPDIR/data"
  mkdir -p "$PG_RUNTIME/ssh" "$PG_DEMO_HOME/whoami" "$BATS_TEST_TMPDIR/bin"
  touch "$PG_DEMO_HOME/.llm-praxis-demo"
  echo "Host x" >"$PG_RUNTIME/ssh/config"
  printf '#!/usr/bin/env bash\necho "$CLAUDE_CONFIG_DIR"\necho "${GITLAB_TOKEN:-}"\n' >"$BATS_TEST_TMPDIR/bin/claude"
  chmod +x "$BATS_TEST_TMPDIR/bin/claude"
  echo "GITLAB_TOKEN=from-env-file" >"$PG_DEMO_HOME/whoami/.env"
  echo dotenv >"$PG_DEMO_HOME/whoami/.envrc"
  direnv allow "$PG_DEMO_HOME/whoami"

  PATH="$BATS_TEST_TMPDIR/bin:$PATH" run --separate-stderr env "$@" "$ROOT/scripts/demo-claude.sh"
}

@test "direnv loads .env into the session" {
  launch_env A=1

  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$PG_DEMO_HOME/claude-config" ]
  [ "${lines[1]}" = from-env-file ]
}

@test "the outer direnv state cannot undo the demo profile" {
  launch_env DIRENV_DIFF=stale DIRENV_DIR=-/tmp DIRENV_FILE=/tmp/.envrc

  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$PG_DEMO_HOME/claude-config" ]
}

@test "the launcher stops when direnv is missing" {
  mkdir -p "$BATS_TEST_TMPDIR/nodirenv"
  for tool in bash dirname cat; do ln -s "$(command -v "$tool")" "$BATS_TEST_TMPDIR/nodirenv/$tool"; done

  PATH="$BATS_TEST_TMPDIR/nodirenv" run "$ROOT/scripts/demo-claude.sh"

  [ "$status" -ne 0 ]
  [[ $output == *"brew install direnv"* ]]
}

@test "each prompt of the deck has its file" {
  for id in $(grep -o 'data-id="[^"]*"' "$ROOT/slides/index.html" | cut -d'"' -f2); do
    [ -f "$ROOT/prompts/$id.md" ]
  done
}
