#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

[ "$#" -ge 1 ] || { echo "Usage: theme-check.sh <theme-slug>" >&2; exit 2; }
THEME="$1"

docker compose run --rm cli theme activate "$THEME" --allow-root
set +e
OUTPUT="$(docker compose run --rm cli theme-check run "$THEME" --allow-root 2>&1)"
STATUS=$?
set -e
echo "$OUTPUT"

# wp-cli also exits non-zero for reasons that mean Theme Check never ran at
# all (theme not found, the plugin missing/deactivated, a docker/wp-cli
# crash) — not only when it ran and found REQUIRED-level problems. Trusting
# a REQUIRED grep alone would let those cases through as "zero problems".
if [ "$STATUS" -ne 0 ] && ! echo "$OUTPUT" | grep -qi 'REQUIRED'; then
  echo "Error: Theme Check did not complete (exit $STATUS) and reported no REQUIRED-level findings — this cannot be trusted as a pass." >&2
  exit 1
fi

if echo "$OUTPUT" | grep -qi 'REQUIRED'; then
  echo "Error: Theme Check reported REQUIRED-level problems in $THEME." >&2
  exit 1
fi

echo "Theme Check passed for $THEME"
