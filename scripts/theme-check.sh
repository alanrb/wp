#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

[ "$#" -ge 1 ] || { echo "Usage: theme-check.sh <theme-slug>" >&2; exit 2; }
THEME="$1"

docker compose run --rm cli theme activate "$THEME" --allow-root
OUTPUT="$(docker compose run --rm cli theme-check run "$THEME" --allow-root 2>&1 || true)"
echo "$OUTPUT"

if echo "$OUTPUT" | grep -qi 'REQUIRED'; then
  echo "Error: Theme Check reported REQUIRED-level problems in $THEME." >&2
  exit 1
fi

echo "Theme Check passed for $THEME"
