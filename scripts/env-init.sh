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

# Install the plugins the local environment needs.
#
# wp-cli fetches these from the wordpress.org API, which fails from inside the
# container often enough to matter ("cURL error 35: TLS connect error"). A
# failed install here is not cosmetic: WooCommerce absent means no products, no
# shop routes, and a verify run that smoke-tests /shop/ against a 404. So fall
# back to downloading on the host — where TLS works — into ./dist, which is
# already mounted at /dist in the cli container, and install from the zip.
DIST_DIR="${DIST_DIR:-$ROOT/dist}"
mkdir -p "$DIST_DIR"

install_plugin() { # slug
  local slug="$1"
  local zip="$DIST_DIR/$slug.zip"

  if compose_cli plugin is-installed "$slug" --allow-root >/dev/null 2>&1; then
    compose_cli plugin activate "$slug" --allow-root >/dev/null
    echo "  $slug already installed"
    return 0
  fi

  if compose_cli plugin install "$slug" --activate --allow-root >/dev/null 2>&1; then
    echo "  $slug installed from wordpress.org"
    return 0
  fi

  echo "  $slug: wordpress.org install failed, downloading on the host instead"

  if [ ! -s "$zip" ]; then
    curl -sSL -o "$zip" "https://downloads.wordpress.org/plugin/$slug.latest-stable.zip" || {
      echo "Error: could not download $slug" >&2
      return 1
    }
  fi

  compose_cli plugin install "/dist/$slug.zip" --activate --allow-root >/dev/null || {
    echo "Error: could not install $slug from $zip" >&2
    return 1
  }

  echo "  $slug installed from $zip"
}

install_plugin woocommerce
install_plugin theme-check

# Fail closed: a missing plugin silently degrades every later gate.
for slug in woocommerce theme-check; do
  compose_cli plugin is-active "$slug" --allow-root >/dev/null 2>&1 || {
    echo "Error: $slug is not active — the environment is not usable as a gate." >&2
    exit 1
  }
done

compose_cli rewrite structure '/%postname%/' --allow-root

echo "Ready at ${WP_URL:-http://localhost:8080}"
