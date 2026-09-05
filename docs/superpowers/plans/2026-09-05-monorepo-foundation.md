# Monorepo Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the client-theme monorepo so that one command scaffolds a valid, activatable WordPress block theme, one command runs it live in Docker with WooCommerce, and one command packages it as a deliverable `.zip`.

**Architecture:** A checked-in `base/theme-template/` is copied and token-substituted by `scripts/new-client.sh` into `themes/<slug>/`, with design tokens merged in from `shared/tokens/` at scaffold time. Shared block patterns are *copied* into themes on demand by `scripts/sync-shared.sh` with a provenance manifest, so no theme ever depends on the repo at runtime. A Docker Compose stack bind-mounts `themes/` into WordPress for live editing, and `scripts/verify.sh` gates a theme by installing its packaged zip into a clean WordPress and smoke-testing the routes.

**Tech Stack:** Bash, Node 22 / npm 11, `@wordpress/scripts` (webpack), Docker Compose (WordPress + MySQL + wp-cli), WooCommerce, Theme Check, bats-core (script tests), pa11y-ci (a11y).

**Spec:** [docs/superpowers/specs/2026-09-05-client-theme-monorepo-foundation-design.md](../specs/2026-09-05-client-theme-monorepo-foundation-design.md)

## Global Constraints

Every task's requirements implicitly include these.

- **Block themes only.** Full Site Editing, `theme.json`, native core blocks. No classic PHP templates.
- **No Custom HTML blocks** in any template, part, or pattern. Post listings use Query Loop. (PRD R1 — Task 2 enforces this with a test.)
- **No runtime coupling between themes.** Shared code is copied in at scaffold/sync time. No parent theme, no cross-theme `require`/`import`, ever.
- **Delivered themes are GPL-2.0-or-later**: `License: GNU General Public License v2 or later` in every theme's `style.css` header, regardless of the repo's Apache-2.0 root LICENSE.
- **WooCommerce support is guarded** by `class_exists( 'WooCommerce' )`; a theme must activate and render with the plugin absent.
- **Scripts are POSIX-portable bash** with `set -euo pipefail`. No GNU-only flags — this runs on macOS. Never use `sed -i` (BSD/GNU incompatible); write to a temp file and `mv`.
- **Every script honours `THEMES_DIR`** (default `<repo>/themes`) so tests can run against a temp directory.
- **Theme slugs** are `client-piano` and `client-jam`; `new-client.sh` takes the bare slug (`piano`) and prefixes `client-`.
- **Theme Check must report zero errors** before any zip is produced.
- **PHP 8.1+ / current WordPress.** Image tags come from `.env`; never hardcode a WordPress version in compose.

---

### Task 1: Repo skeleton, test harness, and scaffold argument validation

**Files:**
- Create: `package.json`, `.gitignore`, `.editorconfig`
- Create: `scripts/new-client.sh`
- Test: `tests/scripts/new-client.bats`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: `scripts/new-client.sh <slug> <display-name> [description]` — exits `2` on usage/validation error, `0` otherwise. Honours `THEMES_DIR`. `npm test` runs `bats tests/scripts`.

- [ ] **Step 1: Create `package.json`**

```json
{
  "name": "client-themes",
  "private": true,
  "version": "1.0.0",
  "description": "Monorepo producing one standalone WordPress block theme per client",
  "license": "Apache-2.0",
  "engines": { "node": ">=20" },
  "scripts": {
    "test": "bats tests/scripts",
    "test:integration": "bats tests/integration",
    "new-client": "./scripts/new-client.sh",
    "env:up": "docker compose up -d",
    "env:down": "docker compose down",
    "env:reset": "docker compose down -v && docker compose up -d",
    "env:cli": "docker compose run --rm cli wp"
  },
  "devDependencies": {
    "bats": "^1.11.0"
  }
}
```

- [ ] **Step 2: Create `.gitignore`**

```gitignore
node_modules/
dist/
themes/*/build/
themes/*/node_modules/
.env
.DS_Store
```

- [ ] **Step 3: Create `.editorconfig`**

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = tab

[*.{json,yml,yaml,md}]
indent_style = space
indent_size = 2

[*.sh]
indent_style = space
indent_size = 2
```

- [ ] **Step 4: Install dependencies**

Run: `npm install`
Expected: `node_modules/` created, `package-lock.json` written, `npx bats --version` prints a version.

- [ ] **Step 5: Write the failing test**

Create `tests/scripts/new-client.bats`:

```bash
#!/usr/bin/env bats

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$ROOT/scripts/new-client.sh"
  export THEMES_DIR="$BATS_TEST_TMPDIR/themes"
  mkdir -p "$THEMES_DIR"
}

@test "exits 2 and prints usage with no arguments" {
  run "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "exits 2 when only a slug is given" {
  run "$SCRIPT" piano
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "rejects an uppercase slug" {
  run "$SCRIPT" Piano "Piano Store"
  [ "$status" -eq 2 ]
  [[ "$output" == *"lowercase"* ]]
}

@test "rejects a slug containing a space" {
  run "$SCRIPT" "piano store" "Piano Store"
  [ "$status" -eq 2 ]
}

@test "rejects a slug starting with a hyphen" {
  run "$SCRIPT" -piano "Piano Store"
  [ "$status" -eq 2 ]
}

@test "accepts a valid slug and display name" {
  run "$SCRIPT" piano "Piano Store & Services"
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 6: Run the test to verify it fails**

Run: `npm test`
Expected: FAIL — every test errors because `scripts/new-client.sh` does not exist.

- [ ] **Step 7: Write the minimal implementation**

Create `scripts/new-client.sh`:

```bash
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
```

- [ ] **Step 8: Make it executable and run the tests**

Run: `chmod +x scripts/new-client.sh && npm test`
Expected: PASS — 6 tests, 0 failures.

- [ ] **Step 9: Commit**

```bash
git add package.json package-lock.json .gitignore .editorconfig scripts/new-client.sh tests/scripts/new-client.bats
git commit -m "Add repo skeleton, bats harness, and scaffold argument validation"
```

---

### Task 2: The base theme template

**Files:**
- Create: `base/theme-template/style.css`, `base/theme-template/theme.json`, `base/theme-template/functions.php`
- Create: `base/theme-template/templates/{index,front-page,page,single,archive,search,404}.html`
- Create: `base/theme-template/parts/{header,footer}.html`
- Create: `base/theme-template/patterns/.gitkeep`
- Test: `tests/scripts/theme-template.bats`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: a template tree whose placeholders are exactly `{{CLIENT_SLUG}}`, `{{CLIENT_NAME}}`, `{{CLIENT_DESCRIPTION}}`, `{{VERSION}}`. Task 3 substitutes these; no other placeholder tokens may exist.

- [ ] **Step 1: Write the failing test**

Create `tests/scripts/theme-template.bats`:

```bash
#!/usr/bin/env bats

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  TEMPLATE="$ROOT/base/theme-template"
}

@test "contains every file required of a block theme" {
  for f in style.css theme.json functions.php \
           templates/index.html templates/front-page.html templates/page.html \
           templates/single.html templates/archive.html templates/search.html templates/404.html \
           parts/header.html parts/footer.html; do
    [ -f "$TEMPLATE/$f" ] || { echo "missing $f"; return 1; }
  done
}

@test "theme.json is valid JSON at schema version 3" {
  run node -e "const t=require('$TEMPLATE/theme.json'); process.exit(t.version === 3 ? 0 : 1)"
  [ "$status" -eq 0 ]
}

@test "style.css declares a GPL-2.0-or-later license" {
  grep -q "License: GNU General Public License v2 or later" "$TEMPLATE/style.css"
}

@test "style.css carries the name and version placeholders" {
  grep -q "Theme Name: {{CLIENT_NAME}}" "$TEMPLATE/style.css"
  grep -q "Version: {{VERSION}}" "$TEMPLATE/style.css"
}

@test "uses no Custom HTML blocks anywhere" {
  ! grep -rq "wp:html" "$TEMPLATE"
}

@test "guards WooCommerce support behind a class_exists check" {
  grep -q "class_exists( 'WooCommerce' )" "$TEMPLATE/functions.php"
}

@test "uses only the four approved placeholder tokens" {
  run bash -c "grep -rho '{{[A-Z_]*}}' '$TEMPLATE' | sort -u"
  [ "$status" -eq 0 ]
  expected=$'{{CLIENT_DESCRIPTION}}\n{{CLIENT_NAME}}\n{{CLIENT_SLUG}}\n{{VERSION}}'
  [ "$output" = "$expected" ]
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `npx bats tests/scripts/theme-template.bats`
Expected: FAIL — "missing style.css", template directory does not exist.

- [ ] **Step 3: Create `base/theme-template/style.css`**

```css
/*
Theme Name: {{CLIENT_NAME}}
Theme URI: https://example.com/{{CLIENT_SLUG}}
Description: {{CLIENT_DESCRIPTION}}
Version: {{VERSION}}
Requires at least: 6.6
Requires PHP: 8.1
License: GNU General Public License v2 or later
License URI: https://www.gnu.org/licenses/gpl-2.0.html
Text Domain: {{CLIENT_SLUG}}
Tags: block-theme, full-site-editing, e-commerce, accessibility-ready
*/
```

- [ ] **Step 4: Create `base/theme-template/theme.json`**

Settings deliberately omit `palette`, `fontFamilies`, and `spacingSizes` — Task 4 merges those in from `shared/tokens/`.

```json
{
	"$schema": "https://schemas.wp.org/trunk/theme.json",
	"version": 3,
	"settings": {
		"appearanceTools": true,
		"useRootPaddingAwareAlignments": true,
		"layout": { "contentSize": "720px", "wideSize": "1240px" },
		"color": { "custom": false, "defaultPalette": false, "defaultGradients": false },
		"typography": { "fluid": true, "defaultFontSizes": false },
		"spacing": { "units": [ "px", "em", "rem", "vh", "vw", "%" ] }
	},
	"styles": {
		"spacing": { "padding": { "top": "0", "bottom": "0", "left": "var(--wp--preset--spacing--40)", "right": "var(--wp--preset--spacing--40)" } }
	},
	"templateParts": [
		{ "name": "header", "title": "Header", "area": "header" },
		{ "name": "footer", "title": "Footer", "area": "footer" }
	]
}
```

- [ ] **Step 5: Create `base/theme-template/functions.php`**

```php
<?php
/**
 * {{CLIENT_NAME}} theme functions.
 *
 * @package {{CLIENT_SLUG}}
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

add_action(
	'after_setup_theme',
	function () {
		add_theme_support( 'wp-block-styles' );
		add_theme_support( 'responsive-embeds' );
		add_theme_support( 'editor-styles' );

		if ( class_exists( 'WooCommerce' ) ) {
			add_theme_support( 'woocommerce' );
		}
	}
);
```

Asset enqueueing is added in Task 6, once the build pipeline exists.

- [ ] **Step 6: Create `base/theme-template/parts/header.html`**

```html
<!-- wp:group {"tagName":"header","style":{"spacing":{"padding":{"top":"var:preset|spacing|40","bottom":"var:preset|spacing|40"}}},"layout":{"type":"constrained"}} -->
<header class="wp-block-group" style="padding-top:var(--wp--preset--spacing--40);padding-bottom:var(--wp--preset--spacing--40)">
	<!-- wp:group {"layout":{"type":"flex","justifyContent":"space-between","flexWrap":"wrap"}} -->
	<div class="wp-block-group">
		<!-- wp:site-title {"level":0} /-->
		<!-- wp:navigation {"overlayMenu":"mobile"} /-->
	</div>
	<!-- /wp:group -->
</header>
<!-- /wp:group -->
```

- [ ] **Step 7: Create `base/theme-template/parts/footer.html`**

```html
<!-- wp:group {"tagName":"footer","style":{"spacing":{"padding":{"top":"var:preset|spacing|60","bottom":"var:preset|spacing|60"}}},"layout":{"type":"constrained"}} -->
<footer class="wp-block-group" style="padding-top:var(--wp--preset--spacing--60);padding-bottom:var(--wp--preset--spacing--60)">
	<!-- wp:group {"layout":{"type":"flex","justifyContent":"space-between","flexWrap":"wrap"}} -->
	<div class="wp-block-group">
		<!-- wp:site-title {"level":0} /-->
		<!-- wp:paragraph {"fontSize":"small"} -->
		<p class="has-small-font-size">&copy; {{CLIENT_NAME}}</p>
		<!-- /wp:paragraph -->
	</div>
	<!-- /wp:group -->
</footer>
<!-- /wp:group -->
```

- [ ] **Step 8: Create the seven templates**

`templates/index.html` — the Query Loop listing:

```html
<!-- wp:template-part {"slug":"header","tagName":"header"} /-->

<!-- wp:group {"tagName":"main","layout":{"type":"constrained"}} -->
<main class="wp-block-group">
	<!-- wp:query {"queryId":0,"query":{"perPage":10,"pages":0,"offset":0,"postType":"post","order":"desc","orderBy":"date","inherit":true},"layout":{"type":"default"}} -->
	<div class="wp-block-query">
		<!-- wp:post-template -->
			<!-- wp:post-title {"isLink":true,"level":2} /-->
			<!-- wp:post-date /-->
			<!-- wp:post-excerpt /-->
		<!-- /wp:post-template -->
		<!-- wp:query-pagination -->
			<!-- wp:query-pagination-previous /-->
			<!-- wp:query-pagination-numbers /-->
			<!-- wp:query-pagination-next /-->
		<!-- /wp:query-pagination -->
		<!-- wp:query-no-results -->
			<!-- wp:paragraph -->
			<p>Nothing found.</p>
			<!-- /wp:paragraph -->
		<!-- /wp:query-no-results -->
	</div>
	<!-- /wp:query -->
</main>
<!-- /wp:group -->

<!-- wp:template-part {"slug":"footer","tagName":"footer"} /-->
```

`templates/single.html`:

```html
<!-- wp:template-part {"slug":"header","tagName":"header"} /-->

<!-- wp:group {"tagName":"main","layout":{"type":"constrained"}} -->
<main class="wp-block-group">
	<!-- wp:post-title {"level":1} /-->
	<!-- wp:post-featured-image /-->
	<!-- wp:post-content {"layout":{"type":"constrained"}} /-->
</main>
<!-- /wp:group -->

<!-- wp:template-part {"slug":"footer","tagName":"footer"} /-->
```

`templates/page.html`:

```html
<!-- wp:template-part {"slug":"header","tagName":"header"} /-->

<!-- wp:group {"tagName":"main","layout":{"type":"constrained"}} -->
<main class="wp-block-group">
	<!-- wp:post-title {"level":1} /-->
	<!-- wp:post-content {"layout":{"type":"constrained"}} /-->
</main>
<!-- /wp:group -->

<!-- wp:template-part {"slug":"footer","tagName":"footer"} /-->
```

`templates/front-page.html`, `templates/archive.html`, `templates/search.html` — copy `index.html` verbatim. They are differentiated per client in the theme plans; here they only need to exist and be valid.

`templates/404.html`:

```html
<!-- wp:template-part {"slug":"header","tagName":"header"} /-->

<!-- wp:group {"tagName":"main","layout":{"type":"constrained"}} -->
<main class="wp-block-group">
	<!-- wp:heading {"level":1} -->
	<h1 class="wp-block-heading">Page not found</h1>
	<!-- /wp:heading -->
	<!-- wp:paragraph -->
	<p>The page you were looking for doesn't exist. Try a search instead.</p>
	<!-- /wp:paragraph -->
	<!-- wp:search {"buttonText":"Search"} /-->
</main>
<!-- /wp:group -->

<!-- wp:template-part {"slug":"footer","tagName":"footer"} /-->
```

- [ ] **Step 9: Create the empty patterns directory**

Run: `mkdir -p base/theme-template/patterns && touch base/theme-template/patterns/.gitkeep`

- [ ] **Step 10: Run the tests to verify they pass**

Run: `npx bats tests/scripts/theme-template.bats`
Expected: PASS — 7 tests, 0 failures. If the placeholder test fails, an unapproved `{{TOKEN}}` crept in; remove it.

- [ ] **Step 11: Commit**

```bash
git add base/theme-template tests/scripts/theme-template.bats
git commit -m "Add tokenised base block theme template"
```

---

### Task 3: Scaffold by copy and token substitution

**Files:**
- Modify: `scripts/new-client.sh`
- Test: `tests/scripts/new-client.bats:1` (append cases)

**Interfaces:**
- Consumes: `base/theme-template/` and its four placeholders from Task 2.
- Produces: `$THEMES_DIR/client-<slug>/` — a complete theme with no placeholders remaining, version `1.0.0`, and an empty `.shared-manifest.json` (`{"patterns":{}}`) that Task 7 populates.

- [ ] **Step 1: Write the failing tests**

Append to `tests/scripts/new-client.bats`:

```bash
@test "creates the theme directory with the client- prefix" {
  run "$SCRIPT" piano "Piano Store & Services"
  [ "$status" -eq 0 ]
  [ -d "$THEMES_DIR/client-piano" ]
  [ -f "$THEMES_DIR/client-piano/theme.json" ]
  [ -f "$THEMES_DIR/client-piano/templates/index.html" ]
}

@test "leaves no placeholder tokens behind" {
  "$SCRIPT" piano "Piano Store & Services" >/dev/null
  ! grep -rq '{{' "$THEMES_DIR/client-piano"
}

@test "writes the display name into the style.css header" {
  "$SCRIPT" piano "Piano Store & Services" >/dev/null
  grep -q "Theme Name: Piano Store & Services" "$THEMES_DIR/client-piano/style.css"
  grep -q "Version: 1.0.0" "$THEMES_DIR/client-piano/style.css"
  grep -q "Text Domain: client-piano" "$THEMES_DIR/client-piano/style.css"
}

@test "uses the description argument when supplied" {
  "$SCRIPT" jam "Fruit Jam Production" "Preserves made on site" >/dev/null
  grep -q "Description: Preserves made on site" "$THEMES_DIR/client-jam/style.css"
}

@test "produces a theme.json that parses as JSON" {
  "$SCRIPT" piano "Piano Store & Services" >/dev/null
  run node -e "require('$THEMES_DIR/client-piano/theme.json')"
  [ "$status" -eq 0 ]
}

@test "writes an empty shared manifest" {
  "$SCRIPT" piano "Piano Store & Services" >/dev/null
  run node -e "const m=require('$THEMES_DIR/client-piano/.shared-manifest.json'); process.exit(Object.keys(m.patterns).length === 0 ? 0 : 1)"
  [ "$status" -eq 0 ]
}

@test "refuses to overwrite an existing theme" {
  "$SCRIPT" piano "Piano Store & Services" >/dev/null
  run "$SCRIPT" piano "Piano Store & Services"
  [ "$status" -eq 1 ]
  [[ "$output" == *"already exists"* ]]
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npx bats tests/scripts/new-client.bats`
Expected: FAIL — the six original tests pass; the new ones fail because nothing is created.

- [ ] **Step 3: Replace the placeholder body of `scripts/new-client.sh`**

Replace the final `echo "Would scaffold ..."` line with:

```bash
TEMPLATE="$ROOT/base/theme-template"
VERSION="1.0.0"

[ -d "$TEMPLATE" ] || { echo "Error: template not found at $TEMPLATE" >&2; exit 1; }

if [ -e "$DEST" ]; then
  echo "Error: $DEST already exists — refusing to overwrite" >&2
  exit 1
fi

mkdir -p "$THEMES_DIR"
cp -R "$TEMPLATE" "$DEST"

# Substitute placeholders. Never use sed -i: it is not portable across BSD/GNU.
while IFS= read -r -d '' file; do
  tmp="$file.tmp"
  sed \
    -e "s|{{CLIENT_SLUG}}|$THEME_SLUG|g" \
    -e "s|{{CLIENT_NAME}}|$DISPLAY_NAME|g" \
    -e "s|{{CLIENT_DESCRIPTION}}|$DESCRIPTION|g" \
    -e "s|{{VERSION}}|$VERSION|g" \
    "$file" > "$tmp"
  mv "$tmp" "$file"
done < <(find "$DEST" -type f ! -name '.gitkeep' -print0)

printf '{\n\t"patterns": {}\n}\n' > "$DEST/.shared-manifest.json"

echo "Created $DEST"
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `npm test`
Expected: PASS — 13 tests, 0 failures.

- [ ] **Step 5: Verify manually against the real themes directory**

Run: `npm run new-client -- piano "Piano Store & Services" && ls themes/client-piano`
Expected: the full theme tree. Then `rm -rf themes/client-piano` — the real themes are created in their own plans.

- [ ] **Step 6: Commit**

```bash
git add scripts/new-client.sh tests/scripts/new-client.bats
git commit -m "Scaffold client themes by copy and token substitution"
```

---

### Task 4: Shared design tokens merged at scaffold time

**Files:**
- Create: `shared/tokens/color.json`, `shared/tokens/typography.json`, `shared/tokens/spacing.json`
- Create: `scripts/lib/merge-tokens.mjs`
- Modify: `scripts/new-client.sh`
- Test: `tests/scripts/merge-tokens.bats`

**Interfaces:**
- Consumes: the scaffolded `theme.json` from Task 3.
- Produces: `node scripts/lib/merge-tokens.mjs <theme.json path> <tokens dir>` — merges each token file into `settings.<key>` in place, preserving existing keys. Deep-merges objects; replaces arrays wholesale. Exits non-zero with a message on invalid JSON.

- [ ] **Step 1: Write the failing test**

Create `tests/scripts/merge-tokens.bats`:

```bash
#!/usr/bin/env bats

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  MERGE="$ROOT/scripts/lib/merge-tokens.mjs"
  WORK="$BATS_TEST_TMPDIR/work"
  mkdir -p "$WORK/tokens"
  cat > "$WORK/theme.json" <<'JSON'
{ "version": 3, "settings": { "layout": { "contentSize": "720px" }, "color": { "custom": false } } }
JSON
  cat > "$WORK/tokens/color.json" <<'JSON'
{ "palette": [ { "slug": "base", "color": "#ffffff", "name": "Base" } ] }
JSON
}

@test "merges a token file into the matching settings key" {
  run node "$MERGE" "$WORK/theme.json" "$WORK/tokens"
  [ "$status" -eq 0 ]
  run node -e "const t=require('$WORK/theme.json'); process.exit(t.settings.color.palette[0].slug === 'base' ? 0 : 1)"
  [ "$status" -eq 0 ]
}

@test "preserves settings keys that the tokens do not mention" {
  node "$MERGE" "$WORK/theme.json" "$WORK/tokens"
  run node -e "const t=require('$WORK/theme.json'); process.exit(t.settings.color.custom === false && t.settings.layout.contentSize === '720px' ? 0 : 1)"
  [ "$status" -eq 0 ]
}

@test "fails loudly on malformed token JSON" {
  echo '{ broken' > "$WORK/tokens/color.json"
  run node "$MERGE" "$WORK/theme.json" "$WORK/tokens"
  [ "$status" -ne 0 ]
  [[ "$output" == *"color.json"* ]]
}

@test "scaffolded themes receive the shared palette" {
  export THEMES_DIR="$BATS_TEST_TMPDIR/themes"
  "$ROOT/scripts/new-client.sh" piano "Piano Store" >/dev/null
  run node -e "const t=require('$THEMES_DIR/client-piano/theme.json'); process.exit(Array.isArray(t.settings.color.palette) && t.settings.color.palette.length > 0 ? 0 : 1)"
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `npx bats tests/scripts/merge-tokens.bats`
Expected: FAIL — `Cannot find module .../merge-tokens.mjs`.

- [ ] **Step 3: Write `scripts/lib/merge-tokens.mjs`**

```javascript
#!/usr/bin/env node
import { readFileSync, writeFileSync, readdirSync } from 'node:fs';
import { basename, join } from 'node:path';

const [ themeJsonPath, tokensDir ] = process.argv.slice( 2 );

if ( ! themeJsonPath || ! tokensDir ) {
	console.error( 'Usage: merge-tokens.mjs <theme.json> <tokens-dir>' );
	process.exit( 2 );
}

const readJson = ( file ) => {
	try {
		return JSON.parse( readFileSync( file, 'utf8' ) );
	} catch ( error ) {
		console.error( `Error: ${ basename( file ) } is not valid JSON — ${ error.message }` );
		process.exit( 1 );
	}
};

const isPlainObject = ( value ) =>
	value !== null && typeof value === 'object' && ! Array.isArray( value );

const deepMerge = ( target, source ) => {
	for ( const [ key, value ] of Object.entries( source ) ) {
		target[ key ] = isPlainObject( value ) && isPlainObject( target[ key ] )
			? deepMerge( target[ key ], value )
			: value;
	}
	return target;
};

const themeJson = readJson( themeJsonPath );
themeJson.settings = themeJson.settings ?? {};

for ( const file of readdirSync( tokensDir ).filter( ( f ) => f.endsWith( '.json' ) ).sort() ) {
	const settingsKey = basename( file, '.json' );
	const tokens = readJson( join( tokensDir, file ) );
	themeJson.settings[ settingsKey ] = deepMerge(
		themeJson.settings[ settingsKey ] ?? {},
		tokens
	);
}

writeFileSync( themeJsonPath, JSON.stringify( themeJson, null, '\t' ) + '\n' );
```

- [ ] **Step 4: Create the three token files**

These are neutral defaults; each client theme overrides them with its own identity in its own plan. `shared/tokens/color.json`:

```json
{
	"palette": [
		{ "slug": "base", "color": "#ffffff", "name": "Base" },
		{ "slug": "contrast", "color": "#111111", "name": "Contrast" },
		{ "slug": "accent", "color": "#3858e9", "name": "Accent" },
		{ "slug": "muted", "color": "#6b6b6b", "name": "Muted" }
	]
}
```

`shared/tokens/typography.json`:

```json
{
	"fontSizes": [
		{ "slug": "small", "size": "0.875rem", "name": "Small", "fluid": false },
		{ "slug": "medium", "size": "1rem", "name": "Medium", "fluid": false },
		{ "slug": "large", "size": "1.5rem", "name": "Large", "fluid": { "min": "1.25rem", "max": "1.75rem" } },
		{ "slug": "x-large", "size": "2.25rem", "name": "Extra Large", "fluid": { "min": "1.75rem", "max": "2.75rem" } },
		{ "slug": "xx-large", "size": "3.5rem", "name": "Display", "fluid": { "min": "2.5rem", "max": "4.5rem" } }
	]
}
```

`shared/tokens/spacing.json`:

```json
{
	"spacingSizes": [
		{ "slug": "20", "size": "0.5rem", "name": "1" },
		{ "slug": "30", "size": "1rem", "name": "2" },
		{ "slug": "40", "size": "1.5rem", "name": "3" },
		{ "slug": "50", "size": "2.5rem", "name": "4" },
		{ "slug": "60", "size": "4rem", "name": "5" },
		{ "slug": "70", "size": "6rem", "name": "6" },
		{ "slug": "80", "size": "8rem", "name": "7" }
	]
}
```

- [ ] **Step 5: Wire the merge into `scripts/new-client.sh`**

Insert immediately before the `.shared-manifest.json` line:

```bash
node "$ROOT/scripts/lib/merge-tokens.mjs" "$DEST/theme.json" "$ROOT/shared/tokens"
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `npm test`
Expected: PASS — 17 tests, 0 failures.

- [ ] **Step 7: Commit**

```bash
git add shared/tokens scripts/lib/merge-tokens.mjs scripts/new-client.sh tests/scripts/merge-tokens.bats
git commit -m "Merge shared design tokens into theme.json at scaffold time"
```

---

### Task 5: Dockerised WordPress with WooCommerce

**Files:**
- Create: `docker-compose.yml`, `.env.example`
- Create: `docker/mu-plugins/register-client-themes.php`
- Create: `scripts/env-init.sh`
- Modify: `package.json` (add `env:init`)
- Test: `tests/integration/env.bats`

**Interfaces:**
- Consumes: `scripts/new-client.sh` from Task 3 (the integration test scaffolds a throwaway theme).
- Produces: a running site on `http://localhost:${WP_PORT:-8080}`, WooCommerce and Theme Check active, and `docker compose run --rm cli wp <args>` as the wp-cli entry point. Themes in `./themes` are registered as a **second theme directory**, so the repo is never polluted by plugin/theme installs.

**Why a second theme directory:** bind-mounting `./themes` directly over `wp-content/themes` hides WordPress's bundled themes (breaking fallback) and causes anything wp-cli installs to be written into the repo. Registering `wp-content/client-themes` as an additional directory keeps both working.

- [ ] **Step 1: Create `.env.example`**

```bash
# Copy to .env and adjust. Leave WP_IMAGE_TAG unset to track the latest WordPress.
WP_IMAGE_TAG=php8.3-apache
WP_PORT=8080
WP_URL=http://localhost:8080
WP_ADMIN_USER=admin
WP_ADMIN_PASSWORD=admin
WP_ADMIN_EMAIL=dev@example.com
```

To exercise NFR4 (current minus one), set `WP_IMAGE_TAG=6.8-php8.3-apache` and re-run `npm run env:reset`.

- [ ] **Step 2: Create `docker-compose.yml`**

```yaml
services:
  db:
    image: mysql:8.4
    environment:
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: wordpress
      MYSQL_ROOT_PASSWORD: root
    volumes:
      - db_data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-uroot", "-proot"]
      interval: 5s
      timeout: 5s
      retries: 20

  wordpress:
    image: wordpress:${WP_IMAGE_TAG:-php8.3-apache}
    depends_on:
      db:
        condition: service_healthy
    ports:
      - "${WP_PORT:-8080}:80"
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: wordpress
      WORDPRESS_DB_NAME: wordpress
      WORDPRESS_DEBUG: 1
      WORDPRESS_CONFIG_EXTRA: |
        define( 'WP_DEBUG_LOG', '/var/www/html/wp-content/debug.log' );
        define( 'WP_DEBUG_DISPLAY', false );
    volumes:
      - wp_data:/var/www/html
      - ./themes:/var/www/html/wp-content/client-themes
      - ./docker/mu-plugins:/var/www/html/wp-content/mu-plugins

  cli:
    image: wordpress:cli-php8.3
    depends_on:
      - wordpress
    user: "33:33"
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: wordpress
      WORDPRESS_DB_NAME: wordpress
    volumes:
      - wp_data:/var/www/html
      - ./themes:/var/www/html/wp-content/client-themes
      - ./docker/mu-plugins:/var/www/html/wp-content/mu-plugins
      - ./dist:/dist
    entrypoint: wp

volumes:
  db_data:
  wp_data:
```

- [ ] **Step 3: Create `docker/mu-plugins/register-client-themes.php`**

```php
<?php
/**
 * Plugin Name: Register client themes directory
 * Description: Exposes the repo's themes/ bind mount to WordPress without hiding bundled themes.
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

register_theme_directory( WP_CONTENT_DIR . '/client-themes' );
```

- [ ] **Step 4: Create `scripts/env-init.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

[ -f .env ] || cp .env.example .env
# shellcheck disable=SC1091
set -a; . ./.env; set +a

compose_cli() { docker compose run --rm cli "$@"; }

echo "Waiting for WordPress to answer..."
for _ in $(seq 1 60); do
  if compose_cli core is-installed --allow-root >/dev/null 2>&1; then
    echo "WordPress already installed."
    break
  fi
  if compose_cli core install \
      --url="${WP_URL:-http://localhost:8080}" \
      --title="Client Themes Dev" \
      --admin_user="${WP_ADMIN_USER:-admin}" \
      --admin_password="${WP_ADMIN_PASSWORD:-admin}" \
      --admin_email="${WP_ADMIN_EMAIL:-dev@example.com}" \
      --skip-email --allow-root >/dev/null 2>&1; then
    echo "WordPress installed."
    break
  fi
  sleep 2
done

compose_cli core is-installed --allow-root || { echo "Error: WordPress failed to install" >&2; exit 1; }

compose_cli plugin install woocommerce theme-check --activate --allow-root
compose_cli rewrite structure '/%postname%/' --allow-root

echo "Ready at ${WP_URL:-http://localhost:8080}"
```

- [ ] **Step 5: Add the npm scripts**

In `package.json`, add to `scripts`:

```json
"env:init": "./scripts/env-init.sh",
"env:logs": "docker compose logs -f wordpress"
```

- [ ] **Step 6: Write the integration test**

Create `tests/integration/env.bats`:

```bash
#!/usr/bin/env bats

setup_file() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  cd "$ROOT"
  ./scripts/new-client.sh smoke "Smoke Test Theme" >/dev/null 2>&1 || true
}

teardown_file() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
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
```

- [ ] **Step 7: Bring the stack up and run the test**

```bash
chmod +x scripts/env-init.sh
cp .env.example .env
npm run env:up
npm run env:init
npm run test:integration
```

Expected: 5 tests pass. If "the site responds" fails, give Apache a few more seconds and re-run; if `client-smoke` is missing, the mu-plugin is not mounted — check `docker compose exec wordpress ls wp-content/mu-plugins`.

- [ ] **Step 8: Commit**

```bash
git add docker-compose.yml .env.example docker scripts/env-init.sh package.json tests/integration/env.bats
git commit -m "Add Dockerised WordPress stack with WooCommerce and Theme Check"
```

---

### Task 6: Shared build pipeline and asset enqueueing

**Files:**
- Create: `shared/build/webpack.config.js`
- Create: `base/theme-template/webpack.config.js`, `base/theme-template/src/index.js`, `base/theme-template/src/style.scss`
- Create: `scripts/build-theme.sh`
- Modify: `base/theme-template/functions.php`, `package.json`
- Test: `tests/scripts/build.bats`

**Interfaces:**
- Consumes: the scaffolded theme from Task 3.
- Produces: `scripts/build-theme.sh <theme-slug> [--watch]` → writes `themes/<slug>/build/index.js`, `build/style-index.css`, `build/index.asset.php`. `functions.php` enqueues using `$asset['version']` and `$asset['dependencies']` — never a hardcoded version (FR6).

- [ ] **Step 1: Write the failing test**

Create `tests/scripts/build.bats`:

```bash
#!/usr/bin/env bats

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export THEMES_DIR="$BATS_TEST_TMPDIR/themes"
  "$ROOT/scripts/new-client.sh" piano "Piano Store" >/dev/null
}

@test "functions.php enqueues from the generated asset file" {
  grep -q "build/index.asset.php" "$THEMES_DIR/client-piano/functions.php"
  grep -q "asset\['version'\]" "$THEMES_DIR/client-piano/functions.php"
  grep -q "asset\['dependencies'\]" "$THEMES_DIR/client-piano/functions.php"
}

@test "functions.php hardcodes no asset version" {
  ! grep -Eq "wp_enqueue_(style|script)\(.*'1\.0\.0'" "$THEMES_DIR/client-piano/functions.php"
}

@test "the scaffolded theme has a webpack config and a src entry point" {
  [ -f "$THEMES_DIR/client-piano/webpack.config.js" ]
  [ -f "$THEMES_DIR/client-piano/src/index.js" ]
  [ -f "$THEMES_DIR/client-piano/src/style.scss" ]
}

@test "building produces the asset manifest and compiled files" {
  run "$ROOT/scripts/build-theme.sh" client-piano
  [ "$status" -eq 0 ]
  [ -f "$THEMES_DIR/client-piano/build/index.asset.php" ]
  [ -f "$THEMES_DIR/client-piano/build/index.js" ]
  [ -f "$THEMES_DIR/client-piano/build/style-index.css" ]
}

@test "building an unknown theme fails with a clear message" {
  run "$ROOT/scripts/build-theme.sh" client-nope
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `npx bats tests/scripts/build.bats`
Expected: FAIL — `functions.php` has no enqueue block yet.

- [ ] **Step 3: Add `@wordpress/scripts`**

Run: `npm install --save-dev @wordpress/scripts@^30.0.0 sass`

- [ ] **Step 4: Create `shared/build/webpack.config.js`**

```javascript
/**
 * Shared webpack configuration for every client theme.
 * Themes require this file so build behaviour stays identical across clients.
 */
const defaultConfig = require( '@wordpress/scripts/config/webpack.config' );

module.exports = {
	...defaultConfig,
	// wp-scripts defaults to src/index.js -> build/. That is what every theme uses.
};
```

- [ ] **Step 5: Create the template's build inputs**

`base/theme-template/webpack.config.js` — the relative path is correct because themes live at `themes/<slug>/`:

```javascript
module.exports = require( '../../shared/build/webpack.config.js' );
```

`base/theme-template/src/index.js`:

```javascript
/**
 * Front-end entry point for {{CLIENT_NAME}}.
 * Importing the stylesheet makes wp-scripts emit build/style-index.css.
 */
import './style.scss';
```

`base/theme-template/src/style.scss`:

```scss
/* {{CLIENT_NAME}} — styles that theme.json cannot express belong here. */

:where(body) {
	// Placeholder rule so the stylesheet is emitted; replaced per client.
	--client-theme-loaded: 1;
}
```

- [ ] **Step 6: Add the enqueue block to `base/theme-template/functions.php`**

Append:

```php
add_action(
	'wp_enqueue_scripts',
	function () {
		$asset_file = get_theme_file_path( 'build/index.asset.php' );

		if ( ! file_exists( $asset_file ) ) {
			return;
		}

		$asset = require $asset_file;

		wp_enqueue_style(
			'{{CLIENT_SLUG}}-style',
			get_theme_file_uri( 'build/style-index.css' ),
			array(),
			$asset['version']
		);

		wp_enqueue_script(
			'{{CLIENT_SLUG}}-script',
			get_theme_file_uri( 'build/index.js' ),
			$asset['dependencies'],
			$asset['version'],
			true
		);
	}
);
```

- [ ] **Step 7: Create `scripts/build-theme.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEMES_DIR="${THEMES_DIR:-$ROOT/themes}"

[ "$#" -ge 1 ] || { echo "Usage: build-theme.sh <theme-slug> [--watch]" >&2; exit 2; }

THEME="$1"
MODE="build"
[ "${2:-}" = "--watch" ] && MODE="start"

THEME_PATH="$THEMES_DIR/$THEME"
[ -d "$THEME_PATH" ] || { echo "Error: theme '$THEME' not found at $THEME_PATH" >&2; exit 1; }

cd "$THEME_PATH"
"$ROOT/node_modules/.bin/wp-scripts" "$MODE"
```

- [ ] **Step 8: Add npm scripts**

```json
"build": "./scripts/build-theme.sh",
"watch": "./scripts/build-theme.sh"
```

Watch is invoked as `npm run watch -- client-piano --watch`.

- [ ] **Step 9: Run the tests to verify they pass**

Run: `chmod +x scripts/build-theme.sh && npx bats tests/scripts/build.bats`
Expected: PASS — 5 tests. The build test takes ~20s on first run.

- [ ] **Step 10: Commit**

```bash
git add shared/build base/theme-template scripts/build-theme.sh package.json package-lock.json tests/scripts/build.bats
git commit -m "Add shared build pipeline and derived asset enqueueing"
```

---

### Task 7: Opt-in shared pattern sync with a provenance manifest

**Files:**
- Create: `scripts/sync-shared.sh`, `scripts/lib/manifest.mjs`
- Create: `shared/patterns/README.md`
- Test: `tests/scripts/sync-shared.bats`

**Interfaces:**
- Consumes: `.shared-manifest.json` written by Task 3; `$THEMES_DIR`.
- Produces: `scripts/sync-shared.sh <theme-slug> [pattern-name...] [--force]`. Copies `shared/patterns/<name>.php` into `themes/<slug>/patterns/<name>.php`, rewrites the pattern's `Slug:` header from `shared/<name>` to `<theme-slug>/<name>`, prepends a provenance comment, and records `{source, rev, checksum}` per pattern. Aborts with exit `1` if the theme's local copy no longer matches its recorded checksum, unless `--force`.
- `scripts/lib/manifest.mjs read <manifest> <pattern>` prints the recorded checksum or an empty string; `... write <manifest> <pattern> <source> <rev> <checksum>` upserts the entry.

This is the mechanism answering PRD R2. Propagation is deliberate and copy-based, so no theme depends on the repo at runtime (§6.1).

- [ ] **Step 1: Write the failing test**

Create `tests/scripts/sync-shared.bats`:

```bash
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `npx bats tests/scripts/sync-shared.bats`
Expected: FAIL — `scripts/sync-shared.sh` does not exist.

- [ ] **Step 3: Write `scripts/lib/manifest.mjs`**

```javascript
#!/usr/bin/env node
import { readFileSync, writeFileSync } from 'node:fs';

const [ command, manifestPath, pattern, source, rev, checksum ] = process.argv.slice( 2 );

const load = () => {
	try {
		const data = JSON.parse( readFileSync( manifestPath, 'utf8' ) );
		data.patterns = data.patterns ?? {};
		return data;
	} catch {
		return { patterns: {} };
	}
};

if ( command === 'read' ) {
	process.stdout.write( load().patterns[ pattern ]?.checksum ?? '' );
} else if ( command === 'write' ) {
	const data = load();
	data.patterns[ pattern ] = { source, rev, checksum };
	writeFileSync( manifestPath, JSON.stringify( data, null, '\t' ) + '\n' );
} else {
	console.error( 'Usage: manifest.mjs read|write <manifest> <pattern> [source] [rev] [checksum]' );
	process.exit( 2 );
}
```

- [ ] **Step 4: Write `scripts/sync-shared.sh`**

```bash
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

for name in "${PATTERNS[@]}"; do
  src="$SHARED_PATTERNS_DIR/$name.php"
  dest="$THEME_PATH/patterns/$name.php"
  [ -f "$src" ] || { echo "Error: shared pattern '$name' not found at $src" >&2; exit 1; }

  if [ -f "$dest" ] && [ "$FORCE" -eq 0 ]; then
    recorded="$(node "$ROOT/scripts/lib/manifest.mjs" read "$MANIFEST" "$name.php")"
    current="$(checksum_of "$dest")"
    if [ -n "$recorded" ] && [ "$recorded" != "$current" ]; then
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
    tail -n +2 "$src" | sed -e "s|Slug: shared/|Slug: $THEME/|"
  } > "$dest.tmp"
  mv "$dest.tmp" "$dest"

  node "$ROOT/scripts/lib/manifest.mjs" write "$MANIFEST" "$name.php" \
    "shared/patterns/$name.php" "$REV" "$(checksum_of "$dest")"

  echo "Synced $name -> $THEME"
done
```

- [ ] **Step 5: Document the shared pattern contract**

Create `shared/patterns/README.md`:

```markdown
# Shared block patterns

A pattern belongs here **only once two client themes genuinely need it**. Until
then it lives in the theme that uses it. Do not add patterns speculatively.

Each file is a standard WordPress pattern with a `Slug: shared/<name>` header;
`scripts/sync-shared.sh` rewrites that slug to the consuming theme's namespace
when it copies the file in.

Sync is deliberate and copy-based — nothing here is loaded at runtime by a
delivered theme. Editing a synced pattern inside a client theme is allowed; the
next sync will refuse to overwrite it until you pass `--force`.
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `chmod +x scripts/sync-shared.sh && npx bats tests/scripts/sync-shared.bats`
Expected: PASS — 10 tests, 0 failures.

- [ ] **Step 7: Add the npm script and commit**

Confirm `"sync-shared": "./scripts/sync-shared.sh"` is present in `package.json`, then:

```bash
git add scripts/sync-shared.sh scripts/lib/manifest.mjs shared/patterns/README.md package.json tests/scripts/sync-shared.bats
git commit -m "Add opt-in shared pattern sync with provenance manifest"
```

---

### Task 8: Packaging a theme for delivery

**Files:**
- Create: `scripts/package-theme.sh`
- Modify: `package.json`
- Test: `tests/scripts/package-theme.bats`

**Interfaces:**
- Consumes: `scripts/build-theme.sh` from Task 6.
- Produces: `scripts/package-theme.sh <theme-slug> [--skip-lint]` → `dist/<theme-slug>-<version>.zip`, where `<version>` is read from the theme's own `style.css` header (FR8). Exits non-zero if lint fails, if the build is missing, or if the version header is absent.

**Scope note:** the spec says packaging is gated on lint *and* Theme Check. Lint runs here because it is local and fast; Theme Check needs the Docker stack, so it runs in `verify.sh` (Task 9) immediately **before** packaging. The delivery gate is `npm run verify`, of which `package` is one step — `npm run package` on its own is the developer's quick path.

- [ ] **Step 1: Write the failing test**

Create `tests/scripts/package-theme.bats`:

```bash
#!/usr/bin/env bats

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$ROOT/scripts/package-theme.sh"
  export THEMES_DIR="$BATS_TEST_TMPDIR/themes"
  export DIST_DIR="$BATS_TEST_TMPDIR/dist"
  "$ROOT/scripts/new-client.sh" piano "Piano Store" >/dev/null
  "$ROOT/scripts/build-theme.sh" client-piano >/dev/null
}

@test "produces a zip named for the theme and its version" {
  run "$SCRIPT" client-piano --skip-lint
  [ "$status" -eq 0 ]
  [ -f "$DIST_DIR/client-piano-1.0.0.zip" ]
}

@test "the zip contains the theme in a top-level folder" {
  "$SCRIPT" client-piano --skip-lint >/dev/null
  run unzip -l "$DIST_DIR/client-piano-1.0.0.zip"
  [[ "$output" == *"client-piano/style.css"* ]]
  [[ "$output" == *"client-piano/theme.json"* ]]
  [[ "$output" == *"client-piano/build/index.js"* ]]
}

@test "the zip excludes all development files" {
  "$SCRIPT" client-piano --skip-lint >/dev/null
  run unzip -l "$DIST_DIR/client-piano-1.0.0.zip"
  [[ "$output" != *"client-piano/src/"* ]]
  [[ "$output" != *"node_modules"* ]]
  [[ "$output" != *"webpack.config.js"* ]]
  [[ "$output" != *".shared-manifest.json"* ]]
}

@test "picks up a bumped version from style.css" {
  tmp="$THEMES_DIR/client-piano/style.css.tmp"
  sed -e 's/Version: 1.0.0/Version: 2.3.1/' "$THEMES_DIR/client-piano/style.css" > "$tmp"
  mv "$tmp" "$THEMES_DIR/client-piano/style.css"
  "$SCRIPT" client-piano --skip-lint >/dev/null
  [ -f "$DIST_DIR/client-piano-2.3.1.zip" ]
}

@test "fails when the theme has never been built" {
  rm -rf "$THEMES_DIR/client-piano/build"
  run "$SCRIPT" client-piano --skip-lint
  [ "$status" -ne 0 ]
  [[ "$output" == *"build"* ]]
}

@test "fails on an unknown theme" {
  run "$SCRIPT" client-nope --skip-lint
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `npx bats tests/scripts/package-theme.bats`
Expected: FAIL — `scripts/package-theme.sh` does not exist.

- [ ] **Step 3: Write `scripts/package-theme.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEMES_DIR="${THEMES_DIR:-$ROOT/themes}"
DIST_DIR="${DIST_DIR:-$ROOT/dist}"

[ "$#" -ge 1 ] || { echo "Usage: package-theme.sh <theme-slug> [--skip-lint]" >&2; exit 2; }

THEME="$1"
SKIP_LINT=0
[ "${2:-}" = "--skip-lint" ] && SKIP_LINT=1

THEME_PATH="$THEMES_DIR/$THEME"
[ -d "$THEME_PATH" ] || { echo "Error: theme '$THEME' not found at $THEME_PATH" >&2; exit 1; }

VERSION="$(grep -m1 '^Version:' "$THEME_PATH/style.css" | sed -e 's/^Version:[[:space:]]*//' | tr -d '\r')"
[ -n "$VERSION" ] || { echo "Error: no 'Version:' header in $THEME/style.css" >&2; exit 1; }

[ -f "$THEME_PATH/build/index.asset.php" ] || {
  echo "Error: $THEME has no build output — run: npm run build -- $THEME" >&2
  exit 1
}

if [ "$SKIP_LINT" -eq 0 ]; then
  ( cd "$THEME_PATH" && "$ROOT/node_modules/.bin/wp-scripts" lint-js src ) \
    || { echo "Error: JS lint failed — not packaging." >&2; exit 1; }
  ( cd "$THEME_PATH" && "$ROOT/node_modules/.bin/wp-scripts" lint-style "src/**/*.scss" ) \
    || { echo "Error: style lint failed — not packaging." >&2; exit 1; }
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

cp -R "$THEME_PATH" "$STAGE/$THEME"

# Development-only artefacts never ship (FR7, NFR5).
rm -rf "$STAGE/$THEME/src" "$STAGE/$THEME/node_modules" "$STAGE/$THEME/tests"
rm -f  "$STAGE/$THEME/webpack.config.js" "$STAGE/$THEME/.shared-manifest.json" \
       "$STAGE/$THEME/package.json" "$STAGE/$THEME/package-lock.json"
find "$STAGE/$THEME" \( -name '.gitkeep' -o -name '.DS_Store' -o -name '*.map' \) -delete

mkdir -p "$DIST_DIR"
OUT="$DIST_DIR/$THEME-$VERSION.zip"
rm -f "$OUT"
( cd "$STAGE" && zip -rq "$OUT" "$THEME" )

echo "Packaged $OUT"
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `chmod +x scripts/package-theme.sh && npx bats tests/scripts/package-theme.bats`
Expected: PASS — 6 tests, 0 failures.

- [ ] **Step 5: Add the repo-wide lint and format scripts**

The spec's command surface includes `npm run lint` and `npm run format` across every theme. Add to `package.json`:

```json
"lint": "wp-scripts lint-js themes/*/src && wp-scripts lint-style \"themes/*/src/**/*.scss\"",
"format": "wp-scripts format themes/*/src"
```

Run: `npm run lint`
Expected: passes (or reports real problems in a theme's `src/`). With no themes present it is a no-op.

- [ ] **Step 6: Add the npm script and commit**

Confirm `"package": "./scripts/package-theme.sh"` is in `package.json`, then:

```bash
git add scripts/package-theme.sh package.json tests/scripts/package-theme.bats
git commit -m "Package themes for delivery with dev files excluded"
```

---

### Task 9: The delivery gate — `npm run verify`

**Files:**
- Create: `scripts/verify.sh`, `scripts/lib/validate-theme-json.mjs`, `.pa11yci.json`
- Modify: `package.json`
- Test: `tests/scripts/validate-theme-json.bats`, `tests/integration/verify.bats`

**Interfaces:**
- Consumes: every script from Tasks 3–8, and the running stack from Task 5.
- Produces: `scripts/verify.sh <theme-slug>` — runs the seven gates from spec §9 in order, stopping at the first failure, and exits `0` only if all pass.
- `node scripts/lib/validate-theme-json.mjs <path>` exits `0` if the file is a structurally valid v3 `theme.json`, else prints the specific problem and exits `1`.

- [ ] **Step 1: Write the failing test for theme.json validation**

Create `tests/scripts/validate-theme-json.bats`:

```bash
#!/usr/bin/env bats

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  VALIDATE="$ROOT/scripts/lib/validate-theme-json.mjs"
  WORK="$BATS_TEST_TMPDIR"
}

@test "accepts a scaffolded theme.json" {
  export THEMES_DIR="$WORK/themes"
  "$ROOT/scripts/new-client.sh" piano "Piano Store" >/dev/null
  run node "$VALIDATE" "$WORK/themes/client-piano/theme.json"
  [ "$status" -eq 0 ]
}

@test "rejects a wrong schema version" {
  echo '{ "version": 2, "settings": {} }' > "$WORK/bad.json"
  run node "$VALIDATE" "$WORK/bad.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"version"* ]]
}

@test "rejects malformed JSON" {
  echo '{ nope' > "$WORK/bad.json"
  run node "$VALIDATE" "$WORK/bad.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"JSON"* ]]
}

@test "rejects a palette entry missing a colour" {
  echo '{ "version": 3, "settings": { "color": { "palette": [ { "slug": "base", "name": "Base" } ] } } }' > "$WORK/bad.json"
  run node "$VALIDATE" "$WORK/bad.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"base"* ]]
}

@test "rejects duplicate palette slugs" {
  echo '{ "version": 3, "settings": { "color": { "palette": [ { "slug": "base", "name": "A", "color": "#fff" }, { "slug": "base", "name": "B", "color": "#000" } ] } } }' > "$WORK/bad.json"
  run node "$VALIDATE" "$WORK/bad.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"duplicate"* ]]
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `npx bats tests/scripts/validate-theme-json.bats`
Expected: FAIL — validator does not exist.

- [ ] **Step 3: Write `scripts/lib/validate-theme-json.mjs`**

```javascript
#!/usr/bin/env node
import { readFileSync } from 'node:fs';

const [ path ] = process.argv.slice( 2 );
const fail = ( message ) => {
	console.error( `Invalid theme.json: ${ message }` );
	process.exit( 1 );
};

if ( ! path ) {
	console.error( 'Usage: validate-theme-json.mjs <path>' );
	process.exit( 2 );
}

let theme;
try {
	theme = JSON.parse( readFileSync( path, 'utf8' ) );
} catch ( error ) {
	fail( `not valid JSON — ${ error.message }` );
}

if ( theme.version !== 3 ) {
	fail( `version must be 3, found ${ JSON.stringify( theme.version ) }` );
}

for ( const key of [ 'settings', 'styles' ] ) {
	if ( key in theme && ( theme[ key ] === null || typeof theme[ key ] !== 'object' || Array.isArray( theme[ key ] ) ) ) {
		fail( `"${ key }" must be an object` );
	}
}

const palette = theme.settings?.color?.palette;
if ( palette !== undefined ) {
	if ( ! Array.isArray( palette ) ) {
		fail( 'settings.color.palette must be an array' );
	}
	const seen = new Set();
	for ( const entry of palette ) {
		for ( const field of [ 'slug', 'name', 'color' ] ) {
			if ( ! entry?.[ field ] ) {
				fail( `palette entry "${ entry?.slug ?? '(no slug)' }" is missing "${ field }"` );
			}
		}
		if ( seen.has( entry.slug ) ) {
			fail( `duplicate palette slug "${ entry.slug }"` );
		}
		seen.add( entry.slug );
	}
}

const fontSizes = theme.settings?.typography?.fontSizes;
if ( fontSizes !== undefined && ! Array.isArray( fontSizes ) ) {
	fail( 'settings.typography.fontSizes must be an array' );
}

process.exit( 0 );
```

- [ ] **Step 4: Run it to verify it passes**

Run: `npx bats tests/scripts/validate-theme-json.bats`
Expected: PASS — 5 tests.

- [ ] **Step 5: Create `.pa11yci.json`**

```json
{
	"defaults": {
		"standard": "WCAG2AA",
		"timeout": 30000,
		"chromeLaunchConfig": { "args": [ "--no-sandbox" ] }
	},
	"urls": [
		"http://localhost:8080/",
		"http://localhost:8080/shop/"
	]
}
```

- [ ] **Step 6: Write `scripts/verify.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEMES_DIR="${THEMES_DIR:-$ROOT/themes}"
DIST_DIR="${DIST_DIR:-$ROOT/dist}"
cd "$ROOT"

[ -f .env ] && { set -a; . ./.env; set +a; }
WP_URL="${WP_URL:-http://localhost:8080}"

[ "$#" -ge 1 ] || { echo "Usage: verify.sh <theme-slug>" >&2; exit 2; }
THEME="$1"
THEME_PATH="$THEMES_DIR/$THEME"
[ -d "$THEME_PATH" ] || { echo "Error: theme '$THEME' not found at $THEME_PATH" >&2; exit 1; }

wp() { docker compose run --rm cli "$@" --allow-root; }
step() { echo; echo "==> $1"; }

step "1/7 Lint"
( cd "$THEME_PATH" && "$ROOT/node_modules/.bin/wp-scripts" lint-js src )
( cd "$THEME_PATH" && "$ROOT/node_modules/.bin/wp-scripts" lint-style "src/**/*.scss" )
while IFS= read -r -d '' php_file; do
  docker compose run --rm --entrypoint php cli -l "/var/www/html/wp-content/client-themes/${php_file#"$THEMES_DIR/"}" >/dev/null
done < <(find "$THEME_PATH" -name '*.php' -not -path '*/node_modules/*' -print0)

step "2/7 Validate theme.json"
node "$ROOT/scripts/lib/validate-theme-json.mjs" "$THEME_PATH/theme.json"

step "3/7 Theme Check"
wp theme activate "$THEME"
CHECK_OUTPUT="$(wp theme-check "$THEME" 2>&1 || true)"
echo "$CHECK_OUTPUT"
if echo "$CHECK_OUTPUT" | grep -qi 'REQUIRED'; then
  echo "Error: Theme Check reported REQUIRED-level problems." >&2
  exit 1
fi

step "4/7 Build and package"
"$ROOT/scripts/build-theme.sh" "$THEME"
"$ROOT/scripts/package-theme.sh" "$THEME" --skip-lint
VERSION="$(grep -m1 '^Version:' "$THEME_PATH/style.css" | sed -e 's/^Version:[[:space:]]*//' | tr -d '\r')"
ZIP="$DIST_DIR/$THEME-$VERSION.zip"
for forbidden in "$THEME/src/" "node_modules" "webpack.config.js" ".shared-manifest.json"; do
  if unzip -l "$ZIP" | grep -q -- "$forbidden"; then
    echo "Error: packaged zip contains development file matching '$forbidden'" >&2
    exit 1
  fi
done

step "5/7 Install the packaged zip into WordPress"
wp theme install "/dist/$THEME-$VERSION.zip" --force --activate
wp theme is-active "$THEME"

step "6/7 Route smoke test"
POST_URL="$(wp post list --post_type=post --posts_per_page=1 --field=url | head -n1 || true)"
PAGE_URL="$(wp post list --post_type=page --posts_per_page=1 --field=url | head -n1 || true)"
wp eval 'file_put_contents( WP_CONTENT_DIR . "/debug.log", "" );' >/dev/null 2>&1 || true

ROUTES=( "$WP_URL/" "$WP_URL/?s=test" "$WP_URL/no-such-page-404/" "$WP_URL/shop/" "$WP_URL/cart/" "$WP_URL/checkout/" )
[ -n "$POST_URL" ] && ROUTES+=( "$POST_URL" )
[ -n "$PAGE_URL" ] && ROUTES+=( "$PAGE_URL" )

for url in "${ROUTES[@]}"; do
  code="$(curl -s -o /dev/null -w '%{http_code}' "$url")"
  expected=200
  [[ "$url" == *"no-such-page-404"* ]] && expected=404
  if [ "$code" != "$expected" ]; then
    echo "Error: $url returned $code (expected $expected)" >&2
    exit 1
  fi
  echo "  ok  $code  $url"
done

if wp eval 'echo file_get_contents( WP_CONTENT_DIR . "/debug.log" );' 2>/dev/null | grep -Eq 'PHP (Warning|Notice|Fatal|Deprecated)'; then
  echo "Error: PHP notices were logged while rendering — see wp-content/debug.log" >&2
  wp eval 'echo file_get_contents( WP_CONTENT_DIR . "/debug.log" );'
  exit 1
fi

step "7/7 Accessibility"
"$ROOT/node_modules/.bin/pa11y-ci" --config "$ROOT/.pa11yci.json"

echo
echo "PASS — $THEME $VERSION is ready to deliver: $ZIP"
```

- [ ] **Step 7: Add pa11y-ci, the npm script, and make it executable**

```bash
npm install --save-dev pa11y-ci@^3.1.0
chmod +x scripts/verify.sh
```

Add `"verify": "./scripts/verify.sh"` to `package.json` scripts.

- [ ] **Step 8: Add the standalone Theme Check script**

The spec's command surface includes `npm run check -- <theme>` as a fast standalone gate, separate from the full `verify`. Create `scripts/theme-check.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

[ "$#" -ge 1 ] || { echo "Usage: theme-check.sh <theme-slug>" >&2; exit 2; }
THEME="$1"

docker compose run --rm cli theme activate "$THEME" --allow-root
OUTPUT="$(docker compose run --rm cli theme-check "$THEME" --allow-root 2>&1 || true)"
echo "$OUTPUT"

if echo "$OUTPUT" | grep -qi 'REQUIRED'; then
  echo "Error: Theme Check reported REQUIRED-level problems in $THEME." >&2
  exit 1
fi

echo "Theme Check passed for $THEME"
```

Add `"check": "./scripts/theme-check.sh"` to `package.json`, then `chmod +x scripts/theme-check.sh`.

Run: `npm run check -- client-smoke`
Expected: prints Theme Check output and exits 0.

- [ ] **Step 9: Write the integration test**

Create `tests/integration/verify.bats`:

```bash
#!/usr/bin/env bats

setup_file() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  cd "$ROOT"
  ./scripts/new-client.sh smoke "Smoke Test Theme" >/dev/null 2>&1 || true
}

teardown_file() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  rm -rf "$ROOT/themes/client-smoke" "$ROOT/dist/client-smoke-1.0.0.zip"
  docker compose run --rm cli theme delete client-smoke --allow-root >/dev/null 2>&1 || true
}

@test "a freshly scaffolded theme passes the full delivery gate" {
  run "$ROOT/scripts/verify.sh" client-smoke
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ready to deliver"* ]]
}
```

- [ ] **Step 10: Run the gate end to end**

Run: `npm run env:up && npm run env:init && npx bats tests/integration/verify.bats`
Expected: PASS. This is the moment the foundation is proven: a theme created by script alone survives lint, Theme Check, packaging, reinstallation from its zip, route rendering, and an accessibility scan.

Known first-run friction: pa11y-ci downloads Chromium on install; if `/shop/` 404s, WooCommerce has not created its pages — run `npm run env:cli -- wc --version` and re-run `npm run env:init`.

- [ ] **Step 11: Commit**

```bash
git add scripts/verify.sh scripts/theme-check.sh scripts/lib/validate-theme-json.mjs .pa11yci.json package.json package-lock.json tests/scripts/validate-theme-json.bats tests/integration/verify.bats
git commit -m "Add the delivery gate: lint, theme check, package, install, smoke, a11y"
```

---

### Task 10: Document the foundation

**Files:**
- Modify: `CLAUDE.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: the finished command surface from Tasks 1–9.
- Produces: no code. `CLAUDE.md` stops describing the repo as pre-implementation and starts describing what exists.

- [ ] **Step 1: Rewrite the "Current state" section of `CLAUDE.md`**

Replace the whole "Current state" section with:

```markdown
## Commands

```bash
npm install                                          # once
cp .env.example .env && npm run env:up && npm run env:init   # local WordPress + WooCommerce

npm run new-client -- piano "Piano Store & Services" # scaffold themes/client-piano
npm run build -- client-piano                        # compile assets
npm run watch -- client-piano --watch                # rebuild on change
npm run sync-shared -- client-piano [pattern...]     # opt-in shared pattern pull
npm run package -- client-piano                      # dist/client-piano-<version>.zip
npm run verify -- client-piano                       # the delivery gate (see below)

npm test                                             # bats script tests, no Docker needed
npm run test:integration                             # bats tests against the running stack
npx bats tests/scripts/new-client.bats               # a single test file
npm run env:cli -- theme list                        # any wp-cli command
```

`npm run verify -- <theme>` is the gate that decides whether a theme is deliverable:
lint → `theme.json` validation → Theme Check → build and package → **install that zip into
WordPress and activate it** → route smoke test with a PHP-notice check → pa11y accessibility
scan. A theme that passes has been proven as a packaged artifact, not just as a working tree.

The site runs at http://localhost:8080 (admin/admin). Themes are exposed to WordPress via
`register_theme_directory()` from `docker/mu-plugins/`, mounted at `wp-content/client-themes`
— *not* over `wp-content/themes` — so bundled themes still work and wp-cli installs never
land in the repo.
```

- [ ] **Step 2: Add a shared-library note to `CLAUDE.md`**

Under the architecture section, after the standalone-themes paragraph:

```markdown
**Adding to `shared/`.** A pattern earns its place in `shared/patterns/` only when a *second*
theme needs it — not before. `scripts/sync-shared.sh` copies it into a theme, namespaces its
`Slug:` header, and records source, revision, and checksum in that theme's
`.shared-manifest.json`. A theme that has locally edited a synced pattern will refuse the next
sync until `--force`, so deliberate client divergence is never silently overwritten.
```

- [ ] **Step 3: Replace `README.md`**

```markdown
# Client Themes

A monorepo producing one standalone WordPress block theme per client website.
Each theme is delivered as a self-contained `.zip` with no runtime dependency on
this repository.

See [docs/PRD.md](docs/PRD.md) for the product definition and [CLAUDE.md](CLAUDE.md)
for the command surface and architecture.

## Quick start

```bash
npm install
cp .env.example .env
npm run env:up && npm run env:init     # WordPress + WooCommerce at http://localhost:8080
npm run new-client -- acme "Acme Ltd"  # scaffold themes/client-acme
npm run verify -- client-acme          # prove it is deliverable
```

## Licensing

This repository is Apache-2.0. **Delivered themes are GPL-2.0-or-later**, declared in each
theme's `style.css`, as WordPress themes must be.
```

- [ ] **Step 4: Verify the documented commands actually work**

Run each command in the CLAUDE.md block against a throwaway theme and confirm it behaves as documented. Fix the docs, not the memory of them.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md README.md
git commit -m "Document the foundation's command surface and architecture"
```

---

## Done when

- `npm test` passes with no Docker running.
- `npm run env:up && npm run env:init` yields a WordPress site at :8080 with WooCommerce and Theme Check active.
- `npm run new-client -- x "X"` produces a theme that activates with zero manual fixup.
- `npm run verify -- client-x` passes end to end on that scaffolded theme.
- `CLAUDE.md` describes what exists rather than what is proposed.

## Next plans

1. **`client-piano`** — the piano store's `theme.json` identity, templates, WooCommerce templates, service pages, and patterns.
2. **`client-jam`** — the same for the jam producer, extracting into `shared/patterns/` whatever genuinely repeats between the two.

Neither can be written usefully until this plan's interfaces exist.
