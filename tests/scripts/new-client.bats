#!/usr/bin/env bats

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$ROOT/scripts/new-client.sh"
  export THEMES_DIR="$BATS_TEST_TMPDIR/themes"
  mkdir -p "$THEMES_DIR"
}

@test "exits 2 and prints usage with no arguments" {
  run "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "exits 2 when only a slug is given" {
  run "$SCRIPT" piano
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "rejects an uppercase slug" {
  run "$SCRIPT" Piano "Piano Store"
  [ "$status" -eq 2 ]
  [[ "$output" == *"lowercase"* ]]
}

@test "rejects a slug containing a space" {
  run "$SCRIPT" "piano store" "Piano Store"
  [ "$status" -eq 2 ]
}

@test "rejects a slug starting with a hyphen" {
  run "$SCRIPT" -piano "Piano Store"
  [ "$status" -eq 2 ]
}

@test "accepts a valid slug and display name" {
  run "$SCRIPT" piano "Piano Store & Services"
  [ "$status" -eq 0 ]
}
