# Shared block patterns

A pattern belongs here **only once two client themes genuinely need it**. Until
then it lives in the theme that uses it. Do not add patterns speculatively.

Each file is a standard WordPress pattern with a `Slug: shared/<name>` header;
`scripts/sync-shared.sh` rewrites that slug to the consuming theme's namespace
when it copies the file in.

Sync is deliberate and copy-based — nothing here is loaded at runtime by a
delivered theme. Editing a synced pattern inside a client theme is allowed; the
next sync will refuse to overwrite it until you pass `--force`.
