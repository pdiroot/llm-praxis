#!/usr/bin/env bats
# Needs no playground: checkpoint.sh rejects the id before it calls GitLab.

setup() {
  ROOT="$BATS_TEST_DIRNAME/.."
}

@test "unknown id lists the valid ids" {
  run "$ROOT/scripts/checkpoint.sh" nope
  [ "$status" -ne 0 ]
  [[ $output == *1a-app-written* && $output == *3-end* ]]
}

@test "an id with a path is rejected" {
  run "$ROOT/scripts/checkpoint.sh" ../checkpoints/1-end
  [ "$status" -ne 0 ]
  [[ $output == *"unknown checkpoint"* ]]
}
