#!/usr/bin/env bats

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$ROOT/scripts/lint-themes.sh"
  export THEMES_DIR="$BATS_TEST_TMPDIR/themes"
}

@test "lint exits 0 with a clear message when THEMES_DIR has no themes" {
  run "$SCRIPT" lint
  [ "$status" -eq 0 ]
  [[ "$output" == *"No themes found"* ]]
}

@test "lint fails on a theme with a genuine lint error" {
  "$ROOT/scripts/new-client.sh" piano "Piano Store" >/dev/null
  echo 'const x = ;' >> "$THEMES_DIR/client-piano/src/index.js"
  run "$SCRIPT" lint
  [ "$status" -ne 0 ]
}
