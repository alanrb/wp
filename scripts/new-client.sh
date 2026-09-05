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

TEMPLATE="$ROOT/base/theme-template"
VERSION="1.0.0"

[ -d "$TEMPLATE" ] || { echo "Error: template not found at $TEMPLATE" >&2; exit 1; }

if [ -e "$DEST" ]; then
  echo "Error: $DEST already exists — refusing to overwrite" >&2
  exit 1
fi

mkdir -p "$THEMES_DIR"
cp -R "$TEMPLATE" "$DEST"

# Escape characters that are special on sed's replacement side: backslash,
# ampersand (expands to the whole match), and the '|' delimiter.
sed_escape() { printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'; }

esc_slug="$(sed_escape "$THEME_SLUG")"
esc_name="$(sed_escape "$DISPLAY_NAME")"
esc_desc="$(sed_escape "$DESCRIPTION")"
esc_version="$(sed_escape "$VERSION")"

# Substitute placeholders. Never use sed -i: it is not portable across BSD/GNU.
while IFS= read -r -d '' file; do
  tmp="$file.tmp"
  sed \
    -e "s|{{CLIENT_SLUG}}|$esc_slug|g" \
    -e "s|{{CLIENT_NAME}}|$esc_name|g" \
    -e "s|{{CLIENT_DESCRIPTION}}|$esc_desc|g" \
    -e "s|{{VERSION}}|$esc_version|g" \
    "$file" > "$tmp"
  mv "$tmp" "$file"
done < <(find "$DEST" -type f ! -name '.gitkeep' -print0)

printf '{\n\t"patterns": {}\n}\n' > "$DEST/.shared-manifest.json"

echo "Created $DEST"
