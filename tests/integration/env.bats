#!/usr/bin/env bats

setup_file() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  cd "$ROOT"
  ./scripts/new-client.sh smoke "Smoke Test Theme" >/dev/null 2>&1 || true
}

teardown_file() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  cd "$ROOT"
  docker compose run --rm cli theme activate twentytwentyfive --allow-root >/dev/null 2>&1 || true
  rm -rf "$ROOT/themes/client-smoke"
}

wp() { docker compose run --rm cli "$@" --allow-root; }

@test "the site responds with HTTP 200" {
  run curl -s -o /dev/null -w '%{http_code}' "${WP_URL:-http://localhost:8080}"
  [ "$output" = "200" ]
}

@test "WooCommerce is active" {
  run wp plugin is-active woocommerce
  [ "$status" -eq 0 ]
}

@test "Theme Check is active" {
  run wp plugin is-active theme-check
  [ "$status" -eq 0 ]
}

@test "a scaffolded theme is visible to WordPress" {
  run wp theme list --field=name
  [[ "$output" == *"client-smoke"* ]]
}

@test "a scaffolded theme activates cleanly" {
  run wp theme activate client-smoke
  [ "$status" -eq 0 ]
  run curl -s -o /dev/null -w '%{http_code}' "${WP_URL:-http://localhost:8080}"
  [ "$output" = "200" ]
}
