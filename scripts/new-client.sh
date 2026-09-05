#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEMES_DIR="${THEMES_DIR:-$ROOT/themes}"

usage() {
  echo "Usage: new-client.sh <slug> <display name> [description]" >&2
  echo "  e.g. new-client.sh piano \"Piano Store & Services\"" >&2
  exit 2
}

[ "$#" -ge 2 ] || usage

SLUG="$1"
DISPLAY_NAME="$2"
DESCRIPTION="${3:-$DISPLAY_NAME}"

if ! printf '%s' "$SLUG" | grep -Eq '^[a-z][a-z0-9-]*$'; then
  echo "Error: slug must be lowercase alphanumeric with hyphens, starting with a letter (got '$SLUG')" >&2
  exit 2
fi

THEME_SLUG="client-$SLUG"
DEST="$THEMES_DIR/$THEME_SLUG"

echo "Would scaffold $THEME_SLUG (\"$DISPLAY_NAME\") into $DEST"
