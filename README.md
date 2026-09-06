# Client Themes

A monorepo producing one standalone WordPress block theme per client website. Each theme is
delivered as a self-contained `.zip` with no runtime dependency on this repository.

See [docs/PRD.md](docs/PRD.md) for the product definition and [CLAUDE.md](CLAUDE.md) for the
command surface, architecture and the things that will otherwise cost you an hour.

## Quick start

```bash
npm install

npm run env:use -- piano            # point local commands at this client's stack
npm run env:up && npm run env:init  # WordPress + WooCommerce at http://localhost:8080
npm run seed -- piano               # demo products, pages and posts to look at
```

Each client runs as its own Docker Compose project with its own database, so two client sites can
run side by side without their content mixing — `piano` on :8080, `jam` on :8081.

## Adding a client

```bash
npm run new-client -- acme "Acme Ltd"   # scaffold themes/client-acme
npm run build -- client-acme            # compile its assets
npm run verify -- client-acme           # prove it is deliverable
```

`npm run verify` is the gate that decides whether a theme can be handed over. It lints, validates
`theme.json`, runs Theme Check, builds and packages the theme, **installs that zip into WordPress
and activates it**, renders every route while watching for PHP notices, and runs an accessibility
scan against WCAG 2.1 AA. A theme that passes has been proven as the packaged artifact, not as a
working tree. It fails closed: a step that cannot verify its claim fails the run rather than
reporting a pass.

## Current clients

| Theme | Business |
|---|---|
| `client-piano` | Piano dealer — instrument sales, tuning, repair, restoration and hire |
| `client-jam` | Preserves producer — retail jars and wholesale supply |

Both sell through WooCommerce and ship self-hosted OFL fonts.

## Licensing

This repository is Apache-2.0. **Delivered themes are GPL-2.0-or-later**, declared in each
theme's `style.css`, as WordPress themes must be. Bundled fonts and images must be cleared for
commercial client use — the demo content uses CC0 and public-domain images only, so no client
site inherits an attribution obligation.
