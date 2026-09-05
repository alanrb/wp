#!/usr/bin/env bats

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$ROOT/scripts/sync-shared.sh"
  export THEMES_DIR="$BATS_TEST_TMPDIR/themes"
  export SHARED_PATTERNS_DIR="$BATS_TEST_TMPDIR/shared-patterns"
  mkdir -p "$SHARED_PATTERNS_DIR"
  "$ROOT/scripts/new-client.sh" piano "Piano Store" >/dev/null
  cat > "$SHARED_PATTERNS_DIR/cta-banner.php" <<'PHP'
<?php
/**
 * Title: CTA Banner
 * Slug: shared/cta-banner
 * Categories: call-to-action
 */
?>
<!-- wp:paragraph --><p>Get in touch</p><!-- /wp:paragraph -->
PHP
}

@test "copies a shared pattern into the theme" {
  run "$SCRIPT" client-piano cta-banner
  [ "$status" -eq 0 ]
  [ -f "$THEMES_DIR/client-piano/patterns/cta-banner.php" ]
}

@test "namespaces the pattern slug to the theme" {
  "$SCRIPT" client-piano cta-banner >/dev/null
  grep -q "Slug: client-piano/cta-banner" "$THEMES_DIR/client-piano/patterns/cta-banner.php"
  ! grep -q "Slug: shared/cta-banner" "$THEMES_DIR/client-piano/patterns/cta-banner.php"
}

@test "writes a provenance comment into the copied file" {
  "$SCRIPT" client-piano cta-banner >/dev/null
  grep -q "synced from shared/patterns/cta-banner.php" "$THEMES_DIR/client-piano/patterns/cta-banner.php"
}

@test "records the pattern in the manifest" {
  "$SCRIPT" client-piano cta-banner >/dev/null
  run node -e "const m=require('$THEMES_DIR/client-piano/.shared-manifest.json'); const e=m.patterns['cta-banner.php']; process.exit(e && e.checksum && e.source ? 0 : 1)"
  [ "$status" -eq 0 ]
}

@test "re-syncing an unmodified pattern succeeds" {
  "$SCRIPT" client-piano cta-banner >/dev/null
  run "$SCRIPT" client-piano cta-banner
  [ "$status" -eq 0 ]
}

@test "refuses to clobber a locally modified pattern" {
  "$SCRIPT" client-piano cta-banner >/dev/null
  echo "<!-- local edit -->" >> "$THEMES_DIR/client-piano/patterns/cta-banner.php"
  run "$SCRIPT" client-piano cta-banner
  [ "$status" -eq 1 ]
  [[ "$output" == *"locally modified"* ]]
  grep -q "local edit" "$THEMES_DIR/client-piano/patterns/cta-banner.php"
}

@test "--force overwrites a locally modified pattern" {
  "$SCRIPT" client-piano cta-banner >/dev/null
  echo "<!-- local edit -->" >> "$THEMES_DIR/client-piano/patterns/cta-banner.php"
  run "$SCRIPT" client-piano cta-banner --force
  [ "$status" -eq 0 ]
  ! grep -q "local edit" "$THEMES_DIR/client-piano/patterns/cta-banner.php"
}

@test "syncs every shared pattern when none are named" {
  cp "$SHARED_PATTERNS_DIR/cta-banner.php" "$SHARED_PATTERNS_DIR/hero.php"
  run "$SCRIPT" client-piano
  [ "$status" -eq 0 ]
  [ -f "$THEMES_DIR/client-piano/patterns/hero.php" ]
}

@test "fails on an unknown theme" {
  run "$SCRIPT" client-nope cta-banner
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "fails on an unknown pattern" {
  run "$SCRIPT" client-piano no-such-pattern
  [ "$status" -ne 0 ]
  [[ "$output" == *"no-such-pattern"* ]]
}

@test "fails loudly on a malformed manifest instead of clobbering" {
  "$SCRIPT" client-piano cta-banner >/dev/null
  echo '<<<<<<< HEAD' >> "$THEMES_DIR/client-piano/.shared-manifest.json"
  run "$SCRIPT" client-piano cta-banner
  [ "$status" -ne 0 ]
  [[ "$output" == *"not valid JSON"* ]]
  # the copy from the earlier successful sync must be left exactly as it was
  grep -q "Slug: client-piano/cta-banner" "$THEMES_DIR/client-piano/patterns/cta-banner.php"
}

@test "refuses an existing pattern file with no recorded provenance" {
  mkdir -p "$THEMES_DIR/client-piano/patterns"
  cp "$SHARED_PATTERNS_DIR/cta-banner.php" "$THEMES_DIR/client-piano/patterns/cta-banner.php"
  run "$SCRIPT" client-piano cta-banner
  [ "$status" -eq 1 ]
  [[ "$output" == *"no recorded provenance"* ]]
  grep -q "Slug: shared/cta-banner" "$THEMES_DIR/client-piano/patterns/cta-banner.php"
}

@test "--force syncs an existing pattern file with no recorded provenance" {
  mkdir -p "$THEMES_DIR/client-piano/patterns"
  cp "$SHARED_PATTERNS_DIR/cta-banner.php" "$THEMES_DIR/client-piano/patterns/cta-banner.php"
  run "$SCRIPT" client-piano cta-banner --force
  [ "$status" -eq 0 ]
  grep -q "Slug: client-piano/cta-banner" "$THEMES_DIR/client-piano/patterns/cta-banner.php"
}

@test "rewrites only the header Slug, not a body-level occurrence" {
  cat > "$SHARED_PATTERNS_DIR/related.php" <<'PHP'
<?php
/**
 * Title: Related Pattern
 * Slug: shared/related
 * Categories: text
 */
?>
<!-- wp:paragraph --><p>See also Slug: shared/cta-banner for the matching banner.</p><!-- /wp:paragraph -->
PHP
  run "$SCRIPT" client-piano related
  [ "$status" -eq 0 ]
  grep -q "Slug: client-piano/related" "$THEMES_DIR/client-piano/patterns/related.php"
  grep -q "Slug: shared/cta-banner" "$THEMES_DIR/client-piano/patterns/related.php"
}
