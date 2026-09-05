#!/usr/bin/env bats

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$ROOT/scripts/package-theme.sh"
  export THEMES_DIR="$BATS_TEST_TMPDIR/themes"
  export DIST_DIR="$BATS_TEST_TMPDIR/dist"
  "$ROOT/scripts/new-client.sh" piano "Piano Store" >/dev/null
  "$ROOT/scripts/build-theme.sh" client-piano >/dev/null
}

@test "produces a zip named for the theme and its version" {
  run "$SCRIPT" client-piano --skip-lint
  [ "$status" -eq 0 ]
  [ -f "$DIST_DIR/client-piano-1.0.0.zip" ]
}

@test "the zip contains the theme in a top-level folder" {
  "$SCRIPT" client-piano --skip-lint >/dev/null
  run unzip -l "$DIST_DIR/client-piano-1.0.0.zip"
  [[ "$output" == *"client-piano/style.css"* ]]
  [[ "$output" == *"client-piano/theme.json"* ]]
  [[ "$output" == *"client-piano/build/index.js"* ]]
}

@test "the zip excludes all development files" {
  # The scaffolded fixture has no node_modules/ of its own (the monorepo
  # uses a single root node_modules), so plant one to actually exercise the
  # strip line rather than passing vacuously.
  mkdir -p "$THEMES_DIR/client-piano/node_modules"
  touch "$THEMES_DIR/client-piano/node_modules/dummy.js"
  "$SCRIPT" client-piano --skip-lint >/dev/null
  run unzip -l "$DIST_DIR/client-piano-1.0.0.zip"
  [[ "$output" != *"client-piano/src/"* ]]
  [[ "$output" != *"client-piano/node_modules/"* ]]
  [[ "$output" != *"client-piano/webpack.config.js"* ]]
  [[ "$output" != *"client-piano/package.json"* ]]
  [[ "$output" != *"client-piano/.shared-manifest.json"* ]]
}

@test "picks up a bumped version from style.css" {
  tmp="$THEMES_DIR/client-piano/style.css.tmp"
  sed -e 's/Version: 1.0.0/Version: 2.3.1/' "$THEMES_DIR/client-piano/style.css" > "$tmp"
  mv "$tmp" "$THEMES_DIR/client-piano/style.css"
  "$SCRIPT" client-piano --skip-lint >/dev/null
  [ -f "$DIST_DIR/client-piano-2.3.1.zip" ]
}

@test "fails when the theme has never been built" {
  rm -rf "$THEMES_DIR/client-piano/build"
  run "$SCRIPT" client-piano --skip-lint
  [ "$status" -ne 0 ]
  [[ "$output" == *"build"* ]]
}

@test "fails on an unknown theme" {
  run "$SCRIPT" client-nope --skip-lint
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}
