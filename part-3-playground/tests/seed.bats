#!/usr/bin/env bats

@test "crit_table.py is a standalone file that imports only sys" {
  file="$BATS_TEST_DIRNAME/../seed/crit-table/crit_table.py"

  run grep -E '^(import|from) ' "$file"

  [ "$status" -eq 0 ]
  [ "$output" = "import sys" ]
}
