#!/usr/bin/env bash
set -euo pipefail

# Point the local environment at one client's isolated stack.
#
# Each client gets its own Docker Compose PROJECT, and Compose namespaces
# volumes by project — so `piano` and `jam` end up with completely separate
# MySQL and WordPress volumes. Two databases, two sets of products, no bleed
# between them. They can run at the same time on different ports.
#
# This works by rewriting `.env`, which Compose reads automatically. Every
# other script in the repo (verify.sh, theme-check.sh, the integration tests)
# keeps calling `docker compose` exactly as before and simply talks to
# whichever stack `.env` currently selects — no argument threading required.
#
# Usage: env-use.sh <client> [port]

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

[ "$#" -ge 1 ] || {
  echo "Usage: env-use.sh <client> [port]" >&2
  echo "  e.g. env-use.sh piano" >&2
  exit 2
}

CLIENT="$1"

if ! printf '%s' "$CLIENT" | grep -Eq '^[a-z][a-z0-9-]*$'; then
  echo "Error: client must be lowercase alphanumeric with hyphens (got '$CLIENT')" >&2
  exit 2
fi

# Stable default port per client so two stacks never collide, overridable.
if [ "${2:-}" != "" ]; then
  PORT="$2"
else
  case "$CLIENT" in
    piano) PORT=8080 ;;
    jam)   PORT=8081 ;;
    *)     PORT=8090 ;;
  esac
fi

if ! printf '%s' "$PORT" | grep -Eq '^[0-9]{2,5}$'; then
  echo "Error: port must be numeric (got '$PORT')" >&2
  exit 2
fi

[ -f .env.example ] || { echo "Error: .env.example missing" >&2; exit 1; }

# Start from the example so new settings added there are picked up, then
# override the three values that make a stack client-specific.
TMP=".env.tmp"
grep -v -E '^(COMPOSE_PROJECT_NAME|WP_PORT|WP_URL)=' .env.example > "$TMP"

{
  echo
  echo "# Written by scripts/env-use.sh — selects which client's isolated stack"
  echo "# every docker compose command in this repo talks to."
  echo "COMPOSE_PROJECT_NAME=client-$CLIENT"
  echo "WP_PORT=$PORT"
  echo "WP_URL=http://localhost:$PORT"
} >> "$TMP"

mv "$TMP" .env

echo "Now targeting: client-$CLIENT  (http://localhost:$PORT)"
echo
echo "  npm run env:up      start this client's stack"
echo "  npm run env:init    install WordPress + WooCommerce into it"
echo "  npm run seed -- $CLIENT   populate it"
echo
echo "Each client has its own database volume, so their content never mixes."
