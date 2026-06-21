# Osaurus addendum (2026-06-21) — "Epistemos Picks" model section + harden-after

**Owner (verbatim, 2026-06-21):** *"we can just add my models to the osaurus stack as a section that
says epistemos picks or whatever a clever name so i don't lose my custom hardened models and such. i
would just need to start hardening all the things that exist after the osaurus clone."*

## DESIGN DECISION — "Epistemos Picks" curated section in the Osaurus/act model stack
- When Osaurus is cloned in, its model stack/picker gets a dedicated section (working name **"Epistemos
  Picks"** — owner open to a cleverer name) that surfaces the owner's CUSTOM HARDENED models (the QAT
  GGUF ladder, MLX picks, etc.) sourced from the EXISTING standalone catalog
  `Epistemos/Engine/LocalModelInfrastructure.swift` / LocalModelCatalog / GemmaQATRuntimeLadder.
- This is how the owner's models are PRESERVED + PORTED (per the quarantine guard): not lost, not
  re-imported — the same catalog, surfaced as a curated, top-billed section inside the Osaurus act UI.
- Osaurus already drives "the same on-device models the app routes to" (`LocalModelServer.swift`), so
  this is a UI/section + wiring task over an existing model layer, not a model re-build.
- Honest selection in this section: NO silent Qwen substitute; too-large = honest message (the old chat
  fallback requirement lands HERE, in the new act stack — not as a patch to the quarantined chat).

## SEQUENCING (reaffirmed): Osaurus full clone FIRST → wire "Epistemos Picks" + port IP → THEN harden
ALL existing things on the cloned surface. Hardening the everything-that-exists happens AFTER the clone,
per owner. Cross-ref CHAT_BACKEND_QUARANTINE_NEVER_DELETE_2026_06_21.md (never delete the quarantined
chat) + OSAURUS_P3_IMPORT_PLAN_2026_06_19.md (full-clone strategy + 2026-06-21 directive).
