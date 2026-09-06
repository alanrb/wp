#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# shellcheck source=lib/wp-theme.sh
. "$ROOT/scripts/lib/wp-theme.sh"

[ "$#" -ge 1 ] || { echo "Usage: theme-check.sh <theme-slug>" >&2; exit 2; }
THEME="$1"

# A copy previously installed into wp-content/themes shadows the client-themes
# bind mount, so Theme Check would inspect those stale files instead of the
# live tree. See wp_theme_remove_installed_copy() for the full explanation and
# for why `wp theme delete` must never be used here.
wp_theme_remove_installed_copy "$THEME"

docker compose run --rm cli theme activate "$THEME" --allow-root
wp_theme_check_run "$THEME"

echo "Theme Check passed for $THEME"
