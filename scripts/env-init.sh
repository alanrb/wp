#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

[ -f .env ] || cp .env.example .env
# shellcheck disable=SC1091
set -a; . ./.env; set +a

compose_cli() { docker compose run --rm cli "$@"; }

echo "Waiting for WordPress to answer..."
for _ in $(seq 1 60); do
  if compose_cli core is-installed --allow-root >/dev/null 2>&1; then
    echo "WordPress already installed."
    break
  fi
  if compose_cli core install \
      --url="${WP_URL:-http://localhost:8080}" \
      --title="Client Themes Dev" \
      --admin_user="${WP_ADMIN_USER:-admin}" \
      --admin_password="${WP_ADMIN_PASSWORD:-admin}" \
      --admin_email="${WP_ADMIN_EMAIL:-dev@example.com}" \
      --skip-email --allow-root >/dev/null 2>&1; then
    echo "WordPress installed."
    break
  fi
  sleep 2
done

compose_cli core is-installed --allow-root || { echo "Error: WordPress failed to install" >&2; exit 1; }

compose_cli plugin install woocommerce theme-check --activate --allow-root
compose_cli rewrite structure '/%postname%/' --allow-root

echo "Ready at ${WP_URL:-http://localhost:8080}"
