# PRD — Multi-Client WordPress Block Theme Repository

| Field | Value |
|---|---|
| **Product** | A monorepo for building, maintaining, and delivering WordPress block themes for multiple client websites |
| **Version** | 1.0 (Draft) |
| **Status** | Proposed |
| **Owner** | Repository maintainer / lead developer |
| **Last updated** | 2026-08-21 |

---

## 1. Summary

This repository is a single workspace ("monorepo") that produces one self-contained WordPress **block theme** per client website. The business model is website resale: for each client, a bespoke block theme is designed, built, packaged, and delivered as the front end of their WordPress site. The repository standardizes how new client themes are scaffolded, how design work is turned into code, how each theme is developed and tested locally, and how it is packaged and handed off — so that spinning up the Nth client site is fast, consistent, and low-risk.

The core workflow that this repository is optimized around is: **design in Claude Design → hand off to Claude Code → Claude Code writes block-theme files directly into the repository → the theme runs live in a local Dockerized WordPress instance → package and deliver to the client.**

---

## 2. Background & problem statement

Building each client website from scratch is slow and inconsistent. Common failure modes when running many client sites without shared structure:

- Every theme reinvents its folder structure, `theme.json` shape, build tooling, and local setup.
- Design-to-code is manual and error-prone; visual work is redone by hand as PHP/HTML.
- Shared UI (headers, footers, hero sections, CTAs, pricing tables) is copy-pasted and drifts across projects.
- Local environments differ per developer/machine, causing "works on my machine" issues.
- Delivery is ad hoc — no repeatable packaging or handoff, and no clean way to update a client theme later.

This PRD defines a repository whose explicit goal is to remove that friction and make each additional client theme cheap to produce and safe to maintain.

---

## 3. Goals

- **G1 — Fast client onboarding.** Scaffold a new, fully structured client block theme in minutes with a single command.
- **G2 — Consistency.** Every client theme shares the same base structure, tooling, coding standards, and quality bar, while remaining visually independent.
- **G3 — Design-to-code pipeline.** A first-class path from Claude Design output to a working block theme via Claude Code, minimizing manual re-implementation.
- **G4 — Isolation & safe delivery.** Each client theme is a standalone deliverable; changes to one client can never break another.
- **G5 — Reproducible local development.** Any developer can run any client theme locally with one command using Docker.
- **G6 — Maintainability at scale.** Shared code (patterns, tokens, tooling) is reusable without creating runtime coupling between client sites.
- **G7 — Clean handoff.** Each theme can be exported as a production-ready, standards-compliant, GPL-licensed `.zip` ready to install on the client's host.

---

## 4. Non-goals

- **NG1** — This repository is not a single distributable theme or a theme "framework" sold to third parties.
- **NG2** — It does not manage client hosting, DNS, or production infrastructure (delivery ends at a deployable theme package).
- **NG3** — It does not aim to support classic (PHP-template) themes; the standard is block themes (Full Site Editing) only.
- **NG4** — It is not a page-builder replacement; theming targets native core blocks and the Site Editor, not a proprietary builder.
- **NG5** — Client content authoring, marketing, and copywriting are out of scope.

---

## 5. Users & stakeholders

- **Primary user — the developer/agency.** Scaffolds, designs, builds, and delivers client themes. Needs speed, consistency, and reliable tooling.
- **Secondary user — the client / site administrator.** Receives a theme they can edit in the WordPress Site Editor. Needs an intuitive, on-brand, editable theme.
- **Tooling — Claude Design & Claude Code.** Design generation and design-to-code conversion; treated as part of the standard workflow.

---

## 6. Solution overview

A monorepo containing:

1. An **internal starter template** used to scaffold each new client theme.
2. A **`themes/` directory** holding one standalone block theme per client.
3. A **`shared/` library** of reusable block patterns, `theme.json` presets/design tokens, and build configuration that are composed into client themes at scaffold/build time (not as a runtime dependency).
4. A **Dockerized local WordPress environment** in which any client theme can be developed and previewed live.
5. **Scaffolding and build scripts** that automate creating, building, and packaging themes.

### 6.1 Theme isolation model (key architectural decision)

**Decision: each client theme is a fully standalone block theme.** Shared code is injected at scaffold time and/or compiled in at build time; there is no shared *parent theme* that client sites depend on at runtime.

**Rationale.** In a website-resale model the delivered artifact must be self-contained: one theme = one `.zip` a client can install and run with no external dependency. Standalone themes guarantee that (a) delivery and handoff are clean, (b) a change made for one client cannot regress another, and (c) each theme can be versioned, updated, or retired independently.

**Alternatives considered and rejected:**

- *Shared parent + per-client child themes.* Rejected for delivery: every client install would depend on the parent, updating the parent risks breaking all clients at once, and handoff requires shipping two coupled themes. Central updates are convenient but the blast radius is unacceptable for paid client sites.
- *Independent copies with no sharing.* Rejected as unmaintainable: shared UI and tokens would drift and improvements couldn't be propagated.

The chosen "standalone theme + shared source that is composed in" model captures the DRY benefit at authoring time while keeping the runtime output isolated.

### 6.2 Proposed repository structure

```
wordpress/                     # monorepo root
├── PRD.md
├── docker-compose.yml             # local WordPress + MySQL
├── package.json                   # workspace scripts, shared dev deps
├── .editorconfig / linting configs
├── base/
│   └── theme-template/            # internal starter used to scaffold client themes
├── shared/
│   ├── patterns/                  # reusable block patterns (hero, CTA, pricing, ...)
│   ├── tokens/                    # theme.json presets: color/typography/spacing scales
│   └── build/                     # shared @wordpress/scripts build config
├── themes/
│   ├── client-acme/               # standalone block theme (delivered as-is)
│   ├── client-globex/
│   └── client-initech/
└── scripts/
    ├── new-client.sh              # scaffold a new client theme from base/ + shared/
    └── package-theme.sh           # build + zip a theme for delivery
```

---

## 7. Functional requirements

### FR1 — Scaffold a new client theme
A single command creates a new standalone block theme under `themes/<client>/`, pre-populated with the base template structure and the current shared patterns/tokens. The scaffold must produce a valid, activatable block theme (`style.css` header, `theme.json`, `templates/`, `parts/`, `patterns/`) with no manual fixup required.
- The base template should build on the official scaffolder (`npx @wordpress/create-block --variant theme`) or the Create Block Theme plugin's blank-theme output, so structure stays aligned with WordPress standards.

### FR2 — Per-client design system in `theme.json`
Each client theme must express its full visual identity through `theme.json` settings: color palette, typography scale, spacing scale, and layout widths. This ensures brand consistency across templates and lets the client adjust styles in the Site Editor.

### FR3 — Shared block-pattern & token library
Reusable sections (header, footer, hero, feature grid, CTA, pricing, testimonials, etc.) live in `shared/patterns/` and are composed into client themes. Shared design tokens live in `shared/tokens/`. Updating a shared pattern must be propagatable to client themes deliberately (via re-scaffold/sync), never automatically at runtime.

### FR4 — Reproducible local development environment
The repository ships a Docker-based local WordPress + MySQL stack. Any client theme in `themes/` must be developable and previewable live: files edited on the host (including by Claude Code) appear immediately in the running site via bind mounts, with no rebuild.
- Implementation options: (a) bind-mount the repo `themes/` directory into the container's theme path; or (b) use `@wordpress/env` (`.wp-env.json`), which maps multiple themes cleanly and is purpose-built for multi-theme WordPress development. Either must support switching the active client theme without reconfiguration friction.

### FR5 — Design-to-code pipeline (Claude Design → Claude Code)
The repository must support the standard pipeline:
1. Design a client's screens and design system in Claude Design (header, footer, homepage, single, archive; sections built as reusable blocks).
2. Hand off to Claude Code (handoff bundle or the Claude Design MCP server).
3. Claude Code converts the design into **block-theme output**: mapping the design system into `theme.json`, building templates as native core-block HTML markup (avoiding Custom HTML blocks), creating template parts and block patterns, and using the Query Loop block for post listings.
4. Claude Code writes these files directly into `themes/<client>/`, where they run live in the local Docker instance.

### FR6 — Build & asset pipeline
Themes use a shared build pipeline (`@wordpress/scripts`) for compiling/optimizing CSS/JS and, where needed, custom blocks. Build output must be deterministic and enqueued correctly (no hardcoded asset tags).

### FR7 — Packaging & delivery
A command produces a production-ready `.zip` for a single client theme, containing only the files needed to run (no dev tooling, no repo scaffolding). The output must be installable on any standard WordPress host and pass basic theme-check validation.

### FR8 — Versioning & maintenance
Each client theme carries its own version. The repository must support maintaining and re-delivering an individual client theme later without touching others. Shared-library changes are opt-in per client.

### FR9 — Demo/seed content (optional, phase 2)
Optionally, each theme can ship with importable demo content / starter pages so a new client site looks complete on first install.

---

## 8. Non-functional requirements

- **NFR1 — Standards compliance.** Themes follow WordPress block-theme standards and pass Theme Check; markup relies on native core blocks so the Site Editor remains fully functional.
- **NFR2 — Performance.** Lightweight front end (server-rendered blocks, minimal JS, optimized assets); target strong Core Web Vitals on a standard shared host.
- **NFR3 — Accessibility.** Templates and patterns meet WCAG 2.1 AA basics (semantic structure, color contrast, keyboard navigation, focus states).
- **NFR4 — Compatibility.** Support current and current-minus-one WordPress major versions and supported PHP versions; test against them locally.
- **NFR5 — Security.** No untrusted code, proper escaping in any dynamic PHP, dev-only tooling excluded from delivered packages.
- **NFR6 — Licensing.** All delivered themes are GPLv2-or-later compatible; bundled assets (fonts, images) must be appropriately licensed for client use.
- **NFR7 — Maintainability.** Consistent structure, linting, and formatting across all themes; shared tooling to keep entropy low as the client count grows.
- **NFR8 — Browser support.** Modern evergreen browsers; graceful degradation where reasonable.

---

## 9. Tooling & tech stack

- **CMS / theming:** WordPress block themes (Full Site Editing), `theme.json`, core blocks, block patterns, template parts.
- **Scaffolding:** `@wordpress/create-block --variant theme`; Create Block Theme plugin for Site-Editor-to-file round-trips.
- **Build:** `@wordpress/scripts` (webpack-based), shared config.
- **Local environment:** Docker Compose (WordPress + MySQL), optionally `@wordpress/env`.
- **Design & codegen:** Claude Design (design system + prototypes), Claude Code (design-to-block-theme conversion, file authoring in the repo).
- **Quality:** Theme Check, linting/formatting (`wp-scripts lint`/`format`), accessibility checks.
- **Version control:** Git monorepo; per-theme versioning.

---

## 10. Per-client development workflow

1. **Init.** Run the scaffold command to create `themes/<client>/` from the base template + shared library.
2. **Design.** Produce the client's design system and screens in Claude Design.
3. **Convert.** Hand off to Claude Code; it writes `theme.json`, templates, parts, and patterns into `themes/<client>/`.
4. **Develop & preview.** Run the local Docker stack; activate the theme; iterate in the Site Editor and via Claude Code until it matches the design.
5. **Harden.** Run Theme Check, accessibility and performance passes, and lint/format.
6. **Package.** Build and zip the theme for delivery.
7. **Deliver.** Install on the client's host; hand over documentation for editing in the Site Editor.
8. **Maintain.** Re-open the theme later for updates; optionally sync in improved shared patterns.

---

## 11. Milestones

- **Phase 0 — Foundation.** Repo structure, Docker local environment, base template, scaffold script, one reference client theme end-to-end.
- **Phase 1 — Shared library.** Extract common patterns and design tokens into `shared/`; wire them into scaffolding.
- **Phase 2 — Pipeline hardening.** Standardize the Claude Design → Claude Code conversion steps and prompts; add quality gates (Theme Check, lint, a11y).
- **Phase 3 — Delivery automation.** One-command packaging and delivery; optional demo-content seeding.
- **Phase 4 — Scale.** Documentation, contribution/coding standards, and a repeatable playbook for onboarding new clients.

---

## 12. Success metrics

- **Time-to-first-preview** for a new client theme (target: minutes to a live, activatable theme).
- **Time-to-delivery** from signed brief to packaged theme.
- **Reuse rate** of shared patterns/tokens across client themes.
- **Defect isolation:** zero cross-client regressions caused by shared changes.
- **Standards pass rate:** all delivered themes pass Theme Check and baseline a11y/perf targets.

---

## 13. Risks & open questions

- **R1 — Design-to-block fidelity.** Free-form Claude Design HTML does not always map 1:1 onto core-block markup + `theme.json`. Mitigation: constrain designs to what core blocks + `theme.json` can express; use style variations / custom CSS via `theme.json` `styles` where needed; avoid Custom HTML blocks.
- **R2 — Shared-code propagation.** Because themes are standalone, shared improvements require a deliberate sync mechanism. Open question: re-scaffold vs. a sync command vs. a lightweight build-time composition step.
- **R3 — Local multi-theme ergonomics.** Managing many themes in one Docker instance; decide between multi-mount Compose and `@wordpress/env`.
- **R4 — Client editability vs. developer control.** Clients editing in the Site Editor may diverge from repo source. Open question: expected round-trip policy (e.g., Create Block Theme to export changes back, or treat repo as source of truth).
- **R5 — Asset licensing.** Fonts/images bundled per client must be cleared for commercial client use.

---

## Appendix A — Where to get an "init"/starter block theme

- **`@wordpress/create-block` (official CLI, recommended for this repo).** `npx @wordpress/create-block@latest <name> --variant theme` generates a full block-theme structure (`theme.json`, templates, parts, patterns) with a `@wordpress/scripts` build pipeline. Best fit for scripted, reproducible scaffolding.
- **Create Block Theme (official WordPress.org plugin).** https://wordpress.org/plugins/create-block-theme/ — generate a blank theme, child theme, clone, or style variation from wp-admin; can save Site Editor changes back to theme files; embeds Google/local fonts. Development-only tool.
- **Block Theme Generator (web).** https://fullsiteediting.com/block-theme-generator/ — downloads a `.zip` starter block theme with the standard templates/parts/patterns; convenient for a quick reference baseline.
- **Reference default theme.** Twenty Twenty-Five (bundled with WordPress) is a clean, full block theme useful as a structural reference — not a blank starter.
- **Community starters (GitHub).** e.g. `itsamoreh/block-theme-starter` and `bacoords/block-theme` add opinionated tooling (custom-block scaffolding, `wp-env`, CI) on top of the base structure.
