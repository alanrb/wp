#!/usr/bin/env bats

setup_file() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  cd "$ROOT"
  ./scripts/new-client.sh smoke "Smoke Test Theme" >/dev/null 2>&1 || true
}

# setup_file() runs once, in its own process — variables it sets are not
# visible inside individual @test bodies, which each run in a fresh process.
# Recompute ROOT here so it is available where the test needs it.
setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

# Every fail-closed case here plants a real defect in the LIVE theme and moves
# the backup back afterwards. If bats is interrupted between those two steps
# the restore never runs: the developer's source theme is left corrupted and
# the stray .bak would be copied into the next packaged zip. Sweep any backup
# back into place after each test so an abort cannot leak one.
teardown() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  [ -d "$ROOT/themes/client-smoke" ] || return 0
  find "$ROOT/themes/client-smoke" -name '*.bak' -print0 2>/dev/null |
    while IFS= read -r -d '' bak; do
      mv "$bak" "${bak%.bak}"
    done
}

teardown_file() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  cd "$ROOT"
  # client-smoke may be the active theme at this point (verify.sh activates and
  # installs it) — reactivate a bundled theme first so the shared dev stack is
  # never left serving a blank page for the deleted active theme.
  docker compose run --rm cli theme activate twentytwentyfive --allow-root >/dev/null 2>&1 || true
  # Remove any installed copy by explicit container path, never with
  # `wp theme delete`: with no installed copy present that resolves to the
  # client-themes bind mount and would delete the developer's source theme.
  docker compose run --rm --entrypoint rm cli \
    -rf /var/www/html/wp-content/themes/client-smoke >/dev/null 2>&1 || true
  docker compose run --rm cli transient delete theme_roots --network --allow-root >/dev/null 2>&1 || true
  rm -rf "$ROOT/themes/client-smoke" "$ROOT/dist/client-smoke-1.0.0.zip"
}

@test "a freshly scaffolded theme passes the full delivery gate" {
  run "$ROOT/scripts/verify.sh" client-smoke
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ready to deliver"* ]]
}

# The fail-closed guarantee is this task's entire point, so it needs its own
# proof: deliberately break something real and confirm verify.sh actually
# stops and says why, instead of only asserting the happy path passes.
@test "the gate fails closed on an invalid theme.json" {
  local theme_json="$ROOT/themes/client-smoke/theme.json"
  cp "$theme_json" "$theme_json.bak"
  # Corrupt the schema version — the cheapest reliable, real defect to
  # trigger: Step 2/7 (validate-theme-json.mjs) must catch this before the
  # gate ever reaches Theme Check, packaging, or install.
  node -e '
    const fs = require("fs");
    const path = process.argv[1];
    const theme = JSON.parse(fs.readFileSync(path, "utf8"));
    theme.version = 2;
    fs.writeFileSync(path, JSON.stringify(theme, null, 2));
  ' "$theme_json"

  run "$ROOT/scripts/verify.sh" client-smoke

  mv "$theme_json.bak" "$theme_json"

  echo "$output"
  [ "$status" -ne 0 ]
  [[ "$output" == *"version must be 3"* ]]
  [[ "$output" != *"ready to deliver"* ]]
}

# A second, slower fail-closed proof that exercises Finding 2 directly: a
# real PHP notice logged while rendering must be caught by the route smoke
# test's debug.log scan, all the way through build, package, and install.
@test "the gate fails closed when rendering logs a PHP notice" {
  local functions_php="$ROOT/themes/client-smoke/functions.php"
  cp "$functions_php" "$functions_php.bak"
  cat >> "$functions_php" <<'PHP'

// Deliberately injected by tests/integration/verify.bats to prove the
// delivery gate's debug-log scan (Finding 2) actually catches a real PHP
// notice logged while rendering, not just a broken read of debug.log.
add_action(
	'wp_footer',
	function () {
		echo $verify_bats_deliberate_notice_trigger;
	}
);
PHP

  run "$ROOT/scripts/verify.sh" client-smoke

  # `mv` renames the backup back into place WITHOUT touching its mtime, which
  # is older than the mtime the wordpress container's opcache recorded when it
  # compiled the injected version (opcache.validate_timestamps only invalidates
  # on a mtime it hasn't seen before, and only re-checks at all once every
  # opcache.revalidate_freq=2s — going backward in time never trips it, no
  # matter how long a caller then waits). Reproduced directly: after this same
  # restore, the wordpress container kept executing the injected snippet's
  # bytecode indefinitely until the file's mtime was bumped forward. `touch`
  # forces a strictly newer mtime so the very next request recompiles for
  # real, which the following test (a clean consecutive run against this same
  # theme) depends on.
  mv "$functions_php.bak" "$functions_php"
  touch "$functions_php"

  echo "$output"
  [ "$status" -ne 0 ]
  [[ "$output" == *"PHP notices were logged while rendering"* ]]
  [[ "$output" != *"ready to deliver"* ]]
}

# Regression for the Critical finding: `wp theme install` puts a copy under
# wp-content/themes, which core registers AFTER the mu-plugin registers
# wp-content/client-themes, and search_theme_directories() lets the later root
# win a duplicate slug — so the installed copy SHADOWS the bind mount. Left
# behind, it made every subsequent run's Theme Check inspect the previous run's
# frozen files while packaging read the live tree: the gate could print "ready
# to deliver" for a zip carrying a REQUIRED-level violation, and live editing
# silently stopped working for any theme verified once.
#
# Proving it needs two consecutive runs: pass once, then break the LIVE tree
# only and require the second run to see it.
@test "a second consecutive verify inspects the live tree, not the installed copy" {
  run "$ROOT/scripts/verify.sh" client-smoke
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ready to deliver"* ]]

  # Pin the EXIT trap directly: a passing run must leave no shadowing copy
  # behind in the default theme root, so host edits keep appearing live.
  run docker compose run --rm --entrypoint test cli \
    -e /var/www/html/wp-content/themes/client-smoke
  [ "$status" -ne 0 ]

  # A REQUIRED-level Theme Check violation (Bad_Things_Check bans
  # base64_decode) planted in the live tree only. It has to survive
  # tc_strip_comments(), so it is a string literal rather than a comment, and
  # it must still pass `php -l` in step 1/7 so the run reaches Theme Check.
  local functions_php="$ROOT/themes/client-smoke/functions.php"
  cp "$functions_php" "$functions_php.bak"
  printf '\n$verify_bats_live_tree_probe = %s;\nunset( $verify_bats_live_tree_probe );\n' \
    "'base64_decode'" >> "$functions_php"

  run "$ROOT/scripts/verify.sh" client-smoke

  # See the identical restore two tests above: `mv` alone can leave the file
  # with an older mtime than opcache last compiled, which never revalidates on
  # its own. Nothing here re-renders this theme afterwards, but keep the
  # restore honest anyway rather than depending on that happening to be true.
  mv "$functions_php.bak" "$functions_php"
  touch "$functions_php"

  echo "$output"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Theme Check reported REQUIRED-level problems"* ]]
  [[ "$output" != *"ready to deliver"* ]]
}

# The gate must refuse Custom HTML blocks in a real theme's own markup (PRD
# R1) — they break the Site Editor, Theme Check does not look for them, and
# tests/scripts/theme-template.bats only ever guarded the base template.
@test "the gate fails closed on a wp:html block in the theme's templates" {
  local index_html="$ROOT/themes/client-smoke/templates/index.html"
  cp "$index_html" "$index_html.bak"
  printf '\n<!-- wp:html -->\n<p>nope</p>\n<!-- /wp:html -->\n' >> "$index_html"

  run "$ROOT/scripts/verify.sh" client-smoke

  mv "$index_html.bak" "$index_html"

  echo "$output"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Custom HTML blocks (wp:html) are forbidden"* ]]
  [[ "$output" != *"ready to deliver"* ]]
}
