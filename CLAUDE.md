# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
npm install                                          # once
cp .env.example .env && npm run env:up && npm run env:init   # local WordPress + WooCommerce

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
docker compose run --rm cli theme list               # any wp-cli command (cli's entrypoint is `wp`)
```

`npm run lint` / `npm run format` run `wp-scripts lint-js`/`lint-style`/`format` over every
theme under `themes/` (honouring a `THEMES_DIR` override) and exit 0 with nothing to do when no
themes exist yet — safe to run on a fresh clone.

`npm run verify -- <theme>` is the gate that decides whether a theme is deliverable:
lint → `theme.json` validation → Theme Check → build and package → **install that zip into
WordPress and activate it** → route smoke test with a PHP-notice check → pa11y accessibility
scan. A theme that passes has been proven as a packaged artifact, not just as a working tree.
Both the Theme Check step and the PHP-notice scan check the underlying command's exit status,
not just its output, so the gate fails closed rather than reporting a false pass.

The site runs at http://localhost:8080 (admin/admin). Themes are exposed to WordPress via
`register_theme_directory()` from `docker/mu-plugins/`, mounted at `wp-content/client-themes`
— *not* over `wp-content/themes` — so bundled themes still work and wp-cli installs (which land
in the default `wp-content/themes`) never land in the repo's bind-mounted `themes/`.

> **Known issue:** the `env:cli` npm script (`docker compose run --rm cli wp`) passes a
> redundant literal `wp` on top of the `cli` service's own `entrypoint: wp` in
> `docker-compose.yml`, so `npm run env:cli -- <args>` currently fails with "'wp' is not a
> registered wp command". Call `docker compose run --rm cli <args>` directly until that's fixed.

## What this repo is

A monorepo that produces **one self-contained WordPress block theme per client website**, for a website-resale business. Each theme is designed, built, packaged as a `.zip`, and delivered to the client's own host. Delivery ends at the theme package — no hosting/DNS/infra management.

The intended pipeline: design in Claude Design → hand off to Claude Code → Claude Code writes block-theme files directly into `themes/<client>/` → the theme runs live in a local Dockerized WordPress → package and deliver.

## Architecture: the decisions that matter

**Each client theme is fully standalone.** There is no shared parent theme and no runtime dependency between themes. Shared patterns and design tokens live in `shared/` and are composed into a client theme at *scaffold/build time only*. This is deliberate and load-bearing:

- One theme = one installable `.zip` with no external dependency.
- A change made for one client can never regress another.
- Propagating a shared-library improvement into an existing client theme must be an explicit, opt-in action (re-scaffold or sync) — never automatic, never at runtime.

Parent/child themes and fully-independent copies were both considered and rejected (PRD §6.1). Do not reintroduce a parent theme or any cross-theme runtime import.

**Adding to `shared/`.** A pattern earns its place in `shared/patterns/` only when a *second*
theme needs it — not before. `scripts/sync-shared.sh` copies it into a theme, namespaces its
`Slug:` header, and records source, revision, and checksum in that theme's
`.shared-manifest.json`. A theme that has locally edited a synced pattern will refuse the next
sync until `--force`, so deliberate client divergence is never silently overwritten.

**Block themes only.** Full Site Editing, `theme.json`, native core blocks, template parts, block patterns, Query Loop for post listings. Classic PHP-template themes are out of scope, as are proprietary page builders.

**`theme.json` is the design system.** A client's entire visual identity — color palette, typography scale, spacing scale, layout widths — is expressed in `theme.json` settings/styles, so the client can adjust it in the Site Editor. Reach for `theme.json` `styles` or a style variation before writing custom CSS.

**Avoid Custom HTML blocks.** Templates must be native core-block markup so the Site Editor stays fully functional. Free-form design HTML does not map 1:1 onto core blocks; constrain the design to what core blocks + `theme.json` can express rather than escaping into raw HTML (PRD R1).

### Target layout (PRD §6.2)

```
docker-compose.yml     # local WordPress + MySQL (or .wp-env.json)
package.json           # workspace scripts, shared dev deps
base/theme-template/   # internal starter used to scaffold client themes
shared/patterns/       # reusable block patterns (hero, CTA, pricing, ...)
shared/tokens/         # theme.json presets: color/typography/spacing scales
shared/build/          # shared @wordpress/scripts config
themes/<client>/       # standalone block theme, delivered as-is
scripts/new-client.sh  # scaffold from base/ + shared/
scripts/package-theme.sh # build + zip for delivery
```

A scaffolded theme must be valid and activatable with zero manual fixup: `style.css` header, `theme.json`, `templates/`, `parts/`, `patterns/`.

## Tooling

- **Scaffolding:** `base/theme-template/` is the internal starter; `scripts/new-client.sh` copies it into `themes/client-<slug>/`, substitutes `{{CLIENT_SLUG}}`/`{{CLIENT_NAME}}`/`{{CLIENT_DESCRIPTION}}`/`{{VERSION}}` tokens (skipping the binary `screenshot.png`), and merges `shared/tokens/` into the new `theme.json`. The Create Block Theme plugin remains the dev-only tool for Site-Editor-to-file round-trips; it is not part of this pipeline.
- **Build:** `@wordpress/scripts` (webpack), config shared from `shared/build/webpack.config.js`. `scripts/build-theme.sh` (wrapped by `npm run build` / `npm run watch`) runs it per theme.
- **Local env:** Docker Compose (`docker-compose.yml`) — WordPress + MySQL, with `themes/` bind-mounted read/write into `wp-content/client-themes` and switching the active theme a plain `wp theme activate`.
- **Quality gates:** Theme Check (`npm run check`, also run inside `npm run verify`), `wp-scripts lint-js`/`lint-style`/`format` (`npm run lint` / `npm run format`), and pa11y-ci against WCAG2AA (`.pa11yci.json`, the last step of `npm run verify`).

## Constraints on delivered themes

- Packaged `.zip` contains only runtime files — no dev tooling, no repo scaffolding — and must install on a standard WordPress host and pass Theme Check.
- Each theme carries **its own version**; any one theme must be re-openable and re-deliverable without touching others.
- Support current and current-minus-one WordPress major versions and their supported PHP versions.
- Delivered theme code must be GPLv2-or-later compatible, and bundled fonts/images cleared for commercial client use. The repo root's own `LICENSE` is **Apache-2.0** and does not apply to shipped themes: `base/theme-template/style.css` declares `License: GNU General Public License v2 or later`, so every scaffolded theme carries its own GPL-2.0-or-later header, as WordPress themes must.
- Escape properly in any dynamic PHP; keep the front end server-rendered and JS-light.
