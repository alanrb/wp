#!/usr/bin/env bats

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  TEMPLATE="$ROOT/base/theme-template"
}

@test "contains every file required of a block theme" {
  for f in style.css theme.json functions.php \
           templates/index.html templates/front-page.html templates/page.html \
           templates/single.html templates/archive.html templates/search.html templates/404.html \
           parts/header.html parts/footer.html; do
    [ -f "$TEMPLATE/$f" ] || { echo "missing $f"; return 1; }
  done
}

@test "theme.json is valid JSON at schema version 3" {
  run node -e "const t=require('$TEMPLATE/theme.json'); process.exit(t.version === 3 ? 0 : 1)"
  [ "$status" -eq 0 ]
}

@test "style.css declares a GPL-2.0-or-later license" {
  grep -q "License: GNU General Public License v2 or later" "$TEMPLATE/style.css"
}

@test "style.css carries the name and version placeholders" {
  grep -q "Theme Name: {{CLIENT_NAME}}" "$TEMPLATE/style.css"
  grep -q "Version: {{VERSION}}" "$TEMPLATE/style.css"
}

@test "uses no Custom HTML blocks anywhere" {
  ! grep -rq "wp:html" "$TEMPLATE"
}

@test "guards WooCommerce support behind a class_exists check" {
  grep -q "class_exists( 'WooCommerce' )" "$TEMPLATE/functions.php"
}

@test "uses only the four approved placeholder tokens" {
  run bash -c "grep -rho '{{[A-Z_]*}}' '$TEMPLATE' | sort -u"
  [ "$status" -eq 0 ]
  expected=$'{{CLIENT_DESCRIPTION}}\n{{CLIENT_NAME}}\n{{CLIENT_SLUG}}\n{{VERSION}}'
  [ "$output" = "$expected" ]
}
