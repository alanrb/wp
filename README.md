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
