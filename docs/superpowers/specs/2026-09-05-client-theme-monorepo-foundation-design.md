# Design — Client Theme Monorepo Foundation (Phase 0)

| Field | Value |
|---|---|
| **Date** | 2026-09-05 |
| **Status** | Approved, ready for planning |
| **Scope** | PRD Phase 0 foundation + two client themes built in parallel |
| **Source** | [docs/PRD.md](../../PRD.md) |

## 1. Objective

Stand up the monorepo described in the PRD and take **two real client themes** through it end to end: a piano store with services, and a fruit jam production facility. Both sell online via WooCommerce. Success is two standalone, Theme-Check-clean `.zip` files that install and run on a stock WordPress host, produced by repeatable scripts rather than by hand.

## 2. Decisions

These were settled during brainstorming and are not open for re-litigation during implementation.

| # | Decision | Rationale |
|---|---|---|
| D1 | **Docker Compose**, not `@wordpress/env`, for the local stack | Full control over services and the WP/PHP version matrix; matches PRD §6.2 |
| D2 | `base/theme-template/` is **checked into the repo** and copied by the scaffold script | Deterministic and offline; the composition step is ours, which is where D4 hooks in |
| D3 | Build **both** client themes in parallel in this pass | Two real consumers make the shared library evidence-based rather than speculative |
| D4 | Shared code is **extracted at the moment of the second consumer**, and *copied* into themes by `sync-shared.sh` with a provenance manifest | Answers PRD R2. Preserves §6.1 isolation: no runtime coupling, propagation is opt-in |
| D5 | **WooCommerce** support in both themes, guarded by `class_exists` | Both clients sell; the guard keeps the `.zip` standalone per §6.1 |
| D6 | Fonts are **self-hosted OFL** faces bundled per theme | NFR6 licensing; no third-party CDN call |

### Open item

Real brand names are unknown. Implementation proceeds with slugs `client-piano` and `client-jam` and display names "Piano Store & Services" / "Fruit Jam Production". Renaming later touches the theme folder, the `style.css` header, and `theme.json` only.

## 3. Repository structure

```
docker-compose.yml   .env.example   package.json   .editorconfig   .gitignore
base/theme-template/          # tokenised starter, seeded from create-block --variant theme
shared/tokens/                # color / typography / spacing preset JSON
shared/patterns/              # populated only when BOTH themes need a section
shared/build/                 # shared @wordpress/scripts config
themes/client-piano/
themes/client-jam/
scripts/new-client.sh  scripts/sync-shared.sh  scripts/package-theme.sh  scripts/verify.sh
dist/                         # packaged .zip output (gitignored)
```

## 4. Local environment (FR4, NFR4)

Docker Compose with four services:

- **db** — MySQL 8.4, named volume for data.
- **wordpress** — `wordpress:${WP_VERSION}-php${PHP_VERSION}-apache` on `:8080`. WP core in a named volume so plugins and uploads survive restarts. `./themes` bind-mounted over `wp-content/themes`, so every client theme is present at once and host edits (including Claude Code's) appear live with no rebuild.
- **cli** — `wordpress:cli` sharing the same volumes, for all wp-cli work.
- **init** — one-shot: installs WordPress, then installs and activates WooCommerce and Theme Check.

`WP_VERSION` and `PHP_VERSION` come from `.env`, which is how current / current-minus-one is tested without editing compose.

## 5. Build pipeline (FR6)

`@wordpress/scripts` with webpack config shared from `shared/build/`. Each theme has `src/` (SCSS + JS) compiled to `build/`. `functions.php` enqueues via the generated `build/*.asset.php` so versions and dependencies are derived, never hardcoded.

## 6. Command surface

The root `package.json` is the only interface anyone needs:

```
npm run env:up | env:down | env:reset | env:cli
npm run new-client -- piano "Piano Store & Services"
npm run sync-shared -- client-piano
npm run build|watch -- client-piano
npm run lint | format
npm run check -- client-piano        # Theme Check in-container
npm run package -- client-piano      # dist/client-piano-1.0.0.zip
npm run verify -- client-piano       # full gate, see §9
```

### Script behaviour and failure modes

- **new-client.sh** — validates the slug (lowercase, alphanumeric + hyphen), requires a display name, and **refuses to overwrite** an existing theme directory. Copies `base/theme-template/`, substitutes `{{CLIENT_SLUG}}` / `{{CLIENT_NAME}}` / `{{CLIENT_DESCRIPTION}}` / `{{VERSION}}`, merges `shared/tokens/` into the new `theme.json`, and writes an empty `.shared-manifest.json`. Output must be activatable with zero manual fixup (FR1).
- **sync-shared.sh** — copies named shared patterns into `themes/<slug>/patterns/` with a provenance header comment, recording source path, revision, and checksum in `.shared-manifest.json`. If a theme's local copy no longer matches its recorded checksum, the sync **aborts** rather than clobbering deliberate client divergence; `--force` overrides.
- **package-theme.sh** — refuses to build a zip if lint or Theme Check fail. Copies runtime files only; `src/`, `node_modules/`, configs, and `.shared-manifest.json` are excluded (FR7, NFR5). Zip name derives from the theme's own version (FR8).

## 7. Design systems (FR2)

Each client's identity lives entirely in `theme.json` — palette, fluid type scale, spacing scale, layout widths — so the client can adjust it in the Site Editor. Each theme also ships one alternate style variation in `styles/`. All palette pairings are verified to WCAG 2.1 AA contrast before shipping (NFR3). The two are deliberately pulled apart on ground, type, and rhythm so they do not read as the same site.

**Piano Store & Services** — showroom, warm and considered. A slow, high-value purchase sold on craft and trust.

- Palette: ink `#12100D`, paper `#F7F3EC`, walnut `#7A5230`, brass `#C08A3E`, muted `#6B6259`
- Type: Fraunces (display, optical sizing) + Inter (body)
- Layout: content 720px, wide 1240px; 8-step spacing scale, generous; fluid type enabled

**Fruit Jam Production** — preserves, bright and appetising. Retail jars plus wholesale.

- Palette: damson `#4A1230`, cream `#FFF9F0`, jam `#C8305B`, leaf `#5E8C4A`, ink `#241A20`
- Type: Bricolage Grotesque (display) + Public Sans (body)
- Layout: content 760px, wide 1200px; tighter spacing scale, heavier weights, rounded corners

## 8. Theme contents

Both themes get the standard block-theme template set — `index`, `front-page`, `page`, `single`, `archive`, `search`, `404` — plus `parts/header.html` and `parts/footer.html`, authored as **native core-block markup**. No Custom HTML blocks (PRD R1); post listings use Query Loop.

WooCommerce adds `archive-product`, `single-product`, `taxonomy-product_cat`, `page-cart`, `page-checkout`, and `order-confirmation`, built from Woo's own blocks so they inherit `theme.json` styling.

Content shapes diverge, and this is where the themes stop being twins:

- **Piano** — a small catalogue of high-value instruments (grand, upright, digital, pre-owned) alongside **service** pages (tuning, repair, restoration, rental) with an enquiry/booking path and a showroom/visit page.
- **Jam** — a wide catalogue of packaged goods and gift sets, a **wholesale/trade** enquiry path, a facility-and-process story, stockists, and recipes via the blog.

## 9. Verification (`npm run verify -- <theme>`)

Block themes are not meaningfully unit-testable; the meaningful test is that the *delivered artifact* builds, passes standards, installs clean, and renders. One command per theme, failing on first error:

1. `wp-scripts lint:js` and `lint:style`, plus `php -l` on every PHP file
2. `theme.json` validated against the published WordPress schema
3. **Theme Check** via wp-cli in the container — zero errors (NFR1)
4. `package` the theme, then assert the zip contains no `src/`, `node_modules/`, or config files
5. **Install that zip into a clean WordPress** in the container and activate it — tests the deliverable, not the working tree
6. Route smoke test: home, single post, page, search, 404, product archive, single product, cart, checkout each return 200 with no PHP notices in the log
7. `pa11y-ci` against home plus one product page for WCAG 2.1 AA regressions (NFR3)

## 10. Out of scope

Demo/seed content (PRD FR9), CI, client hosting or deployment, and any shared *parent* theme. Shared patterns are populated only as the two builds produce genuine duplicates — `shared/patterns/` starting empty is a valid outcome of this phase, not a failure.

## 11. Licensing note

The repository root ships an Apache-2.0 `LICENSE`, but NFR6 requires delivered themes be GPLv2-or-later compatible. Each delivered theme carries its own GPL-2.0-or-later declaration in its `style.css` header, and the mismatch at the repo root must be resolved before the first client handoff.
