#!/usr/bin/env bash
set -euo pipefail

# Seed demo content into the local WordPress for one client theme.
#
# Demo content is site data, not theme data — none of it ships inside a
# delivered zip. It exists so a theme can be reviewed against a populated shop
# rather than empty states.
#
# Usage: seed.sh <piano|jam>

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

[ "$#" -ge 1 ] || { echo "Usage: seed.sh <piano|jam>" >&2; exit 2; }

CLIENT="$1"
SEED_FILE="$ROOT/scripts/seed/seed-$CLIENT.php"

[ -f "$SEED_FILE" ] || { echo "Error: no seeder at $SEED_FILE" >&2; exit 1; }

# The cli container mounts ./dist at /dist, which is the simplest path already
# shared with the container. Stage the seeder there rather than adding a mount.
STAGE="$ROOT/dist/seed"
mkdir -p "$STAGE"
cp "$ROOT/scripts/seed/seed-lib.php" "$STAGE/seed-lib.php"
cp "$SEED_FILE" "$STAGE/seed-$CLIENT.php"

cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT

docker compose run --rm cli eval-file "/dist/seed/seed-$CLIENT.php" --allow-root

echo
echo "Seeded $CLIENT. Activate its theme with: npm run env:cli -- theme activate client-$CLIENT"
