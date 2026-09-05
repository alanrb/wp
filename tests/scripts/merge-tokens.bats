#!/usr/bin/env bats

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  MERGE="$ROOT/scripts/lib/merge-tokens.mjs"
  WORK="$BATS_TEST_TMPDIR/work"
  mkdir -p "$WORK/tokens"
  cat > "$WORK/theme.json" <<'JSON'
{ "version": 3, "settings": { "layout": { "contentSize": "720px" }, "color": { "custom": false } } }
JSON
  cat > "$WORK/tokens/color.json" <<'JSON'
{ "palette": [ { "slug": "base", "color": "#ffffff", "name": "Base" } ] }
JSON
}

@test "merges a token file into the matching settings key" {
  run node "$MERGE" "$WORK/theme.json" "$WORK/tokens"
  [ "$status" -eq 0 ]
  run node -e "const t=require('$WORK/theme.json'); process.exit(t.settings.color.palette[0].slug === 'base' ? 0 : 1)"
  [ "$status" -eq 0 ]
}

@test "preserves settings keys that the tokens do not mention" {
  node "$MERGE" "$WORK/theme.json" "$WORK/tokens"
  run node -e "const t=require('$WORK/theme.json'); process.exit(t.settings.color.custom === false && t.settings.layout.contentSize === '720px' ? 0 : 1)"
  [ "$status" -eq 0 ]
}

@test "fails loudly on malformed token JSON" {
  echo '{ broken' > "$WORK/tokens/color.json"
  run node "$MERGE" "$WORK/theme.json" "$WORK/tokens"
  [ "$status" -ne 0 ]
  [[ "$output" == *"color.json"* ]]
}

@test "scaffolded themes receive the shared palette" {
  export THEMES_DIR="$BATS_TEST_TMPDIR/themes"
  "$ROOT/scripts/new-client.sh" piano "Piano Store" >/dev/null
  run node -e "const t=require('$THEMES_DIR/client-piano/theme.json'); process.exit(Array.isArray(t.settings.color.palette) && t.settings.color.palette.length > 0 ? 0 : 1)"
  [ "$status" -eq 0 ]
}
