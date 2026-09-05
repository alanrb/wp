# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current state

This repository is **pre-implementation**. It contains only `docs/PRD.md`, `README.md`, and `LICENSE` — no themes, no build tooling, no Docker config, no scripts. [docs/PRD.md](docs/PRD.md) is the authoritative spec; read it before building anything here. Everything below describes the target design from that PRD, not code that exists.

When asked to "build X", first check whether the foundation it depends on (repo structure, base template, local WP stack, scaffold script — PRD Phase 0) exists yet.

## What this repo is

A monorepo that produces **one self-contained WordPress block theme per client website**, for a website-resale business. Each theme is designed, built, packaged as a `.zip`, and delivered to the client's own host. Delivery ends at the theme package — no hosting/DNS/infra management.

The intended pipeline: design in Claude Design → hand off to Claude Code → Claude Code writes block-theme files directly into `themes/<client>/` → the theme runs live in a local Dockerized WordPress → package and deliver.

## Architecture: the decisions that matter

**Each client theme is fully standalone.** There is no shared parent theme and no runtime dependency between themes. Shared patterns and design tokens live in `shared/` and are composed into a client theme at *scaffold/build time only*. This is deliberate and load-bearing:

- One theme = one installable `.zip` with no external dependency.
- A change made for one client can never regress another.
- Propagating a shared-library improvement into an existing client theme must be an explicit, opt-in action (re-scaffold or sync) — never automatic, never at runtime.

Parent/child themes and fully-independent copies were both considered and rejected (PRD §6.1). Do not reintroduce a parent theme or any cross-theme runtime import.

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

## Intended tooling

None of this is wired up yet; these are the tools the PRD commits to, so prefer them over alternatives when implementing:

- **Scaffolding:** `npx @wordpress/create-block@latest <name> --variant theme` as the basis for `base/theme-template/`. The Create Block Theme plugin is the dev-only tool for Site-Editor-to-file round-trips.
- **Build:** `@wordpress/scripts` (webpack), config shared from `shared/build/`. Output must be deterministic and enqueued properly — no hardcoded asset tags.
- **Local env:** Docker Compose (WordPress + MySQL) with `themes/` bind-mounted, or `@wordpress/env` via `.wp-env.json`. Host edits (including Claude Code's) must appear live with no rebuild, and switching the active client theme must be friction-free.
- **Quality gates:** Theme Check, `wp-scripts lint` / `wp-scripts format`, accessibility checks (WCAG 2.1 AA basics).

## Constraints on delivered themes

- Packaged `.zip` contains only runtime files — no dev tooling, no repo scaffolding — and must install on a standard WordPress host and pass Theme Check.
- Each theme carries **its own version**; any one theme must be re-openable and re-deliverable without touching others.
- Support current and current-minus-one WordPress major versions and their supported PHP versions.
- Delivered theme code must be GPLv2-or-later compatible, and bundled fonts/images cleared for commercial client use. Note the repo root ships an **Apache-2.0** `LICENSE`, which does not match that requirement — resolve the licensing story before the first delivery rather than assuming the root license applies to shipped themes.
- Escape properly in any dynamic PHP; keep the front end server-rendered and JS-light.
