#!/usr/bin/env bash
# Shared helpers for the two entry points that run Theme Check against a theme
# inside the Docker stack: scripts/verify.sh and scripts/theme-check.sh.
#
# This file is SOURCED, never executed. Callers run under `set -euo pipefail`
# from the repo root, so `docker compose` resolves the project's
# docker-compose.yml.

WP_THEME_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Remove a previously installed copy of $1 from the DEFAULT theme root.
#
# The mu-plugin registers wp-content/client-themes (the repo's themes/ bind
# mount) at wp-settings.php:506; core registers wp-content/themes later, at
# line 571. search_theme_directories() iterates the roots in order and the
# LATER root wins a duplicate slug, so a copy installed into wp-content/themes
# SHADOWS the bind mount. Two things then break:
#
#   * Theme Check inspects the previous run's installed files while packaging
#     reads the live tree, so the gate can pass a zip that carries a
#     REQUIRED-level violation — it fails open.
#   * host edits stop appearing in the browser with no rebuild.
#
# The copy lives in the wp_data named volume, so it also survives env:down.
#
# DANGER: never use `wp theme delete` here. With no installed copy present that
# resolves to the bind mount and would DELETE THE DEVELOPER'S SOURCE THEME.
# Remove by explicit container path only.
#
# Removing the directory leaves the slug still resolvable through the
# client-themes root, so an active theme with this slug stays valid — this is
# not the R9 "delete a theme directory" case that requires reactivating a
# bundled theme first.
wp_theme_remove_installed_copy() {
	local theme="${1:-}"

	# A blank or path-bearing slug here would turn the rm below into something
	# far more destructive than intended.
	case "$theme" in
		'' | . | .. | */* | -*)
			echo "Error: refusing to remove an installed theme copy for unsafe slug '$theme'" >&2
			return 1
			;;
	esac

	docker compose run --rm --entrypoint rm cli \
		-rf "/var/www/html/wp-content/themes/$theme" >/dev/null 2>&1 || true

	# search_theme_directories() caches slug -> root in the `theme_roots` site
	# transient. Without dropping it, WordPress keeps resolving the slug to the
	# root the copy just left, and every later `wp theme ...` call reports the
	# theme as missing.
	docker compose run --rm cli transient delete theme_roots --network --allow-root \
		>/dev/null 2>&1 || true
}

# Run Theme Check against $1 and fail closed.
#
# Severity comes from the `type` column of the JSON result table (see
# scripts/lib/theme-check-report.mjs), never from grepping the whole output.
#
# wp-cli exits non-zero both when Theme Check ran and found problems AND when it
# never ran at all (theme not found, plugin missing/deactivated, a docker/wp-cli
# crash). Swallowing that would let those cases through as "zero problems
# found", so the run must be shown to have produced a real result table before
# its silence is trusted.
wp_theme_check_run() {
	local theme="$1"
	local out err report
	local status=0 report_status=0

	err="$(mktemp)"
	out="$(docker compose run --rm cli theme-check run "$theme" --format=json --allow-root 2>"$err")" \
		|| status=$?

	report="$(printf '%s' "$out" | node "$WP_THEME_LIB_DIR/theme-check-report.mjs")" \
		|| report_status=$?

	if [ -n "$report" ]; then
		printf '%s\n' "$report"
	fi

	if [ "$report_status" -eq 2 ]; then
		echo "Error: Theme Check did not complete for '$theme' (wp-cli exit $status) — its output was not a parseable result table, so this cannot be trusted as a pass." >&2
		printf '%s\n' "$out" >&2
		cat "$err" >&2
		rm -f "$err"
		return 1
	fi

	if [ "$report_status" -ne 0 ]; then
		cat "$err" >&2
		rm -f "$err"
		echo "Error: Theme Check reported REQUIRED-level problems in $theme." >&2
		return 1
	fi

	if [ "$status" -ne 0 ]; then
		echo "Error: Theme Check did not complete (exit $status) and reported no REQUIRED-level findings — this cannot be trusted as a pass." >&2
		cat "$err" >&2
		rm -f "$err"
		return 1
	fi

	rm -f "$err"
	return 0
}
