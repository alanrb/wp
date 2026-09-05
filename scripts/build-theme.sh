#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEMES_DIR="${THEMES_DIR:-$ROOT/themes}"

[ "$#" -ge 1 ] || { echo "Usage: build-theme.sh <theme-slug> [--watch]" >&2; exit 2; }

THEME="$1"
MODE="build"
[ "${2:-}" = "--watch" ] && MODE="start"

THEME_PATH="$THEMES_DIR/$THEME"
[ -d "$THEME_PATH" ] || { echo "Error: theme '$THEME' not found at $THEME_PATH" >&2; exit 1; }

export SHARED_WEBPACK_CONFIG="$ROOT/shared/build/webpack.config.js"

# Every scaffolded theme's package.json hard-codes a literal browserslist
# array instead of "extends @wordpress/browserslist-config" -- see the
# top-of-file comment in shared/build/webpack.config.js for why (a webpack
# 5.110.3 regression) and what to do once it's fixed upstream.

cd "$THEME_PATH"
"$ROOT/node_modules/.bin/wp-scripts" "$MODE"
