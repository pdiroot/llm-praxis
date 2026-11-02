#!/usr/bin/env bats
# bats file_tags=live
# Runs against the started playground; skips when GitLab does not answer.

setup() {
  ROOT="$BATS_TEST_DIRNAME/.."
  # shellcheck source=../scripts/lib.sh
  source "$ROOT/scripts/lib.sh"
  wait_http https://gitlab.playground.localhost/users/sign_in 200 5 || skip "GitLab is down"
}

teardown() {
  if [[ -n ${TOKEN_ID:-} ]]; then
    api DELETE "/personal_access_tokens/$TOKEN_ID" >/dev/null || true
  fi
}

@test "the bootstrap is idempotent" {
  run "$ROOT/scripts/bootstrap.sh"
  [ "$status" -eq 0 ]
  run "$ROOT/scripts/bootstrap.sh"
  [ "$status" -eq 0 ]
  [ "$(api GET '/users?username=demo' | jq length)" -eq 1 ]
  [ "$(api GET /runners/all | jq length)" -eq 1 ]
  [ "$(api GET /projects/demo%2Fwhoami/repository/commits | jq length)" -eq 0 ]
  [ "$(api GET /projects/demo%2Fwhoami | jq -r .description)" = "A whoami web app that Claude Code builds and ships live in the LLM Praxis session" ]
  [ "$(api GET /projects/demo%2Fwhoami/variables | jq length)" -eq 2 ]
}

@test "demo signs in with the fixed password" {
  uid=$(api GET '/users?username=demo' | jq -r '.[0].id')
  resp=$(api POST "/users/$uid/personal_access_tokens" -d name=bats -d 'scopes[]=api' -d "expires_at=$(date -v+1d +%F)")
  TOKEN_ID=$(jq -r .id <<<"$resp")
  run env GITLAB_HOST=gitlab.playground.localhost GITLAB_TOKEN="$(jq -r .token <<<"$resp")" glab api user
  [ "$status" -eq 0 ]
  [ "$(jq -r .username <<<"$output")" = demo ]
  [ "$(api GET '/users?username=root' | jq length)" -eq 1 ]
}

@test "the hello-world repository has its merge requests" {
  [ "$(api GET '/projects/demo%2Fhello-world/merge_requests?state=opened' | jq length)" -eq 1 ]
  [ "$(api GET '/projects/demo%2Fhello-world/merge_requests?state=merged' | jq length)" -eq 1 ]
  [ "$(api GET '/projects/demo%2Fhello-world/merge_requests?state=closed' | jq length)" -eq 1 ]
}

@test "root and demo have the fixed password" {
  run docker compose -f "$ROOT/compose.yaml" exec -T gitlab gitlab-rails runner \
    'puts %w[root demo].map { |n| User.find_by_username(n).valid_password?("P@ssw0rd") }.join(",")'
  [ "$status" -eq 0 ]
  [ "${lines[-1]}" = "true,true" ]
}
