#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEMES_DIR="${THEMES_DIR:-$ROOT/themes}"

usage() { echo "Usage: lint-themes.sh <lint|format>" >&2; exit 2; }

[ "$#" -ge 1 ] || usage
MODE="$1"
case "$MODE" in
  lint|format) ;;
  *) usage ;;
esac

WP_SCRIPTS="$ROOT/node_modules/.bin/wp-scripts"

# Collect the themes that actually have something to lint/format. A fresh
# clone (or a THEMES_DIR override in tests) may have no themes at all, or the
# directory may not exist yet -- that is not an error, there is just nothing
# to do.
THEMES=()
if [ -d "$THEMES_DIR" ]; then
  for dir in "$THEMES_DIR"/*/; do
    [ -d "${dir}src" ] || continue
    THEMES+=("${dir%/}")
  done
fi

if [ "${#THEMES[@]}" -eq 0 ]; then
  echo "No themes found under $THEMES_DIR — nothing to $MODE."
  exit 0
fi

if [ "$MODE" = "lint" ]; then
  for theme in "${THEMES[@]}"; do
    "$WP_SCRIPTS" lint-js "$theme/src"
    "$WP_SCRIPTS" lint-style "$theme/src/**/*.scss"
  done
else
  for theme in "${THEMES[@]}"; do
    "$WP_SCRIPTS" format "$theme/src"
  done
fi
