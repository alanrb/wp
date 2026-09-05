#!/usr/bin/env bats

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export THEMES_DIR="$BATS_TEST_TMPDIR/themes"
  "$ROOT/scripts/new-client.sh" piano "Piano Store" >/dev/null
}

@test "functions.php enqueues from the generated asset file" {
  grep -q "build/index.asset.php" "$THEMES_DIR/client-piano/functions.php"
  grep -q "asset\['version'\]" "$THEMES_DIR/client-piano/functions.php"
  grep -q "asset\['dependencies'\]" "$THEMES_DIR/client-piano/functions.php"
}

@test "functions.php hardcodes no asset version" {
  ! grep -Eq "wp_enqueue_(style|script)\(.*'1\.0\.0'" "$THEMES_DIR/client-piano/functions.php"
}

@test "the scaffolded theme has a webpack config and a src entry point" {
  [ -f "$THEMES_DIR/client-piano/webpack.config.js" ]
  [ -f "$THEMES_DIR/client-piano/src/index.js" ]
  [ -f "$THEMES_DIR/client-piano/src/style.scss" ]
}

@test "building produces the asset manifest and compiled files" {
  run "$ROOT/scripts/build-theme.sh" client-piano
  [ "$status" -eq 0 ]
  [ -f "$THEMES_DIR/client-piano/build/index.asset.php" ]
  [ -f "$THEMES_DIR/client-piano/build/index.js" ]
  [ -f "$THEMES_DIR/client-piano/build/style-index.css" ]
}

@test "building an unknown theme fails with a clear message" {
  run "$ROOT/scripts/build-theme.sh" client-nope
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}
