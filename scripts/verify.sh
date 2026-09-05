#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEMES_DIR="${THEMES_DIR:-$ROOT/themes}"
DIST_DIR="${DIST_DIR:-$ROOT/dist}"
cd "$ROOT"

[ -f .env ] && { set -a; . ./.env; set +a; }
WP_URL="${WP_URL:-http://localhost:8080}"
# Exported so `docker compose run` (a child process) resolves the cli
# container's /dist mount from the same DIST_DIR verify.sh itself uses —
# see docker-compose.yml's `${DIST_DIR:-./dist}:/dist` (Finding 5).
export DIST_DIR

[ "$#" -ge 1 ] || { echo "Usage: verify.sh <theme-slug>" >&2; exit 2; }
THEME="$1"
THEME_PATH="$THEMES_DIR/$THEME"
[ -d "$THEME_PATH" ] || { echo "Error: theme '$THEME' not found at $THEME_PATH" >&2; exit 1; }

wp() { docker compose run --rm cli "$@" --allow-root; }
step() { echo; echo "==> $1"; }

# WooCommerce redirects an empty /checkout/ to /cart/ on template_redirect,
# before the checkout template ever runs — so a plain route smoke test only
# ever proves the redirect fires, never that checkout itself renders. Drop a
# temporary mu-plugin that suppresses that redirect for the life of this run,
# so /checkout/ actually executes its own template like every other route,
# and make sure it's removed again no matter how this script exits.
MU_PLUGIN_DIR="$ROOT/docker/mu-plugins"
MU_PLUGIN="$MU_PLUGIN_DIR/zzz-verify-suppress-checkout-redirect.php"
cleanup_mu_plugin() { rm -f "$MU_PLUGIN"; }
trap cleanup_mu_plugin EXIT
mkdir -p "$MU_PLUGIN_DIR"
cat > "$MU_PLUGIN" <<'PHP'
<?php
/**
 * Plugin Name: Verify: suppress checkout empty-cart redirect
 * Description: Written and removed by scripts/verify.sh for the duration of
 * a single run. Suppresses WooCommerce's woocommerce_checkout_redirect_empty_cart
 * redirect so the delivery gate's route smoke test renders /checkout/ itself
 * instead of only proving the redirect to /cart/ fires.
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

add_filter( 'woocommerce_checkout_redirect_empty_cart', '__return_false' );
PHP

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
set +e
CHECK_OUTPUT="$(wp theme-check run "$THEME" 2>&1)"
CHECK_STATUS=$?
set -e
echo "$CHECK_OUTPUT"
# A non-zero exit is expected when Theme Check actually ran and found
# REQUIRED-level problems (handled below) — but wp-cli also exits non-zero
# for reasons that mean Theme Check never ran at all (theme not found, the
# plugin missing/deactivated, a docker/wp-cli crash). Silently swallowing
# that with `|| true` and trusting only the REQUIRED grep would let those
# cases through as "zero problems found". Require the run to have actually
# produced a Theme Check result before trusting its silence.
if [ "$CHECK_STATUS" -ne 0 ] && ! echo "$CHECK_OUTPUT" | grep -qi 'REQUIRED'; then
  echo "Error: Theme Check did not complete (exit $CHECK_STATUS) and reported no REQUIRED-level findings — this cannot be trusted as a pass." >&2
  exit 1
fi
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
# The cli container's /dist mount is derived from DIST_DIR (see
# docker-compose.yml's `${DIST_DIR:-./dist}:/dist`, and the `export
# DIST_DIR` above) so it stays in sync with $ZIP. Still, confirm the exact
# zip we just packaged is actually visible at that path inside the
# container before installing — if the mount and DIST_DIR have somehow
# drifted apart, install a stale or wrong zip only over our dead body.
if ! docker compose run --rm --entrypoint test cli -f "/dist/$THEME-$VERSION.zip" >/dev/null 2>&1; then
  echo "Error: $ZIP is not visible inside the cli container at /dist/$THEME-$VERSION.zip." >&2
  echo "       DIST_DIR ($DIST_DIR) and the cli container's /dist mount have drifted apart — refusing to install a possibly-wrong zip." >&2
  exit 1
fi
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
  if [ "$code" != "$expected" ]; then
    if [[ "$url" == *"/checkout/"* ]]; then
      echo "Error: $url returned $code (expected $expected) — the checkout-redirect suppression (mu-plugin) did not take effect, so /checkout/ is UNPROVEN. Refusing to report PASS while silently skipping this route." >&2
    else
      echo "Error: $url returned $code (expected $expected)" >&2
    fi
    exit 1
  fi
  echo "  ok  $code  $url"
done

# `wp eval ... | grep ...` alone can't tell "log is clean" apart from
# "wp eval itself died" — pipefail doesn't help because grep's own no-match
# exit status is rightmost in the pipeline either way. Check wp eval's exit
# status explicitly so a broken read can't be mistaken for a clean log.
set +e
DEBUG_LOG="$(wp eval 'echo file_get_contents( WP_CONTENT_DIR . "/debug.log" );' 2>&1)"
DEBUG_STATUS=$?
set -e
if [ "$DEBUG_STATUS" -ne 0 ]; then
  echo "Error: could not read wp-content/debug.log via wp eval (exit $DEBUG_STATUS) — cannot verify rendering produced no PHP notices." >&2
  echo "$DEBUG_LOG" >&2
  exit 1
fi
if echo "$DEBUG_LOG" | grep -Eq 'PHP (Warning|Notice|Fatal|Deprecated)'; then
  echo "Error: PHP notices were logged while rendering — see wp-content/debug.log" >&2
  echo "$DEBUG_LOG"
  exit 1
fi

step "7/7 Accessibility"
"$ROOT/node_modules/.bin/pa11y-ci" --config "$ROOT/.pa11yci.json"

echo
echo "PASS — $THEME $VERSION is ready to deliver: $ZIP"
