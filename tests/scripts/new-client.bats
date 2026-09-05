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

@test "creates the theme directory with the client- prefix" {
  run "$SCRIPT" piano "Piano Store & Services"
  [ "$status" -eq 0 ]
  [ -d "$THEMES_DIR/client-piano" ]
  [ -f "$THEMES_DIR/client-piano/theme.json" ]
  [ -f "$THEMES_DIR/client-piano/templates/index.html" ]
}

@test "leaves no placeholder tokens behind" {
  "$SCRIPT" piano "Piano Store & Services" >/dev/null
  ! grep -rq '{{' "$THEMES_DIR/client-piano"
}

@test "writes the display name into the style.css header" {
  "$SCRIPT" piano "Piano Store & Services" >/dev/null
  grep -q "Theme Name: Piano Store & Services" "$THEMES_DIR/client-piano/style.css"
  grep -q "Version: 1.0.0" "$THEMES_DIR/client-piano/style.css"
  grep -q "Text Domain: client-piano" "$THEMES_DIR/client-piano/style.css"
}

@test "uses the description argument when supplied" {
  "$SCRIPT" jam "Fruit Jam Production" "Preserves made on site" >/dev/null
  grep -q "Description: Preserves made on site" "$THEMES_DIR/client-jam/style.css"
}

@test "produces a theme.json that parses as JSON" {
  "$SCRIPT" piano "Piano Store & Services" >/dev/null
  run node -e "require('$THEMES_DIR/client-piano/theme.json')"
  [ "$status" -eq 0 ]
}

@test "writes an empty shared manifest" {
  "$SCRIPT" piano "Piano Store & Services" >/dev/null
  run node -e "const m=require('$THEMES_DIR/client-piano/.shared-manifest.json'); process.exit(Object.keys(m.patterns).length === 0 ? 0 : 1)"
  [ "$status" -eq 0 ]
}

@test "refuses to overwrite an existing theme" {
  "$SCRIPT" piano "Piano Store & Services" >/dev/null
  run "$SCRIPT" piano "Piano Store & Services"
  [ "$status" -eq 1 ]
  [[ "$output" == *"already exists"* ]]
}

@test "preserves backslash, ampersand, and pipe in description" {
  "$SCRIPT" guitar "Guitar Shop" "Guitars \& Sons | Co." >/dev/null
  grep -q 'Description: Guitars \\& Sons | Co.' "$THEMES_DIR/client-guitar/style.css"
}

@test "rejects display name containing comment-terminator */" {
  run "$SCRIPT" weird "Weird */ Name"
  [ "$status" -eq 2 ]
  [[ "$output" == *"cannot contain */"* ]]
  [ ! -d "$THEMES_DIR/client-weird" ]
}

@test "rejects display name containing newline" {
  run "$SCRIPT" multi $'Multi\nLine' "desc"
  [ "$status" -eq 2 ]
  [[ "$output" == *"cannot contain newlines or control characters"* ]]
  [ ! -d "$THEMES_DIR/client-multi" ]
}
