---
name: experimental-cross-run-discovery
description: >
  Learn ACROSS the user's agent runs — mine the accumulated substrate (provenance notes / saved
  notes) for recurring patterns, gate them by frequency, and surface ONLY the proven ones
  (withhold one-offs). The fourth moat axis: retrieval pulls context IN, write-back pushes results
  OUT, verification checks TRUTH, and this DISCOVERS what recurs across sessions. Use for the user
  Skills library (recurring tool workflows), "you always do X after Y" suggestions, or any
  cross-session learning. Class: scan substrate corpus → mine candidates → frequency/novelty gate →
  surface gate-passed only. Composes experimental-run-provenance (the per-run records it mines).
---

# Experimental: cross-run discovery (learn across sessions)

## Why (the moat, fourth axis)
No standalone agent app learns across sessions — each boots cold. Epistemos accumulates a durable
record of every run (provenance notes in the vault), so it can notice what the user *repeatedly*
does and offer it back. This is the "user Skills library" of Finalization #3 — and note it IS
applicable here (the tool sequences come from the CLI agent), unlike the agent_core ReplayBundle
(`.epbundle`), which is an in-process-runtime feature that CLI agents don't populate.

## The pattern
1. **The corpus is the substrate you already write.** run-provenance writes `Provenance--*.md` notes
   (each = one run's tool sequence). Read them read-only over `EPISTEMOS_VAULT_ROOT` (never touch the
   vault engine). Parse the ordered items with a stable regex (`^\s*\d+\.\s+\*\*([^*]+)\*\*`).
2. **Mine candidates deterministically** — e.g. contiguous tool subsequences length [2,4], deduped
   per run. Key them with a delimiter no item contains (`"|::|"`, NOT `""` — that collides and can
   only be split by char).
3. **GATE by frequency across DISTINCT runs** — a candidate passes only if it recurs across
   `>= minRuns` runs; below that it is WITHHELD (never surfaced as proven). Drop candidates subsumed
   by a longer, >=-frequency one (keep the most specific frequent workflow). No LLM — pure + testable.
4. **Surface gate-passed only** — a compact web panel (reuse an existing popover; no new button).
   Hidden entirely when nothing passes — honest: "learned workflows" appear only once they recur.

## Verification (DoD)
Pure + deterministic → verify HEADLESS with a fixture corpus: N runs sharing a sequence → it is
discovered with the right frequency; a one-off → WITHHELD. (Proven: 4 provenance notes →
`search_notes → read_file` freq 3 discovered, `WebFetch → Write` one-off withheld.) Add it to the
regression witness. Every fork edit → a `PATCH_LEDGER.md` row.

## Reuse targets
- Promote a discovered workflow into a named, applyable macro (compose experimental-submission-enhance
  to draft a description; user-review before it's "a skill" — the acceptance gate).
- Mine saved notes (not just provenance) for recurring topics → "you keep returning to X."
- Combine with experimental-substrate-verification: only count a run whose citations checked out.
