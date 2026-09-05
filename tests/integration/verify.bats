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
