# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
npm install                                          # once

npm run env:use -- piano                             # target that client's stack (see below)
npm run env:up && npm run env:init                   # WordPress + WooCommerce for it
npm run seed -- piano                                # demo products, pages, posts

npm run new-client -- piano "Piano Store & Services" # scaffold themes/client-piano
npm run build -- client-piano                        # compile assets
npm run watch -- client-piano --watch                # rebuild on change
npm run sync-shared -- client-piano [pattern...]     # opt-in shared pattern pull
npm run package -- client-piano                      # dist/client-piano-<version>.zip
npm run check -- client-piano                        # standalone Theme Check gate
npm run verify -- client-piano                       # the delivery gate (see below)

npm test                                             # bats script tests, no Docker needed
npm run test:integration                             # bats tests against the running stack
npx bats tests/scripts/new-client.bats               # a single test file
npm run env:cli -- theme list                        # any wp-cli command
node scripts/dev/shot.mjs <url> out.png [width] full # screenshot a page to look at it
```

`npm run lint` / `npm run format` run `wp-scripts` over every theme's `src/` (honouring
`THEMES_DIR`) via `scripts/lint-themes.sh`, and exit 0 with a message when no themes exist —
safe on a fresh clone.

## One isolated stack per client

Each client is its own Docker Compose **project**, and Compose namespaces volumes by project —
so `client-piano` and `client-jam` have completely separate MySQL and WordPress volumes. Two
databases, two shops, no bleed. They run at the same time on different ports.

```
npm run env:use -- piano    # piano :8080
npm run env:use -- jam      # jam   :8081
```

`env-use.sh` works by rewriting `.env`, which Compose reads automatically. That is deliberate:
every other script (`verify.sh`, `theme-check.sh`, the integration tests) keeps calling
`docker compose` unchanged and simply talks to whichever stack `.env` selects, instead of
threading a client argument through a dozen scripts. **A stale `.env` therefore points your
commands at the wrong client** — check it first when something targets a site you did not expect.

Themes reach WordPress via `register_theme_directory()` from `docker/mu-plugins/`, mounted at
`wp-content/client-themes` — *not* over `wp-content/themes`. Bundled themes keep working, and
wp-cli installs (which land in the default `wp-content/themes`) never touch the repo's
bind-mounted `themes/`. Note the consequence: WordPress resolves a duplicate slug to the
**later-registered** root, so an installed copy shadows the bind mount. `verify.sh` removes any
installed copy before running and on exit; without that, Theme Check silently inspects a stale
build and live editing stops working.

`env-init.sh` installs WooCommerce and Theme Check, falling back to downloading on the host when
the wordpress.org API fails inside the container (`cURL error 35` is frequent), and **fails
closed** if either ends up inactive — a missing plugin silently degrades every later gate.

## What this repo is

A monorepo that produces **one self-contained WordPress block theme per client website**, for a
website-resale business. Each theme is designed, built, packaged as a `.zip`, and delivered to
the client's own host. Delivery ends at the theme package — no hosting/DNS/infra management.

Two client themes exist: `client-piano` (a piano dealer with a workshop) and `client-jam` (a
preserves producer selling retail and wholesale). Both sell through WooCommerce.

## Architecture: the decisions that matter

**Each client theme is fully standalone.** There is no shared parent theme and no runtime
dependency between themes. Shared patterns and design tokens live in `shared/` and are composed
into a client theme at *scaffold/sync time only*. This is deliberate and load-bearing:

- One theme = one installable `.zip` with no external dependency.
- A change made for one client can never regress another.
- Propagating a shared-library improvement into an existing client theme must be an explicit,
  opt-in action — never automatic, never at runtime.

Parent/child themes and fully-independent copies were both considered and rejected (PRD §6.1).
Do not reintroduce a parent theme or any cross-theme runtime import.

**Adding to `shared/`.** A pattern earns its place in `shared/patterns/` only when a *second*
theme needs it — not before. `scripts/sync-shared.sh` copies it into a theme, namespaces its
`Slug:` header, and records source, revision, and checksum in that theme's
`.shared-manifest.json`. A theme that has locally edited a synced pattern, or that has a pattern
file with no recorded provenance, refuses the next sync until `--force` — deliberate client
divergence is never silently overwritten. `shared/patterns/` being empty is a valid state.

**Block themes only.** Full Site Editing, `theme.json`, native core blocks, template parts, block
patterns, Query Loop for post listings. Classic PHP-template themes are out of scope, as are
proprietary page builders.

**`theme.json` is the design system.** A client's entire visual identity — palette, typography
scale, spacing scale, layout widths — lives in `theme.json` settings/styles, so the client can
adjust it in the Site Editor. Reach for `theme.json` `styles` or a style variation before writing
custom CSS. Fonts are self-hosted OFL faces in `themes/<client>/assets/fonts/`, declared as
`fontFace` `src: file:./assets/fonts/…` — no CDN call, and licensing stays clean for a client.

**No Custom HTML blocks.** Templates must be native core-block markup so the Site Editor stays
fully functional (PRD R1). `verify.sh` fails on `wp:html` anywhere in a theme's `templates/`,
`parts/` or `patterns/`.

**Themes own their WooCommerce markup.** `base/theme-template/` ships `archive-product`,
`taxonomy-product_cat`, `single-product`, `page-cart`, `page-checkout` and `order-confirmation`.
Without them WordPress falls back to WooCommerce's own block templates, which inject a
catalog-sorting `<select>` in a form with no submit button — a WCAG 2.1 AA failure that makes a
scaffolded theme unable to pass its own gate. Do not delete these from the base template.

## The delivery gate

`npm run verify -- <theme>` decides whether a theme is deliverable:

1. lint (JS, styles, `php -l`) and a `wp:html` check
2. `theme.json` structural validation
3. Theme Check — zero REQUIRED problems, severity read from `--format=json`, not grepped text
4. build and package, then assert the zip carries no dev files
5. **install that zip into WordPress and activate it** — the artifact is what gets tested
6. route smoke test (including `/shop/`, `/cart/`, `/checkout/`) with a PHP-notice scan
7. pa11y-ci against WCAG2AA, via `.pa11yci.js` whose host derives from `WP_URL`

**The gate must fail closed.** Every step checks the underlying command's own exit status rather
than trusting silent output, and step 7 asserts the scanned page is actually served by the theme
under test — with per-client ports, a hardcoded host would happily scan another client's site and
pass. `tests/integration/verify.bats` proves the gate exits non-zero on a corrupt `theme.json`, a
logged PHP notice, and a `wp:html` block. If you add a step, add its failure test too.

## Layout

```
docker-compose.yml     # per-client stack; images and mounts parameterised via .env
docker/mu-plugins/     # registers themes/ as a second theme directory
base/theme-template/   # tokenised starter, including the WooCommerce template set
shared/tokens/         # theme.json presets merged in at scaffold time
shared/patterns/       # only what two themes genuinely share
shared/build/          # shared @wordpress/scripts config
themes/<client>/       # standalone block theme, delivered as-is
scripts/               # new-client, build, sync-shared, package, verify, theme-check, env-*
scripts/lib/           # merge-tokens, manifest, theme-json validation, theme-check report
scripts/seed/          # demo content (site data — never ships in a zip)
scripts/dev/           # screenshot helper
tests/scripts/         # unit tests, no Docker
tests/integration/     # tests against a running stack
```

## Demo content

`npm run seed -- <client>` populates the local site with products, prices, pages, posts and a
navigation menu. This is **site data, not theme data** — none of it ships in a delivered zip.
Seeding *adds*; run `scripts/seed/reset.php` via `wp eval-file` first for a clean shop.

Images come from Openverse filtered to **CC0 and public-domain marks only**, so a client site
carries no attribution obligation. Where no freely licensed photograph exists, the product ships
without one rather than taking on a credit requirement. Openly licensed photography of modern
products is thin — real client work replaces all of it with the client's own.

## Constraints on delivered themes

- The `.zip` contains only runtime files — no `src/`, `node_modules/`, `webpack.config.js`,
  `package.json` or `.shared-manifest.json` — and must install on a standard host and pass
  Theme Check.
- Each theme carries **its own version**; any one theme is re-deliverable without touching others.
- Support current and current-minus-one WordPress majors and their PHP versions. Both
  `WP_IMAGE_TAG` and `PHP_TAG` must move together, or the gate validates a different PHP version
  from the one the site serves.
- Delivered code is GPLv2-or-later, and bundled fonts and images must be cleared for commercial
  client use. The repo root's `LICENSE` is **Apache-2.0** and does not apply to shipped themes:
  `base/theme-template/style.css` declares GPL-2.0-or-later, so every scaffolded theme carries it.
- Escape properly in any dynamic PHP; keep the front end server-rendered and JS-light.

## Gotchas worth knowing before you spend an hour on them

- The user's global `~/.gitignore_global` ignores `.gitignore` itself, plus `dist`, `build` and
  `node_modules`. Files you expect to commit can vanish silently — check `git show --stat HEAD`
  and use `git add -f` where needed.
- `base/theme-template/package.json` pins a literal `browserslist` array rather than
  `extends @wordpress/browserslist-config`; the reason is documented at the top of
  `shared/build/webpack.config.js`. Do not "tidy" it without reading that note.
- Scaffolding refuses a client name containing `*/` or control characters — they would break the
  `style.css` comment header or crash the substitution mid-copy.
