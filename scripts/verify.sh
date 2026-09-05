#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEMES_DIR="${THEMES_DIR:-$ROOT/themes}"
DIST_DIR="${DIST_DIR:-$ROOT/dist}"
cd "$ROOT"

[ -f .env ] && { set -a; . ./.env; set +a; }
WP_URL="${WP_URL:-http://localhost:8080}"

[ "$#" -ge 1 ] || { echo "Usage: verify.sh <theme-slug>" >&2; exit 2; }
THEME="$1"
THEME_PATH="$THEMES_DIR/$THEME"
[ -d "$THEME_PATH" ] || { echo "Error: theme '$THEME' not found at $THEME_PATH" >&2; exit 1; }

wp() { docker compose run --rm cli "$@" --allow-root; }
step() { echo; echo "==> $1"; }

step "1/7 Lint"
( cd "$THEME_PATH" && "$ROOT/node_modules/.bin/wp-scripts" lint-js src )
( cd "$THEME_PATH" && "$ROOT/node_modules/.bin/wp-scripts" lint-style "src/**/*.scss" )
while IFS= read -r -d '' php_file; do
  docker compose run --rm --entrypoint php cli -l "/var/www/html/wp-content/client-themes/${php_file#"$THEMES_DIR/"}" >/dev/null
done < <(find "$THEME_PATH" -name '*.php' -not -path '*/node_modules/*' -print0)

step "2/7 Validate theme.json"
node "$ROOT/scripts/lib/validate-theme-json.mjs" "$THEME_PATH/theme.json"

step "3/7 Theme Check"
wp theme activate "$THEME"
CHECK_OUTPUT="$(wp theme-check run "$THEME" 2>&1 || true)"
echo "$CHECK_OUTPUT"
if echo "$CHECK_OUTPUT" | grep -qi 'REQUIRED'; then
  echo "Error: Theme Check reported REQUIRED-level problems." >&2
  exit 1
fi

step "4/7 Build and package"
"$ROOT/scripts/build-theme.sh" "$THEME"
"$ROOT/scripts/package-theme.sh" "$THEME" --skip-lint
VERSION="$(grep -m1 '^Version:' "$THEME_PATH/style.css" | sed -e 's/^Version:[[:space:]]*//' | tr -d '\r')"
ZIP="$DIST_DIR/$THEME-$VERSION.zip"
for forbidden in "$THEME/src/" "node_modules" "webpack.config.js" ".shared-manifest.json"; do
  if unzip -l "$ZIP" | grep -q -- "$forbidden"; then
    echo "Error: packaged zip contains development file matching '$forbidden'" >&2
    exit 1
  fi
done

step "5/7 Install the packaged zip into WordPress"
wp theme install "/dist/$THEME-$VERSION.zip" --force --activate
wp theme is-active "$THEME"

step "6/7 Route smoke test"
POST_URL="$(wp post list --post_type=post --post_status=publish --posts_per_page=1 --field=url | head -n1 || true)"
PAGE_URL="$(wp post list --post_type=page --post_status=publish --posts_per_page=1 --field=url | head -n1 || true)"
wp eval 'file_put_contents( WP_CONTENT_DIR . "/debug.log", "" );' >/dev/null 2>&1 || true

ROUTES=( "$WP_URL/" "$WP_URL/?s=test" "$WP_URL/no-such-page-404/" "$WP_URL/shop/" "$WP_URL/cart/" "$WP_URL/checkout/" )
[ -n "$POST_URL" ] && ROUTES+=( "$POST_URL" )
[ -n "$PAGE_URL" ] && ROUTES+=( "$PAGE_URL" )

for url in "${ROUTES[@]}"; do
  code="$(curl -s -o /dev/null -w '%{http_code}' "$url")"
  expected=200
  [[ "$url" == *"no-such-page-404"* ]] && expected=404
  # WooCommerce redirects an empty checkout to the cart page by design
  # (woocommerce_checkout_redirect_empty_cart) — a fresh store has no cart
  # contents, so accept that specific, well-known redirect as a pass.
  if [[ "$url" == *"/checkout/"* && "$code" = "302" ]]; then
    redirect="$(curl -s -o /dev/null -w '%{redirect_url}' "$url")"
    if [[ "$redirect" == "$WP_URL/cart/"* ]]; then
      echo "  ok  302  $url (redirected to cart — empty cart)"
      continue
    fi
  fi
  if [ "$code" != "$expected" ]; then
    echo "Error: $url returned $code (expected $expected)" >&2
    exit 1
  fi
  echo "  ok  $code  $url"
done

if wp eval 'echo file_get_contents( WP_CONTENT_DIR . "/debug.log" );' 2>/dev/null | grep -Eq 'PHP (Warning|Notice|Fatal|Deprecated)'; then
  echo "Error: PHP notices were logged while rendering — see wp-content/debug.log" >&2
  wp eval 'echo file_get_contents( WP_CONTENT_DIR . "/debug.log" );'
  exit 1
fi

step "7/7 Accessibility"
"$ROOT/node_modules/.bin/pa11y-ci" --config "$ROOT/.pa11yci.json"

echo
echo "PASS — $THEME $VERSION is ready to deliver: $ZIP"
