#!/usr/bin/env bats

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  VALIDATE="$ROOT/scripts/lib/validate-theme-json.mjs"
  WORK="$BATS_TEST_TMPDIR"
}

@test "accepts a scaffolded theme.json" {
  export THEMES_DIR="$WORK/themes"
  "$ROOT/scripts/new-client.sh" piano "Piano Store" >/dev/null
  run node "$VALIDATE" "$WORK/themes/client-piano/theme.json"
  [ "$status" -eq 0 ]
}

@test "rejects a wrong schema version" {
  echo '{ "version": 2, "settings": {} }' > "$WORK/bad.json"
  run node "$VALIDATE" "$WORK/bad.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"version"* ]]
}

@test "rejects malformed JSON" {
  echo '{ nope' > "$WORK/bad.json"
  run node "$VALIDATE" "$WORK/bad.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"JSON"* ]]
}

@test "rejects a palette entry missing a colour" {
  echo '{ "version": 3, "settings": { "color": { "palette": [ { "slug": "base", "name": "Base" } ] } } }' > "$WORK/bad.json"
  run node "$VALIDATE" "$WORK/bad.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"base"* ]]
}

@test "rejects duplicate palette slugs" {
  echo '{ "version": 3, "settings": { "color": { "palette": [ { "slug": "base", "name": "A", "color": "#fff" }, { "slug": "base", "name": "B", "color": "#000" } ] } } }' > "$WORK/bad.json"
  run node "$VALIDATE" "$WORK/bad.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"duplicate"* ]]
}
