# Vendored: osaurus-ai/osaurus (Osaurus Act substrate, P3.0)

**This is a full, take-control vendor of the entire Osaurus app** (owner directive
2026-06-21: "the ENTIRE app, settings, everything, zero cherry-pick"). The `.git`
history was stripped — this is now OUR source, not a live submodule.

| Field | Value |
|-------|-------|
| Upstream | https://github.com/osaurus-ai/osaurus |
| Pinned commit | `ae3a3c5d01ded68a2d5feec9ef75519905925411` |
| Clone date | 2026-06-21 |
| License | **MIT** — Copyright (c) 2026 Osaurus, Inc. (see `LICENSE`) |
| ProvenanceGate verdict | `direct_import` (MIT permissive, MAS/closed-source compatible) |
| Update command | `scripts/update-osaurus.sh` (re-clones latest, re-pins this SHA) |

## What was kept / dropped
- **Kept:** the full source — `App/`, `Packages/OsaurusCore/` (the SPM core library to
  link in S3), `OsaurusCLI` equivalents, `scripts/`, `Makefile`, `LICENSE`, `README.md`,
  `docs/`, `assets/`, `sandbox/Dockerfile`, `osaurus.xcworkspace`. Zero source cherry-pick.
- **Dropped/ignored:** upstream `.git`; generated benchmark output under `results/`
  (left ignored via upstream's own `.gitignore` — regenerable, not source).
- A parent-repo `.gitignore` exception (`!LocalPackages/osaurus/Packages/**`) prevents the
  broad `Packages/` SwiftPM rule from swallowing OsaurusCore.

## Build wiring status (honest)
- **NOT yet linked into the Epistemos Xcode build.** This commit vendors the source on
  disk only (S2-vendor). Linking `OsaurusCore` (Pro-gated, `#if !EPISTEMOS_APP_STORE`)
  via xcodegen is the next slice (S3). Until then this source is inert and cannot affect
  the Epistemos build — the existing `ActOsaurusBridge` seam stays honest/inert.

## Conflict-resolution policy (owner 2026-06-21)
On any clash between the owner's IP / existing app and Osaurus: **favor Osaurus.**
Cherry-pick only the owner's IP / app parts that *work with* Osaurus and port them onto
the Osaurus engine. The front-end stays **minimal Epistemos pixel-art native style** —
reskin Osaurus views to app chrome; for surfaces the app lacks, build new pixel-art native
front-ends. Never delete the quarantined chat; port its compatible IP, then retire only
after the 4-part bar + owner OK.
