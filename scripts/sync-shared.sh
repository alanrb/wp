#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEMES_DIR="${THEMES_DIR:-$ROOT/themes}"
SHARED_PATTERNS_DIR="${SHARED_PATTERNS_DIR:-$ROOT/shared/patterns}"

[ "$#" -ge 1 ] || { echo "Usage: sync-shared.sh <theme-slug> [pattern...] [--force]" >&2; exit 2; }

THEME="$1"; shift
FORCE=0
PATTERNS=()
for arg in "$@"; do
  if [ "$arg" = "--force" ]; then FORCE=1; else PATTERNS+=("$arg"); fi
done

THEME_PATH="$THEMES_DIR/$THEME"
[ -d "$THEME_PATH" ] || { echo "Error: theme '$THEME' not found at $THEME_PATH" >&2; exit 1; }

MANIFEST="$THEME_PATH/.shared-manifest.json"
REV="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo 'unversioned')"
checksum_of() { shasum -a 256 "$1" | awk '{print $1}'; }

if [ "${#PATTERNS[@]}" -eq 0 ]; then
  while IFS= read -r file; do
    PATTERNS+=("$(basename "$file" .php)")
  done < <(find "$SHARED_PATTERNS_DIR" -maxdepth 1 -name '*.php' | sort)
fi

[ "${#PATTERNS[@]}" -gt 0 ] || { echo "Nothing to sync: $SHARED_PATTERNS_DIR has no patterns."; exit 0; }

mkdir -p "$THEME_PATH/patterns"

for name in ${PATTERNS[@]+"${PATTERNS[@]}"}; do
  src="$SHARED_PATTERNS_DIR/$name.php"
  dest="$THEME_PATH/patterns/$name.php"
  [ -f "$src" ] || { echo "Error: shared pattern '$name' not found at $src" >&2; exit 1; }

  if [ -f "$dest" ] && [ "$FORCE" -eq 0 ]; then
    recorded="$(node "$ROOT/scripts/lib/manifest.mjs" read "$MANIFEST" "$name.php")"
    current="$(checksum_of "$dest")"
    if [ -z "$recorded" ]; then
      echo "Error: $THEME/patterns/$name.php exists with no recorded provenance — refusing to overwrite. Re-run with --force if this file is safe to replace." >&2
      exit 1
    fi
    if [ "$recorded" != "$current" ]; then
      echo "Error: $THEME/patterns/$name.php has been locally modified — refusing to overwrite. Re-run with --force to discard local changes." >&2
      exit 1
    fi
  fi

  {
    echo "<?php"
    echo "/**"
    echo " * NOTE: synced from shared/patterns/$name.php at $REV — edit the shared copy,"
    echo " * then re-run: npm run sync-shared -- $THEME $name"
    echo " */"
    tail -n +2 "$src" | awk -v theme="$THEME" '
      !done && /Slug: shared\// { sub(/Slug: shared\//, "Slug: " theme "/"); done=1 }
      { print }
    '
  } > "$dest.tmp"
  mv "$dest.tmp" "$dest"

  node "$ROOT/scripts/lib/manifest.mjs" write "$MANIFEST" "$name.php" \
    "shared/patterns/$name.php" "$REV" "$(checksum_of "$dest")"

  echo "Synced $name -> $THEME"
done
