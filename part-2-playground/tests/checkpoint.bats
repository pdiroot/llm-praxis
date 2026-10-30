#!/usr/bin/env bats
# bats file_tags=live
# Live test: needs the running playground. It rewrites demo/whoami and the
# deployments of both VMs; run "task reset" afterwards.

setup() {
  ROOT="$BATS_TEST_DIRNAME/.."
  # shellcheck source=../scripts/lib.sh
  source "$ROOT/scripts/lib.sh"
  wait_http https://gitlab.playground.localhost/users/sign_in 200 5 || skip "GitLab is down"
  P=demo%2Fwhoami
}

site() { curl -sS --cacert "$PG_CA_DIR/ca.crt" "https://$1.playground.localhost/$2"; }
head_of() { API_SUDO=demo api GET "/projects/$P/repository/branches/$1" | jq -r .commit.id; }

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
  [ "$(API_SUDO=demo api GET "/projects/$P/repository/commits/feat%2Fwhoami" | jq -r '.parent_ids[0]')" = "$(head_of main)" ]
}

@test "a jump drops the other branches and leaves the clone on main" {
  run "$ROOT/scripts/checkpoint.sh" 2a-json-written
  [ "$status" -eq 0 ]
  [ "$(cat "$ROOT/checkpoints/2a-json-written/BRANCH_NAME")" = feat/json ]
  run "$ROOT/scripts/checkpoint.sh" 1-end
  echo "$output"
  [ "$status" -eq 0 ]
  [ "$(API_SUDO=demo api GET "/projects/$P/repository/branches" | jq -r 'map(.name) | join(",")')" = main ]
  [ "$(git -C "$PG_RUNTIME/clone/whoami" branch --show-current)" = main ]
  [ "$(git -C "$PG_RUNTIME/clone/whoami" branch | wc -l | tr -d ' ')" -eq 1 ]
}
