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

cd "$THEME_PATH"
"$ROOT/node_modules/.bin/wp-scripts" "$MODE"
