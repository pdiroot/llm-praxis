#!/usr/bin/env bats

setup() {
  SSH="$BATS_TEST_DIRNAME/../scripts/ssh.sh"
  export PG_RUNTIME="$BATS_TEST_TMPDIR/runtime"
}

@test "keys are made once" {
  "$SSH" keys
  before=$(shasum "$PG_RUNTIME"/ssh/mac* "$PG_RUNTIME"/ssh/config)

  run "$SSH" keys

  [ "$status" -eq 0 ]
  [ "$(shasum "$PG_RUNTIME"/ssh/mac* "$PG_RUNTIME"/ssh/config)" = "$before" ]
  [ "$(stat -f %Lp "$PG_RUNTIME/ssh/mac")" = 600 ]
}

@test "only the mac key is made" {
  "$SSH" keys

  [ -f "$PG_RUNTIME/ssh/mac.pub" ]
  [ ! -e "$PG_RUNTIME/ssh/ci" ]
}

@test "the config names only the gitlab host" {
  "$SSH" keys
  config="$PG_RUNTIME/ssh/config"

  run awk '/^Host /{h=$2} /Port /{print h, $2}' "$config"

  [ "$output" = "gitlab.playground.localhost 2222" ]
  [ "$(grep -c '^Host ' "$config")" -eq 1 ]
  grep -q "IdentityFile $PG_RUNTIME/ssh/mac" "$config"
  grep -q "UserKnownHostsFile $PG_RUNTIME/ssh/known_hosts" "$config"
}
