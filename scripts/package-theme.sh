#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEMES_DIR="${THEMES_DIR:-$ROOT/themes}"
DIST_DIR="${DIST_DIR:-$ROOT/dist}"

[ "$#" -ge 1 ] || { echo "Usage: package-theme.sh <theme-slug> [--skip-lint]" >&2; exit 2; }

THEME="$1"
SKIP_LINT=0
[ "${2:-}" = "--skip-lint" ] && SKIP_LINT=1

THEME_PATH="$THEMES_DIR/$THEME"
[ -d "$THEME_PATH" ] || { echo "Error: theme '$THEME' not found at $THEME_PATH" >&2; exit 1; }

VERSION="$(grep -m1 '^Version:' "$THEME_PATH/style.css" | sed -e 's/^Version:[[:space:]]*//' | tr -d '\r')"
[ -n "$VERSION" ] || { echo "Error: no 'Version:' header in $THEME/style.css" >&2; exit 1; }

[ -f "$THEME_PATH/build/index.asset.php" ] || {
  echo "Error: $THEME has no build output — run: npm run build -- $THEME" >&2
  exit 1
}

if [ "$SKIP_LINT" -eq 0 ]; then
  ( cd "$THEME_PATH" && "$ROOT/node_modules/.bin/wp-scripts" lint-js src ) \
    || { echo "Error: JS lint failed — not packaging." >&2; exit 1; }
  ( cd "$THEME_PATH" && "$ROOT/node_modules/.bin/wp-scripts" lint-style "src/**/*.scss" ) \
    || { echo "Error: style lint failed — not packaging." >&2; exit 1; }
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

cp -R "$THEME_PATH" "$STAGE/$THEME"

# Development-only artefacts never ship (FR7, NFR5).
rm -rf "$STAGE/$THEME/src" "$STAGE/$THEME/node_modules" "$STAGE/$THEME/tests"
rm -f  "$STAGE/$THEME/webpack.config.js" "$STAGE/$THEME/.shared-manifest.json" \
       "$STAGE/$THEME/package.json" "$STAGE/$THEME/package-lock.json"
find "$STAGE/$THEME" \( -name '.gitkeep' -o -name '.DS_Store' -o -name '*.map' \) -delete

mkdir -p "$DIST_DIR"
OUT="$DIST_DIR/$THEME-$VERSION.zip"
rm -f "$OUT"
( cd "$STAGE" && zip -rq "$OUT" "$THEME" )

echo "Packaged $OUT"
