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

teardown_file() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  cd "$ROOT"
  # client-smoke may be the active theme at this point (verify.sh activates and
  # installs it) — reactivate a bundled theme first so the shared dev stack is
  # never left serving a blank page for the deleted active theme.
  docker compose run --rm cli theme activate twentytwentyfive --allow-root >/dev/null 2>&1 || true
  rm -rf "$ROOT/themes/client-smoke" "$ROOT/dist/client-smoke-1.0.0.zip"
  docker compose run --rm cli theme delete client-smoke --allow-root >/dev/null 2>&1 || true
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

  mv "$functions_php.bak" "$functions_php"

  echo "$output"
  [ "$status" -ne 0 ]
  [[ "$output" == *"PHP notices were logged while rendering"* ]]
  [[ "$output" != *"ready to deliver"* ]]
}
