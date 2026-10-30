#!/usr/bin/env bats
# bats file_tags=live
# Live test: needs the running playground. It rewrites demo/whoami and the
# deployments of both VMs; run "task reset" afterwards.

setup() {
  ROOT="$BATS_TEST_DIRNAME/.."
  # shellcheck source=../scripts/lib.sh
  source "$ROOT/scripts/lib.sh"
  P=demo%2Fwhoami
}

site() { curl -sS --cacert "$PG_CA_DIR/ca.crt" "https://$1.playground.localhost/$2"; }
head_of() { API_SUDO=demo api GET "/projects/$P/repository/branches/$1" | jq -r .commit.id; }

@test "unknown id lists the valid ids" {
  run "$ROOT/scripts/checkpoint.sh" nope
  [ "$status" -ne 0 ]
  [[ $output == *1a-app-written* && $output == *3-end* ]]
}

@test "jump forward" {
  run "$ROOT/scripts/checkpoint.sh" 2-end
  echo "$output"
  [ "$status" -eq 0 ]
  sha=$(head_of main)
  [ "$(site prod '?format=json' | jq -r .commit)" = "${sha:0:8}" ]
  [ "$(site test '?format=json' | jq -r .commit)" = "${sha:0:8}" ]
}

@test "jump backward" {
  run "$ROOT/scripts/checkpoint.sh" 2-end
  [ "$status" -eq 0 ]
  run "$ROOT/scripts/checkpoint.sh" 1-end
  echo "$output"
  [ "$status" -eq 0 ]
  [[ $(site prod '?format=json') != '{'* ]]
  run ssh -F "$PG_RUNTIME/ssh/config" prod.playground.localhost 'grep -c Restart= /etc/systemd/system/whoami.service'
  [ "$output" = 0 ]
}

@test "a mid checkpoint keeps main" {
  run "$ROOT/scripts/checkpoint.sh" 1a-app-written
  echo "$output"
  [ "$status" -eq 0 ]
  [ "$(API_SUDO=demo api GET "/projects/$P/repository/commits?ref_name=main" | jq length)" -eq 1 ]
  API_SUDO=demo api GET "/projects/$P/repository/tree?ref=main" | jq -e 'map(.name) == ["CLAUDE.md"]'
  API_SUDO=demo api GET "/projects/$P/repository/tree?ref=feat/whoami" | jq -e 'map(.name) | index("main.go")'
}
